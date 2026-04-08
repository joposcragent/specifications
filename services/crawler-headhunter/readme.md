# crawler-headhunter

Сервис сбора новых вакансий с сайта hh.ru.

Сервис представляет из себя backend-приложение на node.js, запускающее playwrite, с его помощью осуществляющее сбор данных с UI сайта hh.ru и запись собранных данных в БД.

crawler-headhunter собирает данные с html-страниц сайта hh.ru и сохраняет данные в БД при помощи сервиса [job-postings-crud].

## Запуск задания сбора данных

`POST /crawler/start`

Входных параметров нет.

Алгоритм работы:

1. Если процесс сбора уже запущен — немедленно возвращает `HTTP 200` без запуска нового задания.
2. Запускает процесс сбора в фоновом потоке и немедленно возвращает `HTTP 200`:
   1. При возникновении любого исключения в ходе запуска джоба возвращает `HTTP 500` с текстом исключения в теле ответа.
3. Фоновый процесс запрашивает у `settings-manager` список поисковых запросов и css-селекторы:
   1. `GET http://settings-manager:8080/search-query/list`
   2. `GET http://settings-manager:8080/query-selector/list`
4. Для каждого поискового запроса:
   1. Запрашивает у HH.ru количество страниц результатов:
      1. Запрашивает первую страницу поискового запроса;
      2. Ищет элемент селектором `JOB_POSTING_LIST_PAGES_LINKS` и пересчитывает количество элементов `<li>`;
      3. Если селектором ничего не нашлось, значит страница только одна.
   2. Для каждой страницы:
      1. Собирает карточки вакансий селектором `JOB_POSTING_LIST_CARDS`;
      2. Из карточек собирает метаданные: `uid`, `title`, `company`, `url`;
      3. Собирает найденные `uid` в массив и через `job-postings-crud`; получает только новые `uid`:
         1. `GET http://job-postings-crud:8080/job-postings/search-query/non-existent`.
      4. Если новых `uid` нет — прерывает цикл по страницам;
      5. Для каждой новой вакансии:
         1. Получает страницу вакансии путем открытия страницы вакансии по `url` в новой вкладке;
         2. Собирает со страницы вакансии данные: `content`, `publishedDate`;
         3. Очищает очищает `content` от html-тэгов и разметки;
         4. Сохраняет вакансию через `job-postings-crud`: `uid`, `title`, `company`, `url`, `content`, `publishedDate`:
            1. `POST http://job-postings-crud:8080/job-postings/{jobPostingUuid}`;
            2. UUID v4 для `{jobPostingUuid}` crawler генерит сам.
         5. При возникновении любого исключения — пропускает вакансию и продолжает (skip-and-continue).

### Диаграмма последовательности

```mermaid
sequenceDiagram
    participant Scheduler
    participant Crawler as crawler-headhunter
    participant Settings as settings-manager
    participant Postings as job-postings-crud
    participant HH as HH.ru

    Scheduler->>Crawler: POST /crawler/start

    alt джоб уже запущен
        Crawler-->>Scheduler: HTTP 200 (тихий игнор)
    else
        Crawler-->>Scheduler: HTTP 200
        Note over Crawler,HH: асинхронный фоновый процесс
        Crawler->>Settings: GET поисковые запросы и css-селекторы

        loop По каждому поисковому запросу
            Crawler->>HH: Запросить количество страниц

            loop По страницам запроса
                Crawler->>+HH: Собрать вакансии со страницы
                HH->>-Crawler: uid, title, company, url
                Crawler->>+Postings: Проверить uid на уникальность
                Postings->>-Crawler: Только новые uid
                Crawler->>Crawler: Нет новых uid → прервать цикл по страницам

                loop По всем новым вакансиям
                    Crawler->>+HH: Получить страницу вакансии
                    HH->>-Crawler: content, publishedDate
                    Crawler->>Postings: Сохранить вакансию (uid, title, company, url, content, publishedDate)
                    Note right of Postings: ошибка → skip-and-continue
                end
            end
        end
    end
```

[job-postings-crud]: ../job-postings-crud/index.md
