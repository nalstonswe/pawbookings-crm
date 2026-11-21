# Static data for the demo seeds: business definitions plus the name,
# breed, and free-text pools the generator draws from. Kept separate from
# the generator (demo_business_seeder.rb) so tuning "what a business looks
# like" never means touching the logic that builds it.
module DemoCatalog
  # `employees` counts everyone with an owner/admin/staff membership;
  # `customers` counts customer memberships (including the fixed
  # customer@<domain> demo login). `shared_customers` is how many of those
  # customers also hold an account at the previously seeded business -- the
  # same person using two businesses on the platform, which is exactly the
  # case tenant isolation has to get right.
  #
  # Each offering's `schedule` is either `nightly: true` (boarding: one
  # midnight-to-midnight slot per night) or `days` (Date#wday, 0 = Sunday)
  # plus `windows` ([start_hour, end_hour] pairs in the business time zone).
  # `replaces` renames one of the three default offerings BusinessSignup
  # creates instead of leaving it behind next to the custom one.
  BUSINESSES = [
    {
      slug: "paws-and-play", name: "Paws & Play Daycare", time_zone: "America/New_York",
      domain: "pawsandplay.example", seed: 101, employees: 8, customers: 64,
      shared_customers: 0, bookings_per_customer: 4.5, cancellation_window_hours: 24,
      offerings: [
        { name: "Daycare", kind: "daycare", capacity: 10, weight: 60,
          description: "Supervised group play, naps, and snacks.",
          instructions: "Drop off between 8:30 and 9:30. Bring current vaccination records.",
          schedule: { days: [ 1, 2, 3, 4, 5 ], windows: [ [ 9, 17 ] ] } },
        { name: "Training", kind: "training", capacity: 1, duration: 60, weight: 15,
          description: "One-on-one sessions with a certified trainer.",
          instructions: "Bring high-value treats and a standard 6ft leash.",
          schedule: { days: [ 2, 4 ], windows: [ [ 14, 15 ], [ 15, 16 ], [ 16, 17 ] ] } },
        { name: "Boarding", kind: "boarding", capacity: 5, weight: 25,
          description: "Overnight stays in a private suite with evening playtime.",
          instructions: "Check-in from noon, check-out by 11am. Pack your dog's own food.",
          schedule: { nightly: true } },
        { name: "Weekend Puppy Social", kind: "daycare", capacity: 8, weight: 10,
          description: "Saturday morning socialization for dogs under one year old.",
          instructions: "Puppies must have had at least their second round of shots.",
          schedule: { days: [ 6 ], windows: [ [ 10, 13 ] ] } }
      ]
    },
    {
      slug: "canine-collegiate", name: "Canine Collegiate", time_zone: "America/New_York",
      domain: "caninecollegiate.example", seed: 202, employees: 6, customers: 41,
      shared_customers: 6, bookings_per_customer: 3.5, cancellation_window_hours: 48,
      offerings: [
        { name: "Campus Day School", replaces: "Daycare", kind: "daycare", capacity: 12, weight: 25,
          description: "A structured day of play mixed with short training refreshers.",
          instructions: "Dogs must be spayed or neutered if over 8 months old.",
          schedule: { days: [ 1, 2, 3, 4, 5 ], windows: [ [ 8, 16 ] ] } },
        { name: "Obedience 101 (Group Class)", kind: "training", capacity: 8, duration: 60, weight: 30,
          description: "Six-week foundation class covering sit, down, stay, and loose-leash walking.",
          instructions: "Arrive 10 minutes early. Bring treats and your dog's vaccination records.",
          schedule: { days: [ 1, 3 ], windows: [ [ 18, 19 ] ] } },
        { name: "Private Training Session", replaces: "Training", kind: "training", capacity: 1, duration: 60,
          weight: 25, description: "Individual coaching tailored to behavior goals.",
          instructions: "Tell us about specific problem behaviors in the booking notes.",
          schedule: { days: [ 1, 2, 3, 4, 5 ], windows: [ [ 10, 11 ], [ 11, 12 ], [ 13, 14 ] ] } },
        { name: "Board & Train", replaces: "Boarding", kind: "boarding", capacity: 6, weight: 20,
          description: "Overnight stay with daily training sessions.",
          instructions: "Minimum two nights. We send a progress report each evening.",
          schedule: { nightly: true } },
        { name: "Agility Intensive (Seasonal)", kind: "training", capacity: 6, duration: 90, weight: 0,
          active: false, description: "Weekend agility course -- returns in the spring.",
          instructions: "Not currently bookable.",
          schedule: { days: [ 6 ], windows: [ [ 9, 11 ] ] } }
      ]
    },
    {
      slug: "bark-avenue", name: "Bark Avenue Boarding", time_zone: "America/New_York",
      domain: "barkavenue.example", seed: 303, employees: 9, customers: 72,
      shared_customers: 8, bookings_per_customer: 4, cancellation_window_hours: 72,
      offerings: [
        { name: "Day Play", replaces: "Daycare", kind: "daycare", capacity: 15, weight: 25,
          description: "Open-hours daycare in our indoor and outdoor play yards.",
          instructions: "Drop off any time between 7am and 10am.",
          schedule: { days: [ 1, 2, 3, 4, 5, 6 ], windows: [ [ 7, 18 ] ] } },
        { name: "Standard Kennel Boarding", replaces: "Boarding", kind: "boarding", capacity: 18, weight: 45,
          description: "Climate-controlled kennels with three potty breaks a day.",
          instructions: "Check-in 8am-6pm. Medications must be in original packaging.",
          schedule: { nightly: true } },
        { name: "Luxury Suite Boarding", kind: "boarding", capacity: 4, weight: 20,
          description: "Private suite with a raised bed, webcam, and bedtime story.",
          instructions: "Includes one 30 minute one-on-one play session per day.",
          schedule: { nightly: true } },
        { name: "Basic Manners Training", replaces: "Training", kind: "training", capacity: 2, duration: 45,
          weight: 10, description: "Small-group refreshers for boarding guests and locals.",
          instructions: "Open to current boarding guests or by appointment.",
          schedule: { days: [ 3, 5 ], windows: [ [ 11, 12 ], [ 15, 16 ] ] } }
      ]
    },
    {
      slug: "happy-tails-resort", name: "Happy Tails Resort & Spa", time_zone: "America/Chicago",
      domain: "happytails.example", seed: 404, employees: 10, customers: 80,
      shared_customers: 8, bookings_per_customer: 4.5, cancellation_window_hours: 24,
      offerings: [
        { name: "Full Day Daycare", replaces: "Daycare", kind: "daycare", capacity: 25, weight: 38,
          description: "A full day of play across five themed play yards.",
          instructions: "Bring a lunch if your dog is on a special diet.",
          schedule: { days: [ 1, 2, 3, 4, 5, 6 ], windows: [ [ 7, 18 ] ] } },
        { name: "Half Day Daycare", kind: "daycare", capacity: 12, weight: 17,
          description: "Morning or afternoon session -- great for puppies and seniors.",
          instructions: "Pick up by the end of your chosen session.",
          schedule: { days: [ 1, 2, 3, 4, 5 ], windows: [ [ 7, 12 ], [ 13, 18 ] ] } },
        { name: "Resort Boarding", replaces: "Boarding", kind: "boarding", capacity: 20, weight: 30,
          description: "Spacious suites with daily enrichment and a spa bath on checkout.",
          instructions: "Check-in 7am-7pm. Holiday stays require a deposit.",
          schedule: { nightly: true } },
        { name: "Private Training", replaces: "Training", kind: "training", capacity: 2, duration: 60,
          weight: 15, description: "Hour-long sessions with our training staff.",
          instructions: "Up to two dogs from the same household per session.",
          schedule: { days: [ 1, 2, 3, 4, 5, 6 ], windows: [ [ 9, 10 ], [ 10, 11 ], [ 14, 15 ], [ 15, 16 ] ] } }
      ]
    },
    {
      slug: "sunset-paws", name: "Sunset Paws Training & Daycare", time_zone: "America/Los_Angeles",
      domain: "sunsetpaws.example", seed: 505, employees: 4, customers: 30,
      shared_customers: 4, bookings_per_customer: 3, cancellation_window_hours: 12,
      offerings: [
        { name: "Neighborhood Daycare", replaces: "Daycare", kind: "daycare", capacity: 8, weight: 45,
          description: "Small-group daycare capped at eight dogs.",
          instructions: "Drop-off 8-9am, pick-up 4-5pm.",
          schedule: { days: [ 1, 2, 3, 4, 5 ], windows: [ [ 8, 17 ] ] } },
        { name: "Behavior Coaching", replaces: "Training", kind: "training", capacity: 1, duration: 60,
          weight: 40, description: "Reactivity, leash manners, and puppy basics.",
          instructions: "First session includes a 15 minute intake chat.",
          schedule: { days: [ 1, 2, 3, 4, 5, 6 ], windows: [ [ 9, 10 ], [ 10, 11 ], [ 16, 17 ] ] } },
        { name: "Home-Style Boarding", replaces: "Boarding", kind: "boarding", capacity: 3, weight: 15,
          description: "Overnight stays in the owner's home -- limited to three guests.",
          instructions: "Dogs must be comfortable with other dogs and cats.",
          schedule: { nightly: true } }
      ]
    }
  ].freeze

  CUSTOMER_EMAIL_DOMAINS = %w[ example.com example.net example.org mail.example inbox.example ].freeze

  FIRST_NAMES = %w[
    Olivia Liam Emma Noah Ava Elijah Sophia Lucas Isabella Mason Mia Logan Amelia Ethan Harper
    James Evelyn Benjamin Abigail Henry Emily Alexander Ella Jackson Scarlett Sebastian Grace Aiden
    Chloe Matthew Zoey Samuel Penelope David Layla Joseph Riley Carter Nora Owen Lily Wyatt Eleanor
    Jack Hannah Luke Lillian Jayden Addison Dylan Aubrey Grayson Stella Levi Natalie Isaac Zoe
    Gabriel Leah Julian Hazel Mateo Violet Anthony Aurora Jaxon Savannah Lincoln Audrey Joshua Brooklyn
    Christopher Bella Andrew Claire Theodore Skylar Caleb Lucy Ryan Paisley Asher Everly Nathan Anna
    Thomas Caroline Leo Nova Isaiah Genesis Charles Emilia Josiah Kennedy Hudson Maya Priya Arjun
    Mei Hiroshi Fatima Omar Sofia Camila Diego Valentina Rohan Anika Kenji Amara Kwame Ines
  ].uniq.freeze

  LAST_NAMES = %w[
    Smith Johnson Williams Brown Jones Garcia Miller Davis Rodriguez Martinez Hernandez Lopez Gonzalez
    Wilson Anderson Thomas Taylor Moore Jackson Martin Lee Perez Thompson White Harris Sanchez Clark
    Ramirez Lewis Robinson Walker Young Allen King Wright Scott Torres Nguyen Hill Flores Green Adams
    Nelson Baker Hall Rivera Campbell Mitchell Carter Roberts Patel Kim Chen Singh Khan Okafor Murphy
    Kelly Bennett Cooper Reed Bailey Bell Gomez Kelley Howard Ward Cox Diaz Richardson Wood Watson
    Brooks Price Sullivan Foster Powell Long Hughes Morgan Cruz Reyes Russell Griffin Hayes Myers Ford
  ].uniq.freeze

  PET_NAMES = %w[
    Bella Max Charlie Luna Cooper Lucy Buddy Daisy Rocky Bailey Maggie Duke Sadie Bear Molly Tucker
    Zoe Jack Lola Oliver Penny Finn Ruby Murphy Stella Teddy Rosie Winston Piper Louie Willow Milo
    Gracie Gus Nala Hank Ellie Otis Pepper Scout Sophie Ziggy Roxy Harley Coco Archie Lilly Bruno
    Hazel Moose Maple Biscuit Waffles Pickle Mochi Noodle Peanut Biscotti Juno Atlas Koda Remy Sasha
    Thor Loki Ginger Oreo Cleo Rex Marley Dixie Rusty Sunny Tank Bandit Chewie Pixie Gizmo Nugget
    Pretzel Bubba Sage Olive Mabel Frankie Mac Tilly Banjo Obi Beau Cash Jasper Ozzy Poppy Rudy
    Walter Wrigley Yoshi Zeke Abby Bentley Chico Dolly Echo Fenway Georgia Hobbes Iggy Jax Kona Lucky
  ].uniq.freeze

  # [name, min_kg, max_kg]
  BREEDS = [
    [ "Labrador Retriever", 25, 36 ], [ "Golden Retriever", 25, 34 ], [ "French Bulldog", 8, 14 ],
    [ "Beagle", 9, 14 ], [ "German Shepherd", 22, 40 ], [ "Standard Poodle", 20, 32 ],
    [ "Miniature Poodle", 5, 9 ], [ "Bulldog", 18, 25 ], [ "Boxer", 25, 32 ], [ "Dachshund", 6, 13 ],
    [ "Cavalier King Charles Spaniel", 5, 8 ], [ "Shih Tzu", 4, 8 ], [ "Yorkshire Terrier", 2, 4 ],
    [ "Siberian Husky", 16, 27 ], [ "Australian Shepherd", 16, 29 ], [ "Border Collie", 14, 20 ],
    [ "Pembroke Welsh Corgi", 10, 14 ], [ "Great Dane", 45, 80 ], [ "Bernese Mountain Dog", 32, 52 ],
    [ "Rottweiler", 36, 60 ], [ "Pit Bull Terrier", 14, 32 ], [ "Chihuahua", 1.5, 3.5 ],
    [ "Havanese", 4, 7 ], [ "Maltipoo", 3, 9 ], [ "Goldendoodle", 15, 36 ], [ "Labradoodle", 18, 33 ],
    [ "Cocker Spaniel", 11, 15 ], [ "Jack Russell Terrier", 6, 8 ], [ "Pug", 6, 10 ],
    [ "Doberman Pinscher", 27, 45 ], [ "Vizsla", 20, 30 ], [ "Shiba Inu", 8, 11 ],
    [ "Basset Hound", 20, 29 ], [ "Mixed Breed", 5, 35 ], [ "Mixed Breed", 5, 35 ],
    [ "Mixed Breed", 5, 35 ], [ "Labrador Retriever", 25, 36 ], [ "Golden Retriever", 25, 34 ]
  ].freeze

  FEEDING_INSTRUCTIONS = [
    "One cup of kibble, twice daily.",
    "Half a cup morning and evening; no table scraps.",
    "Raw diet -- owner supplies pre-portioned meals.",
    "Grain-free kibble, 1.5 cups at dinner only.",
    "Small portion at noon to avoid an upset stomach.",
    "Slow-feeder bowl required; he gulps his food.",
    "Wet food topper on dry kibble, twice daily."
  ].freeze

  MEDICATION_INSTRUCTIONS = [
    "Joint supplement with breakfast.",
    "Thyroid pill every morning, hidden in cheese.",
    "Allergy tablet once daily with food.",
    "Eye drops twice daily (left eye).",
    "Flea and tick chewable on the first of each month."
  ].freeze

  BEHAVIORAL_NOTES = [
    "Anxious around large dogs; prefers a quiet corner.",
    "Very food motivated -- keep treats out of reach.",
    "Pulls hard on the leash; use a front-clip harness.",
    "Shy with strangers at first but warms up quickly.",
    "Barks at the mailman; otherwise very friendly.",
    "High energy, needs frequent breaks from play groups.",
    "Resource guards toys; play with separate toys only.",
    "Escape artist -- double-check gates.",
    "Gets overstimulated in big groups; does best with calm dogs.",
    "Sweet with every dog and person. Loves belly rubs."
  ].freeze

  EMERGENCY_NOTES = [
    "Prone to seizures; call owner immediately.",
    "Allergic to chicken -- ask before offering treats.",
    "Brachycephalic: watch for overheating.",
    "Heart murmur; avoid strenuous exercise.",
    "Preferred vet: Lakeside Animal Hospital."
  ].freeze

  BOOKING_NOTES = [
    "First time with you -- please call if there are any issues.",
    "Regulars, no special instructions.",
    "Please give his medication with lunch.",
    "We'll be out of town for a family event.",
    "Would like some extra playtime if possible.",
    "She gets car sick, so a light breakfast only.",
    "Working on leash manners, any tips appreciated.",
    "Business trip -- my sister will do the pickup.",
    "He's recovering from a minor paw injury, go easy.",
    "Back-to-back appointments that week, thank you!",
    "Dropping off a little early if that's okay."
  ].freeze

  DENIAL_REASONS = [
    "We need updated vaccination records before we can accept this booking.",
    "Unfortunately we're unable to take that date -- please try another day.",
    "Our team doesn't have an evaluation spot open before then.",
    "We're closed for staff training on that date.",
    "Please book a temperament assessment first.",
    "The requested time is outside our normal hours."
  ].freeze

  CAPACITY_DENIAL_REASON = "Sorry, we're fully booked for those dates.".freeze

  # Draws unique "First Last" pairs in a fixed shuffled order so the same
  # people are generated on every run. Every business shares one pool, so
  # no two accounts across the platform ever collide on an email address.
  class NamePool
    def initialize(random)
      @names = FIRST_NAMES.product(LAST_NAMES).shuffle(random: random)
      @cursor = 0
    end

    def take(count)
      @names[@cursor, count].tap { @cursor += count }
    end
  end
end
