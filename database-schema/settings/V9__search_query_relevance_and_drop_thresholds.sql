-- Пороги релевантности переносятся в search_queries (без DEFAULT в каталоге для порогов).
-- Булевы is_active / is_lazy_scraping — с DEFAULT по ТЗ.

alter table settings.search_queries
    add column content_relevance double precision;

alter table settings.search_queries
    add column notification_relevance double precision;

update settings.search_queries
set content_relevance     = 0.82,
    notification_relevance = 0.92
where content_relevance is null
   or notification_relevance is null;

alter table settings.search_queries
    alter column content_relevance set not null;

alter table settings.search_queries
    alter column notification_relevance set not null;

alter table settings.search_queries
    add column is_active boolean not null default true;

alter table settings.search_queries
    add column is_lazy_scraping boolean not null default false;

drop table settings.relevance_thresholds;

drop type settings.threshold_type;
