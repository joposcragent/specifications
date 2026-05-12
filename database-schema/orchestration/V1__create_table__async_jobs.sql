create table if not exists orchestration.async_jobs
(
    uuid        uuid                           default gen_random_uuid()                         not null,
    name        varchar                                                                          not null,
    parent_uuid uuid,
    status      orchestration.async_job_status default 'STARTED'::orchestration.async_job_status not null,
    result      jsonb,
    started_at  timestamp with time zone       default now()                                     not null,
    updated_at  timestamp with time zone,
    finished_at timestamp with time zone
);

comment on column orchestration.async_jobs.name is 'Имя джоба (collection-batch, job-posting-ceate, etc)';

alter table orchestration.async_jobs
    owner to postgres;

create index if not exists async_jobs_name_index
    on orchestration.async_jobs (name);

comment on index orchestration.async_jobs_name_index is 'Поиск по имени топика';

create index if not exists async_jobs_parent_uuid_index
    on orchestration.async_jobs (parent_uuid);

comment on index orchestration.async_jobs_parent_uuid_index is 'Поиск непосредственных потомков';

create index if not exists async_jobs_status_started_at_index
    on orchestration.async_jobs (status, started_at);

comment on index orchestration.async_jobs_status_started_at_index is 'Поиск устаревших статусов';

create unique index if not exists async_jobs_parent_uuid_uuid_uindex
    on orchestration.async_jobs (parent_uuid, uuid);

comment on index orchestration.async_jobs_parent_uuid_uuid_uindex is 'Индекс для иерархических запросов';

alter table orchestration.async_jobs
    add constraint async_jobs_pk
        primary key (uuid);

comment on index orchestration.async_jobs_pk is 'Первичный ключ';

