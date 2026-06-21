from .common import *

SECRET_KEY = os.environ['DJANGO_SECRET_KEY']

DEBUG = False

ALLOWED_HOSTS = ['*']
# ES_URL 由 docker-compose 的 env_file 注入，见 common.py

CSRF_TRUSTED_ORIGINS = ['*']

# 信任 Nginx 传递的 HTTPS 协议头
SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')
