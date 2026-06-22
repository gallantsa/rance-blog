from .common import *

SECRET_KEY = 'development-secret-key'

DEBUG = True

ALLOWED_HOSTS = ['*']
# ES_URL 由 docker-compose 或 .env 文件注入，见 common.py

# 本地开发无 ES，关闭实时索引（防止 Post.save() 触发 ES 连接报错）
HAYSTACK_SIGNAL_PROCESSOR = "haystack.signals.BaseSignalProcessor"
