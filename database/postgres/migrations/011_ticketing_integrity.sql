begin;

alter table trips
    alter column capacity set not null,
    alter column reserved_seats set not null,
    add constraint trips_capacity_non_negative
        check (capacity >= 0),
    add constraint trips_reserved_seats_valid
        check (reserved_seats between 0 and capacity),
    add constraint trips_status_allowed
        check (status in ('Scheduled', 'Cancelled', 'Completed'));

alter table products
    alter column name set not null,
    alter column price set not null,
    alter column currency set not null,
    add constraint products_price_non_negative
        check (price >= 0),
    add constraint products_currency_format
        check (currency ~ '^[A-Z]{3}$');

alter table users
    alter column email set not null,
    alter column is_disabled set not null,
    add constraint users_email_unique
        unique (email);

alter table tickets
    alter column user_id set not null,
    alter column trip_id set not null,
    alter column ticket_code set not null,
    alter column status set not null,
    alter column product_code set not null,
    alter column valid_from_utc set not null,
    alter column valid_to_utc set not null,
    alter column price set not null,
    alter column currency set not null,
    add constraint tickets_ticket_code_unique
        unique (ticket_code),
    add constraint tickets_identity_unique
        unique (id, ticket_code),
    add constraint tickets_status_allowed
        check (status in ('Pending', 'Active', 'Validated', 'Cancelled', 'Expired')),
    add constraint tickets_price_non_negative
        check (price >= 0),
    add constraint tickets_currency_format
        check (currency ~ '^[A-Z]{3}$'),
    add constraint tickets_validity_window_valid
        check (valid_to_utc >= valid_from_utc),
    add constraint tickets_user_fk
        foreign key (user_id) references users(id)
        on update restrict on delete restrict,
    add constraint tickets_trip_fk
        foreign key (trip_id) references trips(id)
        on update restrict on delete restrict,
    add constraint tickets_product_fk
        foreign key (product_code) references products(code)
        on update restrict on delete restrict;

alter table payments
    alter column user_id set not null,
    alter column ticket_id set not null,
    alter column amount set not null,
    alter column currency set not null,
    alter column status set not null,
    alter column created_utc set not null,
    add constraint payments_external_reference_unique
        unique (external_payment_reference),
    add constraint payments_amount_non_negative
        check (amount >= 0),
    add constraint payments_currency_format
        check (currency ~ '^[A-Z]{3}$'),
    add constraint payments_status_allowed
        check (status in ('Pending', 'Captured', 'Failed', 'Refunded')),
    add constraint payments_captured_reference_required
        check (status <> 'Captured' or external_payment_reference is not null),
    add constraint payments_user_fk
        foreign key (user_id) references users(id)
        on update restrict on delete restrict,
    add constraint payments_ticket_fk
        foreign key (ticket_id) references tickets(id)
        on update restrict on delete restrict;

alter table validations
    alter column ticket_id set not null,
    alter column ticket_code set not null,
    alter column result set not null,
    alter column validated_utc set not null,
    add constraint validations_result_allowed
        check (result in ('Accepted', 'Rejected')),
    add constraint validations_ticket_identity_fk
        foreign key (ticket_id, ticket_code)
        references tickets(id, ticket_code)
        on update restrict on delete restrict,
    add constraint validations_stop_fk
        foreign key (stop_id) references stops(id)
        on update restrict on delete restrict;

commit;
