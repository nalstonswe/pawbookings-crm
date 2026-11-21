# Populates one already-created business with a realistic-looking history:
# staff, customers, pets, availability, and bookings spread across the past
# six weeks and the next five, in every status, with backdated timestamps.
#
# Bookings go through the real service objects (BookingRequestService,
# BookingAcceptance, BookingDenial, BookingCancellation) so capacity checks
# and allocations are exactly what production traffic would produce -- a
# booking that doesn't fit is denied, just like it would be in the app.
# Only timestamps are rewritten afterwards (update_all/update_columns) to
# give the data a believable timeline; nothing is invented that the
# services didn't create.
#
# Everything is driven by a per-business Random seed, so a fresh database
# always gets the same data. The whole business is populated inside one
# transaction and skipped once it already has its target number of
# customers, which keeps `db:seed` idempotent.
class DemoBusinessSeeder
  PAST_DAYS = 42
  FUTURE_DAYS = 35

  PAST_OUTCOMES = { completed: 70, cancelled: 12, denied: 18 }.freeze
  IN_PROGRESS_OUTCOMES = { accepted: 85, cancelled: 5, denied: 10 }.freeze
  FUTURE_OUTCOMES = { pending: 22, accepted: 56, denied: 9, cancelled: 13 }.freeze
  VACCINATION_STATUSES = { up_to_date: 68, expired: 14, unknown: 18 }.freeze
  PET_COUNTS = [ 1, 1, 1, 1, 1, 2, 2, 2, 3 ].freeze
  BOARDING_NIGHTS = [ 1, 2, 2, 3, 3, 4, 5, 7 ].freeze

  def initialize(business:, spec:, password_digest:, names:, shared_customers:)
    @business = business
    @spec = spec
    @password_digest = password_digest
    @names = names.dup
    @shared_customers = shared_customers
    @rng = Random.new(spec.fetch(:seed))
    @now = Time.current
  end

  # Returns the business's customer Users (used to share a few of them with
  # the next business).
  def call
    if populated?
      log("already populated, skipping")
    else
      Time.use_zone(@business.time_zone) { ActiveRecord::Base.transaction { populate } }
    end
    @business.memberships.customer.includes(:user).map(&:user)
  end

  private

  attr_reader :rng

  def populated?
    @business.memberships.customer.count >= @spec[:customers]
  end

  def populate
    @biz_created_at = @now - rng.rand(240..540).days
    @first_activity = {}

    configure_business
    @offerings = ensure_offerings
    @slots = ensure_slots
    @staff = ensure_staff
    @customers = ensure_customers
    ensure_pets
    @hot_slots = @offerings.to_h { |offering, _| [ offering.id, @slots[offering.id].select(&:active?).sample(6, random: rng) ] }
    @records = create_bookings
    finalize_bookings
    backdate_customers

    log(summary)
  end

  # -- business, offerings, availability --------------------------------

  def configure_business
    @business.update!(settings: @business.settings.merge("cancellation_window_hours" => @spec[:cancellation_window_hours]))
    backdate(@business, @biz_created_at)
  end

  def ensure_offerings
    @spec[:offerings].map do |os|
      attrs = {
        name: os[:name], service_kind: os[:kind], default_capacity: os[:capacity],
        default_duration_minutes: os[:duration], description: os[:description],
        customer_facing_instructions: os[:instructions], active: os.fetch(:active, true)
      }
      offering = @business.service_offerings.find_by(name: os[:name])
      offering ||= @business.service_offerings.find_by(name: os[:replaces]) if os[:replaces]

      if offering
        offering.update!(attrs)
      else
        offering = @business.service_offerings.create!(attrs)
      end
      backdate(offering, @biz_created_at + 1.hour)
      [ offering, os ]
    end
  end

  def ensure_slots
    zone = @business.time_zone
    today = Date.current
    closed_days = Array.new(3) { today + rng.rand(-PAST_DAYS..FUTURE_DAYS) }
    slots = Hash.new { |hash, id| hash[id] = [] }

    (-PAST_DAYS..FUTURE_DAYS).each do |offset|
      day = today + offset

      @offerings.each do |offering, os|
        next unless offering.active?

        schedule = os[:schedule]
        if schedule[:nightly]
          slots[offering.id] << find_or_create_slot(offering, day.in_time_zone(zone), (day + 1).in_time_zone(zone), true)
        elsif schedule[:days].include?(day.wday)
          schedule[:windows].each do |from, to|
            starts_at = day.in_time_zone(zone).change(hour: from)
            ends_at = day.in_time_zone(zone).change(hour: to)
            slots[offering.id] << find_or_create_slot(offering, starts_at, ends_at, !closed_days.include?(day))
          end
        end
      end
    end

    # Slots are normally published a few weeks ahead of time.
    published_at = "LEAST(starts_at - interval '21 days', now() at time zone 'utc')"
    @business.availability_slots.update_all("created_at = #{published_at}, updated_at = #{published_at}")
    slots
  end

  def find_or_create_slot(offering, starts_at, ends_at, active)
    capacity = offering.default_capacity
    capacity = [ capacity + rng.rand(-2..3), 1 ].max if rng.rand < 0.12

    offering.availability_slots.find_or_create_by!(starts_at: starts_at, ends_at: ends_at) do |slot|
      slot.business = @business
      slot.capacity = capacity
      slot.active = active
    end
  end

  # -- people -----------------------------------------------------------

  def ensure_staff
    domain = @spec[:domain]
    total = @spec[:employees]
    extra_roles = []
    extra_roles << :owner if total >= 9
    extra_roles << :admin if total >= 6
    extra_roles.concat([ :staff ] * (total - 3 - extra_roles.size))

    accounts = [ [ "owner@#{domain}", :owner ], [ "admin@#{domain}", :admin ], [ "staff@#{domain}", :staff ] ]
    extra_roles.each do |role|
      first, last = @names.shift
      accounts << [ "#{slug(first)}.#{slug(last)}@#{domain}", role ]
    end

    staff = accounts.map do |email, role|
      user = find_or_create_user(email)
      membership = @business.memberships.find_by(user: user) || @business.memberships.create!(user: user, role: role)
      joined_at = role == :owner && email.start_with?("owner@") ? @biz_created_at : @biz_created_at + rng.rand(1..120).days
      backdate(user, joined_at)
      backdate(membership, joined_at)
      { user: user, membership: membership, joined_at: joined_at }
    end

    record_staff_history(staff)
    staff
  end

  # Audit trail for how the team got to its current shape, so the audit
  # log page isn't empty before anyone acts on a booking.
  def record_staff_history(staff)
    owner = staff.first[:user]

    staff.select { |s| s[:membership].admin? }.each do |admin|
      created_at = [ admin[:joined_at] + rng.rand(30..120).days, @now - 1.day ].min
      audit("membership.role_changed", admin[:membership], created_at, actor: owner,
            metadata: { from: "staff", to: "admin", user_id: admin[:user].id })
    end

    previous_window = 24
    return if @spec[:cancellation_window_hours] == previous_window

    created_at = [ @biz_created_at + rng.rand(30..100).days, @now - 1.day ].min
    audit("business.settings_changed", @business, created_at, actor: owner, metadata: {
      before: { "name" => @business.name, "time_zone" => @business.time_zone,
                "settings" => { "cancellation_window_hours" => previous_window } },
      after: { "name" => @business.name, "time_zone" => @business.time_zone,
               "settings" => { "cancellation_window_hours" => @spec[:cancellation_window_hours] } }
    })
  end

  def ensure_customers
    domain = @spec[:domain]
    count = @spec[:customers]
    users = [ find_or_create_user("customer@#{domain}") ]

    # A few people use more than one business on the platform.
    users.concat(@shared_customers.first(@spec[:shared_customers]))
    users.uniq!

    @names.first(count).each_with_index do |(first, last), index|
      break if users.size >= count

      email_domain = DemoCatalog::CUSTOMER_EMAIL_DOMAINS[index % DemoCatalog::CUSTOMER_EMAIL_DOMAINS.size]
      users << find_or_create_user("#{slug(first)}.#{slug(last)}@#{email_domain}")
    end

    users.map do |user|
      membership = @business.memberships.find_by(user: user) || @business.memberships.create!(user: user, role: :customer)
      { user: user, membership: membership, pets: [] }
    end
  end

  def find_or_create_user(email)
    User.find_by(email: email) || User.create!(email: email, password_digest: @password_digest)
  end

  def ensure_pets
    @customers.each do |customer|
      existing = @business.pets.where(user: customer[:user]).to_a
      existing = Array.new(PET_COUNTS.sample(random: rng)) { create_pet(customer[:user], existing) } if existing.empty?
      customer[:pets] = existing
    end
  end

  def create_pet(user, siblings)
    name = (DemoCatalog::PET_NAMES - siblings.map(&:name)).sample(random: rng)
    breed, min_kg, max_kg = DemoCatalog::BREEDS.sample(random: rng)
    age_days = 120 + ((rng.rand**1.5) * 14 * 365).to_i
    vaccination_status = weighted(VACCINATION_STATUSES)

    pet = @business.pets.create!(
      user: user, name: name, species: :dog, breed: breed,
      sex: rng.rand < 0.5 ? :male : :female,
      birth_date: Date.current - age_days,
      weight: (min_kg + rng.rand * (max_kg - min_kg)).round(1),
      vaccination_status: vaccination_status,
      vaccination_expires_on: vaccination_expiry(vaccination_status),
      feeding_instructions: maybe(0.6, DemoCatalog::FEEDING_INSTRUCTIONS),
      medication_instructions: maybe(0.12, DemoCatalog::MEDICATION_INSTRUCTIONS),
      behavioral_notes: maybe(0.35, DemoCatalog::BEHAVIORAL_NOTES),
      emergency_notes: maybe(0.1, DemoCatalog::EMERGENCY_NOTES),
      status: rng.rand < 0.05 ? :archived : :active
    )
    siblings << pet
    pet
  end

  def vaccination_expiry(status)
    case status
    when :up_to_date then Date.current + rng.rand(10..350)
    when :expired then Date.current - rng.rand(5..200)
    end
  end

  # -- bookings ---------------------------------------------------------

  def create_bookings
    target = (@customers.size * @spec[:bookings_per_customer]).round
    # Booking activity is heavily skewed: a few regulars book constantly,
    # many book occasionally, and some customers have never booked at all.
    customer_weights = @customers.filter_map do |customer|
      next unless customer[:pets].any?(&:active?)

      [ customer, rng.rand < 0.12 ? 0 : (rng.rand**2) * 9 + 0.5 ]
    end
    offering_weights = @offerings.select { |offering, _| offering.active? }.map { |pair| [ pair, pair.last[:weight] ] }

    Array.new(target) do
      customer = weighted(customer_weights)
      offering, os = weighted(offering_weights)
      window = pick_window(offering, os)
      next unless window

      pets = customer[:pets].select(&:active?)
      pets = pets.sample(rng.rand < 0.75 ? 1 : rng.rand(1..pets.size), random: rng)
      place_booking(customer: customer, offering: offering, pets: pets, window: window, outcome: pick_outcome(window))
    end.compact
  end

  def pick_window(offering, os)
    list = @slots[offering.id].select(&:active?)
    return if list.empty?

    count =
      if os[:schedule][:nightly] then BOARDING_NIGHTS.sample(random: rng)
      elsif offering.daycare? && rng.rand < 0.15 then rng.rand(2..3)
      else 1
      end

    past, future = list.partition { |slot| slot.ends_at <= @now }
    pool = rng.rand < 0.6 ? past : future
    pool = list if pool.empty?
    hot = @hot_slots[offering.id] & pool
    anchor = rng.rand < 0.2 && hot.any? ? hot.sample(random: rng) : pool.sample(random: rng)

    index = [ list.index(anchor), list.size - count ].min.clamp(0..)
    list[index, count]
  end

  def pick_outcome(window)
    if window.last.ends_at <= @now then weighted(PAST_OUTCOMES)
    elsif window.first.starts_at <= @now then weighted(IN_PROGRESS_OUTCOMES)
    else weighted(FUTURE_OUTCOMES)
    end
  end

  def place_booking(customer:, offering:, pets:, window:, outcome:)
    result = BookingRequestService.new(
      business: @business, customer: customer[:user], service_offering_id: offering.id,
      pet_ids: pets.map(&:id), notes: maybe(0.45, DemoCatalog::BOOKING_NOTES),
      requested_starts_at: window.first.starts_at, requested_ends_at: window.last.ends_at
    ).call
    raise "Failed to seed booking: #{result.errors&.full_messages}" unless result.success?

    record = { booking: result.booking, customer: customer, offering: offering, outcome: outcome, accepted: false }

    case outcome
    when :accepted, :completed
      accept(record) || deny(record, DemoCatalog::CAPACITY_DENIAL_REASON)
    when :denied
      deny(record, DemoCatalog::DENIAL_REASONS.sample(random: rng))
    when :cancelled
      accept(record) if rng.rand < 0.6
      BookingCancellation.new(booking: record[:booking]).call
    end

    record
  end

  def accept(record)
    record[:accepted] = BookingAcceptance.new(booking: record[:booking]).call.success?
  end

  def deny(record, reason)
    BookingDenial.new(booking: record[:booking], reason: reason).call
    record.merge!(outcome: :denied, reason: reason)
  end

  # Rewrites timestamps so the history reads like it happened over time
  # (requested ahead of the date, decided within a day or two, completed
  # after the service ended) and records the matching audit events.
  def finalize_bookings
    @records.each do |record|
      booking = record[:booking]
      starts_at = booking.requested_starts_at
      status = record[:outcome]
      decided = record[:accepted] || status == :denied

      created_at = booking_created_at(record, starts_at)
      decided_at = decision_time(created_at, starts_at) if decided
      updated_at =
        case status
        when :pending then created_at
        when :accepted, :denied then decided_at
        when :completed then [ booking.requested_ends_at + rng.rand(10..480).minutes, @now - 1.minute ].min
        when :cancelled then cancellation_time(decided_at || created_at, starts_at)
        end

      Booking.where(id: booking.id).update_all(
        status: status.to_s, created_at: created_at, updated_at: updated_at,
        notified_at: decided ? [ decided_at + rng.rand(1..4).minutes, @now ].min : nil
      )
      BookingPet.where(booking_id: booking.id).update_all(created_at: created_at, updated_at: created_at)
      if decided && status != :cancelled && status != :denied
        BookingAllocation.where(booking_id: booking.id).update_all(created_at: decided_at, updated_at: decided_at)
      end

      record_decision_audit(record, decided_at)
      user_id = record[:customer][:user].id
      @first_activity[user_id] = [ @first_activity[user_id], created_at ].compact.min
    end
  end

  def booking_created_at(record, starts_at)
    created_at =
      if record[:outcome] == :pending
        @now - rng.rand(10..(9 * 24 * 60)).minutes
      else
        lead_days = record[:offering].boarding? ? rng.rand(3..45) : rng.rand(1..21)
        starts_at - lead_days.days - rng.rand(0..1439).minutes
      end

    [ [ created_at, starts_at - 1.hour, @now - rng.rand(5..600).minutes ].min, @biz_created_at + 1.day ].max
  end

  def decision_time(created_at, starts_at)
    upper = [ @now - 1.minute, starts_at - 10.minutes ].min
    decided_at = created_at + rng.rand(10..2160).minutes
    [ [ decided_at, upper ].min, created_at + 1.minute ].max
  end

  def cancellation_time(from, starts_at)
    limit = [ @now - 1.minute, starts_at ].min
    span = limit - from
    span > 60 ? from + rng.rand * span : from
  end

  def record_decision_audit(record, decided_at)
    return unless decided_at

    if record[:accepted]
      audit("booking.accepted", record[:booking], decided_at)
    elsif record[:outcome] == :denied
      audit("booking.denied", record[:booking], decided_at, metadata: { reason: record[:reason] })
    end
  end

  def audit(action, target, created_at, actor: nil, metadata: {})
    actor ||= @staff.sample(random: rng)[:user]
    @business.audit_events.create!(
      actor: actor, action: action, target: target, metadata: metadata,
      created_at: created_at, updated_at: created_at
    )
  end

  # Accounts exist before their first booking, usually long before.
  def backdate_customers
    age_days = ((@now - @biz_created_at) / 1.day).to_i

    @customers.each do |customer|
      joined_at = @now - rng.rand(30..(age_days - 5)).days
      first_booking_at = @first_activity[customer[:user].id]
      joined_at = [ joined_at, first_booking_at - rng.rand(2..168).hours ].min if first_booking_at
      joined_at = [ joined_at, @biz_created_at + 1.day ].max

      backdate(customer[:user], joined_at)
      backdate(customer[:membership], joined_at)
      customer[:pets].each { |pet| backdate(pet, joined_at + rng.rand(1..60).minutes) }
    end
  end

  # -- helpers ----------------------------------------------------------

  def backdate(record, time)
    return unless record.created_at > time

    record.update_columns(created_at: time, updated_at: time)
  end

  def weighted(choices)
    choices = choices.to_a
    roll = rng.rand * choices.sum { |_, weight| weight }
    choices.each do |choice, weight|
      roll -= weight
      return choice if roll < 0
    end
    choices.last.first
  end

  def maybe(probability, pool)
    pool.sample(random: rng) if rng.rand < probability
  end

  def slug(name)
    name.downcase.gsub(/[^a-z]/, "")
  end

  def summary
    counts = @business.bookings.group(:status).count.sort.map { |status, n| "#{n} #{status}" }.join(", ")
    "#{@business.name}: #{@staff.size} staff, #{@customers.size} customers, " \
      "#{@business.pets.count} pets, #{@business.availability_slots.count} slots, " \
      "#{@business.bookings.count} bookings (#{counts})"
  end

  def log(message)
    puts "[seed] #{@business.slug}: #{message}"
  end
end
