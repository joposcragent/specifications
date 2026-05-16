# Потребители сообщений

Работает с PostgreSQL:

- База данных `joposcragent`
- Схема `orchestration`

Потребляет сообщения в топиках Kafka:

- [`async-job.collection-batch-begin`] - для запуска пакетного сбора по активным поисковым запросам;
- [`async-job.job-posting-create-result`] - для запуска оценки по успешно созданной вакансии.

Публикует сообщения в топики Kafka:

- [`async-job.collection-query-begin`] - запускает пакетный сбор вакансий;
- [`async-job.collection-batch-result`] - завершение пакетного сбора;
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
   1. Если ни одного нет публикует сообщение [`async-job.collection-batch-result`], см. п. 4.2:
      1. в тело сообщения передает `status` = `CANCELED` и `result` = `"Не найдено активных поисковых запросов"`;
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
4. При любом не перехваченном исключении:
   1. логирует ошибку;
   2. Публикует сообщение [`async-job.collection-batch-result`]:
      1. Топик: `async-job.collection-batch`
      2. Заголовки:
         1. `key` = `{payload}.jobUuid`;
         2. `createdAt` = текущий момент времени;
         3. `type` = `async-job.collection-batch-result`;
      3. Тело:
         1. `jobUuid` = `{payload}.jobUuid`;
         2. `status` = `FAILED`;
         3. `result` = `"${описание ошибки, какое есть}"`;

## Завершение пакетного сбора

Обрабатывает сообщения `async-job.collection-query-result` и закрывает родительский джоб `async-job.collection-batch`, если все его подчиненные джобы завершены.

| Входящий параметр | Источник            | Описание                                   |
|-------------------|---------------------|--------------------------------------------|
| 📌`{key}`         | Заголовок сообщения |                                            |
| 📌`{type}`        | Заголовок сообщения |                                            |
| 📌`{createdAt}`   | Заголовок сообщения |                                            |
| 📌`{payload}`     | Тело сообщения      | схема [`async-job.collection-query-result`] |

Алгоритм работы:

1. Слушает топик `async-job.collection-query`, выбирая из него только сообщения с заголовком `type` = `async-job.collection-query-result`.
2. Запросом к БД получает `{parentUuid}` от джоба с `uuid` = `{payload}.jobUuid`,
   1. Если `{parentUuid}` не задан, то молча завершает обработку.
3. Запросом к БД из таблицы `joposcragent.orchestration.async_jobs` получает все джобы, у которых (одновременно):
   1. `parent_uuid` = `{parentUuid}`;
   2. `status` не в списке (`'SUCCEEDED'`, `'FAILED'`, `'CANCELED'`).
4. Если список пустой, то:
   1. Логирует INFO `Auto resolving parent task ${parentUuid}`
   2. Устанавливает status = `'SUCCEEDED'` для джоба с `uuid` = `${parentUuid}`

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
