create table job_postings.postings
(
    uuid              uuid                           default gen_random_uuid()                    not null
        constraint postings_pk
            primary key,
    uid               varchar                                                                      not null,
    publication_date  date                                                                         not null,
    title             varchar                                                                      not null,
    url               varchar                                                                      not null,
    title_vector      real[],
    content_path      varchar,
    content_vector    real[],
    evaluation_status job_postings.evaluation_status default 'NEW'::job_postings.evaluation_status not null,
    response_status   job_postings.response_status,
    created_at        timestamp with time zone       default now()                                 not null,
    updated_at        timestamp with time zone
);

comment on table job_postings.postings is 'Метаданные вакансий';

comment on column job_postings.postings.uuid is 'Внутренний UUID вакансии, генерируется системой';

comment on column job_postings.postings.uid is 'Уникальный ID вакансии на сайте вакансий';

comment on column job_postings.postings.publication_date is 'Дата публикации на сайте';

comment on column job_postings.postings.url is 'URL вакансии на сайте';

comment on column job_postings.postings.title_vector is 'Векторное представление названия';

comment on column job_postings.postings.content_path is 'Путь до содержимого в объектном хранилище';

comment on column job_postings.postings.content_vector is 'Векторное представление контента';

comment on column job_postings.postings.evaluation_status is 'Статус автоматического процесса оценки ';

comment on column job_postings.postings.response_status is 'Статус отклика, проставляется вручную';

comment on column job_postings.postings.created_at is 'Дата создания записи';

alter table job_postings.postings
    owner to postgres;

create index postings_uid_index
    on job_postings.postings (uid);

