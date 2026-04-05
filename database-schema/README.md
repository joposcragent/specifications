# Схема БД и миграции Flyway

В этом каталоге лежат SQL-миграции [Flyway](https://documentation.red-gate.com/flyway/). Каждый **подкаталог первого уровня** — это имя **схемы PostgreSQL**; все скрипты из подкаталога выполняются в контексте этой схемы (отдельный прогон Flyway на каждую папку).

## Требования

- [Docker](https://docs.docker.com/) с поддержкой Compose (v2)
- Для ручной сборки образа — доступ к реестру `docker.io`

## Быстрый старт (PostgreSQL + миграции)

Из каталога `database-schema`:

```bash
docker compose up --build
```

Сервис `postgres` поднимается с healthcheck к служебной базе `postgres`. Затем одноразовый сервис `ensure-db` при необходимости создаёт базу с именем `POSTGRES_DB` (если её ещё нет). Это нужно, когда том данных уже инициализирован с другим `POSTGRES_DB` или вы сменили имя базы в `.env`: без этого шага Flyway получал бы ошибку «database does not exist». После успешного завершения `ensure-db` запускается одноразовый контейнер `flyway` с миграциями. Данные БД хранятся в именованном томе `postgres_data`, чтобы перезапуск не сбрасывал состояние.

Подключение с хоста:

- **Хост:** `localhost`
- **Порт:** значение `POSTGRES_PORT` (по умолчанию `5432`)
- **База:** `POSTGRES_DB` (по умолчанию `joposcragent`)
- **Пользователь / пароль:** `POSTGRES_USER` / `POSTGRES_PASSWORD` (по умолчанию `postgres` / `postgres`)

Если порт `5432` на машине уже занят (другой PostgreSQL и т.п.), задайте другой порт, например:

```bash
POSTGRES_PORT=5433 docker compose up --build
```

либо создайте файл `.env` рядом с `docker-compose.yaml` и укажите там `POSTGRES_PORT=5433`.

Флаг `--abort-on-container-exit` завершает весь стек при первом выходе контейнера; одноразовый `ensure-db` завершится до `flyway`, и остальные сервисы могут остановиться преждевременно. Для полного прогона миграций используйте обычный `docker compose up --build` или `docker compose up --build -d`, затем при необходимости смотрите логи: `docker compose logs flyway`.

## Переменные окружения

| Переменная          | Назначение      | Значение по умолчанию |
| ------------------- | --------------- | --------------------- |
| `POSTGRES_USER`     | пользователь БД | `postgres`            |
| `POSTGRES_PASSWORD` | пароль          | `postgres`            |
| `POSTGRES_DB`       | имя базы        | `joposcragent`        |
| `POSTGRES_PORT`     | порт на хосте   | `5432`                |

Пароли в репозиторий не коммитьте: для локальной разработки используйте `.env` (файл добавьте в `.gitignore` в корне репозитория, если ещё не игнорируется).

## Сборка только образа Flyway

Контекст сборки — текущий каталог (`database-schema`):

```bash
docker build -t local-flyway-migrate .
```

Образ наследует [официальный образ `flyway/flyway`][flyway-image] с фиксированным тегом (см. `Dockerfile`). Точка входа — скрипт `migrate.sh`: для каждой подпапки в `/flyway/sql` выполняется `flyway migrate` с `-locations` и `-schemas`, соответствующими имени папки. Порядок схем — **лексикографический** (через `sort`).

Запуск миграций вручную (БД должна быть доступна по сети, например уже запущенный контейнер `postgres`):

```bash
docker run --rm \
  -e FLYWAY_URL="jdbc:postgresql://host.docker.internal:5432/joposcragent" \
  -e FLYWAY_USER="postgres" \
  -e FLYWAY_PASSWORD="postgres" \
  local-flyway-migrate
```

Подставьте хост, порт и учётные данные под вашу среду. На Linux вместо `host.docker.internal` может понадобиться IP хоста или `--network host`.

## Образ Flyway в другом docker-compose

Образ содержит только миграции и скрипт `migrate.sh`; ему нужны переменные `FLYWAY_URL`, `FLYWAY_USER`, `FLYWAY_PASSWORD` (как в официальной документации [Flyway][flyway-docs]). База данных должна уже существовать (или создавайте её отдельным шагом, по аналогии с сервисом `ensure-db` в [файле Compose][compose-file]).

### На вашей локальной машине

1. **Соберите образ** из каталога `database-schema` и задайте удобный тег (один раз или после каждого изменения SQL):

   ```bash
   docker build -t local-flyway-migrate /путь/к/database-schema
   ```

2. **Подключите образ в другом проекте** одним из способов:

   - Указать готовый тег:

     ```yaml
     services:
       migrate:
         image: local-flyway-migrate
         environment:
           FLYWAY_URL: jdbc:postgresql://db:5432/имя_базы
           FLYWAY_USER: postgres
           FLYWAY_PASSWORD: postgres
         depends_on:
           db:
             condition: service_healthy
         restart: "no"
     ```

   - Либо собрать из исходников без отдельного `docker build` (путь к каталогу с `Dockerfile` и миграциями должен быть доступен с вашей машины):

     ```yaml
     services:
       migrate:
         build:
           context: /путь/к/database-schema
           dockerfile: Dockerfile
         environment:
           FLYWAY_URL: jdbc:postgresql://db:5432/имя_базы
           FLYWAY_USER: postgres
           FLYWAY_PASSWORD: postgres
         depends_on:
           db:
             condition: service_healthy
         restart: "no"
     ```

3. **Имя хоста в `FLYWAY_URL`** должно совпадать с именем сервиса PostgreSQL в **том же** файле Compose (пример выше: `db`). Тогда контейнеры в одной сети видят друг друга по DNS Docker.

4. Если PostgreSQL крутится **на хосте**, а Flyway — в контейнере другого compose, используйте `host.docker.internal` (Windows, macOS, Docker Desktop) или IP хоста в `FLYWAY_URL`, например `jdbc:postgresql://host.docker.internal:5432/имя_базы`.

### Публикация образа в Docker Hub

Имя образа на [Docker Hub][docker-hub] имеет вид `имя_пользователя/имя_репозитория:тег` (например `myuser/joposcragent-flyway:1.0.0`). Репозиторий можно [создать в веб-интерфейсе][docker-hub-repos] заранее или он появится при первом `docker push`, если политика аккаунта это допускает.

1. Войдите в Docker с учётной записью Hub (интерактивно запросит пароль или [Personal Access Token][docker-hub-token]):

   ```bash
   docker login
   ```

   Для неинтерактивного сценария (CI) используйте `echo "$DOCKERHUB_TOKEN" | docker login --username "$DOCKERHUB_USER" --password-stdin`.

2. Перейдите в каталог `database-schema` и соберите образ с **тегом под Docker Hub**:

   ```bash
   cd database-schema
   docker build -t myuser/joposcragent-flyway:1.0.0 .
   ```

   Подставьте своё имя пользователя Hub, имя репозитория и тег (часто используют семантическую версию или `latest`).

3. Отправьте образ в реестр:

   ```bash
   docker push myuser/joposcragent-flyway:1.0.0
   ```

После успешной загрузки образ доступен по адресу вида `docker.io/myuser/joposcragent-flyway:1.0.0` (префикс `docker.io/` в compose обычно можно не указывать).

### На удалённой машине (образ с Docker Hub)

1. На сервере выполните `docker pull myuser/joposcragent-flyway:1.0.0` или задайте тот же образ в `docker-compose.yaml`, чтобы при `docker compose pull` загрузка шла автоматически.

2. В сервисе миграций укажите опубликованный образ и переменные `FLYWAY_*`:

   ```yaml
   services:
     migrate:
       image: myuser/joposcragent-flyway:1.0.0
       environment:
         FLYWAY_URL: jdbc:postgresql://db:5432/имя_базы
         FLYWAY_USER: postgres
         FLYWAY_PASSWORD: postgres
       depends_on:
         db:
           condition: service_healthy
       restart: "no"
   ```

3. В `FLYWAY_URL` укажите хост PostgreSQL, **видимый с удалённой машины**: имя сервиса БД в том же compose, IP/hostname сервера в сети, адрес облачной БД. `localhost` внутри контейнера — это сам контейнер, а не хост сервера; для БД на том же хосте без общей сети compose нужны `network_mode: host`, отдельный IP хоста или пользовательская сеть Docker.

4. Пароли и URL задавайте через переменные окружения или механизм секретов на сервере, не коммитьте их в репозиторий.

**Итог:** локально удобно собирать из `build.context` или локального тега; на удалённой машине — тянуть образ с Docker Hub по имени `пользователь/репозиторий:тег` и настраивать `FLYWAY_URL` относительно сети **того** хоста, где запускается контейнер Flyway.

## Добавление миграций

1. Выберите схему — подкаталог с её именем (например `settings`, `job_postings`).
2. Добавьте файл с именем по соглашению Flyway: `V<версия>__<краткое_описание>.sql` (после номера версии — **два** подчёркивания).
3. В SQL используйте полные имена объектов с указанием схемы, например `settings.my_table`, чтобы не зависеть от `search_path`.

Отдельные потоки миграций: в каждой схеме своя таблица истории `flyway_schema_history`. Порядок применения **разных** схем задаётся сортировкой имён каталогов; при необходимости явного порядка зависимостей между схемами можно завести префиксы в именах папок (например `01_core`) **без** смены имени схемы в SQL (потребуется согласованное решение в скриптах и в этом README).

## Новая миграция при уже запущенном Compose

Сценарий: контейнер с PostgreSQL уже работает (например после `docker compose up -d`), данные в томе сохранены, вы добавили файл миграции в подкаталог схемы.

1. Убедитесь, что имя файла и номер версии соответствуют соглашению Flyway и **больше**, чем последняя применённая версия в этой схеме (см. таблицу `flyway_schema_history` в нужной схеме или список уже существующих `V*__*.sql` в папке).
2. Пересоберите образ сервиса `flyway`, чтобы в образ попали новые SQL-файлы с диска:

   ```bash
   docker compose build flyway
   ```

3. Запустите миграции повторно одноразовым контейнером (PostgreSQL при этом не пересоздаётся, том с данными не трогается):

   ```bash
   docker compose run --rm flyway
   ```

   Команда использует те же `FLYWAY_*`, что и в [файле Compose][compose-file], и подключается к сервису `postgres` по сети Compose.

Если контейнер с БД не запущен, перед шагом 3 выполните `docker compose up -d postgres` (или полный `docker compose up -d` — поднимутся зависимости по `depends_on`).

Альтернатива одной командой после правок в SQL: `docker compose up --build flyway` — пересоберёт образ `flyway` и выполнит миграции; при необходимости поднимет `postgres`, если он ещё не работает.

[compose-file]: docker-compose.yaml
[docker-hub]: https://hub.docker.com/
[docker-hub-repos]: https://docs.docker.com/docker-hub/repos/create/
[docker-hub-token]: https://docs.docker.com/docker-hub/access-tokens/
[flyway-docs]: https://documentation.red-gate.com/flyway/
[flyway-image]: https://hub.docker.com/r/flyway/flyway
