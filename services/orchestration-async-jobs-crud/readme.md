<!-- markdownlint-disable MD013 -->

# REST API orchestration-async-jobs-crud

Сервис ведёт учёт асинхронных джобов в PostgreSQL (`joposcragent`, схема `orchestration`). Помимо REST-ручек ниже, он **подписан на Kafka** и по сообщениям begin/result создаёт строки джобов, связи с сущностями и завершающие статусы.

## Kafka

Потребители, фильтр по `type`, таблицы и согласованность с REST описаны в [спецификации по Kafka][kafka-async].

## Создать новый джоб

`POST /async-jobs/{jobUuid}`

| Входной параметр         | Источник      | Комментарий                         |
|--------------------------|---------------|-------------------------------------|
| 📌`{jobUuid}`            | path-параметр | Совпадает с `uuid` в теле запроса   |
| 📌`{createAsyncJobItem}` | тело запроса  | Объект `CreateAsyncJobItem`         |

Алгоритм работы:

1. Валидирует тело запроса как `CreateAsyncJobItem`.
   1. При ошибках валидации возвращает HTTP 400.
2. Ищет в БД `joposcragent.orchestration.async_jobs` запись с `uuid` = `{jobUuid}`.
   1. Если запись уже есть, возвращает HTTP 409.
3. Создаёт новую строку в `joposcragent.orchestration.async_jobs` с полями:
   1. `uuid` = `{jobUuid}`;
   2. `name` = `{createAsyncJobItem}.name`;
   3. `parent_uuid` = `{createAsyncJobItem}.parentUuid`;
   4. `context` = сериализованный JSON из `{createAsyncJobItem}.context`, если поле передано в теле; иначе `NULL`;
   5. остальные дефолтные
4. Возвращает HTTP 200 без тела.

## Обновить данные джоба

`PATCH /async-jobs/{jobUuid}`

| Входной параметр         | Источник      | Комментарий                         |
|--------------------------|---------------|-------------------------------------|
| 📌`{jobUuid}`            | path-параметр |                                     |
| 📌`{patchAsyncJobItem}`  | тело запроса  | Объект `PatchAsyncJobItem`          |

Алгоритм работы:

1. Валидирует тело запроса как `PatchAsyncJobItem`.
   1. При ошибках валидации или если в теле нет ни одного поля для изменения, возвращает HTTP 400.
2. Ищет в БД `joposcragent.orchestration.async_jobs` запись с `uuid` = `{jobUuid}`.
   1. Если не находит, возвращает HTTP 404.
3. Обновляет найденную запись только по полям, присутствующим в `{patchAsyncJobItem}`
   (частичное обновление; отсутствующие поля не меняются). Для `context` допускается значение JSON `null` в теле — в этом случае в БД записывается `NULL`.
4. Возвращает HTTP 200 без тела.

## Установка завершающего статуса для джоба

`POST /async-jobs/{jobUuid}/finish/{terminalStatus}`

| Входной параметр         | Источник      | Комментарий                         |
|--------------------------|---------------|-------------------------------------|
| 📌`{jobUuid}`            | path-параметр |                                     |
| 📌`{terminalStatus}`     | path-параметр | `SUCCEEDED`, `FAILED` или `CANCELED`|

Алгоритм работы:

1. Проверяет, что `{terminalStatus}` — одно из значений `SUCCEEDED`, `FAILED`, `CANCELED`.
   1. Иначе возвращает HTTP 400.
2. Ищет в БД `joposcragent.orchestration.async_jobs` запись с `uuid` = `{jobUuid}`.
   1. Если не находит, возвращает HTTP 404.
3. Если у найденной записи `status` не равен `STARTED`, возвращает HTTP 409 без изменений в БД.
4. Записывает статус в `joposcragent.orchestration.async_jobs`:
   1. `status` = `{terminalStatus}`
   2. `finished_at` = `updated_at` = `now()`
