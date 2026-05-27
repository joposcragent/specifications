# Потребители сообщений

Интеграции по HTTP:

- [`settings-manager`][settings-manager-index] — активные поисковые запросы (см. раздел «Запуск пакетного сбора вакансий»);
- [`orchestration-async-jobs-crud`][async-jobs-crud-readme] — учёт асинхронных джобов (см. раздел «Завершение пакетного сбора»).

Потребляет сообщения в топиках Kafka:

- [`async-job.collection-batch-begin`] - для запуска пакетного сбора по активным поисковым запросам;
- [`async-job.job-posting-create-result`] - для запуска оценки по успешно созданной вакансии.

Публикует сообщения в топики Kafka:

- [`async-job.collection-query-begin`] - запускает пакетный сбор вакансий;
- [`async-job.collection-batch-result`] - результат запуска пакетного сбора (успех, отмена или ошибка fan-out);
- [`async-job.job-posting-evaluate-begin`] - запускает оценку

## Запуск пакетного сбора вакансий

Выбирает из топика `async-job.collection-batch` сообщения с типом `async-job.collection-batch-begin` и публикует сообщения `async-job.collection-query-begin`.

| Входящий параметр | Источник            | Описание                                   |
|-------------------|---------------------|--------------------------------------------|
| 📌`{key}`         | Заголовок сообщения |                                            |
| 📌`{type}`        | Заголовок сообщения |                                            |
| 📌`{createdAt}`   | Заголовок сообщения |                                            |
| 📌`{payload}`     | Тело сообщения      | схема [`async-job.collection-batch-begin`] |

Алгоритм работы:

1. Слушает топик `async-job.collection-batch`, выбирая из него только сообщения с заголовком `type` = `async-job.collection-batch-begin`
2. Запросом `GET /search-query/list?activeOnly=true` к `settings-manager` получает `{queryList}` — массив активных поисковых запросов.
   1. Если ни одного нет, публикует сообщение [`async-job.collection-batch-result`], см. п. 2.1:
      1. в тело сообщения передаёт `status` = `CANCELED` и `result` с полем `message` = `"Не найдено активных поисковых запросов"`;
   2. **п. 2.1** — заголовки и топик как в п. 4.1, `type` = `async-job.collection-batch-result`, `jobUuid` = `{payload}.jobUuid`.
3. Для каждого запроса из массива:
   1. Генерирует `{currentJobUuid}` - новый UUID v4
   2. Отправляет сообщение [`async-job.collection-query-begin`]:
      1. Топик: `async-job.collection-query`
      2. `headers` сообщения:
         1. `key` = `{currentJobUuid}`
         2. `createdAt` = текущий момент времени
         3. `type` = `async-job.collection-query-begin`
         4. `schemaVersion` = `1.0`
      3. `payload` сообщения
         1. `jobUuid` = `{currentJobUuid}`;
         2. `parentJobUuid` = `{MessagePayload}.jobUuid`
         3. `entityUuid` = `{queryList}.uuid` - uuid текущего поискового запроса
         4. `query` = `{queryList}.query`
         5. `searchQueryUuid` = `{queryList}.uuid`
         6. `lazy` = `{queryList}.isLazyScraping`
4. После успешной публикации всех `collection-query-begin` (без неперехваченных исключений на шагах 2–3):
   1. **п. 4.1** — публикует сообщение [`async-job.collection-batch-result`]:
      1. Топик: `async-job.collection-batch`
      2. Заголовки:
         1. `key` = `{payload}.jobUuid`;
         2. `createdAt` = текущий момент времени;
         3. `type` = `async-job.collection-batch-result`;
         4. `schemaVersion` = `1.0`
      3. Тело:
         1. `jobUuid` = `{payload}.jobUuid`;
         2. `status` = `SUCCEEDED` — успешное **развёртывание** дочерних `collection-query-begin`, а не итог сбора по всем запросам;
         3. `result` — JSON-объект, например `message` с текстом о числе запущенных джобов и `childJobsDispatched` = размер `{queryList}`.
5. При любом неперехваченном исключении на шагах 2–4:
   1. логирует ошибку;
   2. **п. 4.2** — публикует сообщение [`async-job.collection-batch-result`] (заголовки и топик как в п. 4.1):
      1. `jobUuid` = `{payload}.jobUuid`;
      2. `status` = `FAILED`;
      3. `result` — JSON-объект с полем `message` = описание ошибки.

## Завершение пакетного сбора

Обрабатывает сообщения `async-job.collection-query-result` и закрывает родительский джоб `async-job.collection-batch`, если все его подчинённые джобы завершены. Данные джобов и смена завершающего статуса выполняются **только** через REST API [`orchestration-async-jobs-crud`][async-jobs-crud-readme]; `orchestration-conductor` не обращается к PostgreSQL по учёту джобов.

