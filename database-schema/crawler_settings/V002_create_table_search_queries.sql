create table if not exists user_profile.search_queries
(
    uuid       uuid                     default uuid_generate_v4() not null,
    query      varchar                                             not null,
    created_at timestamp with time zone default now()              not null,
    updated_at timestamp with time zone
);

alter table user_profile.search_queries
    add constraint search_queries_pk
        primary key (uuid);

