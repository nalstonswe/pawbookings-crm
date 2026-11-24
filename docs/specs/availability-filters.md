# Spec: Availability page filters

**Status:** Draft, derived from requirements-gathering meeting notes and a follow-up Q&A.
**Scope:** Admin Availability overview page (`AvailabilityOverviewPage.jsx`).

## 1. Goal

Add filters to the Availability page: service, date range, minimum remaining capacity, and availability state.

### Non-negotiables
- Filtered results never include data from other businesses.
- Stacked filters return correct data (all filters combine with AND).
- Returned data is cached on the client, keyed by the filters (TanStack Query `queryKey`).

### Out of scope (deferred to a later release)
- Free-text search.
- Persisting filters across page refresh (URL / localStorage / sessionStorage).
- Extra "has the API data changed?" request logic. Only React Query's built-in structural sharing applies.

## 2. Current state (for reference)

- The page uses `useAllAvailabilitySlots`, which fetches each service's slots separately (`GET .../service_offerings/:id/availability_slots`, unpaginated) and merges them client-side.
- The admin slot payload has `capacity` and `active` only. It has no `remaining_capacity`.
- `remaining_capacity` exists only on the customer-facing `GET .../service_offerings/:id/availability` endpoint (future-only, 14-day default, 60-day max, 200-slot limit).
- `availabilityStatus.js` derives Closed / Full / Limited / Available on the client.
- Pending bookings reserve no capacity (ADR 0005). Only accepted bookings' allocations reduce remaining capacity.
- The `QueryClient` has no `staleTime` configured.

## 3. Filters

All inputs are single-select. Filters combine with AND.

| Filter | Control | Behavior |
|---|---|---|
| Service | Dropdown: "All services" + **active** services | One service at a time |
| From | Date picker | Interpreted in the **business's time zone** |
| To | Date picker | Same. Requires `From` |
| Min remaining capacity | Number input | Integer >= 1. Blank = no filter |
| Availability state | Dropdown: Closed, Full, Limited, Available | Replaces the earlier Active/Inactive filter. "Closed" = inactive slot |

### 3.1 Date semantics
- A slot matches if `starts_at` is within `[from 00:00:00, to 23:59:59]`, inclusive, in the business time zone.
- Only **future** slots are ever returned.
- Every request is bounded to a **60-day maximum** window, including when no dates are given. Slots more than 60 days out are not reachable from this page (accepted).

| Input | Result |
|---|---|
| Neither set | Future slots, 60-day bound applies |
| `from` only | `from` to `from + 60 days` |
| `to` only | **Rejected** (`to` requires `from`) |
| `to` < `from` | **Rejected** |
| Range > 60 days | **Rejected** |

Rejections are enforced on **both** layers:
- **Client:** the form blocks selection or submit. It shows a friendly inline message, e.g. that availability can't be viewed more than 60 days out.
- **Server:** the API returns `422` with a validation error (direct API calls must be protected too).

### 3.2 Min remaining capacity
- Integer >= 1 only. Blank means no filter.
- Non-integer, zero or negative: the server returns `422` and the UI shows an inline form error.

### 3.3 Availability state
Computed from `capacity`, `remaining_capacity` and `active`:

| State | Rule |
|---|---|
| Closed | `active = false` |
| Full | active and `remaining_capacity <= 0` |
| Limited | active and `remaining_capacity <= max(1, ceil(capacity * 0.25))` |
| Available | otherwise |

The server reimplements this rule to filter paginated results. There must be **one documented source of truth** (currently the `availabilityStatus.js` thresholds), with tests on both server and client.

## 4. Interaction

