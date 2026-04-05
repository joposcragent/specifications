create type settings.threshold_type as enum ('TITLE', 'GENERAL', 'NOTIFICATION');

alter type settings.threshold_type owner to postgres;

