# Idempotent demo data for local development: five businesses, each with
# staff, customers, pets, services, availability, and a booking history
# covering every status. Paws & Play also keeps a small hand-written demo
# (the customer@ account) below; the bulk data is generated afterwards
# from db/seeds/.
# Safe to run repeatedly (`bin/rails db:seed`) -- every step checks for
# existing data first rather than assuming a fresh database.
#
# Booking/decision data goes through the real service objects
# (BusinessSignup, BookingRequestService, BookingAcceptance, etc.), the
# same code paths production traffic uses, rather than writing rows
# directly -- so seeded data is guaranteed to be as consistent as
# anything the app itself would produce.

DEMO_PASSWORD = "password12345"

def seed_log(message)
  puts "[seed] #{message}"
end

business = Business.find_by(slug: "paws-and-play")

if business
  seed_log("Business 'paws-and-play' already exists, skipping business/owner creation.")
else
  result = BusinessSignup.new(
    business_name: "Paws & Play Daycare",
    business_slug: "paws-and-play",
    time_zone: "America/New_York",
    owner_email: "owner@pawsandplay.example",
    owner_password: DEMO_PASSWORD
  ).call

  raise "Failed to seed demo business: #{result.errors&.full_messages}" unless result.success?

  business = result.business
  seed_log("Created business '#{business.name}' (#{business.slug}) with owner #{result.user.email}.")
end

def find_or_create_member(business, email, role)
  user = User.find_or_create_by!(email: email) { |u| u.password = DEMO_PASSWORD }
  business.memberships.find_or_create_by!(user: user) { |m| m.role = role }
  user
end

find_or_create_member(business, "admin@pawsandplay.example", :admin)
find_or_create_member(business, "staff@pawsandplay.example", :staff)
customer = find_or_create_member(business, "customer@pawsandplay.example", :customer)
seed_log("Ensured admin, staff, and customer memberships exist.")

rex = business.pets.find_or_create_by!(user: customer, name: "Rex") do |pet|
  pet.species = :dog
  pet.breed = "Labrador Retriever"
  pet.birth_date = 3.years.ago.to_date
  pet.weight = 28.5
  pet.sex = :male
  pet.vaccination_status = :up_to_date
  pet.vaccination_expires_on = 6.months.from_now.to_date
  pet.feeding_instructions = "One cup of kibble, twice daily."
end

biscuit = business.pets.find_or_create_by!(user: customer, name: "Biscuit") do |pet|
  pet.species = :dog
  pet.breed = "Beagle"
  pet.birth_date = 1.year.ago.to_date
  pet.weight = 11.0
  pet.sex = :female
  pet.vaccination_status = :unknown
  pet.behavioral_notes = "Anxious around large dogs; prefers a quiet corner."
end
seed_log("Ensured pets Rex and Biscuit exist for the demo customer.")

daycare = business.service_offerings.find_by!(service_kind: :daycare)
training = business.service_offerings.find_by!(service_kind: :training)
boarding = business.service_offerings.find_by!(service_kind: :boarding)

def find_or_create_slot(business, offering, starts_at, ends_at, capacity)
  offering.availability_slots.find_or_create_by!(starts_at: starts_at, ends_at: ends_at) do |slot|
    slot.business = business
    slot.capacity = capacity
  end
end

# A daycare slot most weekdays for the next two weeks, a handful of
# one-hour training slots, and a few boarding nights.
weekday_offsets = (1..14).reject do |offset|
  day = offset.days.from_now.to_date
  day.saturday? || day.sunday?
end

daycare_slots = weekday_offsets.map do |offset|
  day = offset.days.from_now.to_date
  find_or_create_slot(
    business, daycare,
    day.in_time_zone(business.time_zone).change(hour: 9),
    day.in_time_zone(business.time_zone).change(hour: 17),
    10
  )
end
accepted_slot = daycare_slots.first
pending_slot = daycare_slots.third

