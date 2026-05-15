# Работа сервиса `crawler-headhunter` с топиками Kafka

## Запуск пакетного сбора вакансий

Слушает топик: `async-job.collection-query`

| Входящий параметр | Источник            | Комментарий                                   |
|-------------------|---------------------|-----------------------------------------------|
| 📌`{key}`         | Заголовок сообщения |                                               |
| 📌`{type}`        | Заголовок сообщения |                                               |
| 📌`{createdAt}`   | Заголовок сообщения |                                               |
| 📌`{payload}`     | Тело сообщения      | схема [async-job.collection-query-begin.yaml] |

Алгоритм работы:

1. Применяет фильтр по заголовку:
   1. Если `{type}` не равен `async-job.collection-query-begin`, пропускает сообщение, ничего не логируя.
2. Валидирует структуру `{payload}`
   1. При некорректной структуре логирует ошибку и публикует fail-сообщение п. 4.
3. Асинхронно запускает тот же процесс, который запускает [`POST /crawler/start`]
   1. В `correlationId` передает `{payload}.jobUuid`
4. В случае, если цикл прошел вхолостую (вакансий по запросу нет вообще, либо нет ни одной новой), публикует canceled-сообщение [`async-job.collection-query-result`]:
   1. Топик: `async-job.collection-query`
   2. Заголовки:
      1. `key` = `{key}`;
      2. `type` = `async-job.collection-query-result`;
      3. `createdAt` = текущий момент времени;
      4. `schemaVersion` = `1.0`;
   3. Тело:
      1. `jobUuid` = `{key}`
      2. `status` = `CANCELED`
      3. `result` = `"${описание}"` - вакансий вообще нет, либо вакансии в принципе есть, но ни одной новой.
      4. `pagesProcessed` = количество реально обработанных страниц
      5. `newVacanciesSaved` = `0`;
5. При любом не перехваченном исключении публикует fail-сообщение [`async-job.collection-query-result`]:
   1. Топик: `async-job.collection-query`
   2. Заголовки:
      1. `key` = `{key}`;
      2. `type` = `async-job.collection-query-result`;
      3. `createdAt` = текущий момент времени;
      4. `schemaVersion` = `1.0`;
   3. Тело:
      1. `jobUuid` = `{key}`
      2. `status` = `FAILED`
      3. `result` = `"${описание ошибки, какое есть}"`

<!-- LINKS -->
[async-job.collection-query-begin.yaml]: ../../messaging/async-job.collection-query/async-job.collection-query-begin.yaml#/components/schemas/MessagePayload
[`POST /crawler/start`]: ./readme.md#запуск-задания-сбора-данных
[`async-job.collection-query-result`]: ../../messaging/async-job.collection-query/async-job.collection-query-result.yaml
