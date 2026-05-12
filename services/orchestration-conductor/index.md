# orchestration-conductor

Сервис оркестрации процесса сбора и оценки вакансий.

Публикует REST API на отправку сообщений в Kafka (`collection-batch`,
`collection-query`, `job-posting-create`, `async-job-end`), хранит
состояние джобов в PostgreSQL (БД `joposcragent`, схема `orchestration`)
и отдаёт REST API для чтения джобов и их иерархий.

Консьюмеры обрабатывают входящие сообщения: планируют сбор с HeadHunter,
создают вакансии и запускают оценку, закрывают родительские джобы при
завершении дочерних.

Контракты REST описаны в OpenAPI; поведение консьюмеров — в отдельном
документе.

- [REST API][rest]
- [Консьюмеры][consumer]
- [OpenAPI][openapi]

[rest]: ./rest.md
[consumer]: ./consumer.md
[openapi]: ./openapi.yaml
