# PawBookings CRM

A multitenant CRM and booking platform for dog daycare, boarding, and
training businesses. Staff manage services, availability, and incoming
booking requests; customers browse availability and request bookings
for their pets.

## Stack

- **Backend:** Ruby on Rails 8 (API mode), PostgreSQL, Pundit
  (authorization), Solid Queue (background jobs)
- **Frontend:** React (JavaScript, no TypeScript), Vite, React Router,
  TanStack Query, Bootstrap 5 + react-bootstrap (UI/styling)

## Prerequisites

- Ruby 3.4.10 (see `backend/.ruby-version` — a version manager like
  `mise`, `rbenv`, or `rvm` will pick this up automatically)
- Node.js 20+
- Docker + Docker Compose (for PostgreSQL — or point the backend at
  your own local Postgres 16+ instead, see `.env.example`)

## Quick start

```sh
git clone <this-repo>
cd pawbookings-crm
cp .env.example .env

# 1. Database
docker compose up -d

# 2. Backend
cd backend
bundle install
bin/rails db:create db:migrate db:seed
bin/rails server            # http://localhost:3000

# 3. Background jobs (separate terminal, still in backend/)
bin/jobs

# 4. Frontend (separate terminal)
cd frontend
npm install
npm run dev                 # http://localhost:5173
```

Open `http://localhost:5173` and log in with one of the seeded demo
accounts below.

### Demo credentials

`db:seed` creates five fully populated businesses, each with its own
staff, customers, pets, services, availability, and booking history
(roughly six weeks back and five weeks ahead, in every booking status).
Every business has an account for each role at `<role>@<domain>`, all
with the password `password12345`:

| Business (slug) | Domain | Time zone | Staff | Customers | Bookings |
|---|---|---|---|---|---|
| Paws & Play Daycare (`paws-and-play`) | `pawsandplay.example` | New York | 8 | 64 | ~300 |
| Canine Collegiate (`canine-collegiate`) | `caninecollegiate.example` | New York | 6 | 41 | ~145 |
| Bark Avenue Boarding (`bark-avenue`) | `barkavenue.example` | New York | 9 | 72 | ~290 |
| Happy Tails Resort & Spa (`happy-tails-resort`) | `happytails.example` | Chicago | 10 | 80 | ~360 |
| Sunset Paws Training & Daycare (`sunset-paws`) | `sunsetpaws.example` | Los Angeles | 4 | 30 | ~90 |

For example, for Paws & Play:

| Role | Email |
|---|---|
| Owner | `owner@pawsandplay.example` |
| Admin | `admin@pawsandplay.example` |
| Staff | `staff@pawsandplay.example` |
| Customer | `customer@pawsandplay.example` |

The remaining staff and customers have generated `first.last@...`
addresses (same password). Some customers belong to two businesses, so
cross-tenant isolation can be exercised with real overlapping accounts.
Bookings are created through the real booking services, so capacity
limits are respected -- requests that didn't fit were denied.

`customer@pawsandplay.example` additionally keeps the original small demo
data set (Rex and Biscuit, one booking per status). The generator lives
in `backend/db/seeds/` (business definitions in `demo_catalog.rb`, logic
in `demo_business_seeder.rb`) and is deterministic. `db:seed` is
idempotent -- safe to run again at any time; businesses that already have
their data are skipped. To regenerate from scratch, use
`bin/rails db:reset`.

## Running tests

```sh
cd backend && bundle exec rspec        # 183 examples
cd frontend && npm test                # 34 tests
```

See [docs/testing.md](docs/testing.md) for what's covered (including
the real-thread concurrency specs) and why a couple of common testing
tools (E2E browser tests, load testing) were deliberately left out.

## Linting and security scanning

```sh
cd backend
bundle exec rubocop           # style
bundle exec brakeman -q       # static security analysis
bundle exec bundler-audit check --update   # dependency vulnerabilities

cd frontend
npm run lint                  # ESLint
npm audit                     # dependency vulnerabilities
```

## Project layout

```
backend/   Rails API (app/, config/, db/, spec/)
frontend/  React SPA (src/)
docs/      Architecture notes, ADRs, and the API reference
```

## Documentation

- [Architecture overview](docs/architecture.md) — system shape, domain
  model, and rejected alternatives
- [Data flow](docs/data-flow.md) — sequence diagrams for auth, booking
  requests, and booking acceptance
- [Tenancy](docs/tenancy.md) — how a business is isolated from every
  other business's data
- [Authorization](docs/authorization.md) — the Pundit policy layer and
  a full role capability matrix
- [Idempotency](docs/idempotency.md) — the `Idempotency-Key` lifecycle
  for booking mutations
- [Performance](docs/performance.md) — N+1 prevention, indexing, and
  what was deliberately not built (yet)
- [Testing](docs/testing.md) — test pyramid, the concurrency-testing
  pattern, and coverage boundaries
- [Frontend styling conventions](docs/frontend-style.md) — the design
  system, shared component library, and how to build a new page
  consistently
- [Architecture decision records](docs/decisions/) — specific
  decisions made over a plausible alternative, and why
- [openapi.yaml](docs/openapi.yaml) — full API reference (paste into
  [Swagger Editor](https://editor.swagger.io/) or any OpenAPI viewer)

## Known limitations

- Single-region, single-database deployment target — see
  [docs/architecture.md](docs/architecture.md) for the reasoning
  (no microservices, no read replica, no cache layer) and what would
  change first if that stopped being true.
- No real SMTP provider is configured for production
  (`config/environments/production.rb` still has Rails' default,
  commented-out SMTP settings) — booking decision emails would fail to
  send until real credentials are added via `bin/rails
  credentials:edit`. Development uses the `:file` delivery method
  (written to `tmp/mails/`) and test uses `:test` (assertable via
  `ActionMailer::Base.deliveries`), so this only matters for an actual
  production deployment, which this project has never had.
- `platform_admin` (a support-staff escalation flag on `User`) exists
  as a schema column and a documented invariant
  ([docs/tenancy.md](docs/tenancy.md#optional-platform-admin-access))
  but has no actual UI or controller logic yet — reserved for a future
  support-tooling milestone, not implemented.

