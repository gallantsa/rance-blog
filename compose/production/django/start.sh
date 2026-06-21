#!/bin/sh
set -e

mkdir -p /app/database

uv run python manage.py migrate --noinput
uv run python manage.py collectstatic --noinput

# 等待 Elasticsearch 就绪（最多 60 秒）
echo "等待 Elasticsearch..."
for i in $(seq 1 30); do
  if uv run python -c "
import os; os.environ['DJANGO_SETTINGS_MODULE']='config.settings.local'
import django; django.setup()
from haystack import connections
backend = connections['default'].get_backend()
try:
    ok = backend.conn.ping()
    print('connected' if ok else '')
except Exception:
    exit(1)
" 2>/dev/null | grep -q connected; then
    echo "Elasticsearch 就绪"
    break
  fi
  echo "  等待 ES... ($i/30)"
  sleep 2
done

# 搜索索引：有数据时增量更新，无数据时全量重建
uv run python manage.py shell -c "
from django.core.management import call_command
from haystack import connections
backend = connections['default'].get_backend()
try:
    count = backend.document_count()
    print(f'ES 索引已有 {count} 条文档，执行增量更新')
    call_command('update_index', age=None)
except Exception:
    print('ES 索引为空或不存在，执行全量重建')
    call_command('clear_index', noinput=True, interactive=False)
    call_command('update_index', age=None)
" 2>&1 | grep -v '^$' || echo 'index rebuild skipped'

exec uv run gunicorn config.wsgi:application -w 4 -k gthread -b 0.0.0.0:8000 --chdir=/app
