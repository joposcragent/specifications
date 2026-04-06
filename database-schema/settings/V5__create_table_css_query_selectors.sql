create table settings.css_query_selectors
(
    type       settings.css_query_selector_type       not null
        constraint css_query_selectors_pk
            primary key,
    selector   varchar                                not null,
    created_at timestamp with time zone default now() not null,
    updated_at timestamp with time zone
);

alter table settings.css_query_selectors
    owner to postgres;

