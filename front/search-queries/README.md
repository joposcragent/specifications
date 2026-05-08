<!-- markdownlint-disable MD013 MD060 -->
# Поисковые запросы

## Назначение и маршрут

- **Раздел меню:** Настройки → **Поисковые запросы**.
- **Маршрут (пример):** `/settings/search-queries`.

## Макет (wireframe)

```text
+--------------------------------------------------------------------------------+
|  Заголовок «Поисковые запросы»    [ Создать ]                                   |
+--------------------------------------------------------------------------------+
|  Таблица: название | запрос | пороги | активен | ленивый | дата | [Собрать]…   |
+--------------------------------------------------------------------------------+
|  (Модалка: name, query, пороги 0–1, чекбоксы isActive / isLazyScraping)         |
+--------------------------------------------------------------------------------+
```

## Данные и API

Базовый URL: `VITE_SETTINGS_MANAGER_BASE_URL`. Контракт: [services/settings-manager/openapi.yaml](../../services/settings-manager/openapi.yaml); алгоритмы: [services/settings-manager/search-query.md](../../services/settings-manager/search-query.md).

### Семантика поля `query`

- В БД хранится **текст запроса в смысле query-string** — содержимое URL **после первого `?`** для выбранной страницы поиска на hh.ru (например `area=1&text=java`).
- Полная ссылка для открытия в браузере собирается как **`{VITE_HH_SEARCH_BASE_URL}?{query}`**, где **`VITE_HH_SEARCH_BASE_URL`** — базовый URL страницы поиска **без** завершающего `?`.

### Поля порогов и флагов

- **`contentRelevance`**, **`notificationRelevance`** — числа в \([0, 1]\); обязательны при создании; при редактировании можно менять через `PATCH`.
- **`isActive`** — участвует ли строка в плановом `collection-batch` (на бэкенде оркестрации неактивные строки отфильтровываются).
- **`isLazyScraping`** — передаётся в краулер как `lazy` при ручном и плановом запуске.

### Список

- **GET /search-query/list**
- Ответ: JSON-массив `SearchQueriesItem` с полями `uuid`, `name`, `query`, `contentRelevance`, `notificationRelevance`, `isActive`, `isLazyScraping`, `createdAt`, `updatedAt`.

### Создание

- Клиент генерирует **UUID v4** для сущности.
- **POST /search-query/{entityUuid}** с телом: `name`, `query`, `contentRelevance`, `notificationRelevance`, опционально `isActive`, `isLazyScraping`.

### Обновление

- **PATCH /search-query/{entityUuid}** — хотя бы одно из полей, перечисленных в OpenAPI.

### Удаление

- **DELETE** `/search-query/{entityUuid}`

### Ручной сбор вакансий

- **POST** `{VITE_CELERY_ORCHESTRATOR_BASE_URL}/events-queue/collection-query` (через dev-proxy `/events-queue/…`) с телом JSON:
  - `name` — отображаемое имя строки;
  - `searchQuery` — значение `query` из строки;
  - `searchQueryUuid` — `uuid` строки;
  - `lazy` — значение `isLazyScraping`.

## Алгоритмы активных элементов

Кнопка «Создать», «Изменить», таблица, удаление — по общим правилам валидации порогов на клиенте (диапазон 0–1) перед `POST`/`PATCH`.

### Кнопка «Собрать вакансии»

- **Клик:** `POST /events-queue/collection-query` с полями `name`, `searchQuery`, `searchQueryUuid`, `lazy` (см. выше).
- **Ошибка сети / HTTP:** показать текст ошибки (см. обёртку `orchestratorErrorMessage`).

## Открытие страницы (mount)

1. `GET /search-query/list`.
2. **200** и пустой массив — пустое состояние («нет запросов»), не ошибка.
3. **500 / сеть** — сообщение об ошибке.

## Связанные спецификации

- [Оболочка приложения](../app-shell/README.md)
- [search-query.md](../../services/settings-manager/search-query.md)
- [settings-manager OpenAPI](../../services/settings-manager/openapi.yaml)
- [celery-orchestrator OpenAPI](../../services/celery-orchestrator/openapi.yaml)