training_slot = find_or_create_slot(
  business, training,
  5.days.from_now.in_time_zone(business.time_zone).change(hour: 14),
  5.days.from_now.in_time_zone(business.time_zone).change(hour: 15),
  1
)

boarding_night_one = find_or_create_slot(
  business, boarding,
  10.days.from_now.in_time_zone(business.time_zone).change(hour: 0),
  11.days.from_now.in_time_zone(business.time_zone).change(hour: 0),
  5
)
boarding_night_two = find_or_create_slot(
  business, boarding,
  11.days.from_now.in_time_zone(business.time_zone).change(hour: 0),
  12.days.from_now.in_time_zone(business.time_zone).change(hour: 0),
  5
)
seed_log("Ensured availability slots exist for daycare, training, and boarding.")

if customer.bookings.any?
  seed_log("Demo customer already has bookings, skipping booking creation.")
else
  request = lambda do |offering, slots, pets, notes|
    BookingRequestService.new(
      business: business, customer: customer, service_offering_id: offering.id,
      pet_ids: Array(pets).map(&:id), notes: notes,
      requested_starts_at: Array(slots).map(&:starts_at).min,
      requested_ends_at: Array(slots).map(&:ends_at).max
    ).call.booking
  end

  request.call(daycare, pending_slot, [ rex ], "First time at daycare, please call if any issues.")

  accepted = request.call(daycare, accepted_slot, [ rex, biscuit ], "Regulars, no special instructions.")
  BookingAcceptance.new(booking: accepted).call

  denied = request.call(training, training_slot, [ biscuit ], "Would like to work on leash manners.")
  BookingDenial.new(booking: denied, reason: "Trainer is fully booked that week.").call

  cancelled = request.call(boarding, [ boarding_night_one, boarding_night_two ], [ rex ], "Out of town for a wedding.")
  BookingCancellation.new(booking: cancelled).call

  seed_log("Created demo bookings: 1 pending, 1 accepted, 1 denied, 1 cancelled.")
end

# --- Additional businesses and bulk data ---------------------------------
# Paws & Play above stays the small, hand-written demo; this section grows
# it and four other businesses into a production-sized dataset. See
# db/seeds/demo_catalog.rb for what each business looks like and
# db/seeds/demo_business_seeder.rb for how it is generated.

require_relative "seeds/demo_catalog"
require_relative "seeds/demo_business_seeder"

def find_or_create_demo_business(spec)
  existing = Business.find_by(slug: spec[:slug])
  return existing if existing

  result = BusinessSignup.new(
    business_name: spec[:name], business_slug: spec[:slug], time_zone: spec[:time_zone],
    owner_email: "owner@#{spec[:domain]}", owner_password: DEMO_PASSWORD
  ).call
  raise "Failed to seed business #{spec[:slug]}: #{result.errors&.full_messages}" unless result.success?

  seed_log("Created business '#{result.business.name}' (#{result.business.slug}).")
  result.business
end

# bcrypt is deliberately slow; hashing the shared demo password once keeps
# creating several hundred accounts down to seconds.
password_digest = BCrypt::Password.create(DEMO_PASSWORD)
name_pool = DemoCatalog::NamePool.new(Random.new(2026))
previous_customers = []

DemoCatalog::BUSINESSES.each do |spec|
  demo_business = find_or_create_demo_business(spec)
  names = name_pool.take(spec[:employees] + spec[:customers])

  previous_customers = DemoBusinessSeeder.new(
    business: demo_business, spec: spec, password_digest: password_digest,
    names: names, shared_customers: previous_customers.last(spec[:shared_customers])
  ).call
end

seed_log("Done. Demo credentials (all use password '#{DEMO_PASSWORD}'):")
DemoCatalog::BUSINESSES.each do |spec|
  seed_log("  #{spec[:name]} (#{spec[:slug]}): " \
           "owner@#{spec[:domain]}, admin@#{spec[:domain]}, staff@#{spec[:domain]}, customer@#{spec[:domain]}")
end
