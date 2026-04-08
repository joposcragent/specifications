# crawler-headhunter

Сервис сбора новых вакансий с сайта hh.ru.

Сервис представляет из себя backend-приложение на node.js, запускающее playwrite, с его помощью осуществляющее сбор данных с UI сайта hh.ru и запись собранных данных в БД.

crawler-headhunter собирает данные с html-страниц сайта hh.ru и сохраняет данные в БД при помощи сервиса [job-postings-crud].

## Запуск задания сбора данных

`POST /crawler/start`

Входных параметров нет.

Алгоритм работы:

1. Немедленно возвращает `HTTP 200` и запускает процесс сбора в фоновом потоке
   1. При возникновении любого исключения в ходе запуска джоба возвращает `HTTP 500` с текстом исключения в теле ответа

### Диаграмма последовательности

```mermaid
sequenceDiagram
    participant settings as settings-manager
    participant crawler as crawler-headhunter
    participant postings as job-postings-crud
    participant transformer as sentence-transformer
    participant evaluator as job-postings-evaluator
    participant hh as HH.ru

    crawler->>settings: Запрашивает поисковые запросы и css-селекторы

    loop По каждому поисковому запросу
        crawler->>hh: Запрашивает количества страниц
        
        loop По страницам запроса
            crawler->>+hh: Собирает все вакансии со страницы
            hh->>-crawler: Основные сведения uid, title, company, url
            crawler->>+postings: Проверить найденные uid на уникальность
            postings->>-crawler: Только новые uid

            crawler->>crawler: Если новых нет, прервать цикл по страницам

            loop По всем новым вакансиям
                crawler->>+hh: Получить страницу вакансии
                hh->>-crawler: Текст и метаданные (content, publishedDate)
                crawler->>postings: Сохранить новую вакансию (uid, title, company, urlб content, publishedDate)
            end            
        end
    end

```

[job-postings-crud]: ../job-postings-crud/index.md
