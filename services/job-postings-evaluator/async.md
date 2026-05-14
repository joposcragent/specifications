# Работа сервиса `job-postings-crud` с сообщениями Kafka

- Потребляет сообщения [`async-job.job-posting-evaluate-begin`] и выполняет оценку вакансии.
- Публикует сообщения [`async-job.job-posting-evaluate-result`] с результатами оценки.

## Выполнение оценки вакансий

| Входящий параметр | Источник            | Описание                                       |
|-------------------|---------------------|------------------------------------------------|
| 📌`{key}`         | Заголовок сообщения |                                                |
| 📌`{type}`        | Заголовок сообщения |                                                |
| 📌`{createdAt}`   | Заголовок сообщения |                                                |
| 📌`{payload}`     | Тело сообщения      | схема [`async-job.job-posting-evaluate-begin`] |

Алгоритм работы:

1. Слушает топик `async-job.job-posting-evaluate`, выбирая из него только сообщения с заголовком `type` = `async-job.job-posting-evaluate-begin`.
2. Читает `{posting_record}` запись из таблицы БД `joposcragent.job_postings.postings`:
   1. `uuid` = `{payload}.jobPostingUuid`
   2. Если записи нет, бросает исключение `"Job posting ${jobPostingUuid} not found"`.
3. Если `{posting_record}.content_vector` не заполнен (null или пустой массив):
   1. Получает `{contentVector}` запросом [Вычислить векторное представление текста]:
      1. `text` = `{posting_record}.content`;
   2. Устанавливает `{posting_record}.content_vector` = `{contentVector}`.
4. Получает `{referenceContext}` запросом [Получение эталонного контекста].
5. Вычисляет `{similarity}` запросом [Вычислить косинусное сходство двух векторов]:
   1. `left` = `{referenceContext}.vector`;
   2. `right` = `{posting_record}.content_vector`.
6. Устанавливает `{posting_record}.relevance` = `{similarity}`.
7. Получает `{searchQueriesItem}` запросом [Получение поискового запроса]:
   1. `entityUuid` = `{posting_record}.search_query_uuid`.
8. Если `{similarity}` >= `{searchQueriesItem}.contentRelevance`:
   1. Устанавливает `{posting_record}.evaluation_status` = `RELEVANT`;
9. В противном случае устанавливает `{posting_record}.evaluation_status` = `IRRELEVANT`;
10. Записывает `{posting_record}` в базу данных.
11. При успешной записи публикует [SUCCEEDED-сообщение]:
    1. `jobUuid` = `{payload}.jobUuid`;
    2. `jobPostingUuid` = `{payload}.jobPostingUuid`;
    3. `evaluationStatus` = `{posting_record}.evaluation_status`;
    4. `relevance` = `{posting_record}.relevance`;
    5. `result` = JSON-объект `{status: ${evaluationStatus}, relevance: ${relevance}}`;
12. При любом не перехваченном исключении отправляет [FAILED-сообщение]:
    1. `{jobUuid}` = `{payload}.jobUuid`;
    2. `{jobPostingUuid}` = `{payload}.jobPostingUuid`;
    3. `{result}` = описание ошибки, какое есть;

## Публикация `-result` сообщений

### Отправка SUCCEEDED-сообщения `async-job.job-posting-evaluate-result`

| Входной параметр     | Комментарий                                                  |
|----------------------|--------------------------------------------------------------|
| 📌`{jobUuid}`        | UUID асинхронного джоба, в рамках которого стартовала оценка |
| 📌`{jobPostingUuid}` | UUID оцененной вакансии                                      |
| `{context}`          | Произвольный JSON-объект или null                            |
| `{result}`           | Произвольный JSON-объект или null                            |
| `{evaluationStatus}` | Присвоенный статус оценки                                    |
| `{relevance}`        | Релевантность, вещественное число                            |

Алгоритм работы:

1. Публикует сообщение `async-job.job-posting-evaluate-result`:
   1. Топик: `async-job.job-posting-evaluate`
   2. Заголовки:
      1. `key` = `{jobUuid}`
      2. `createdAt` = текущий момент времени
      3. `schemaVersion` = `1.0`
      4. `type` = `async-job.job-posting-evaluate-result`
   3. Тело:
      1. `jobUuid` = `{jobUuid}`
      2. `status` = `SUCCEEDED`
      3. `result` = `{result}`
      4. `context` = `{context}`
      5. `jobPostingUuid` = `{jobPostingUuid}`
      6. `evaluationStatus` = `{evaluationStatus}`
      7. `relevance` = `{relevance}`
2. При любом не перехваченном исключении логирует ошибку.

### Отправка FAILED-сообщения `async-job.job-posting-evaluate-result`

| Входной параметр     | Комментарий                                                  |
|----------------------|--------------------------------------------------------------|
| 📌`{jobUuid}`        | UUID асинхронного джоба, в рамках которого стартовала оценка |
| 📌`{jobPostingUuid}` | UUID оцененной вакансии                                      |
| `{context}`          | Произвольный JSON-объект или null                            |
| `{result}`           | Произвольный JSON-объект или null                            |

Алгоритм работы:

1. Публикует сообщение `async-job.job-posting-evaluate-result`:
   1. Топик: `async-job.job-posting-evaluate`
   2. Заголовки:
      1. `key` = `{jobUuid}`
      2. `createdAt` = текущий момент времени
      3. `schemaVersion` = `1.0`
      4. `type` = `async-job.job-posting-evaluate-result`
   3. Тело:
      1. `jobUuid` = `{jobUuid}`
      2. `status` = `FAILED`
      3. `result` = `{result}`
      4. `context` = `{context}`
      5. `jobPostingUuid` = `{jobPostingUuid}`
2. При любом не перехваченном исключении логирует ошибку.

<!-- LINKS -->

[`async-job.job-posting-evaluate-begin`]: ../../messaging/async-job.job-posting-evaluate/async-job.job-posting-evaluate-begin.yaml
[`async-job.job-posting-evaluate-result`]: ../../messaging/async-job.job-posting-evaluate/async-job.job-posting-evaluate-result.yaml
[FAILED-сообщение]: #отправка-failed-сообщения-async-jobjob-posting-evaluate-result
[SUCCEEDED-сообщение]: #отправка-succeeded-сообщения-async-jobjob-posting-evaluate-result
[Вычислить векторное представление текста]: ../sentence-transformer/readme.md#вычислить-векторное-представление-текста
[Вычислить косинусное сходство двух векторов]: ../sentence-transformer/readme.md#вычислить-косинусное-сходство-двух-векторов
[Получение эталонного контекста]: ../settings-manager/reference-context.md#получение-эталонного-контекста
[Получение поискового запроса]: ../settings-manager/search-query.md#получение-поискового-запроса
