# orchestration-scheduler задания по расписанию

Работает с PostgresSQL:

- База данных `joposcragent`
- Схема `orchestration`
- Таблица `scheduler`

Работает с топиками Kafka:

- collection-batch

## Запуск `collection-batch`

Периодичность запуска - раз в 10 минут.

Алгоритм работы:

1. Обновляет `next_run`
   1. Получает первую запись таблицы `scheduler`;
   2. Если строки нет - прерывает работу штатно;
   3. Если дата в `next_run` еще не наступила - прерывает работу штатно;
   4. В остальных случаях:
      1. прибавляет к текущей дате период, соответствующий `cron_expression`;
      2. записывает полученную дату в `next_run`.
2. Ищет в таблице `async_jobs` запись:
   1. `name` = `'collection-batch'`
   2. `status` = `'STARTED'`
3. Если запись существует:
   1. Записывает в лог WARN `Previous collection-batch job ${async_job.uuid} started at ${async_job.started_at} is still running`;
   2. Прерывает работу штатно.
4. Если записи нет, то отправляет сообщение в очередь:
   1. topic: `collection-batch`
   2. `jobUuid` = генерирует новый uuid
   3. `parentJobUuid` = `null`
   4. `entityUuid` = `null`
   5. `data` = `null`
