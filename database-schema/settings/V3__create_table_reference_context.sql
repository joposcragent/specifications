create table settings.reference_context
(
    uuid       uuid                     default gen_random_uuid() not null
        constraint reference_context_pk
            primary key,
    text       varchar                                             not null,
    vector     real[]                                              not null,
    created_at timestamp with time zone default now()              not null,
    updated_at timestamp with time zone
);

comment on table settings.reference_context is 'Таблица всегда хранит одну или ноль строк, то есть по сути это kv-storage';

alter table settings.reference_context
    owner to postgres;

