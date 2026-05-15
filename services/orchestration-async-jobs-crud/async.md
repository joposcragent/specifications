<!-- markdownlint-disable MD013 -->

# Работа сервиса `orchestration-async-jobs-crud` с сообщениями Kafka

Сервис ведёт учёт асинхронных джобов в PostgreSQL (`joposcragent`, схема `orchestration`) по событиям из Kafka. Контракт тела и заголовков сообщений согласован со [схемами messaging][messaging-dir]; структура обёртки сообщения — объект с полями `headers` и `payload` (см. [общую схему сообщения оркестрации][common-orch]).

Используются **две группы потребителей** Kafka (разные `group.id`), чтобы независимо масштабировать обработку стартов и завершений:

1. **Группа begin** — обрабатывает только сообщения, у которых в метаданных указан один из типов begin (см. ниже).
2. **Группа result** — обрабатывает только сообщения с типами result.

Оба потребителя подписываются на одни и те же топики, где встречаются соответствующие сообщения, и **отфильтровывают** записи по полю `type` (в типичном развёртывании оно передаётся в заголовках Kafka вместе с `key`, `createdAt`, `schemaVersion`; см. спецификации сервисов-издателей). Сообщения с неизвестным `type` для данной группы потребитель пропускает без изменений в БД.

## Группа begin

### Типы сообщений и ссылки на схемы

| `type` (заголовок) | Топик (типичное имя) | Схема сообщения |
| ------------------ | -------------------- | --------------- |
| `async-job.collection-batch-begin` | `async-job.collection-batch` | [`async-job.collection-batch-begin`][msg-batch-begin] |
| `async-job.collection-query-begin` | `async-job.collection-query` | [`async-job.collection-query-begin`][msg-query-begin] |
| `async-job.job-posting-evaluate-begin` | `async-job.job-posting-evaluate` | [`async-job.job-posting-evaluate-begin`][msg-eval-begin] |
| `async-job.job-posting-create-begin` | `async-job.job-posting-create` | [`async-job.job-posting-create-begin`][msg-create-begin] |

### Алгоритм при сообщении begin

1. Убедиться, что `type` входит в таблицу выше; иначе выйти.
2. Распарсить `payload` по схеме соответствующего сообщения (включая общие поля [MessagePayload][common-orch-payload]).
3. **Создать** строку в `joposcragent.orchestration.async_jobs`:
   1. `uuid` = `payload.jobUuid`;
   2. `parent_uuid` = `payload.parentJobUuid`, если поле задано; иначе `NULL`;
   3. `name` = значение `type` из заголовка;
   4. `status` = `STARTED`;
   5. `context` = сериализованный объект из `payload.context`, если в `payload` поле `context` задано и является объектом JSON; иначе `NULL`;
   6. прочие поля — значения по умолчанию и серверные метки времени, как при создании через REST (см. [создание джоба][readme-create]).
4. **Идемпотентность**: если строка с таким `uuid` уже существует, залогировать WARN и пропустить сообщение (существующую строку, в том числе поле `context`, не изменять).
5. Если в `payload` **заполнено** `entityUuid` (не пустое значение), **добавить связь** в зависимости от `type`:
   1. для `async-job.collection-query-begin` — вставка в `joposcragent.orchestration.async_jobs_to_search_queries` с `async_job_uuid` = `payload.jobUuid` и `search_query_uuid` = `payload.entityUuid`;
   2. для `async-job.job-posting-evaluate-begin` и `async-job.job-posting-create-begin` — вставка в `joposcragent.orchestration.async_jobs_to_job_postings` с `async_job_uuid` = `payload.jobUuid` и `job_postings_uuid` = `payload.entityUuid`.
   3. Если строка связи уже существует, не дублировать, пропускать без ошибок.

## Группа result

### Типы сообщений (result) и ссылки на схемы

| `type` (заголовок) | Топик (типичное имя) | Схема сообщения |
| ------------------ | -------------------- | --------------- |
| `async-job.job-posting-create-result` | `async-job.job-posting-create` | [`async-job.job-posting-create-result`][msg-create-result] |
| `async-job.job-posting-evaluate-result` | `async-job.job-posting-evaluate` | [`async-job.job-posting-evaluate-result`][msg-eval-result] |
| `async-job.collection-query-result` | `async-job.collection-query` | [`async-job.collection-query-result`][msg-query-result] |
| `async-job.collection-batch-result` | `async-job.collection-batch` | [`async-job.collection-batch-result`][msg-batch-result] |

