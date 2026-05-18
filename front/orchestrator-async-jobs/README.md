<!-- markdownlint-disable MD013 MD060 -->
# Оркестратор · асинхронные джобы

## Назначение и маршрут

- **Раздел меню:** под сабхедером **«Главная»** три пункта **одного уровня** (как у «Вакансий»): «Дашборд», «Вакансии», **«Оркестратор»** (сразу после вакансий, ведёт на этот экран).
- **Маршрут:** `/orchestrator/async-jobs`.
- Реализация: [`web-front`][web-front-repo].

Экран просмотра таблицы записей `orchestration.async_jobs` через REST `orchestration-async-jobs-crud`: серверная пагинация, сортировка и отборы.

## Базовый URL и прокси

Клиент HTTP использует переменную **`VITE_ORCHESTRATION_ASYNC_JOBS_CRUD_BASE_URL`**. Пустое значение — запросы на **тот же origin**, что и SPA; в Docker **nginx** фронта проксирует префикс **`/orchestration-async-jobs-crud/`** на сервис `orchestration-async-jobs-crud`; в dev **Vite** — proxy на сервис (см. корневой [README](../README.md) и `vite.config`).

## Контракты бэкенда

- OpenAPI: [services/orchestration-async-jobs-crud/openapi.yaml](../../services/orchestration-async-jobs-crud/openapi.yaml)
- Поведение списка и отборов: [services/orchestration-async-jobs-crud/readme.md](../../services/orchestration-async-jobs-crud/readme.md) (раздел `GET /async-jobs/list`)
- Связанные сущности джоба: **`GET /async-jobs/{jobUuid}/list/related`**, тело `RelatedEntitiesUuidsList` — см. [orchestration-async-jobs-crud/readme][async-jobs-crud-readme] (раздел с этим путём) и схему в OpenAPI.

## Макет: таблица

Компонент серверной таблицы (`v-data-table-server` или эквивалент): колонки по полям `AsyncJobItem` (`uuid`, `name`, `parentUuid`, `status`, `started_at`, `updated_at`, `finished_at`, краткое представление `context` / `result`).

| Колонка | Сортировка (кнопка в заголовке колонки) | Отбор (`v-menu`) |
|---------|----------------------------------------|------------------|
| `uuid` | Да | Да: ввод UUID → query `jobUuid` |
| `name` | Да | Нет |
| `parentUuid` | Да | Да: ввод UUID → query `parentJobUuid` |
| `status` | Да | Да: выбор значения `AsyncJobStatus` → query `status` |
| `started_at` | Да | Нет |
| `updated_at` | Да | Нет |
| `finished_at` | Да | Нет |
| `context` | Да | Нет |
| `result` | Да | Нет |

- Запрос списка: **`GET /async-jobs/list`** с параметрами `page`, `size`, `sortBy`, `sortDir`, активные отборы (`jobUuid`, `parentJobUuid`, `status`, при необходимости `startedBefore`).
- **`total`** из ответа задаёт длину данных для пагинации.
- Значения по умолчанию сортировки на бэке: `sortBy=started_at`, `sortDir=desc` (если не переданы).

## Фильтры в заголовке (uuid, parentUuid, status)

1. Рядом с кнопкой сортировки — иконка открытия **`v-menu`** с полем ввода (для `status` — выбор из enum или поле с валидацией).
2. **Применить** отправляет запрос с соответствующим query-параметром, сбрасывает страницу на 1, закрывает меню.
3. **ESC** и клик **вне** меню закрывают меню **без** запроса (через поведение `v-menu` / `close-on-content-click`).
4. Рядом с отбором в колонках `uuid`, `parentUuid`, `status` — кнопка **сброса всех отборов** (снимает `jobUuid`, `parentJobUuid`, `status` независимо от колонки, в которой нажата).

## Модалка карточки джоба

1. Каждая ячейка таблицы отображается как **кликабельная ссылка** (кнопка с `role="link"` и стилем текста ссылки); клик открывает **`v-dialog`** с полным объектом строки (все поля `AsyncJobItem`, для `context` / `result` — читаемое представление JSON при необходимости).
2. Закрытие: кнопка-крестик, **ESC**, клик по оверлею (стандартное поведение `v-dialog`).
3. При открытой модалке дополнительно вызывается **`GET /async-jobs/{jobUuid}/list/related`**. В диалоге отображаются списки UUID **`jobPostingsList`** (вакансии) и **`searchQueriesList`** (поисковые запросы): индикатор загрузки на время запроса, сообщение об ошибке при неуспехе, для пустых списков — явная подпись «нет связанных».

## Вход по ссылке (query)

- Поддерживаемые query-параметры на `/orchestrator/async-jobs`:
  - **`jobUuid`** — UUID джоба; при валидном значении устанавливается отбор списка (`GET /async-jobs/list?jobUuid=…`), страница сбрасывается на 1.
  - **`openDetail`** — при значении, интерпретируемом как истина (например `1`), после загрузки данных открывается модалка карточки: строка берётся из текущей страницы списка или, если строки нет, выполняется `GET /async-jobs/{jobUuid}`.
- После успешного открытия модалки по deep link URL **нормализуется** (`router.replace`): параметр `openDetail` удаляется, чтобы повторный F5 не открывал модалку снова; `jobUuid` может сохраняться для сохранения отбора (или сниматься при закрытии модалки — зафиксировать в реализации единообразно).
- С дашборда ссылки ведут на этот маршрут с `jobUuid` и `openDetail=1` (см. [Дашборд][dashboard-readme]).

## Открытие и обновление

1. При первом входе на `/orchestrator/async-jobs` — индикатор загрузки, затем таблица по ответу `GET /async-jobs/list`.
2. Смена страницы, сортировки или применение фильтра — повторный запрос списка.
3. При **F5** — повтор сценария открытия.
4. Если в URL заданы `jobUuid` / `openDetail` — после загрузки списка применить сценарий раздела «Вход по ссылке».

[web-front-repo]: https://github.com/joposcragent/web-front
[dashboard-readme]: ../dashboard/README.md
[async-jobs-crud-readme]: ../../services/orchestration-async-jobs-crud/readme.md
