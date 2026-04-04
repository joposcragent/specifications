create table settings.reference_context
(
    uuid       uuid                     default uuid_generate_v4() not null
        constraint reference_context_pk
            primary key,
    text       varchar                                             not null,
    vector     real[]                                              not null,
    created_at timestamp with time zone default now()              not null,
    updated_at timestamp with time zone
);

alter table settings.reference_context
    owner to postgres;

