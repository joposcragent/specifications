# Потребители сообщений

<!-- markdownlint-disable MD013 -->

Работает с PostgreSQL:

- База данных `joposcragent`
- Схема `orchestration`

Работает с топиками Kafka:

- collection-batch
- collection-query
- job-posting-create
- async-job-end

Структура сообщений во всех топиках, кроме `async-job-end`, идентичная и описана в [common-orchestration-message.yaml](../../messaging/common-orchestration-message.yaml).

## Топик `collection-batch`

Запрашивает настройки поисковых запросов и отправляет свое сообщение `collection-query` для каждого.

| Входящий параметр    | Источник              | Описание |
|----------------------|-----------------------|----------|
| 📌`{MessagePayload}` | тело сообщения топика |          |

Алгоритм работы:

1. Фиксирует начало асинхронного джоба:
   1. Добавляет запись в таблицу `joposcragent.orchestration.async_jobs` со следующими полями
   2. `uuid` = `{MessagePayload}.jobUuid`
   3. `parent_uuid` = `null`
   4. `name` = `'collection-batch'`
   5. `status` = `'STARTED'`
2. Запросом `GET /search-query/list?activeOnly=true` к `settings-manager` получает `{queryList}` — массив **только активных** поисковых запросов.
3. Если список пустой, фиксирует в БД отмену джоба:
   1. `status` = `CANCELED`;
   2. `result` = текст `"Не найдено ни одного активного поискового запроса"`;
   3. `updated_at` = `finished_at` = `now()`
4. Для каждого запроса из массива:
   1. Генерирует `{currentJobUuid}` - новый UUID v4
   2. Отправляет сообщение в топик `collection-query`:
      1. `headers` сообщения:
         1. `key` = `{currentJobUuid}`
         2. `createdAt` = текущий момент времени
      2. `payload` сообщения
         1. `jobUuid` = `{currentJobUuid}`
         2. `parentJobUuid` = `{MessagePayload}.jobUuid`
         3. `entityUuid` = `{queryList}.uuid` - uuid текущего поискового запроса
         4. `jsonData` = текущий элемент `{queryList}`
5. При любом не перехваченном исключении логирует ошибку и фиксирует в БД аварийное завершения джоба:
   1. `status` = `CANCELED`;
   2. `result` = текст `"${message и stack_trace ошибки}"`;
   3. `updated_at` = `finished_at` = `now()`

## Топик `collection-query`

| Входящий параметр    | Источник              | Описание |
|----------------------|-----------------------|----------|
| 📌`{MessagePayload}` | тело сообщения топика |          |

Алгоритм работы:

1. Фиксирует начало асинхронного джоба:
   1. Добавляет запись в таблицу `joposcragent.orchestration.async_jobs` со следующими полями
      1. `uuid` = `{MessagePayload}.jobUuid`
      2. `parent_uuid` = `{MessagePayload}.parentJobUuid`
      3. `name` = `'collection-query'`
      4. `status` = `'STARTED'`
   2. Добавляет (заменяет при совпадении) связь джоба с запросом в таблицу `joposcragent.orchestration.async_jobs_to_search_queries`:
      1. `async_job_uuid` = `{MessagePayload}.jobUuid`
      2. `search_query_uuid` = `{MessagePayload}.entityUuid`
