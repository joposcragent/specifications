create table if not exists user_profile.reference_context
(
    uuid       uuid                     default uuid_generate_v4() not null,
    text       varchar                                             not null,
    vector     real[]                                              not null,
    created_at timestamp with time zone default now()              not null,
    updated_at timestamp with time zone
);

alter table user_profile.reference_context
    add constraint reference_context_pk
        primary key (uuid);

