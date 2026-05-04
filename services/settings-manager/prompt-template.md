# Контроллер шаблона промпта (сопроводительное письмо)

<!-- markdownlint-disable MD013 -->

Работает с PostgreSQL:

- База данных `joposcragent`
- Схема `settings`
- Таблица `prompt_template`

В миграции `V8__create_table_prompt_template.sql` литералы `${JOB_POSTING_CONTENT}` и `${RESUME}` в выражении `DEFAULT` записаны через конкатенацию (`'$' || '{JOB_POSTING_CONTENT}'` и т.д.), чтобы Flyway не воспринимал их как свои плейсхолдеры; в базе хранится обычная строка с `${...}`.

## Получение шаблона

`GET /prompt-template`

Алгоритм работы:

1. Если таблица `prompt_template` пустая, возвращает `HTTP 404`
2. Иначе читает одну строку (первая по `limit 1`)
3. Возвращает JSON **`PromptTemplate`**: `template` (nullable), `createdAt`, `updatedAt` (nullable)
4. При необработанном исключении — `HTTP 500` с текстом ошибки в теле

## Сохранение шаблона

`POST /prompt-template`

| Входной параметр | Источник     | Описание                          |
|------------------|--------------|-----------------------------------|
| Текст шаблона    | тело запроса | `Content-Type: text/plain`        |

Алгоритм работы:

1. Если строки нет — вставить новую с переданным текстом в `template`, `created_at` = `now()`, `updated_at` = `null`
2. Если строка есть — обновить `template`, установить `updated_at` = `now()`; `created_at` не менять
3. Успех: `HTTP 200`, тело — тот же объект **`PromptTemplate`**, что и у `GET` (включая актуальный `template` и метки времени)
4. При необработанном исключении — `HTTP 500`

Плейсхолдеры в тексте шаблона (подстановка на стороне UI при сборке промпта для вакансии):

- `${JOB_POSTING_CONTENT}` — текст вакансии
- `${RESUME}` — эталонный контекст (резюме); см. [контроллер эталонного контекста][reference-context-doc]

[reference-context-doc]: ./reference-context.md
