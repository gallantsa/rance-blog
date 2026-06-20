FROM python:3.12-alpine

ENV PYTHONUNBUFFERED=1

RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories

RUN apk update \
    && apk add --no-cache \
       jpeg-dev \
       zlib-dev \
       freetype-dev \
       lcms2-dev \
       openjpeg-dev \
       tiff-dev \
       tk-dev \
       tcl-dev

WORKDIR /app

# 安装 uv
RUN pip install uv -i https://pypi.tuna.tsinghua.edu.cn/simple

# 仅复制依赖文件，利用 Docker 缓存
COPY pyproject.toml uv.lock ./

# 安装到系统 Python，不创建 .venv（避免 volume mount 冲突）
RUN uv pip install --system -r pyproject.toml -i https://pypi.tuna.tsinghua.edu.cn/simple

COPY . .

COPY ./compose/local/start.sh /start.sh
RUN sed -i 's/\r//' /start.sh && chmod +x /start.sh

CMD ["/start.sh"]
