-- All statements in this file should succeed after the integrity migration.
-- The transaction is rolled back so the test data is not kept.

begin;

update trips
set reserved_seats = reserved_seats + 1
where id = 'TRIP-M2-20260429-1200';

insert into tickets (
    id, user_id, trip_id, ticket_code, status, product_code,
    valid_from_utc, valid_to_utc, price, currency
) values (
    'TICKET-TEST-VALID',
    'USER-1',
    'TRIP-M2-20260429-1200',
    'CODE-TEST-VALID',
    'Active',
    'SINGLE',
    '2026-04-29 11:45:00+00',
    '2026-04-29 14:00:00+00',
    36.00,
    'DKK'
);

insert into payments (
    id, user_id, ticket_id, external_payment_reference,
    amount, currency, status
) values (
    'PAYMENT-TEST-VALID',
    'USER-1',
    'TICKET-TEST-VALID',
    'gateway-capture-test-valid',
    36.00,
    'DKK',
    'Captured'
);

insert into validations (
    id, ticket_id, ticket_code, vehicle_id, stop_id, device_id,
    result, validated_utc
) values (
    'VALIDATION-TEST-VALID',
    'TICKET-TEST-VALID',
    'CODE-TEST-VALID',
    'METRO-M2-TEST',
    'STOP-KONGENS-NYTORV',
    'DEVICE-TEST',
    'Accepted',
    '2026-04-29 12:05:00+00'
);

rollback;
