# orchestration-conductor

Сервис связывает ручной запуск и фоновые шаги пайплайна сбора и оценки вакансий через Kafka: по REST можно поставить в очередь пакетный сбор (`collection-batch`) или сбор по одному поисковому запросу (`collection-query`).

В штатном режиме он слушает сообщения о начале пакетного сбора и о успешном создании вакансии, обращается к `settings-manager` за активными запросами и порождает дочерние джобы в виде сообщений `collection-query-begin`. После обработки `collection-batch-begin` публикует `collection-batch-result` со статусом `SUCCEEDED` (успешный fan-out), `CANCELED` (нет активных запросов) или `FAILED` (ошибка); после успешного создания вакансии — запуск оценки через `job-posting-evaluate-begin`. Для учёта джобов использует PostgreSQL (БД `joposcragent`, схема `orchestration`).

## Оглавление

- [REST API][rest]
- [Консьюмеры][consumer]
- [OpenAPI][openapi]

[rest]: ./rest.md
[consumer]: ./consumer.md
[openapi]: ./openapi.yaml