- The user chooses values, then presses **Submit**.
- A **Clear filters** button resets all filters and refetches.
- Results are paginated with a **Load more** button (the app's existing pattern, as in the bookings page).
- **Empty states:**
  - "No slots exist yet" (no slots at all).
  - "No slots match these filters", with a Clear filters action.
- **Roles:** all members can view and filter. Only owner and admin see the Edit action (unchanged).

## 5. Backend / API

### 5.1 New endpoint
A business-wide paginated slots endpoint replaces the N per-service requests. The path and name are not decided; see Open Questions.

Requirements:
- Scoped to `Current.business`. It never returns another business's data.
- Query params: service, `from`, `to`, min remaining capacity, availability state, `page`, `per_page`.
- Each slot includes `remaining_capacity` (`capacity` minus accepted allocations, floored at 0), plus the service info the table shows.
- Sort: `starts_at ASC, id ASC` (the id tiebreaker keeps paging stable).
- Pagination: default 25, max 100 (existing `Paginatable` convention).
- The response includes `has_more` and `total_count`. This departs from the plain-array convention in `docs/performance.md`, so that doc must be updated.
- Filtering on remaining capacity and state must be applied **before** pagination (SQL-level aggregate), not by counting after the page is cut.
- Validation errors use the existing `validation_failed` error format with `422`.

### 5.2 Performance notes
- Existing slot indexes lead with `service_offering_id`. A `business_id`-led composite index is likely needed for the all-services query. This is undecided (see Open Questions).
- Avoid N+1 queries. Compute accepted counts in one aggregate query (as `AvailabilitiesController` does).

## 6. Client caching and fetching

- **One cache layer:** the TanStack Query cache only. There is no server-side cache.
- **queryKey:** `[business slug, normalized filters, page, user/role]`. Normalize so equivalent filters share a key (e.g. blank vs. absent).
- **Freshness:** React Query defaults (`staleTime` 0, `gcTime` 5 min). There is no explicit invalidation after slot edits or booking accept/cancel. The page may show stale `remaining_capacity` until refetch (accepted).
- **Hybrid filtering on submit:**
  - If the cached data is **complete** (`has_more = false`), filter in memory and send no request.
  - If the cache is **incomplete** (`has_more = true`), show the filtered cached rows immediately, then fetch from the server and replace them.
  - The server is the source of truth. Client filtering is a best-effort optimization.

## 7. Acceptance criteria

1. A request never returns slots from another business, including when `service_id` or other params reference another business's records.
2. Stacking service + date range + min capacity + state returns exactly the slots matching all of them.
3. Date rules in 3.1 hold on both client and server (server returns `422`).
4. Min capacity rules in 3.2 hold on both client and server.
5. The state filter matches the `availabilityStatus.js` thresholds exactly. Server and client share test cases.
6. Responses are sorted by `starts_at, id`, paginate at 25 (max 100), and include `has_more` and `total_count`.
7. A complete cache is filtered without a network request. An incomplete cache triggers a server fetch whose result replaces the interim client-filtered rows.
8. The queryKey includes business slug, normalized filters, page and user/role.
9. Clear filters resets the form and refetches. Both empty states render correctly.
10. Only owner and admin see Edit.

## 8. Testing

- **Backend request specs:** tenant isolation, each filter alone, stacked filters, boundary dates (inclusive start/end in the business time zone), 422 cases, pagination and `has_more` / `total_count`, ordering stability, state thresholds. Include no-N+1 (Bullet).
- **Frontend tests:** form validation messages, submit and clear, hybrid cache behavior (complete vs. incomplete), queryKey contents, empty states, role-based Edit visibility.
- **Parity:** shared cases proving the client's in-memory filtering matches the server for the supported filters.

## 9. Documentation to update

- `docs/openapi.yaml`: new endpoint and params.
- `docs/performance.md`: pagination metadata, new indexes if any, and the "No caching layer" note.
- `docs/tenancy.md`: if the new endpoint changes the scoping description.

## 10. Open questions (undecided; not assumed)

1. **When may the client filter a cached result in memory?** Proposed: only if the new filter is a subset of the cached query's filter. Needs confirmation.
2. **Foreign or invalid IDs:** a `service_id` from another business could return 404, 422 or an empty list (404 suggested). An invalid state value could return 422 (suggested).
3. **"Future only":** does a slot that has started but not ended count as past? If `from` is today, does `max(now, from)` apply?
4. **Stacking:** confirm AND-only with no OR logic.
5. **user/role in queryKey:** does logout or a role change already clear the query cache? If so, this may be redundant.
6. **Dashboard consumer:** `BusinessDashboardPage.jsx` also uses the all-slots hook for capacity warnings. Should it migrate to the new endpoint or keep the old hook?
7. **Active-services-only dropdown:** slots of inactive services are reachable only through "All services". Intended?
8. **Migration:** is a DB migration (new `business_id`-led index) in scope?
9. **Endpoint path and naming**, and whether the old per-service admin list remains unchanged.
10. **Test scope:** confirm the testing plan in section 8.
11. **What the 60-day bound means:** a maximum *range length* (`to - from`, and `from + 60 days` when only `from` is given) or a maximum *distance from today*? Section 3.1 and the "slots more than 60 days out are not reachable" note assume different readings. The suggested code (see [availability-filters-changes.md](availability-filters-changes.md)) implements the range-length reading.

## 11. Decision log (resolved contradictions from the meeting)

| Topic | Original note | Final decision |
|---|---|---|
| Where filtering happens | "Trigger request on submit" | Hybrid: client-side on a complete cache, otherwise server fetch |
| Date bounds | No `to` unless specified | Always bounded to 60 days |
| Status filter | Two filters (Active/Inactive and state) | One merged dropdown (Closed / Full / Limited / Available) |
| Nice-to-haves | Text search, persistence, differ-check | All deferred |
