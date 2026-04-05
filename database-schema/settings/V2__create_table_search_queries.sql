create table settings.search_queries
(
    uuid       uuid                     default gen_random_uuid() not null
        constraint search_queries_pk
            primary key,
    query      varchar                                             not null,
    created_at timestamp with time zone default now()              not null,
    updated_at timestamp with time zone
);

alter table settings.search_queries
    owner to postgres;

