create table settings.css_query_selectors
(
    uuid       uuid                     default uuid_generate_v4() not null
        constraint css_query_selectors_pk
            primary key,
    selector   varchar                                             not null,
    type       settings.css_query_selector_type                    not null
        constraint css_query_selectors_uk_type
            unique,
    created_at timestamp with time zone default now()              not null,
    updated_at timestamp with time zone
);

comment on constraint css_query_selectors_uk_type on settings.css_query_selectors is 'Не может быть больше одного селектора одного типа';

alter table settings.css_query_selectors
    owner to postgres;

