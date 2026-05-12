create type "orchestration".async_job_status as enum ('STARTED', 'SUCCEEDED', 'FAILED', 'CANCELED');

alter type "orchestration".async_job_status owner to postgres;