2. Десериализует и валидирует `{MessagePayload}.jsonData`, назовем значение `{searchQuery}`:
   1. Ожидает, что в jsonData лежит объект со структурой [SearchQueriesItem](../settings-manager/openapi.yaml#/components/schemas/SearchQueriesItem);
   2. Если объект пустой и при ошибках десериализации:
      1. фиксирует аварийное завершения джоба (п. 5);
      2. Завершает обработку сообщения.
3. Дает команду `crawler-headhunter` на асинхронный сбор `POST /crawler/start`, передавая в теле запроса:
   1. `query` = `{searchQuery}.query`;
   2. `searchQueryUuid` = `{searchQuery}.uuid`;
   3. `lazy` = `{searchQuery}.isLazyScraping`;
   4. заголовок `X-Joposcragent-correlationId` = `{MessagePayload}.jobUuid`.
4. Если ответ `crawler-headhunter` отличается от `HTTP 200`:
   1. фиксирует в БД аварийное завершения джоба п. 5;
   2. Завершает обработку сообщения.
5. При любом не перехваченном исключении логирует ошибку и фиксирует в БД аварийное завершения джоба:
   1. `status` = `FAILED`;
   2. `result` = текст `"${message и stack_trace ошибки}"`;
   3. `updated_at` = `finished_at` = `now()`

## Топик `job-postings-create`

| Входящий параметр    | Источник              | Описание |
|----------------------|-----------------------|----------|
| 📌`{MessagePayload}` | тело сообщения топика |          |

Алгоритм работы:

1. Фиксирует начало асинхронного джоба:
   1. Добавляет запись в таблицу `joposcragent.orchestration.async_jobs` со следующими полями
      1. `uuid` = `{MessagePayload}.jobUuid`
      2. `parent_uuid` = `{MessagePayload}.parentJobUuid`
      3. `name` = `'job-posting-create'`
      4. `status` = `'STARTED'`
   2. Добавляет (заменяет при совпадении) связь джоба с вакансией в таблицу `joposcragent.orchestration.async_jobs_to_job_postings`:
      1. `async_job_uuid` = `{MessagePayload}.jobUuid`
      2. `job_postings_uuid` = `{MessagePayload}.entityUuid`
2. Десериализует и валидирует `{MessagePayload}.jsonData`, назовем значение `{jobPostingItem}`:
   1. Ожидает, что в jsonData лежит объект со структурой [JobPostingsItemWrite](../job-postings-crud/openapi.yaml#/components/schemas/JobPostingsItemWrite);
   2. Если объект пустой и при ошибках десериализации:
      1. фиксирует в БД аварийное завершения джоба п. 6;
      2. Завершает обработку сообщения.
3. Создает вакансию
   1. Запрос `POST /job-postings/{jobPostingUuid}` к сервису `job-postings-crud`:
      1. `{jobPostingUuid}` = `{MessagePayload}.entityUuid`;
      2. в тело запроса передает `{jobPostingItem}`.
4. Если от `job-postings-crud` был получен HTTP 200, запускает асинхронную оценку вакансии:
   1. Запрос `POST /evaluate/async/{jobPostingUuid}` к сервису `job-postings-evaluator`:
      1. `{jobPostingUuid}` = `{MessagePayload}.entityUuid`;
      2. заголовок `X-Joposcragent-correlationId` = `{MessagePayload}.jobUuid`.
   2. Завершает обработку сообщения (запись в async_jobs остается со статусом `STARTED`, она завершится, когда придет `async-job-end`).
5. Если от `job-postings-crud` получен ответ 409:
   1. Пишет в лог WARN `"Job posting ${uid} has already been stored earlier"`;
   2. Фиксирует в БД отмену асинхронного джоба:
      1. `status` = `'CANCELED'`;
      2. `result` = `"Evaluation skipped because ${uid} has already been stored earlier"`
      3. `updated_at` = `finished_at` = `now()`;
6. При любом не перехваченном исключении логирует ошибку и фиксирует в БД аварийное завершения джоба:
   1. `status` = `'FAILED'`;
   2. `result` = текст `"${message и stack_trace ошибки}"`;
   3. `updated_at` = `finished_at` = `now()`

## Топик `async-job-end`

Структура сообщения описана в [async-job-end.yaml](../../messaging/async-job-end.yaml).

| Входящий параметр    | Источник              | Описание |
|----------------------|-----------------------|----------|
| 📌`{MessagePayload}` | тело сообщения топика |          |

Алгоритм работы:

1. Находит `{asyncJob}` запись в `joposcragent.orchestration.async_jobs` по `uuid` = `{MessagePayload}.jobUuid`
   1. Если такой нет, логирует ошибку, завершает обработку.
2. Записывает в `{asyncJob}` данные:
   1. `status` = `{MessagePayload}.status`
   2. `result` = `{MessagePayload}.result`
   3. `finished_at` = `updated_at` = текущий момент времени.
3. Если у записи `{asyncJob}` поле `parent_uuid` не null:
   1. Обозначим `{parentJobUuid}` = `{asyncJob}.parent_uuid` (значение не меняется при обновлении на шаге 2).
   2. Ищет в БД незавершенных сиблингов - записи в `joposcragent.orchestration.async_jobs`, у которых:
      1. `parent_uuid` = `{parentJobUuid}`;
      2. `status` = `'STARTED'`
   3. Если ни одного сиблинга не нашлось, то завершает родительский джоб:
      1. Находит запись `joposcragent.orchestration.async_jobs` с `uuid` = `{parentJobUuid}`;
      2. Записывает в нее значения:
         1. `status` = `'SUCCEEDED'`
         2. `updated_at` = `finished_at` = текущий момент времени
