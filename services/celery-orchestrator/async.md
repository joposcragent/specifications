# Асинхронные задачи оркестратора

## `task.collection-batch`

Алгоритм работы:

1. Запросом `GET /search-query/list` к `settings-manager` получает `{queryList}` - массив настроенных поисковых запросов.
2. Если список пустой, то сразу завершает задачу:
   1. `status` = `CANCELLED`;
   2. `Result` = текст `"Поисковые запросы не настроены"`.
3. Для каждого запроса из массива ставит в celery-брокер задачу:
   1. `name` = `task.collection-query`;
   2. `parentId` и `correlation_id` = uuid текущей задачи;
   3. `kwargs.searchQuery` = `{queryList}[].query`.
4. При успешной постановке задач в очередь завершает текущую задачу:
   1. `status` = `SUCCEEDED`;
   2. `result` = `"Запущено ${count} асинхронных процессов сбора вакансий"`, где `count` - количество поставленных в очередь задач.

## `task.collection-query`

| Входной параметр   | Источник                            | Описание        |
|--------------------|-------------------------------------|-----------------|
| 📌 `{searchQuery}` | поле `searchQuery` объекта `kwargs` | массив значений |

Алгоритм работы:

1. Проверяет заполненность `{searchQuery}`, если пусто, завершает задачу:
   1. `status` = `FAILED`;
   2. `result` = `"Поисковый запрос пустой"`.
2. Дает команду `crawler-headhunter` на асинхронный сбор `POST /crawler/start`, передавая в теле запроса:
   1. `list[0]` = `{searchQuery}`;
   2. заголовок `X-Joposcragent-correlationId` = uuid текущей celery-задачи.
3. Если ответ `crawler-headhunter` отличается от `HTTP 200`, завершает задачу:
   1. `status` = `FAILED`;
   2. `result` = `"Не удалось запустить сбор: ${httpCode} ${message}"`, где `httpCode` и `message` - код и тело ответа от `crawler-headhunter`.
4. Если ответ `HTTP 200`, задача висит в статусе `RUNNING` и ждет появления соответствующего события `task.complete`.

## `task.evaluation`

| Входной параметр      | Источник                               | Описание |
|-----------------------|----------------------------------------|----------|
| 📌 `{jobPostingUuid}` | поле `jobPostingUuid` объекта `kwargs` |          |

Алгоритм работы:

1. Проверяет заполненность `{jobPostingUuid}`, если пусто, завершает задачу:
   1. `status` = `FAILED`;
   2. `result` = `"Отсутствует UUID вакансии"`.
2. Дает команду `job-postings-evaluation` на оценку вакансии `POST /evaluate/async/{jobPostingUuid}`:
   1. `jobPostingUuid` = `{jobPostingUuid}`;
   2. заголовок `X-Joposcragent-correlationId` = uuid текущей celery-задачи.
3. Если ответ `job-postings-evaluation` отличается от `HTTP 200`, завершает задачу:
   1. `status` = `FAILED`;
   2. `result` = `"Не удалось запустить оценку: ${httpCode} ${message}"`, где `httpCode` и `message` - код и тело ответа от `job-postings-evaluation`.
4. Если ответ `HTTP 200`, задача висит в статусе `RUNNING` и ждет появления соответствующего события `task.complete`.

## `task.notification`

Алгоритм работы:

1. Безусловно завершает задачу со `status` = `CANCELED` и `result` = `"Not implemented"`

## `task.progress`

Это информационная задача, она нужна, чтобы приземлить свои kwargs и остальные данные в Celery.
Единственный нюанс: она будет `FAILED`, если не сможет найти свою родительскую задачу.

Алгоритм работы:

1. Ищет  задачу с uuid равным `correlation_id`
2. Если не нашлось, завершает задачу:
   1. `status` = `FAILED`;
   2. `result` = `"Не удалось найти родительскую задачу ${correlation_id}"`.
3. Если нашлось, завершает текущую задачу со `status` = `SUCCESS`.

## `task.finish`

| Входной параметр        | Источник                                 | Описание |
|-------------------------|------------------------------------------|----------|
| 📌 `{parentTaskResult}` | поле `parentTaskResult` объекта `kwargs` |          |
| 📌 `{parentTaskStatus}` | поле `parentTaskStatus` объекта `kwargs` |          |

Алгоритм работы:

1. Проверяет заполненность входных параметров и при не заполненных завершает задачу:
   1. `status` = `FAILED`;
   2. `result` = `"Отсутствуют результат и статус родительской задачи"`.
2. Проверяет заполненность поля `correlation_id` задачи и при не заполненном завершает задачу:
   1. `status` = `FAILED`;
   2. `result` = `"Отсутствуют correlation_id родительской задачи"`.
3. Находит `{parentTask}` - задачу с uuid равным `correlation_id`
4. Если не нашлось, завершает задачу:
   1. `status` = `FAILED`;
   2. `result` = `"Не удалось найти родительскую задачу ${correlation_id}"`.
5. Завершает `{parentTask}` c:
   1. `{parentTask}.status` = `{parentTaskStatus}`;
   2. `{parentTask}.result` = `{parentTaskResult}`.
6. Завершает текущую задачу с `status` = `SUCCESS`.
