create table if not exists orchestration.scheduler
(
    next_run        timestamp with time zone default (now() + '01:00:00'::interval) not null,
    cron_expression varchar                  default '0 * * * *'::character varying not null
);

alter table orchestration.scheduler
    owner to postgres;

alter table orchestration.scheduler
    add constraint scheduler_pk
        primary key (next_run);

