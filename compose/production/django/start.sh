#!/bin/sh
set -e

mkdir -p /app/database

uv run python manage.py migrate --noinput
uv run python manage.py collectstatic --noinput
exec uv run gunicorn config.wsgi:application -w 4 -k gthread -b 0.0.0.0:8000 --chdir=/app
