# job-postings-evaluator

Сервис автоматического оценивания вакансий.

Работает с PostgresSQL:

- База данных `joposcragent`
- Схема `job_postings`
- Таблица `postings`

Дополнительно обращается по HTTP к сервисам `settings-manager` и `sentence-transformer` (см. алгоритм синхронной оценки).

## Выполнение оценки переданного набора вакансий (синхронно)

`POST /evaluate/sync`

| Входной параметр | Источник     | Описание                        |
|------------------|--------------|---------------------------------|
| 📌 `{uuids}`     | тело запроса | Список внутренних UUID вакансий |

Алгоритм работы:

1. Запрашивает у `settings-manager` пороги релевантности и вектор эталонного контекста:
   1. `GET http://settings-manager:8080/relevance-thresholds/GENERAL` — порог релевантности текста вакансии; обозначим `{threshold_general}`
   2. `GET http://settings-manager:8080/relevance-thresholds/TITLE` — порог релевантности названия вакансии; обозначим `{threshold_title}`
   3. `GET http://settings-manager:8080/reference-context` — объект с полем `vector`; обозначим `{reference_vector}`
2. Выбирает из таблицы `postings` все строки, для которых одновременно выполняется:
   1. `uuid` входит во множество UUID из `{uuids.list}`
   2. `evaluation_status` принимает одно из значений `NEW` или `PENDING`
3. Если после отбора не осталось ни одной строки, возвращает `HTTP 404`
4. Сначала обрабатывает вакансии в статусе `PENDING`:
   1. Запросом к `sentence-transformer` вычисляет сходство вектора содержимого вакансии с эталонным: `POST http://sentence-transformer:8000/sentence-transformer/vectors/cosine-similarity` с телом `VectorsPair`: `left` = `content_vector` строки вакансии, `right` = `{reference_vector}`; из ответа берётся числовое сходство (например поле `similarity`), обозначим `{sim}`
   2. Сравнивает `{sim}` с `{threshold_general}`: если `{sim}` больше порога — устанавливает для этой вакансии `evaluation_status` = `RELEVANT`; если меньше или равно — `IRRELEVANT`
5. Затем обрабатывает вакансии в статусе `NEW`:
   1. Запросом к `sentence-transformer` вычисляет сходство вектора заголовка с эталонным: `POST http://sentence-transformer:8000/sentence-transformer/vectors/cosine-similarity` с телом `VectorsPair`: `left` = `title_vector` строки вакансии, `right` = `{reference_vector}`; из ответа получаем `{sim}`
   2. Сравнивает `{sim}` с `{threshold_title}`: если `{sim}` больше порога — устанавливает `evaluation_status` = `PENDING`; если меньше или равно — `IRRELEVANT`
6. Записывает обновлённые значения `evaluation_status` в БД для всех обработанных строк
7. Возвращает `HTTP 200` и тело `JobPostingsUidsEvaluatedList`: для вакансий, полученных на вход (отобранных на шаге 2), их `uuid` и новые значения `evaluationStatus` после выполнения шагов 4–6
8. При возникновении любого не перехваченного исключения возвращает `HTTP 500` с текстом исключения в теле ответа

### Диаграмма последовательности (синхронная оценка)

```mermaid
sequenceDiagram
  participant Client
  participant Evaluator
  participant Settings
  participant ST as SentenceTransformer
  participant DB as Postgres

  Client->>Evaluator: POST /evaluate/sync
  Evaluator->>Settings: GET relevance-thresholds/GENERAL
  Evaluator->>Settings: GET relevance-thresholds/TITLE
  Evaluator->>Settings: GET reference-context
  Evaluator->>DB: SELECT postings WHERE uuid IN ... AND status IN NEW,PENDING
  alt нет строк
    Evaluator-->>Client: 404
  end
  loop PENDING записи
    Evaluator->>ST: POST vectors/cosine-similarity content_vector vs reference
    Evaluator->>Evaluator: sim vs threshold_general -> RELEVANT или IRRELEVANT
  end
  loop NEW записи
    Evaluator->>ST: POST vectors/cosine-similarity title_vector vs reference
    Evaluator->>Evaluator: sim vs threshold_title -> PENDING или IRRELEVANT
  end
  Evaluator->>DB: UPDATE evaluation_status
  Evaluator-->>Client: 200 JobPostingsUidsEvaluatedList
```

Подробности по сборке, запуску и отладке реализации — в README репозитория приложения `app/job-postings-evaluator`.

## Запуск асинхронного процесса оценки

`POST /evaluate/async`

Алгоритм работы:

1. Всегда возвращает `HTTP 501` (не реализовано)

## Получение состояния асинхронного задания

`GET /evaluate/async/{jobUuid}`

| Входной параметр | Источник      | Описание              |
|------------------|---------------|-----------------------|
| 📌 `{jobUuid}`   | path-параметр | UUID фонового задания |

Алгоритм работы:

1. Всегда возвращает `HTTP 501` (не реализовано)
