#!/bin/sh
set -eu

SQL_ROOT="/flyway/sql"

for d in $(find "$SQL_ROOT" -mindepth 1 -maxdepth 1 -type d | sort); do
  schema=$(basename "$d")
  echo "Running Flyway migrations for schema: $schema"
  flyway \
    -locations="filesystem:${SQL_ROOT}/${schema}" \
    -schemas="$schema" \
    migrate
done
