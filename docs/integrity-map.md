# Integrity map

The migration keeps the original starter DDL unchanged and adds the rules that can be enforced safely in PostgreSQL.

| Invariant | Classification | Affected tables and columns | Protection | Limitation / expected failure | Evidence |
| --- | --- | --- | --- | --- | --- |
| Capacity cannot be negative | Direct constraint | `trips.capacity` | `NOT NULL`, `trips_capacity_non_negative` | Invalid values fail with `23514` | Fail test 1 |
| Reserved seats must be between zero and capacity | Direct constraint | `trips.reserved_seats`, `trips.capacity` | `NOT NULL`, `trips_reserved_seats_valid` | Only protects one trip row; it does not solve concurrent purchases | Fail tests 2-3 |
| Trip status must be known | Direct constraint | `trips.status` | `trips_status_allowed` | New statuses require a domain/schema change | Migration |
| Product name must be present | Direct constraint | `products.name` | `NOT NULL` | Missing values fail with `23502` | Migration |
| Product price cannot be negative | Direct constraint | `products.price` | `NOT NULL`, `products_price_non_negative` | Invalid values fail with `23514` | Fail test 4 |
| Currency must be present and use the same representation | Direct constraint | `products.currency`, `tickets.currency`, `payments.currency` | `NOT NULL` plus three-letter uppercase checks | This checks representation, not whether a code is an official ISO currency | Fail test 5 |
| User email must be present and unique | Direct / unique rule | `users.email` | `NOT NULL`, `users_email_unique` | Missing email fails with `23502`; duplicate email fails with `23505` | Fail tests 20-21 |
| User disabled state must be known | Direct constraint | `users.is_disabled` | `NOT NULL` | A missing flag fails with `23502`; this does not decide what disabled users are allowed to do | Fail test 22 |
| A ticket must belong to an existing user | Direct constraint | `tickets.user_id` | `NOT NULL`, `tickets_user_fk` | Unknown users fail with `23503` | Fail test 7 |
| A ticket must refer to an existing trip | Direct constraint | `tickets.trip_id` | `NOT NULL`, `tickets_trip_fk` | Unknown trips fail with `23503` | Fail test 6 |
| A ticket must refer to an existing product | Direct constraint | `tickets.product_code` | `NOT NULL`, `tickets_product_fk` | Unknown products fail with `23503` | Fail test 8 |
| Ticket codes must identify one ticket | Unique rule | `tickets.ticket_code` | `NOT NULL`, `tickets_ticket_code_unique` | Duplicate codes fail with `23505` | Fail test 10 |
| Ticket validity cannot end before it begins | Direct constraint | `tickets.valid_from_utc`, `tickets.valid_to_utc` | `NOT NULL`, `tickets_validity_window_valid` | Reversed windows fail with `23514` | Fail test 9 |
| Ticket price cannot be negative | Direct constraint | `tickets.price` | `NOT NULL`, `tickets_price_non_negative` | Invalid values fail with `23514` | Fail test 12 |
| Ticket status must be known | Direct constraint | `tickets.status` | `tickets_status_allowed` | Accepted values are `Pending`, `Active`, `Validated`, `Cancelled`, and `Expired`; anything else fails with `23514` | Pass test and fail test 11 |
| A payment must refer to existing rows | Direct constraint | `payments.user_id`, `payments.ticket_id` | `NOT NULL`, `payments_user_fk`, `payments_ticket_fk` | Unknown references fail with `23503` | Fail test 13 |
| Payment amount cannot be negative | Direct constraint | `payments.amount` | `NOT NULL`, `payments_amount_non_negative` | Invalid values fail with `23514` | Fail test 14 |
| Captured payments need an external reference | Direct constraint | `payments.status`, `payments.external_payment_reference` | `payments_captured_reference_required` | A captured payment without a reference fails with `23514` | Fail test 15 |
| One external payment reference cannot be stored twice | Unique rule | `payments.external_payment_reference` | `payments_external_reference_unique` | Duplicate non-null references fail with `23505`; several nulls are allowed | Fail test 16 |
| Validation ticket id and code must point to the same ticket | Unique / referential rule | `validations.ticket_id`, `validations.ticket_code` | `tickets_identity_unique`, `validations_ticket_identity_fk` | A mixed id/code pair fails with `23503` | Fail test 17 |
| Validation result must be known | Direct constraint | `validations.result` | `NOT NULL`, `validations_result_allowed` | Unknown values fail with `23514` | Fail test 18 |
| A recorded validation stop must exist | Direct constraint | `validations.stop_id` | `validations_stop_fk` | An unknown non-null stop fails with `23503` | Fail test 19 |
| A trip must never be oversold by concurrent purchases | More than one write / transaction rule | `trips.reserved_seats` and the purchase workload | Not solved by this migration | Two writers can observe the same remaining seat before either update commits | Issue 1 |
| Payment capture and local persistence must agree | External system / transaction rule | Payment gateway and `payments` | Unique reference reduces duplicate rows | A constraint cannot make the gateway call and database commit atomic | Issue 2 |
| Disabled users may or may not be allowed to buy | Ambiguous domain decision | `users.is_disabled`, purchase workflow | The flag is required, but no purchase-rule constraint is added | The case must define the behaviour before it is enforced | Issue 3 |

