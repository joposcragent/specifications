create type job_postings.evaluation_status as enum (
    'NEW',
    'TITLE_IRRELEVANT',
    'PENDING',
    'IRRELEVANT',
    'RELEVANT'
    );

alter type job_postings.evaluation_status owner to postgres;
