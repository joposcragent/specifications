-- Выровнять схему с продуктовым правилом: статус рассмотрения всегда задан (по умолчанию NEW).
update job_postings.postings
set response_status = 'NEW'::job_postings.response_status
where response_status is null;

alter table job_postings.postings
    alter column response_status set not null;

alter table job_postings.postings
    alter column response_status set default 'NEW'::job_postings.response_status;
