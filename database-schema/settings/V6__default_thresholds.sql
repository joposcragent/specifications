INSERT INTO settings.relevance_thresholds (type, value, created_at)
VALUES ('CONTENT'::settings.threshold_type, 85, DEFAULT);

INSERT INTO settings.relevance_thresholds (type, value, created_at, updated_at)
VALUES ('NOTIFICATION'::settings.threshold_type, 92, DEFAULT);
