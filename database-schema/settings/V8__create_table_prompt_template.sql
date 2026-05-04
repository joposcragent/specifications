create table settings.prompt_template
(
    uuid       uuid        default gen_random_uuid() not null
        constraint prompt_template_pk
            primary key,
    template   varchar,
    created_at timestamptz default now()             not null,
    updated_at timestamptz
);

comment on table settings.prompt_template is 'Таблица хранит одну строку: шаблон промпта для сопроводительного письма';

alter table settings.prompt_template
    owner to postgres;

do
$$
    begin
        if not exists (select 1 from settings.prompt_template) then
            insert into settings.prompt_template(uuid, template)
            values (gen_random_uuid(),
                    'Ты опытный HR-менеджер. Твоя задача: проанализировать текст вакансии и резюме пользователя, составить эффективное сопроводительное письмо.' ||
                    '\n\n' ||
                    '=== ВАКАНСИЯ ===' ||
                    '\n' ||
                    '$' ||
                    '{JOB_POSTING_CONTENT}' ||
                    '\n\n' ||
                    '\n' ||
                    '=== РЕЗЮМЕ ===' ||
                    '$' ||
                    '{RESUME}');
        end if;
    end
$$;
