#!/bin/bash
# ============================================================
# rance-blog 一键部署脚本
# 适用系统：Rocky Linux 9 / 10（全新安装）
# 用法：
#   1. 将本脚本上传到服务器
#   2. chmod +x deploy_rocky.sh
#   3. 设置 GitHub 仓库地址：export REPO_URL="https://github.com/your/repo.git"
#   4. 设置 Django 密钥：export DJANGO_SECRET_KEY="your-secret-key-here"
#   5. sudo ./deploy_rocky.sh
# ============================================================

set -euo pipefail

# ========== 配置区（可根据需要修改） ==========
PROJECT_NAME="rance-blog"
PROJECT_DIR="/var/www/${PROJECT_NAME}"
GIT_REPO="${REPO_URL:-https://github.com/gallantsa/rance-blog.git}"
BRANCH="${BRANCH:-master}"

# Python 版本（需满足 pyproject.toml 中 >=3.14 的要求）
PYTHON_VERSION="3.14.6"

# 服务端口
NGINX_PORT=80

# 系统用户
APP_USER="www-data"

# Supervisor 配置
SUPERVISOR_CONF="/etc/supervisord.d/${PROJECT_NAME}.ini"

# 日志
LOG_FILE="/var/log/deploy_${PROJECT_NAME}.log"

# ========== 颜色输出 ==========
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ========== 前置检查 ==========
check_prerequisites() {
    if [[ $EUID -ne 0 ]]; then
        error "请使用 sudo 或以 root 用户运行本脚本"
    fi

    if [[ -z "${DJANGO_SECRET_KEY:-}" ]]; then
        error "请设置 DJANGO_SECRET_KEY 环境变量\n  例如: export DJANGO_SECRET_KEY=\"$(openssl rand -hex 40)\""
    fi

    if ! command -v curl &>/dev/null; then
        info "安装 curl..."
        dnf install -y curl
    fi
}

# ========== 安装系统依赖 ==========
install_system_packages() {
    info "===== 更新系统软件包 ====="
    dnf update -y
    dnf install -y epel-release

    info "===== 安装编译工具和系统依赖 ====="
    dnf groupinstall -y "Development Tools"
    dnf install -y \
        gcc \
        gcc-c++ \
        make \
        wget \
        git \
        openssl-devel \
        bzip2-devel \
        libffi-devel \
        zlib-devel \
        readline-devel \
        sqlite-devel \
        ncurses-devel \
        xz-devel \
        tk-devel \
        libxml2-devel \
        libxslt-devel \
        nginx \
        supervisor \
        bzip2

    info "===== 启用并启动服务 ====="
    systemctl enable nginx
    systemctl enable supervisord
}

# ========== 安装 pyenv + Python ==========
install_python() {
    info "===== 安装 pyenv ====="
    if [[ ! -d "$HOME/.pyenv" ]]; then
        curl -fsSL https://pyenv.run | bash
    fi

    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init -)"

    # 写入 bashrc 以便后续命令可用
    grep -qxF 'export PYENV_ROOT="$HOME/.pyenv"' ~/.bashrc 2>/dev/null || {
        echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.bashrc
        echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bashrc
        echo 'eval "$(pyenv init -)"' >> ~/.bashrc
    }

    info "===== 安装 Python ${PYTHON_VERSION}（编译耗时较长，请耐心等待...） ====="
    if ! pyenv versions | grep -q "${PYTHON_VERSION}"; then
        pyenv install "${PYTHON_VERSION}"
    else
        info "Python ${PYTHON_VERSION} 已安装，跳过编译"
    fi

    pyenv global "${PYTHON_VERSION}"
    PYTHON_BIN="$(pyenv which python)"
    info "Python 路径: ${PYTHON_BIN}"
    "${PYTHON_BIN}" --version
}

# ========== 安装 uv ==========
install_uv() {
    info "===== 安装 uv ====="
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
    grep -qxF 'export PATH="$HOME/.local/bin:$PATH"' ~/.bashrc 2>/dev/null || {
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
    }
    uv --version
}

# ========== 克隆项目 ==========
clone_project() {
    info "===== 克隆项目代码 ====="
    if [[ -d "${PROJECT_DIR}" ]]; then
        warn "项目目录已存在，备份为 ${PROJECT_DIR}.bak"
        rm -rf "${PROJECT_DIR}.bak"
        mv "${PROJECT_DIR}" "${PROJECT_DIR}.bak"
    fi

    mkdir -p "${PROJECT_DIR}"
    git clone -b "${BRANCH}" "${GIT_REPO}" "${PROJECT_DIR}"
    cd "${PROJECT_DIR}"
}

# ========== 安装 Python 依赖 ==========
install_dependencies() {
    info "===== 安装 Python 项目依赖 ====="
    cd "${PROJECT_DIR}"

    export PATH="$HOME/.pyenv/bin:$PATH"
    export PATH="$HOME/.local/bin:$PATH"
    eval "$(pyenv init -)"

    uv sync --frozen --python "$(pyenv which python)"
    info "依赖安装完成"
}

# ========== 创建 .env 和配置文件 ==========
configure_environment() {
    info "===== 配置生产环境 ====="

    # 创建日志目录
    mkdir -p /var/log/uwsgi
    mkdir -p /var/log/gunicorn

    # 设置 DJANGO_SECRET_KEY 到 bashrc（持久化）
    grep -qxF 'export DJANGO_SECRET_KEY=' /etc/profile.d/${PROJECT_NAME}.sh 2>/dev/null || {
        echo "export DJANGO_SECRET_KEY='${DJANGO_SECRET_KEY}'" > /etc/profile.d/${PROJECT_NAME}.sh
        chmod +x /etc/profile.d/${PROJECT_NAME}.sh
    }

    # 写入 supervisor 的 environment 配置时使用
    cat > "${PROJECT_DIR}/.env" << EOF
DJANGO_SECRET_KEY=${DJANGO_SECRET_KEY}
DJANGO_SETTINGS_MODULE=config.settings.production
EOF
    chmod 600 "${PROJECT_DIR}/.env"
}

