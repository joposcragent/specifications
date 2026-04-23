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

| Входной параметр      | Источник      | Описание                                         |
|-----------------------|---------------|--------------------------------------------------|
| 📌 `{jobPostingUuid}` | path-параметр | Внутренний UUID вакансии                         |
| 📌 `{jobPosting}`     | тело запроса  | Объект `JobPostingsItemWrite` с данными вакансии |

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
   5. `company` = `{jobPosting.company}`
   6. `url` = `{jobPosting.url}`
   7. `content` = `{jobPosting.content}`
   8. `content_vector` = `{jobPosting.contentVector}`
   9. `evaluation_status` = `{jobPosting.evaluationStatus}`
   10. `response_status` = `{jobPosting.responseStatus}`
4. При успешной записи в БД возвращает `HTTP 200`
5. При возникновении любого не перехваченного исключения возвращает `HTTP 500` с текстом исключения в теле ответа

## Обновление данных вакансии

`PATCH /job-postings/{jobPostingUuid}`

| Входной параметр      | Источник      | Описание                                                           |
|-----------------------|---------------|--------------------------------------------------------------------|
| 📌 `{jobPostingUuid}` | path-параметр | Внутренний UUID вакансии                                           |
| 📌 `{jobPosting}`     | тело запроса  | Ни одно поле не обязательно, но должно присутствовать хотя бы одно |

Алгоритм работы:

1. Проверяет, что в `{jobPosting}` присутствует хотя бы одно поле из набора, допустимого для `JobPostingsItemWrite`
   1. Если ни одного поля нет, возвращает `HTTP 400`
2. Проверяет наличие в таблице `postings` строки с `uuid` = `{jobPostingUuid}`
   1. Если строка не найдена, возвращает `HTTP 404`
3. Обновляет в найденной строке **только те** столбцы, для которых в `{jobPosting}` задано соответствующее поле; остальные столбцы не меняются. Для каждого присутствующего в теле поля:
   1. если задано `uid`, то `uid` = `{jobPosting.uid}`
   2. если задано `publicationDate`, то `publication_date` = `{jobPosting.publicationDate}`
   3. если задано `title`, то `title` = `{jobPosting.title}`
   4. если задано `company`, то `company` = `{jobPosting.company}`
   5. если задано `url`, то `url` = `{jobPosting.url}`
   6. если задано `content`, то `content` = `{jobPosting.content}`
   7. если задано `contentVector`, то `content_vector` = `{jobPosting.contentVector}`
   8. если задано `evaluationStatus`, то `evaluation_status` = `{jobPosting.evaluationStatus}`
   9. если задано `responseStatus`, то `response_status` = `{jobPosting.responseStatus}`
   10. В любом случае выставляет `updated_at` = `now()`
4. Таким образом, если нужно очистить значение какого-то поля, то JobPostingsItemWrite содержит это поле со значением null
5. При успешной записи в БД возвращает `HTTP 200`
6. При возникновении любого не перехваченного исключения возвращает `HTTP 500` с текстом исключения в теле ответа
