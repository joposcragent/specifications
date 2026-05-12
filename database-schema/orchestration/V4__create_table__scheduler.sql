create table if not exists orchestration.async_jobs_to_search_queries
(
    uuid              uuid not null,
    async_job_uuid    uuid not null,
    search_query_uuid uuid not null
);

alter table orchestration.async_jobs_to_search_queries
    owner to postgres;

create unique index if not exists async_jobs_to_search_queries_search_query_uuid_async_job_uuid_u
    on orchestration.async_jobs_to_search_queries (search_query_uuid, async_job_uuid);

comment on index orchestration.async_jobs_to_search_queries_search_query_uuid_async_job_uuid_u is 'Для отбора джобов по поисковым запросам';

alter table orchestration.async_jobs_to_search_queries
    add constraint async_jobs_to_search_queries_pk
        primary key (uuid);

alter table orchestration.async_jobs_to_search_queries
    add constraint async_jobs_to_search_queries_async_jobs_uuid_fk
        foreign key (async_job_uuid) references orchestration.async_jobs
            on delete cascade;

