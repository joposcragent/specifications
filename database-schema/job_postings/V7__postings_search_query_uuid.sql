-- Связь вакансии с поисковым запросом; без DEFAULT в каталоге (значения только из приложения).

alter table job_postings.postings
    add column search_query_uuid uuid;

update job_postings.postings
set search_query_uuid = '00000000-0000-0000-0000-000000000000'::uuid
where search_query_uuid is null;

alter table job_postings.postings
    alter column search_query_uuid set not null;
