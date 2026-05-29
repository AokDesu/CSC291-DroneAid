# Reports are a first-class dispute entity that can override Request outcome

A user-filed Report against a delivered package needs somewhere to go. We promote `Report` from a write-only complaint log into a stateful entity with lifecycle (`open → resolved | dismissed`), a dedicated admin queue at `/admin/reports`, and an explicit coupling to the underlying `Request`: on `resolved`, Admin must pick a Request outcome (`confirmed` for delivery-accepted-with-remedy, `failed` for delivery-never-effectively-happened); `dismissed` leaves the Request as-is. This is the smallest model that lets a user file "package stolen on delivery" without confirming, and lets an Admin act on it without faking the Request status. Skeleton scope: no auto-redelivery, no refund domain, no `acknowledged` intermediate state.

## Considered Options

- **Inline-only admin surface (no queue page).** Rejected — the whole user complaint that triggered this work was "Reports go nowhere." Burying them inside Request detail keeps that dead-end.
- **`resolved` always maps Request → `confirmed`.** Rejected — conflates "delivery accepted with remedy" and "delivery failed but we made the user whole." User's stolen-package case is the latter; marking the Request `confirmed` would be a lie in the data.
- **New terminal Request state `closed`.** Rejected — touches `AppRequestStatus` enum, queue bucketing, history filters, Firestore rules, admin search. Out of skeleton scope; reusing existing `confirmed` / `failed` terminals carries the same information.
- **One Report per Request, ever.** Rejected — a dismissed Report with new evidence emerging has no recourse. "One open at a time" allows legitimate follow-up without enabling spam.

## Consequences

- `requests/{reqId}/reports/{reportId}` schema gains `status`, `resolution`, `resolvedAt`, `resolvedBy`, `resolutionNote` fields. `reportDeliveryIssue` callable becomes an upsert-gated write that rejects when an `open` Report already exists on the Request.
- Two new callables — `resolveReport` and `dismissReport` — own the only path that can mutate a Request out of `delivered` / `confirmed` back to `failed`. Direct Firestore writes to `requests/{reqId}.status` from clients remain forbidden by rules.
- A `collectionGroup('reports')` index is required for the admin queue (sorted by `createdAt desc`, filtered by `status == 'open'`).
- A Request can be Reported even after it reaches `confirmed` — Confirm does not lock out a later Report. The two are not mutually exclusive, only practically rare. Rules must allow the Report-filing path against `confirmed` Requests.
- Filing surfaces are limited to the confirm page and the user-side history detail sheet, gated on Request status ∈ {`delivered`, `confirmed`, `failed`} AND no existing `open` Report. Queue rows and tracking page do NOT offer Report filing — pre-delivery anomalies are out of scope (see CONTEXT.md example dialogue).