# ========== 数据库迁移与静态文件 ==========
setup_django() {
    info "===== 数据库迁移 ====="
    cd "${PROJECT_DIR}"

    export DJANGO_SECRET_KEY="${DJANGO_SECRET_KEY}"
    export DJANGO_SETTINGS_MODULE="config.settings.production"
    export PATH="$HOME/.pyenv/bin:$HOME/.local/bin:$PATH"
    eval "$(pyenv init -)"

    uv run python manage.py migrate --noinput
    info "数据库迁移完成"

    info "===== 收集静态文件 ====="
    uv run python manage.py collectstatic --noinput
    info "静态文件收集完成"

    info "===== 创建超级用户（交互式） ====="
    uv run python manage.py createsuperuser || true
}

# ========== 配置 Supervisor ==========
configure_supervisor() {
    info "===== 配置 Supervisor ====="

    cat > "${SUPERVISOR_CONF}" << EOF
[program:${PROJECT_NAME}]
command=${PROJECT_DIR}/.venv/bin/gunicorn config.wsgi:application --bind 127.0.0.1:8000 --workers 4 --timeout 120 --access-logfile /var/log/gunicorn/access.log --error-logfile /var/log/gunicorn/error.log
directory=${PROJECT_DIR}
user=root
autostart=true
autorestart=true
stopasgroup=true
killasgroup=true
environment=DJANGO_SECRET_KEY="${DJANGO_SECRET_KEY}",DJANGO_SETTINGS_MODULE="config.settings.production"
stdout_logfile=/var/log/gunicorn/supervisor.log
stderr_logfile=/var/log/gunicorn/supervisor_err.log
EOF

    info "Supervisor 配置已写入: ${SUPERVISOR_CONF}"
}

# ========== 配置 Nginx ==========
configure_nginx() {
    info "===== 配置 Nginx ====="

    cat > "/etc/nginx/conf.d/${PROJECT_NAME}.conf" << 'NGINX_EOF'
server {
    listen      80;
    server_name _;
    charset     utf-8;

    # 最大上传大小
    client_max_body_size 10M;

    # 静态文件
    location /static {
        alias /var/www/rance-blog/static;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    # 媒体文件
    location /media {
        alias /var/www/rance-blog/media;
    }

    # 反向代理到 Gunicorn
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
NGINX_EOF

    # 移除默认站点
    rm -f /etc/nginx/conf.d/default.conf

    # 语法检查
    nginx -t
    info "Nginx 配置已写入: /etc/nginx/conf.d/${PROJECT_NAME}.conf"
}

# ========== 配置 Firewall ==========
configure_firewall() {
    info "===== 配置防火墙 ====="
    if command -v firewall-cmd &>/dev/null; then
        firewall-cmd --permanent --add-service=http
        firewall-cmd --permanent --add-service=https
        firewall-cmd --reload
        info "防火墙规则已添加（HTTP/HTTPS）"
    else
        warn "firewalld 未安装，请手动开放端口 ${NGINX_PORT}"
    fi
}

# ========== 设置文件权限 ==========
setup_permissions() {
    info "===== 设置文件权限 ====="
    chown -R root:root "${PROJECT_DIR}"
    chmod -R 755 "${PROJECT_DIR}"
    info "文件权限设置完成"
}

# ========== 启动服务 ==========
start_services() {
    info "===== 重启并启动服务 ====="

    # 重新加载 supervisor 配置
    supervisorctl reread
    supervisorctl update
    supervisorctl start "${PROJECT_NAME}" || supervisorctl restart "${PROJECT_NAME}"

    # 重启 nginx
    systemctl restart nginx

    # 检查服务状态
    info "===== 服务状态检查 ====="
    echo ""
    echo "--- Supervisor ---"
    supervisorctl status "${PROJECT_NAME}"
    echo ""
    echo "--- Nginx ---"
    nginx -t 2>&1 | head -1
    systemctl status nginx --no-pager | head -3
}

# ========== 完成信息 ==========
show_summary() {
    local server_ip
    server_ip=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')

    echo ""
    echo "============================================"
    echo -e "${GREEN}  ✅ 部署完成！${NC}"
    echo "============================================"
    echo ""
    echo "  项目地址:  ${PROJECT_DIR}"
    echo "  访问地址:  http://${server_ip}:${NGINX_PORT}"
    echo "  管理后台:  http://${server_ip}:${NGINX_PORT}/admin/"
    echo ""
    echo "  常用命令:"
    echo "    supervisorctl status ${PROJECT_NAME}    # 查看进程状态"
    echo "    supervisorctl restart ${PROJECT_NAME}   # 重启应用"
    echo "    journalctl -u nginx -f                  # Nginx 日志"
    echo "    tail -f /var/log/gunicorn/error.log     # 应用错误日志"
    echo ""
    echo "  日志文件:  ${LOG_FILE}"
    echo "============================================"
}

# ========== 主流程 ==========
main() {
    echo ""
    echo "============================================"
    echo "  ${PROJECT_NAME} - Rocky Linux 一键部署"
    echo "============================================"
    echo ""

    check_prerequisites
    install_system_packages
    install_python
    install_uv
    clone_project
    install_dependencies
    configure_environment
    setup_django
    configure_supervisor
    configure_nginx
    configure_firewall
    setup_permissions
    start_services
    show_summary
}

main 2>&1 | tee "${LOG_FILE}"
