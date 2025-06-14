#!/bin/bash
set -e

# Wait for postgres
until PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -c '\q'; do
  >&2 echo "Postgres is unavailable - sleeping"
  sleep 1
done

>&2 echo "Postgres is up - executing command"

# Remove the '--' if it's the first argument
if [ "$1" = '--' ]; then
    shift
fi

# Execute odoo with all arguments
exec odoo "$@"