5. Если в конфигурации сервиса `app.autoresolve-parent-tasks` = `true` (по умолчанию `false`) **и** у обновлённого джоба заполнен `parent_uuid` и строка-родитель в `joposcragent.orchestration.async_jobs` с `uuid` = этому `parent_uuid` имеет `status` = `STARTED`:
   1. Ищет в `joposcragent.orchestration.async_jobs` все строки с тем же `parent_uuid`, что и у обновлённого джоба, и со `status` = `STARTED` (сам обновлённый джоб после шага 4 уже не учитывается).
   2. Если таких строк нет, устанавливает родителю (`uuid` = `parent_uuid`) `status` = `SUCCEEDED` и `finished_at` = `updated_at` = `now()`.
6. Возвращает HTTP 200 без тела.

## Получение данных асинхронного джоба

`GET /async-jobs/{jobUuid}`

| Входной параметр | Источник      | Комментарий |
|------------------|---------------|-------------|
| 📌`{jobUuid}`    | path-параметр |             |

Алгоритм работы:

1. Ищет в БД `joposcragent.orchestration.async_jobs` запись с `uuid` = `{jobUuid}`.
   1. Если не находит, возвращает HTTP 404.
2. Возвращает `AsyncJobItem`, заполненный данными найденной записи (включая `context` из БД, при `NULL` в колонке — `null` в JSON), с HTTP 200.

## Добавить связи джоба

`POST /async-jobs/{jobUuid}/related/{entityKind}/{entityUuid}`

| Входной параметр         | Источник      | Комментарий                         |
|--------------------------|---------------|-------------------------------------|
| 📌`{jobUuid}`            | path-параметр |                                     |
| 📌`{entityKind}`         | path-параметр | `POSTING` или `QUERY`               |
| 📌`{entityUuid}`         | path-параметр | UUID связанной сущности             |

Алгоритм работы:

1. Проверяет, что `{entityKind}` равен `POSTING` или `QUERY`.
   1. Иначе возвращает HTTP 400.
2. Ищет в БД `joposcragent.orchestration.async_jobs` запись с `uuid` = `{jobUuid}`.
   1. Если не находит, возвращает HTTP 404.
3. В зависимости от `{entityKind}` добавляет строку в соответствующую таблицу связей:
   1. если `{entityKind}` = `POSTING` — вставка в `joposcragent.orchestration.async_jobs_to_job_postings`
      с полями `async_job_uuid` = `{jobUuid}` и `job_postings_uuid` = `{entityUuid}`;
   2. если `{entityKind}` = `QUERY` — вставка в `joposcragent.orchestration.async_jobs_to_search_queries`
      с полями `async_job_uuid` = `{jobUuid}` и `search_query_uuid` = `{entityUuid}`.
4. Если такая запись в таблице `async_jobs_to_*` уже есть, возвращает HTTP 409 без тела.
5. Возвращает HTTP 200 без тела.

## Получение списка асинхронных джобов

Список джобов в соответствии с отборами

`GET /async-jobs/list`

| Входной параметр  | Источник       | Комментарий |
|-------------------|----------------|-------------|
| `{parentJobUuid}` | query-параметр |             |
| `{status}`        | query-параметр |             |
| `{startedBefore}` | query-параметр |             |
| `{size}`          | query-параметр |             |
| `{page}`          | query-параметр |             |

Алгоритм работы:

1. Делает запрос в БД `joposcragent.orchestration.async_jobs` с отборами:
   1. `parent_uuid` = `{parentJobUuid}`;
   2. `status` = `{status}`;
   3. `started_at` <= `{startedBefore}`;
   4. limit и offset на основании `{size}` и `{page}`.
2. Все query-параметры опциональные, комбинируются по `AND`.
3. Возвращает `AsyncJobList` с массивом найденных записей (каждая запись — `AsyncJobItem`, в том числе с полем `context`).
4. Если ничего не нашлось, то `AsyncJobList` возвращается с пустым массивом внутри, с HTTP 200.

## Получение списка асинхронных джобов, связанных с {entityUuid}

Возвращает плоский список джобов, связанных с {entityUuid}.

