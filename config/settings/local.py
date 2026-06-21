from .common import *

SECRET_KEY = 'development-secret-key'

DEBUG = True

ALLOWED_HOSTS = ['*']
# ES_URL 由 docker-compose 或 .env 文件注入，见 common.py
