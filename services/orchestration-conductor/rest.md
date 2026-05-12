# REST API orchestration-conductor

<!-- markdownlint-disable MD013 -->

## Отправка сообщения в очередь

`POST /topic/{messageType}`

| Входной параметр    | Источник      | Комментарий                                  |
|---------------------|---------------|----------------------------------------------|
| 📌`{messageType}`   | path-параметр | Имя топика, в которой отправляется сообщение |
| 📌`{commonMessage}` | тело запроса  |                                              |

Алгоритм работы:

1. Валидирует структуру `{commonMessage}`
   1. При ошибках возвращает HTTP 400
2. Отправляет сообщение `{commonMessage}` в топик `{messageType}`
3. Возвращает HTTP 202 без тела

Примечание: значение `async-job-end` для `{messageType}` не поддерживается;
завершение джоба отправляют через `POST /topic/async-job-end`
(см. следующий раздел).

## Отправка сообщения async-job-end в очередь

`POST /topic/async-job-end`

| Входной параметр         | Источник     | Комментарий |
|--------------------------|--------------|-------------|
| 📌`{AsyncJobEndMessage}` | тело запроса |             |

Алгоритм работы:

1. Валидирует структуру `{AsyncJobEndMessage}`
   1. При ошибках возвращает HTTP 400
2. Отправляет сообщение `{AsyncJobEndMessage}` в топик `async-job-end`
3. Возвращает HTTP 202 без тела

## Получение данных асинхронного джоба

`GET /async-jobs/{jobUuid}`

| Входной параметр | Источник      | Комментарий |
|------------------|---------------|-------------|
| 📌`{jobUuid}`    | path-параметр |             |

Алгоритм работы:

1. Ищет в БД `joposcragent.orchestration.async_jobs` запись с `uuid` = `{jobUuid}`
   1. Если не находит, возвращает HTTP 404
2. Возвращает `AsyncJobItem`, заполненный данными найденной записи, с HTTP 200

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
   3. `started_at`<=`{startedBefore}`;
   4. limit и offset на основании `{size}` и `{page}`.
2. Все query-параметры опциональные, комбинируются по `AND`.
3. Возвращает `AsyncJobList` с массивом найденных записей.
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

1. Выбирает массив `{async_job_uuid}` помощи UNION:
   1. Из `joposcragent.orchestration.async_jobs_to_job_postings` записи по `job_postings_uuid` = `{entityUuid}`;
   2. Из `joposcragent.orchestration.async_jobs_to_search_queries` записи по `search_query_uuid` = `{entityUuid}`.
2. Выбирает из `joposcragent.orchestration.async_jobs`:
   1. все записи, входящие в `{async_job_uuid}`;
   2. применяет отборы:
      1. `status` = `{status}`;
      2. `started_at`<=`{startedBefore}`;
   3. применяет limit и offset на основании `{size}` и `{page}`.
3. Из полученных записей формирует и возвращает объект `AsyncJobList`.
4. Если не нашлось ни одной записи, то возвращает `AsyncJobList` с пустым массивом внутри, с HTTP 200.

## Получение всей иерархии джобов, начинающейся на {parentJobUuid}

`GET /async-jobs/hierarchy/{parentJobUuid}`

| Входной параметр    | Источник       | Комментарий |
|---------------------|----------------|-------------|
| 📌`{parentJobUuid}` | path-параметр  |             |
| `{size}`            | query-параметр |             |
| `{page}`            | query-параметр |             |

Алгоритм работы:

1. Если в `joposcragent.orchestration.async_jobs` нет строки с `uuid` = `{parentJobUuid}`, возвращает HTTP 404
2. Выбирает из `joposcragent.orchestration.async_jobs`:
   1. рекурсивно все строки, подчиненные `{parentJobUuid}` по полю `parent_uuid`;
   2. применяет `limit` и `offset`, если переданы `{size}` и `{page}`.
3. Из получившихся строк строит дерево `AsyncJobHierarchy` и возвращает его с кодом 200.
4. Если ничего, кроме `{parentJobUuid}`, не найдено, возвращает 200 и `AsyncJobHierarchy` с заполненным `root`, но пустым массивом `children`;

## Получение всех джобов, связанных с {entityUuid}

`GET /async-jobs/hierarchy/related/{entityUuid}`

| Входной параметр | Источник       | Комментарий |
|------------------|----------------|-------------|
| 📌`{entityUuid}` | path-параметр  |             |
| `{size}`         | query-параметр |             |
| `{page}`         | query-параметр |             |

Алгоритм работы:

1. Выбирает в массив `{all_related_uuid}` помощи UNION поле `async_job_uuid`:
   1. Из `joposcragent.orchestration.async_jobs_to_job_postings` записи по `job_postings_uuid` = `{entityUuid}`;
   2. Из `joposcragent.orchestration.async_jobs_to_search_queries` записи по `search_query_uuid` = `{entityUuid}`.
2. Выбирает в `{root_records}` из `joposcragent.orchestration.async_jobs` все строки, у которых `uuid` входит в список `{all_related_uuid}`;
3. Рекурсивно отбирает из `joposcragent.orchestration.async_jobs` все строки:
   1. подчиненные по `parent_uuid` всем строкам из `{root_records}` прямо или косвенно;
   2. применяет `limit` и `offset`, если переданы `{size}` и `{page}`.
4. Из получившегося массива строит дерево `AsyncJobHierarchyRelatedList` и возвращает его с кодом 200.
5. Если не нашлось ни одной строки, все равно возвращает `AsyncJobHierarchyRelatedList` с кодом 200 и пустым `list`
