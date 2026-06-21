#!/bin/sh

python manage.py migrate

# 搜索索引：有数据时增量更新，无数据时全量重建
python manage.py shell -c "
from django.core.management import call_command
from haystack import connections
backend = connections['default'].get_backend()
try:
    count = backend.document_count()
    print(f'ES 索引已有 {count} 条文档，执行增量更新')
    call_command('update_index', age=None)
except Exception:
    print('ES 索引为空，执行全量重建')
    call_command('clear_index', noinput=True, interactive=False)
    call_command('update_index', age=None)
" 2>&1 | grep -v '^$' || echo 'index rebuild skipped'

python manage.py runserver 0.0.0.0:8000
