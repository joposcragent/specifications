create table if not exists crawler_settings.css_query_selectors
(
    uuid     uuid default uuid_generate_v4()          not null
        constraint css_query_selectors_pk
            primary key,
    selector varchar                                  not null,
    type     crawler_settings.css_query_selector_type not null
);

alter table crawler_settings.css_query_selectors
    owner to postgres;