The status sets used in this lab are intentionally small and case-sensitive. If the lifecycle gets more states later, that should be an explicit domain and schema change rather than accepting arbitrary text.

`validations.ticket_code` is not unique. A ticket can appear in more than one validation row. The composite foreign key only makes sure that the stored ticket id and code belong to the same ticket.

## Issue register

### Issue 1 - concurrent seat reservation

- Evidence: `trips_reserved_seats_valid` keeps one trip row internally valid.
- Problem: two purchases can read the same remaining capacity before either update is committed.
- Consequence: a row-level check is not enough to define the complete purchase workflow.
- Specific improvement: handle the seat update inside a transaction with an appropriate locking or atomic update strategy.
- Open question: whether a seat is counted at ticket creation, payment capture, or another state.

### Issue 2 - external payment capture

- Evidence: `payments_external_reference_unique` prevents the same non-null gateway reference from being stored twice.
- Problem: PostgreSQL cannot guarantee that an external gateway operation and the local database commit happen together.
- Consequence: the gateway can succeed while the local write fails, or a retry can arrive later.
- Specific improvement: define idempotency and retry handling in the transaction/workflow design.
- Open question: which payment statuses and retry rules the final payment flow will use.

### Issue 3 - disabled users

- Evidence: `users.is_disabled` is now required, so every user has a stored disabled state.
- Problem: the case still does not define what that state means for purchases or existing tickets.
- Consequence: the flag is structurally reliable, but the purchase rule remains application/domain policy for now.
- Specific improvement: decide the intended behaviour before adding enforcement.
- Open question: whether disabling a user only blocks new purchases or also affects existing tickets.

## State-transition trace

### Ticket purchase

1. The user, trip and product must already exist.
2. A ticket is inserted with a unique code, valid status, non-negative price, valid currency and a valid time window.
3. The trip's `reserved_seats` may be updated and a payment row may be inserted. The payment must point to an existing user and ticket.
4. The constraints keep the resulting rows valid, but the whole multi-row purchase still needs a transaction so partial work is not committed.

### Ticket validation

1. The ticket is found using its id/code.
2. A validation row is inserted with the same ticket id and ticket code pair.
3. If a stop is recorded, it must exist. The validation result must be one of the accepted values.
4. The database does not currently enforce rules such as validation happening inside the ticket validity window because that depends on another row and on the exact domain rule.

## Delete and update behaviour

| Relationship | Policy | Reason |
| --- | --- | --- |
| `operators -> routes` | Restrict deletion while routes exist | Removing an operator should not silently remove timetable data |
| `routes -> trips` | Restrict deletion while trips exist | Trips are part of timetable and ticket history |
| `users -> tickets` | Restrict; use `is_disabled` for normal deactivation | Historical tickets should keep their owner reference |
| `trips -> tickets` | Restrict; cancel or retire trips instead of deleting them | Deleting a trip must not destroy the meaning of sold tickets |
| `products -> tickets` | Restrict | Tickets keep a reference to the product that was sold |
| `tickets -> payments` | Restrict and retain according to policy | Payment history must not disappear when a ticket is removed |
| `tickets -> validations` | Restrict and retain according to policy | Validation history is part of the audit trail |
| `stops -> validations` | Restrict while historical validations refer to the stop | Timetable cleanup must not break old validation records |

Primary and referenced identifiers are not cascaded on update. Changing an identifier used by historical rows should be rejected rather than silently changing its meaning.

## Test evidence

`database/postgres/experiments/constraints_should_pass.sql` contains valid user data, a `Pending` ticket, and a valid purchase and validation path. It runs inside a transaction and rolls the test data back at the end.

`database/postgres/experiments/constraints_should_fail.sql` contains the rejected writes. Each case states the expected SQLSTATE and named constraint, or the affected column for `NOT NULL`, so the failure is tied to a specific invariant instead of an English error message.

## What writers can rely on

After the migration, every writer can rely on the database to reject negative capacities and monetary amounts, impossible seat counts, unknown ticket relationships, duplicate ticket codes, reversed ticket validity windows, invalid stored status values, duplicated external payment references, mismatched validation ticket identities, missing user email or disabled state, and duplicate user email addresses.

The database still does not guarantee transaction-level rules such as concurrent overselling, the business meaning of a disabled user, or agreement with an external payment gateway.
