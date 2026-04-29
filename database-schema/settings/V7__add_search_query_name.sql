alter table settings.search_queries
    add column name varchar(512);

update settings.search_queries
set name = left(query, 512)
where name is null;

alter table settings.search_queries
    alter column name set not null;
