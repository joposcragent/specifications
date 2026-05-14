create type orchestration.scheduler_jobs as enum ('COLLECTION_BATCH', 'RETENTION');

alter type orchestration.scheduler_jobs owner to postgres;

