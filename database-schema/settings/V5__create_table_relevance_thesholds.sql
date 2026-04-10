create table settings.relevance_thresholds
(
    type       settings.threshold_type                not null
        constraint relevance_thresholds_pk
            primary key,
    value      real                                   not null,
    created_at timestamp with time zone default now() not null,
    updated_at timestamp with time zone
);

alter table settings.relevance_thresholds
    owner to postgres;

