-- Run each statement separately after applying the integrity migration.
-- Every statement below should be rejected by PostgreSQL.

-- 1. Capacity cannot be negative.
-- Expected: 23514 (check_violation), trips_capacity_non_negative
update trips
set capacity = -1
where id = 'TRIP-M2-20260429-0800';

-- 2. Reserved seats cannot exceed capacity.
-- Expected: 23514 (check_violation), trips_reserved_seats_valid
update trips
set reserved_seats = capacity + 1
where id = 'TRIP-M2-20260429-0800';

-- 3. Reserved seats cannot be negative.
-- Expected: 23514 (check_violation), trips_reserved_seats_valid
update trips
set reserved_seats = -1
where id = 'TRIP-M2-20260429-0800';

-- 4. Product price cannot be negative.
-- Expected: 23514 (check_violation), products_price_non_negative
update products
set price = -1
where code = 'SINGLE';

-- 5. Currency must use the agreed three-letter uppercase form.
-- Expected: 23514 (check_violation), products_currency_format
update products
set currency = 'dkk'
where code = 'SINGLE';

-- 6. A ticket must reference an existing trip.
-- Expected: 23503 (foreign_key_violation), tickets_trip_fk
insert into tickets (
    id, user_id, trip_id, ticket_code, status,
    product_code, valid_from_utc, valid_to_utc, price, currency
) values (
    'T-INVALID-TRIP', 'USER-1', 'TRIP-DOES-NOT-EXIST',
    'CODE-INVALID-TRIP', 'Active', 'SINGLE',
    '2026-04-29 08:00:00+00', '2026-04-29 09:00:00+00', 36, 'DKK'
);

-- 7. A ticket must reference an existing user.
-- Expected: 23503 (foreign_key_violation), tickets_user_fk
insert into tickets (
    id, user_id, trip_id, ticket_code, status,
    product_code, valid_from_utc, valid_to_utc, price, currency
) values (
    'T-INVALID-USER', 'USER-DOES-NOT-EXIST', 'TRIP-M2-20260429-0800',
    'CODE-INVALID-USER', 'Active', 'SINGLE',
    '2026-04-29 08:00:00+00', '2026-04-29 09:00:00+00', 36, 'DKK'
);

-- 8. A ticket must reference an existing product.
-- Expected: 23503 (foreign_key_violation), tickets_product_fk
insert into tickets (
    id, user_id, trip_id, ticket_code, status,
    product_code, valid_from_utc, valid_to_utc, price, currency
) values (
    'T-INVALID-PRODUCT', 'USER-1', 'TRIP-M2-20260429-0800',
    'CODE-INVALID-PRODUCT', 'Active', 'NO-SUCH-PRODUCT',
    '2026-04-29 08:00:00+00', '2026-04-29 09:00:00+00', 36, 'DKK'
);

-- 9. Ticket validity cannot end before it starts.
-- Expected: 23514 (check_violation), tickets_validity_window_valid
insert into tickets (
    id, user_id, trip_id, ticket_code, status,
    product_code, valid_from_utc, valid_to_utc, price, currency
) values (
    'T-REVERSED', 'USER-1', 'TRIP-M2-20260429-0800',
    'CODE-REVERSED', 'Active', 'SINGLE',
    '2026-04-29 09:00:00+00', '2026-04-29 08:00:00+00', 36, 'DKK'
);

-- 10. Ticket codes must be unique.
-- Expected: 23505 (unique_violation), tickets_ticket_code_unique
insert into tickets (
    id, user_id, trip_id, ticket_code, status,
    product_code, valid_from_utc, valid_to_utc, price, currency
)
select
    'T-DUPLICATE-CODE', user_id, trip_id, ticket_code, status,
    product_code, valid_from_utc, valid_to_utc, price, currency
from tickets
where id = 'TICKET-1';

-- 11. Ticket status must come from the accepted set.
-- Expected: 23514 (check_violation), tickets_status_allowed
update tickets
set status = 'Unknown'
where id = 'TICKET-1';

-- 12. Ticket price cannot be negative.
-- Expected: 23514 (check_violation), tickets_price_non_negative
update tickets
set price = -1
where id = 'TICKET-1';

-- 13. A payment must reference an existing ticket.
-- Expected: 23503 (foreign_key_violation), payments_ticket_fk
insert into payments (
    id, user_id, ticket_id, external_payment_reference,
    amount, currency, status
) values (
    'PAYMENT-UNKNOWN-TICKET', 'USER-1', 'NO-SUCH-TICKET',
    'gateway-capture-invalid', 36, 'DKK', 'Captured'
);

-- 14. Payment amount cannot be negative.
-- Expected: 23514 (check_violation), payments_amount_non_negative
update payments
set amount = -1
where id = 'PAYMENT-1';

-- 15. A captured payment must have an external reference.
-- Expected: 23514 (check_violation), payments_captured_reference_required
update payments
set external_payment_reference = null
where id = 'PAYMENT-1';

-- 16. The same external payment reference cannot be stored twice.
-- Expected: 23505 (unique_violation), payments_external_reference_unique
insert into payments (
    id, user_id, ticket_id, external_payment_reference,
    amount, currency, status
) values (
    'PAYMENT-DUPLICATE-REFERENCE', 'USER-1', 'TICKET-1',
    'gateway-capture-0001', 36, 'DKK', 'Captured'
);

-- 17. Validation ticket id and code must identify the same ticket.
-- Expected: 23503 (foreign_key_violation), validations_ticket_identity_fk
insert into validations (
    id, ticket_id, ticket_code, vehicle_id, stop_id, device_id, result
) values (
    'VALIDATION-MISMATCH', 'TICKET-1', 'CODE-5C-0001',
    'BUS-5C-01', 'STOP-CENTRAL', 'DEVICE-01', 'Accepted'
);

-- 18. Validation result must come from the accepted set.
-- Expected: 23514 (check_violation), validations_result_allowed
update validations
set result = 'Maybe'
where id = 'VALIDATION-1';

-- 19. A recorded validation stop must exist.
-- Expected: 23503 (foreign_key_violation), validations_stop_fk
insert into validations (
    id, ticket_id, ticket_code, vehicle_id, stop_id, device_id, result
) values (
    'VALIDATION-BAD-STOP', 'TICKET-1', 'CODE-M2-0001',
    'METRO-M2-01', 'STOP-DOES-NOT-EXIST', 'DEVICE-01', 'Accepted'
);
