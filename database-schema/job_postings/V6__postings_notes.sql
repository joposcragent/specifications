alter table job_postings.postings
    add column notes text;

comment on column job_postings.postings.notes is 'Произвольный текст заметки пользователя к вакансии';
