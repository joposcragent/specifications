create table if not exists orchestration.async_jobs_to_job_postings
(
    uuid              uuid default gen_random_uuid() not null,
    async_job_uuid    uuid                           not null,
    job_postings_uuid uuid                           not null
);

alter table orchestration.async_jobs_to_job_postings
    owner to postgres;

create unique index if not exists asunc_jobs_to_job_postings_job_postings_uuid_async_job_uuid_uin
    on orchestration.async_jobs_to_job_postings (job_postings_uuid, async_job_uuid);

comment on index orchestration.asunc_jobs_to_job_postings_job_postings_uuid_async_job_uuid_uin is 'Индекс для отбора джобов по вакансиям';

alter table orchestration.async_jobs_to_job_postings
    add constraint async_jobs_to_job_postings_pk
        primary key (uuid);

alter table orchestration.async_jobs_to_job_postings
    add constraint async_jobs_to_job_postings_async_jobs_uuid_fk
        foreign key (async_job_uuid) references orchestration.async_jobs
            on delete cascade;

