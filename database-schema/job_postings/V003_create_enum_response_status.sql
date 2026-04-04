create type job_postings.response_status as enum (
    'NEW',
    'NOT_INTERESTED',
    'RESPONDED',
    'REJECTED'
    );

alter type job_postings.response_status owner to postgres;

