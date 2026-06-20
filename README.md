## 本地运行

### uv

1. **克隆项目到本地**

```
git clone https://github.com/gallantsa/rance-blog.git
```
   
2. **安装 uv（已安装跳过）**

```
pip install uv
```
   
3. **安装项目依赖**

```
cd rance-blog
uv sync
```

4. **迁移数据库**

在项目根目录运行如下命令迁移数据库：

```
uv run python manage.py migrate
```

5. **创建后台管理员账户**

在项目根目录运行如下命令创建后台管理员账户

```
uv run python manage.py createsuperuser
```

6. **运行开发服务器**

在项目根目录运行如下命令开启开发服务器：

```
uv run python manage.py runserver
```

在浏览器访问：http://127.0.0.1:8000

7. **进入后台发布文章**

在浏览器访问：http://127.0.0.1:8000/admin

使用第 5 步创建的后台管理员账户登录后台。

### Docker
