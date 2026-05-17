alter table orchestration.scheduler
    rename column cron_expression to interval;

alter table orchestration.scheduler
    alter column interval set default 'PT1H'::character varying;

update orchestration.scheduler
set interval='PT1H';