Базовые поля результата (`jobUuid`, `status`, `result`) задаются схемой [async-job-end / common-async-job-result][common-async-result]; расширения payload для отдельных `type` — в YAML соответствующего сообщения.

### Алгоритм при сообщении result

1. Убедиться, что `type` входит в таблицу выше; иначе выйти.
2. Распарсить `payload`; взять `jobUuid` = `payload.jobUuid`, терминальный `status` из множества `SUCCEEDED`, `FAILED`, `CANCELED` (как в [AsyncJobTerminalStatus][terminal-status] / [MessagePayload][common-async-result]).
3. Найти в `joposcragent.orchestration.async_jobs` строку с `uuid` = `jobUuid`.
4. Если не найдено или текущий `status` строки **не** `STARTED`:
   1. залогировать WARN, пропустить сообщение.
5. Иначе обновить строку джоба:
   1. `status` = `payload.status`;
   2. `result` = сериализованный `payload.result` (объект JSON, см. [common-async-job-result-message][common-async-result]);
   3. `finished_at` и `updated_at` = текущий момент времени (как в [finish][readme-finish]).
6. **Завершение родителя** (как в шаге 5 [finish][readme-finish]), **только если** в конфигурации сервиса `app.autoresolve-parent-tasks` = `true` (по умолчанию `false`); при `false` этот шаг пропускается:
   1. Если у обновлённого джоба задан `parent_uuid` и у родительской строки (`uuid` = `parent_uuid`) `status` = `STARTED`;
   2. выбрать все дочерние строки с тем же `parent_uuid`, что и у обновлённого джоба, и со `status` = `STARTED`, **исключая** уже обновлённый джоб (он после шага 5 уже не в `STARTED`);
   3. если таких строк **нет**, установить родителю `status` = `SUCCEEDED`, `finished_at` и `updated_at` = `now()`.

При `app.autoresolve-parent-tasks` = `true` родитель переводится в `SUCCEEDED`, когда у него не осталось дочерних джобов в статусе `STARTED`, независимо от того, завершились ли дети успехом или ошибкой — в соответствии с уже описанным REST-алгоритмом `finish`. При `false` строка родителя после обработки result не меняется на этом шаге.

## Связь с REST

Поведение при result по смыслу совпадает с
`POST /async-jobs/{jobUuid}/finish/{terminalStatus}` из [readme][readme-finish],
но инициируется событием Kafka, а не HTTP. Поведение при begin — с созданием
строки и связями, как при сочетании `POST /async-jobs/{jobUuid}` и при
необходимости `POST .../related/...` из [readme][readme-create] и
[readme][readme-related]. Поле
[MessagePayload.context][common-orch-payload] при begin сохраняется в колонке
`async_jobs.context` (см. шаг 3 выше), что согласовано с опциональным полем
`context` в REST при создании джоба.

<!-- LINKS -->

[messaging-dir]: ../../messaging/
[common-orch]: ../../messaging/common-orchestration-message.yaml
[common-orch-payload]: ../../messaging/common-orchestration-message.yaml#/components/schemas/MessagePayload
[common-async-result]: ../../messaging/common-async-job-result-message.yaml
[msg-batch-begin]: ../../messaging/async-job.collection-batch/async-job.collection-batch-begin.yaml
[msg-query-begin]: ../../messaging/async-job.collection-query/async-job.collection-query-begin.yaml
[msg-eval-begin]: ../../messaging/async-job.job-posting-evaluate/async-job.job-posting-evaluate-begin.yaml
[msg-create-begin]: ../../messaging/async-job.job-posting-create/async-job.job-posting-create-begin.yaml
[msg-create-result]: ../../messaging/async-job.job-posting-create/async-job.job-posting-create-result.yaml
[msg-eval-result]: ../../messaging/async-job.job-posting-evaluate/async-job.job-posting-evaluate-result.yaml
[msg-query-result]: ../../messaging/async-job.collection-query/async-job.collection-query-result.yaml
[msg-batch-result]: ../../messaging/async-job.collection-batch/async-job.collection-batch-result.yaml
[readme-create]: ./readme.md#создать-новый-джоб
[readme-finish]: ./readme.md#установка-завершающего-статуса-для-джоба
[readme-related]: ./readme.md#добавить-связи-джоба
[terminal-status]: ./openapi.yaml#/components/schemas/AsyncJobTerminalStatus
