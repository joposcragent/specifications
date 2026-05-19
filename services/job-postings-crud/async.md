# Работа сервиса `job-postings-crud` с топиками Kafka

Работает с PostgreSQL (см. [job-postings-controller.md]).

Потребляет сообщения в топиках Kafka:

- [`async-job.job-posting-create-begin`] — создание записи вакансии в БД по асинхронному заданию.

Публикует сообщения в топики Kafka:

- [`async-job.job-posting-create-result`] — итог обработки `begin`: успешная вставка, ошибка валидации обязательных полей или ошибка сохранения (в том числе откат транзакции / исключение при вставке).

Топик входа и выхода один и тот же: `async-job.job-posting-create`.

При `app.kafka.enabled = false` слушатель и публикация Kafka отключаются (по умолчанию свойство включено).

## Создание вакансии по сообщению begin

Слушает топик: `async-job.job-posting-create`.

Группа консьюмера задаётся свойством `app.kafka.job-posting-create-consumer-group` (по умолчанию `job-postings-crud-job-posting-create`).

| Входящий параметр | Источник | Комментарий |
| ------------------- | ---------- | ------------- |
| 📌`{key}` | Ключ записи Kafka (`record.key`) | Если непустой, передаётся в исходящие заголовки как `key`; иначе для исходящего `key` используется строка `{payload}.jobUuid`. Непустой ключ, являющийся UUID, также может использоваться как `jobUuid` задания, если в payload поле `jobUuid` отсутствует или некорректно |
| 📌`{type}` | Заголовок записи `type`, иначе поле `headers.type` внутри JSON тела сообщения (`value`) | |
| 📌`{payload}` | Узел `payload` в JSON теле сообщения | схема [`async-job.job-posting-create-begin`] |

Алгоритм работы:

1. Определяет `{type}`: сначала заголовок Kafka `type`, иначе читает `value` как JSON и берёт `headers.type`.
   1. Если `{type}` определить нельзя, или он не равен `async-job.job-posting-create-begin`, обработка завершается без логирования и без публикации в Kafka.
2. Парсит тело сообщения как JSON.
   1. При невалидном JSON пишет предупреждение в лог и завершает работу **без** публикации результата в Kafka.
3. Извлекает узел `payload`.
   1. Если узла нет, пишет предупреждение в лог и завершает работу **без** публикации результата в Kafka.
4. Валидирует и маппит `{payload}` в модель сохранения.
   1. Идентификатор задания `jobUuid`: из поля `jobUuid` в `{payload}` либо из непустого `{key}`, если он является UUID.
   2. Обязательны непустые поля: `searchQueryUuid`, `uid`, `title`, `url`, `publicationDate`. Идентификатор вакансии задаётся полем `jobPostingUuid` или, при его отсутствии, полем `entityUuid`.
   3. Поля `company` и `content` опциональны; при отсутствии или пустом значении в БД сохраняется NULL, в лог пишется предупреждение (**warn**).
   4. `publicationDate` — обязательная непустая строка; формат не валидируется и не нормализуется (сохраняется как есть).
   5. При ошибке обязательных полей (отсутствие, пусто, неверный UUID) пишет в лог **error** и публикует результат со статусом `FAILED` и текстом причины в `result.message`, **если** удалось определить `jobUuid` задания; иначе только **error** в лог **без** публикации в Kafka.
5. Выполняет вставку новой строки в таблицу `postings` со всеми полями, полученными из сообщения (после маппинга).
   1. При успешной вставке публикует результат со статусом `SUCCEEDED`, см. раздел ниже.
   2. При любом исключении при сохранении (в том числе нарушение ограничений БД, откат транзакции) пишет ошибку в лог и публикует результат со статусом `FAILED` с текстом причины в `result.message`.

## Сообщение результата `async-job.job-posting-create-result`

Публикуется в топик: `async-job.job-posting-create`.

Структура тела сообщения: JSON-объект с полями `headers` и `payload` (как в спецификации [`async-job.job-posting-create-result`]); одновременно дублируются поля в **заголовках** записи Kafka: `key`, `type`, `createdAt`, `schemaVersion`.

| Поле / заголовок | Значение |
| ------------------ | ---------- |
| `key` | То же, что входящий `{key}` (см. таблицу выше) |
| `type` | `async-job.job-posting-create-result` |
| `createdAt` | Текущий момент времени (UTC, строка ISO-8601) |
| `schemaVersion` | `1.0` |
| `payload.jobUuid` | UUID задания (из входящего `payload.jobUuid` или, при маппинге в сервисе, из ключа записи) |
| `payload.status` | `SUCCEEDED` или `FAILED` |
| `payload.result` | Объект с полем `message` (при успехе — «Вакансия сохранена»; при ошибке — текст исключения или сообщения СУБД) |
| `payload.jobPostingUuid` | При `SUCCEEDED` — UUID сохранённой вакансии; при `FAILED` поле в `payload` не передаётся |

<!-- LINKS -->

[job-postings-controller.md]: ./job-postings-controller.md
[`async-job.job-posting-create-begin`]: ../../messaging/async-job.job-posting-create/async-job.job-posting-create-begin.yaml
[`async-job.job-posting-create-result`]: ../../messaging/async-job.job-posting-create/async-job.job-posting-create-result.yaml
