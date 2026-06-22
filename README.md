# rance-blog

基于 Django 5.2 的个人博客系统，支持 Markdown 渲染、全文搜索、RSS 订阅、评论等功能。

## 功能特性

- 📝 **Markdown 写作** — 支持代码高亮、目录生成、LaTeX 公式
- 🔍 **全文搜索** — Elasticsearch + Haystack，支持中文分词和高亮
- 📡 **RSS 订阅** — 自动生成文章订阅源
- 💬 **评论系统** — 支持文章评论
- 📊 **阅读统计** — 每篇文章独立阅读计数
- 🏷️ **分类与标签** — 文章分类、标签筛选
- 📄 **分页浏览** — 每页 10 篇文章
- 🐳 **Docker 支持** — 本地开发与生产部署一键启动
- ✅ **100% 测试覆盖** — 45 个单元测试

## 技术栈

| 组件 | 技术 |
|------|------|
| Web 框架 | Django 5.2 LTS |
| 数据库 | SQLite（开发） |
| 搜索引擎 | Elasticsearch 7.17 + Haystack |
| 前端 | Bootstrap 3 + jQuery |
| 包管理 | uv |
| 容器化 | Docker + Docker Compose |
| 进程管理 | Gunicorn |
| 反向代理 | Nginx |
| 测试 | Django TestCase + Coverage |

## 快速开始

### 本地开发（无 Docker）

```bash
# 1. 克隆
git clone https://github.com/gallantsa/rance-blog.git
cd rance-blog

# 2. 安装依赖
uv sync

# 3. 迁移数据库
uv run python manage.py migrate

# 4. 创建管理员
uv run python manage.py createsuperuser

# 5. 启动服务
uv run python manage.py runserver

# 6. 访问 http://127.0.0.1:8000
```

> 本地开发无 Elasticsearch，搜索功能不可用。如需搜索请使用 Docker 方式。

### Docker 开发环境（含 Elasticsearch）

```bash
# 构建并启动（自动建索引）
docker compose -f local.yml up -d

# 创建管理员
docker exec -it rance-blog uv run python manage.py createsuperuser

# 生成测试数据（可选）
docker exec -it rance-blog uv run python scripts/fake.py

# 访问 http://127.0.0.1:8000
```

### Docker 生产环境

```bash
# 配置环境变量
mkdir -p .envs
cat > .envs/.production << EOF
DJANGO_SECRET_KEY=your-secure-key-here
EOF

# 构建并启动
docker compose -f production.yml up -d

# 创建管理员
docker exec -it rance-blog uv run python manage.py createsuperuser

# 访问 http://localhost
```

## 项目结构

```
rance-blog/
├── blog/                   # 博客应用
│   ├── feeds.py            # RSS 订阅
│   ├── models.py           # 数据模型（Post、Category、Tag）
│   ├── views.py            # 视图（IndexView、PostDetailView 等）
│   ├── urls.py             # URL 路由
│   ├── templatetags/       # 自定义模板标签
│   ├── search_indexes.py   # Haystack 搜索索引
│   ├── elasticsearch2_ik_backend.py  # 自定义 ES 后端
│   ├── utils.py            # 搜索高亮器
│   └── tests/              # 单元测试
├── comments/               # 评论应用
│   ├── models.py           # Comment 模型
│   ├── forms.py            # 评论表单
│   ├── views.py            # 评论提交视图
│   └── tests/              # 单元测试
├── config/                 # Django 配置
│   ├── settings/
│   │   ├── common.py       # 公共配置
│   │   ├── local.py        # 开发配置
│   │   └── production.py   # 生产配置
│   ├── urls.py             # 根路由
│   └── wsgi.py             # WSGI 入口
├── templates/              # 模板
│   ├── base.html           # 基础模板
│   ├── blog/               # 博客模板
│   ├── comments/           # 评论模板
│   └── search/             # 搜索模板
├── compose/                # Docker 编排
│   ├── local/              # 本地开发 Dockerfile
│   └── production/         # 生产环境 Dockerfile（Django + Nginx + ES）
├── scripts/
│   └── fake.py             # 测试数据生成脚本
├── doc/                    # 项目文档
├── local.yml               # Docker Compose（开发）
├── production.yml          # Docker Compose（生产）
├── deploy_rocky.sh         # Rocky Linux 部署脚本
└── pyproject.toml          # 项目依赖
```

## 常用命令

```bash
# 运行测试
uv run python manage.py test

# 生成覆盖率报告
uv run coverage run --source=blog,comments manage.py test
uv run coverage html && open htmlcov/index.html

# 生成测试数据（200 篇文章 + 评论）
uv run python scripts/fake.py

# 重建搜索索引
uv run python manage.py rebuild_index --noinput
```

## API 路由

| 路径 | 说明 |
|------|------|
| `/` | 博客首页 |
| `/post/<pk>/` | 文章详情 |
| `/category/<pk>/` | 分类筛选 |
| `/tag/<pk>/` | 标签筛选 |
| `/archives/<year>/<month>/` | 按年月归档 |
| `/search/?q=` | 全文搜索 |
| `/all/rss/` | RSS 订阅 |
| `/admin/` | 管理后台 |

## 文档

详见 [doc/](doc/) 目录：
- **项目开发计划** — 里程碑与进度
- **技术选型方案** — 技术决策记录
- **架构设计文档** — 系统架构
- **项目接口文档** — API 路由与视图
- **项目数据库表设计** — 数据模型
- **部署文档** — 部署指南
- **开发环境搭建指南** — 环境配置
- **阶段关键代码** — 开发过程中的代码变更记录
- **项目中遇到的问题解决** — Bug 与解决方案汇总

## License

MIT