| Входящий параметр | Источник            | Описание                                                         |
|-------------------|---------------------|------------------------------------------------------------------|
| 📌`{key}`         | Заголовок сообщения |                                                                  |
| 📌`{type}`        | Заголовок сообщения |                                                                  |
| 📌`{createdAt}`   | Заголовок сообщения |                                                                  |
| 📌`{payload}`     | Тело сообщения      | схема [`async-job.collection-query-result`]                      |

Алгоритм работы:

1. Слушает топик `async-job.collection-query`, выбирая из него только сообщения с заголовком `type` = `async-job.collection-query-result`.
2. Запросом `GET /async-jobs/{payload.jobUuid}` к [`orchestration-async-jobs-crud`][async-jobs-crud-readme] получает джоб `{jobItem}` (тело ответа — `AsyncJobItem`).
   1. При ответе HTTP 404 логирует предупреждение и завершает обработку сообщения.
   2. Если у `{jobItem}` поле `parentUuid` отсутствует или равно `null`, молча завершает обработку.
3. Запросом `GET /async-jobs/list?parentJobUuid={jobItem.parentUuid}&status=STARTED` к [`orchestration-async-jobs-crud`][async-jobs-crud-readme] получает список дочерних джобов родителя, которые ещё в работе (`AsyncJobList`).
   1. Если массив `list` непустой, завершает обработку (есть незавершённые подзадачи).
4. Если `list` пустой, то:
   1. Логирует INFO `Auto resolving parent task ${jobItem.parentUuid}`.
   2. Вызывает `POST /async-jobs/{jobItem.parentUuid}/finish/SUCCEEDED` к [`orchestration-async-jobs-crud`][async-jobs-crud-readme] с телом `application/json` (схема [`FinishAsyncJobItem`][finish-async-job-item]).
      1. В теле **обязательно** передаёт поле `result` — JSON-объект `{"autoResolved": true, "autoResolveSource": "{payload}.jobUuid"}`: `autoResolveSource` равен UUID дочернего джоба (`{payload}.jobUuid`), по результату которого принято решение о завершении родителя.
      2. При ответе HTTP 409 (у родителя статус уже не `STARTED`, например родитель уже автозавершён этим же сервисом по другому пути) считает шаг успешно выполненным с точки зрения идемпотентности; при необходимости пишет сообщение уровня DEBUG.
      3. При ответе HTTP 404 логирует ошибку (несогласованное состояние данных).

## Запуск оценки новой вакансии

Выбирает из `async-job.job-posting-create` сообщения [`async-job.job-posting-create-result`] об успешном создании вакансии и публикует сообщения [`async-job.job-posting-evaluate-begin`].

| Входящий параметр | Источник            | Описание                                      |
|-------------------|---------------------|-----------------------------------------------|
| 📌`{key}`         | Заголовок сообщения |                                               |
| 📌`{type}`        | Заголовок сообщения |                                               |
| 📌`{createdAt}`   | Заголовок сообщения |                                               |
| 📌`{payload}`     | Тело сообщения      | схема [`async-job.job-posting-create-result`] |

Алгоритм работы:

1. Слушает топик `async-job.job-posting-create`, выбирая из него только сообщения с заголовком `type` = `async-job.job-posting-create-result`
2. Если `{payload}.status` не равен `SUCCEEDED`, молча пропускает сообщение.
3. Генерирует `{currentJobUuid}` - новый UUID v4.
4. Публикует сообщение [`async-job.job-posting-evaluate-begin`]:
   1. Топик: `async-job.job-posting-evaluate`.
   2. Заголовки:
      1. `key` = `{currentJobUuid}`;
      2. `createdAt` = текущий момент времени;
      3. `type` = `async-job.job-posting-evaluate-begin`;
      4. `schemaVersion` = `1.0`.
   3. Тело:
      1. `jobUuid` = `{currentJobUuid}`;
      2. `parentJobUuid` = `{payload}.jobUuid`;
      3. `entityUuid` = `{payload}.jobPostingUuid`;
      4. `jobPostingUuid` = `{payload}.jobPostingUuid`.

<!-- LINKS -->

[`async-job.collection-batch-begin`]: ../../messaging/async-job.collection-batch/async-job.collection-batch-begin.yaml
[`async-job.job-posting-create-result`]: ../../messaging/async-job.job-posting-create/async-job.job-posting-create-result.yaml
[`async-job.collection-query-begin`]: ../../messaging/async-job.collection-query/async-job.collection-query-begin.yaml
[`async-job.job-posting-evaluate-begin`]: ../../messaging/async-job.job-posting-evaluate/async-job.job-posting-evaluate-begin.yaml
[`async-job.collection-batch-result`]: ../../messaging/async-job.collection-batch/async-job.collection-batch-result.yaml
[`async-job.collection-query-result`]: ../../messaging/async-job.collection-query/async-job.collection-query-result.yaml

[settings-manager-index]: ../settings-manager/index.md
[async-jobs-crud-readme]: ../orchestration-async-jobs-crud/readme.md
[finish-async-job-item]: ../orchestration-async-jobs-crud/openapi.yaml#/components/schemas/FinishAsyncJobItem
