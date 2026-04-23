# Сервис celery-orchestrator

Python-сервис инкапсулирует взаимодействие с **Celery** и брокером **Redis**, а также ведёт учёт **оркестрационных задач** пайплайна сбора и оценки вакансий. Поведение бизнес-процесса задано в [UC-02 «Оркестрация процесса»](../../../solution/src/md/40-solution/10-use-cases/UC-02-collection-job.md); выбор стека описан в [ADR-003](../../../solution/src/md/40-solution/90-ADR/ADR-003-celery-redis.md).

Контракт REST API см. в [openapi.yaml](./openapi.yaml) в этом каталоге.

## Оглавление

1. [REST-интерфейс]
2. [Async tasks]

<!--LINKS-->

[REST-интерфейс]: ./rest.md
[Async tasks]: ./async.md