`GET /async-jobs/list/related/{entityUuid}`

| Входной параметр  | Источник       | Комментарий                           |
|-------------------|----------------|---------------------------------------|
| 📌`{entityUuid}`  | path-параметр  | UUID объекта, с которым связаны джобы |
| `{status}`        | query-параметр |                                       |
| `{startedBefore}` | query-параметр |                                       |
| `{size}`          | query-параметр |                                       |
| `{page}`          | query-параметр |                                       |

Алгоритм работы:

1. Выбирает массив `{async_job_uuid}` с помощью UNION:
   1. Из `joposcragent.orchestration.async_jobs_to_job_postings` записи по `job_postings_uuid` = `{entityUuid}`;
   2. Из `joposcragent.orchestration.async_jobs_to_search_queries` записи по `search_query_uuid` = `{entityUuid}`.
2. Выбирает из `joposcragent.orchestration.async_jobs`:
   1. все записи, входящие в `{async_job_uuid}`;
   2. применяет отборы:
      1. `status` = `{status}`;
      2. `started_at` <= `{startedBefore}`;
   3. применяет limit и offset на основании `{size}` и `{page}`.
3. Из полученных записей формирует и возвращает объект `AsyncJobList` (элементы — `AsyncJobItem`, с полем `context`).
4. Если не нашлось ни одной записи, то возвращает `AsyncJobList` с пустым массивом внутри, с HTTP 200.

## Получение всей иерархии джобов с корнем {parentJobUuid}

`GET /async-jobs/hierarchy/{parentJobUuid}`

| Входной параметр    | Источник       | Комментарий |
|---------------------|----------------|-------------|
| 📌`{parentJobUuid}` | path-параметр  |             |
| `{size}`            | query-параметр |             |
| `{page}`            | query-параметр |             |

Алгоритм работы:

1. Если в `joposcragent.orchestration.async_jobs` нет строки с `uuid` = `{parentJobUuid}`, возвращает HTTP 404.
2. Выбирает из `joposcragent.orchestration.async_jobs`:
   1. рекурсивно все строки, подчинённые `{parentJobUuid}` по полю `parent_uuid`;
   2. применяет `limit` и `offset`, если переданы `{size}` и `{page}`.
3. Из получившихся строк строит дерево `AsyncJobHierarchy` и возвращает его с кодом 200.
4. Если ничего, кроме `{parentJobUuid}`, не найдено, возвращает 200 и `AsyncJobHierarchy` с заполненным `root`, но пустым массивом `children`.

## Получение всех джобов, связанных с {entityUuid}

`GET /async-jobs/hierarchy/related/{entityUuid}`

| Входной параметр | Источник       | Комментарий |
|------------------|----------------|-------------|
| 📌`{entityUuid}` | path-параметр  |             |
| `{size}`         | query-параметр |             |
| `{page}`         | query-параметр |             |

Алгоритм работы:

1. Выбирает в массив `{all_related_uuid}` с помощью UNION поле `async_job_uuid`:
   1. Из `joposcragent.orchestration.async_jobs_to_job_postings` записи по `job_postings_uuid` = `{entityUuid}`;
   2. Из `joposcragent.orchestration.async_jobs_to_search_queries` записи по `search_query_uuid` = `{entityUuid}`.
2. Выбирает в `{root_records}` из `joposcragent.orchestration.async_jobs` все строки, у которых `uuid` входит в список `{all_related_uuid}`;
3. Рекурсивно отбирает из `joposcragent.orchestration.async_jobs` все строки:
   1. подчинённые по `parent_uuid` всем строкам из `{root_records}` прямо или косвенно;
   2. применяет `limit` и `offset`, если переданы `{size}` и `{page}`.
4. Из получившегося массива строит дерево `AsyncJobHierarchyRelatedList` и возвращает его с кодом 200.
5. Если не нашлось ни одной строки, всё равно возвращает `AsyncJobHierarchyRelatedList` с кодом 200 и пустым `list`.

<!-- LINKS -->

[kafka-async]: ./async.md
