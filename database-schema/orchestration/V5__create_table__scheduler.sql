create table if not exists orchestration.scheduler
(
    uuid            uuid    default gen_random_uuid()              not null,
    job_type        orchestration.scheduler_jobs                   not null,
    next_run        timestamp with time zone                       not null,
    cron_expression varchar default '0 * * * *'::character varying not null
);

alter table orchestration.scheduler
    owner to postgres;

alter table orchestration.scheduler
    add constraint scheduler_pk
        primary key (uuid);

alter table orchestration.scheduler
    add constraint scheduler_idx_unique_job_type
        unique (job_type);

