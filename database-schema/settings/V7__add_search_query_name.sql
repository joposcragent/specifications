alter table settings.search_queries
    add column name varchar;

update settings.search_queries
set name = left(query, 100)
where name is null;

alter table settings.search_queries
    alter column name set not null;
