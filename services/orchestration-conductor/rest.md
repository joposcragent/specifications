# REST API orchestration-conductor

## Запустить collection-batch вручную

`POST /enqueue/collection-batch`

Алгоритм работы:

1. Генерирует `{currentJobUuid}` - новый UUID v4.
2. Публикует сообщение [`async-job.collection-batch-begin`]:
   1. Топик: `async-job.collection-batch`
   2. Заголовки:
      1. `key` = `{currentJobUuid}`;
      2. `createdAt` = текущий момент времени;
      3. `type` = `async-job.collection-batch-begin`;
      4. `schemaVersion` = `1.0`;
   3. Тело:
      1. `jobUuid` = `{currentJobUuid}`;
3. Возвращает HTTP 204 с `jobUuid` = `{currentJobUuid}`

## Запустить collection-query вручную

`POST /enqueue/collection-query`

|Входной параметр|Источник|Комментарий|
|---|---|---|
|📌`{SearchQueryItem}`|тело запроса||

Алгоритм работы:

1. Генерирует `{currentJobUuid}` - новый UUID v4.
2. Публикует сообщение [`async-job.collection-query-begin`]:
   1. Топик: `async-job.collection-query`
   2. Заголовки:
      1. `key` = `{currentJobUuid}`
      2. `createdAt` = текущий момент времени
      3. `schemaVersion` = `1.0`
      4. `type` = `async-job.collection-query-begin`
   3. Тело:
      1. `jobUuid` = `{currentJobUuid}`
      2. `query` = `{SearchQueryItem}.query`
      3. `entityUuid` = `{SearchQueryItem}.uuid`
      4. `searchQueryUuid` = `{SearchQueryItem}.uuid`
      5. `lazy` = `{SearchQueryItem}.isLazyScraping`
3. Возвращает HTTP 204 с `jobUuid` = `{currentJobUuid}`

<!-- LINKS -->
[`async-job.collection-batch-begin`]: ../../messaging/async-job.collection-batch/async-job.collection-batch-begin.yaml
[`async-job.collection-query-begin`]: ../../messaging/async-job.collection-query/async-job.collection-query-begin.yaml
