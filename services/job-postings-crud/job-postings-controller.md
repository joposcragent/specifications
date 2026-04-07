# Контроллер управления вакансиями

Работает с PostgresSQL:

- База данных `joposcragent`
- Схема `job_postings`
- Таблица `postings`

## Получение вакансии по UUID

`GET /job-postings/{jobPostingUuid}`

| Входной параметр      | Источник      | Описание                 |
|-----------------------|---------------|--------------------------|
| 📌 `{jobPostingUuid}` | path-параметр | Внутренний UUID вакансии |

Алгоритм работы:

1. Ищет в таблице `postings` строку с `uuid` = `{jobPostingUuid}`
   1. Если строка не найдена, возвращает `HTTP 404`
2. Возвращает объект `JobPostingsItem`, используя поля найденной строки
3. При возникновении любого не перехваченного исключения возвращает `HTTP 500` с текстом исключения в теле ответа

## Сохранение новой вакансии

`POST /job-postings/{jobPostingUuid}`

| Входной параметр      | Источник      | Описание                                    |
|-----------------------|---------------|---------------------------------------------|
| 📌 `{jobPostingUuid}` | path-параметр | Внутренний UUID вакансии                    |
| 📌 `{jobPosting}`     | тело запроса  | Объект `JobPostingsItem` с данными вакансии |

Алгоритм работы:

1. Проверяет наличие в таблице `postings` строки с `uuid` = `{jobPostingUuid}`
   1. Если строка найдена, возвращает `HTTP 409` с текстом `Вакансия с uuid {jobPostingUuid} уже есть в БД`
2. Проверяет наличие в таблице `postings` строки с `uid` = `{jobPosting.uid}`
   1. Если строка найдена, возвращает `HTTP 409` с текстом `Вакансия с uid {jobPosting.uid} уже есть в БД`
3. Добавляет строку в таблицу `postings`, заполняя поля следующим образом:
   1. `uuid` = `{jobPostingUuid}`
   2. `uid` = `{jobPosting.uid}`
   3. `publication_date` = `{jobPosting.publicationDate}`
   4. `title` = `{jobPosting.title}`
   5. `url` = `{jobPosting.url}`
   6. `title_vector` = `{jobPosting.titleVector}`
   7. `content_vector` = `{jobPosting.contentVector}`
   8. `evaluation_status` = `{jobPosting.evaluationStatus}`
   9. `response_status` = `{jobPosting.responseStatus}`
4. При успешной записи в БД возвращает `HTTP 200`
5. При возникновении любого не перехваченного исключения возвращает `HTTP 500` с текстом исключения в теле ответа

## Обновление данных вакансии

`PUT /job-postings/{jobPostingUuid}`

| Входной параметр      | Источник      | Описание                                        |
|-----------------------|---------------|-------------------------------------------------|
| 📌 `{jobPostingUuid}` | path-параметр | Внутренний UUID вакансии                        |
| 📌 `{jobPosting}`     | тело запроса  | Объект `JobPostingsItem` с обновлёнными данными |

Алгоритм работы:

1. Проверяет наличие в таблице `postings` строки с `uuid` = `{jobPostingUuid}`
   1. Если строка не найдена, возвращает `HTTP 404`
2. Обновляет поля найденной строки:
   1. `uid` = `{jobPosting.uid}`
   2. `publication_date` = `{jobPosting.publicationDate}`
   3. `title` = `{jobPosting.title}`
   4. `url` = `{jobPosting.url}`
   5. `title_vector` = `{jobPosting.titleVector}`
   6. `content_vector` = `{jobPosting.contentVector}`
   7. `evaluation_status` = `{jobPosting.evaluationStatus}`
   8. `response_status` = `{jobPosting.responseStatus}`
   9. `updated_at` = `now()`
3. При успешной записи в БД возвращает `HTTP 200`
4. При возникновении любого не перехваченного исключения возвращает `HTTP 500` с текстом исключения в теле ответа
