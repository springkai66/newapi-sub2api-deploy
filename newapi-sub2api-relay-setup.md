# NewAPI + Sub2API 中转站完整实操方案

> 适用场景：合法授权的内部 AI API 网关、团队额度分发、多模型统一入口、Claude Code / Codex / Gemini 等 Coding Agent 工具接入。
>
> 不建议把个人订阅账号包装成公开商业中转服务。公开运营涉及上游 ToS、备案、实名、内容安全、日志留存、支付、税务和用户隐私等合规问题。

---

## 1. 总体架构

推荐组合方式：

```text
用户 Claude Code / Codex / Cherry Studio / OpenAI SDK
  ↓
https://api.example.com
  ↓
NewAPI：对外入口、用户、令牌、余额、渠道、价格倍率、日志
  ↓
Docker 内网 http://sub2api:8080
  ↓
Sub2API：上游账号池、订阅额度、OAuth/API Key、Claude Code/Codex/Gemini 调度
  ↓
Anthropic / OpenAI / Gemini / Azure / Bedrock / Vertex / 合法第三方上游
```

职责划分：

| 组件 | 作用 | 是否对外暴露 |
|---|---|---|
| NewAPI | 用户系统、API Key、计费、渠道、模型倍率、统一入口 | 是 |
| Sub2API | 上游账号池、订阅资源调度、Claude Code/Codex/Gemini 适配 | 建议否，或仅管理员 IP 可访问 |
| PostgreSQL | 持久化数据库 | 否 |
| Redis | 缓存、限流、队列状态 | 否 |
| Caddy | HTTPS 证书、反向代理、日志 | 是 |

推荐域名：

```text
api.example.com    -> NewAPI，对外服务
sub.example.com    -> Sub2API 管理后台，可选，建议仅管理员 IP 可访问
```

---

## 2. 服务器准备

最低配置：

```text
2C4G / 40GB SSD / Ubuntu 22.04 或 24.04
```

建议配置：

```text
4C8G / 80GB SSD / 新加坡、日本、美国西海岸等网络稳定地区
```

开放端口：

```text
80/tcp
443/tcp
```

不要对公网开放：

```text
3000 NewAPI 容器端口
8080 Sub2API 容器端口
5432 PostgreSQL
6379 Redis
```

---

## 3. 安装 Docker

```bash
sudo apt update
sudo apt install -y ca-certificates curl gnupg git openssl
curl -fsSL https://get.docker.com | sudo bash
sudo systemctl enable docker
sudo systemctl start docker

docker version
docker compose version
```

如果当前用户需要免 sudo 使用 Docker：

```bash
sudo usermod -aG docker $USER
newgrp docker
```

---

## 4. 创建目录结构

```bash
sudo mkdir -p /opt/ai-gateway
sudo chown -R $USER:$USER /opt/ai-gateway
cd /opt/ai-gateway

mkdir -p newapi/data newapi/logs sub2api/data caddy/logs initdb
```

最终结构：

```text
/opt/ai-gateway/
  docker-compose.yml
  .env
  caddy/
    Caddyfile
    logs/
  initdb/
    01-init.sql
  newapi/
    data/
    logs/
  sub2api/
    data/
```

---

## 5. 生成密钥

执行 4 次：

```bash
openssl rand -hex 32
openssl rand -hex 32
openssl rand -hex 32
openssl rand -hex 32
```

分别用于：

```text
NEWAPI_SESSION_SECRET
NEWAPI_CRYPTO_SECRET
SUB2API_JWT_SECRET
SUB2API_TOTP_KEY
```

再准备两个强密码：

```text
POSTGRES_PASSWORD
REDIS_PASSWORD
```

建议只用大小写字母、数字、下划线，避免 Docker Compose 或 SQL 初始化时出现转义问题。

---

## 6. 编写 .env

创建文件：

```bash
nano /opt/ai-gateway/.env
```

内容模板：

```env
POSTGRES_PASSWORD=ChangeThisPostgresPassword_2026
REDIS_PASSWORD=ChangeThisRedisPassword_2026

NEWAPI_SESSION_SECRET=替换为openssl生成的随机值
NEWAPI_CRYPTO_SECRET=替换为openssl生成的随机值

SUB2API_ADMIN_EMAIL=admin@example.com
SUB2API_ADMIN_PASSWORD=ChangeThisAdminPassword_2026
SUB2API_JWT_SECRET=替换为openssl生成的随机值
SUB2API_TOTP_KEY=替换为openssl生成的随机值

DOMAIN_API=api.example.com
DOMAIN_SUB=sub.example.com

TZ=Asia/Shanghai
```

注意：

1. `DOMAIN_API` 和 `DOMAIN_SUB` 只作为记录，Caddyfile 里仍然要写真实域名。
2. `SUB2API_ADMIN_PASSWORD` 必须足够强。
3. 生产环境不要把 `.env` 提交到 Git。

---

## 7. 初始化 PostgreSQL 多数据库

创建初始化脚本：

```bash
nano /opt/ai-gateway/initdb/01-init.sql
```

内容：

```sql
CREATE USER newapi WITH PASSWORD 'ChangeThisPostgresPassword_2026';
CREATE DATABASE newapi OWNER newapi;

CREATE USER sub2api WITH PASSWORD 'ChangeThisPostgresPassword_2026';
CREATE DATABASE sub2api OWNER sub2api;

GRANT ALL PRIVILEGES ON DATABASE newapi TO newapi;
GRANT ALL PRIVILEGES ON DATABASE sub2api TO sub2api;
```

把 `ChangeThisPostgresPassword_2026` 改成 `.env` 里的 `POSTGRES_PASSWORD`。

说明：

- 这个初始化脚本只会在 PostgreSQL 数据目录第一次创建时执行。
- 如果你已经启动过 PostgreSQL，再改这个文件不会自动生效。需要手动进库创建，或删除数据卷重建。
- 生产环境谨慎删除数据卷，会清空数据库。

---

## 8. 编写 docker-compose.yml

创建文件：

```bash
nano /opt/ai-gateway/docker-compose.yml
```

内容：

```yaml
services:
  caddy:
    image: caddy:2
    container_name: ai-caddy
    restart: always
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./caddy/Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy_data:/data
      - caddy_config:/config
      - ./caddy/logs:/var/log/caddy
    depends_on:
      - new-api
      - sub2api
    networks:
      - ai-net

  new-api:
    image: calciumion/new-api:latest
    container_name: new-api
    restart: always
    command: --log-dir /app/logs
    volumes:
      - ./newapi/data:/data
      - ./newapi/logs:/app/logs
    environment:
      - TZ=${TZ}
      - SQL_DSN=postgresql://newapi:${POSTGRES_PASSWORD}@postgres:5432/newapi
      - REDIS_CONN_STRING=redis://:${REDIS_PASSWORD}@redis:6379/0
      - SESSION_SECRET=${NEWAPI_SESSION_SECRET}
      - CRYPTO_SECRET=${NEWAPI_CRYPTO_SECRET}
      - ERROR_LOG_ENABLED=true
      - BATCH_UPDATE_ENABLED=true
      - STREAMING_TIMEOUT=600
      - RELAY_TIMEOUT=0
      - NODE_NAME=new-api-1
    depends_on:
      - postgres
      - redis
    networks:
      - ai-net

  sub2api:
    image: weishaw/sub2api:latest
    container_name: sub2api
    restart: always
    ulimits:
      nofile:
        soft: 100000
        hard: 100000
    volumes:
      - ./sub2api/data:/app/data
    environment:
      - AUTO_SETUP=true
      - SERVER_HOST=0.0.0.0
      - SERVER_PORT=8080
      - SERVER_MODE=release
      - RUN_MODE=standard
      - TZ=${TZ}

      - DATABASE_HOST=postgres
      - DATABASE_PORT=5432
      - DATABASE_USER=sub2api
      - DATABASE_PASSWORD=${POSTGRES_PASSWORD}
      - DATABASE_DBNAME=sub2api
      - DATABASE_SSLMODE=disable
      - DATABASE_MAX_OPEN_CONNS=100
      - DATABASE_MAX_IDLE_CONNS=30

      - REDIS_HOST=redis
      - REDIS_PORT=6379
      - REDIS_PASSWORD=${REDIS_PASSWORD}
      - REDIS_DB=1
      - REDIS_POOL_SIZE=1024
      - REDIS_MIN_IDLE_CONNS=10
      - REDIS_ENABLE_TLS=false

      - ADMIN_EMAIL=${SUB2API_ADMIN_EMAIL}
      - ADMIN_PASSWORD=${SUB2API_ADMIN_PASSWORD}
      - JWT_SECRET=${SUB2API_JWT_SECRET}
      - TOTP_ENCRYPTION_KEY=${SUB2API_TOTP_KEY}

      - SERVER_MAX_REQUEST_BODY_SIZE=268435456
      - GATEWAY_MAX_BODY_SIZE=268435456
      - SERVER_H2C_ENABLED=true
      - SERVER_H2C_MAX_CONCURRENT_STREAMS=50
    depends_on:
      - postgres
      - redis
    networks:
      - ai-net

  postgres:
    image: postgres:15
    container_name: ai-postgres
    restart: always
    environment:
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - POSTGRES_USER=postgres
      - TZ=${TZ}
    volumes:
      - pg_data:/var/lib/postgresql/data
      - ./initdb:/docker-entrypoint-initdb.d:ro
    networks:
      - ai-net

  redis:
    image: redis:7
    container_name: ai-redis
    restart: always
    command: ["redis-server", "--requirepass", "${REDIS_PASSWORD}", "--appendonly", "yes", "--maxclients", "10000"]
    volumes:
      - redis_data:/data
    networks:
      - ai-net

networks:
  ai-net:
    driver: bridge

volumes:
  pg_data:
  redis_data:
  caddy_data:
  caddy_config:
```

---

## 9. 编写 Caddyfile

创建文件：

```bash
nano /opt/ai-gateway/caddy/Caddyfile
```

基础版本：

```caddyfile
api.example.com {
    encode zstd gzip

    reverse_proxy new-api:3000 {
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        header_up X-Forwarded-Proto {scheme}
        header_up X-Forwarded-Host {host}

        transport http {
            keepalive 120s
            keepalive_idle_conns 256
            compression off
        }
    }

    request_body {
        max_size 256MB
    }

    log {
        output file /var/log/caddy/newapi.log {
            roll_size 100mb
            roll_keep 10
            roll_keep_for 720h
        }
        format json
    }
}

sub.example.com {
    encode zstd gzip

    reverse_proxy sub2api:8080 {
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        header_up X-Forwarded-Proto {scheme}
        header_up X-Forwarded-Host {host}

        transport http {
            keepalive 120s
            keepalive_idle_conns 256
            compression off
        }
    }

    request_body {
        max_size 256MB
    }

    log {
        output file /var/log/caddy/sub2api.log {
            roll_size 100mb
            roll_keep 10
            roll_keep_for 720h
        }
        format json
    }
}
```

把 `api.example.com` 和 `sub.example.com` 改成你的真实域名。

### 9.1 更安全的 Sub2API 后台限制版本

如果 Sub2API 后台只允许你的固定公网 IP 访问，用这个替换 `sub.example.com` 段：

```caddyfile
sub.example.com {
    @not_allowed not remote_ip 你的公网IP
    respond @not_allowed "Forbidden" 403

    encode zstd gzip

    reverse_proxy sub2api:8080 {
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        header_up X-Forwarded-Proto {scheme}
        header_up X-Forwarded-Host {host}

        transport http {
            keepalive 120s
            keepalive_idle_conns 256
            compression off
        }
    }

    request_body {
        max_size 256MB
    }
}
```

如果你完全不想暴露 Sub2API，就删除 `sub.example.com` 这一整段。NewAPI 仍然可以通过 Docker 内网访问：

```text
http://sub2api:8080
```

---

## 10. DNS 配置

在域名解析商处添加：

```text
A    api.example.com    你的服务器公网 IP
A    sub.example.com    你的服务器公网 IP
```

如果不用 Sub2API 公网后台，只添加：

```text
A    api.example.com    你的服务器公网 IP
```

等待 DNS 生效后检查：

```bash
ping api.example.com
ping sub.example.com
```

---

## 11. 启动服务

```bash
cd /opt/ai-gateway

docker compose pull
docker compose up -d

docker compose ps
```

看日志：

```bash
docker compose logs -f caddy
docker compose logs -f new-api
docker compose logs -f sub2api
docker compose logs -f postgres
docker compose logs -f redis
```

访问：

```text
https://api.example.com
https://sub.example.com
```

---

## 12. 初始化 NewAPI

打开：

```text
https://api.example.com
```

首次进入后完成：

1. 创建或登录管理员账号。
2. 立刻修改管理员密码。
3. 关闭开放注册，除非你明确要对外开放。
4. 设置站点名称和前端地址。
5. 创建用户分组：
   - `default`
   - `vip`
   - `internal`
6. 设置模型倍率和计费规则。
7. 创建测试用户和测试令牌。

NewAPI 后台主要会用到：

```text
渠道管理
令牌管理
用户管理
日志
系统设置
模型倍率 / 分组倍率
```

---

## 13. 初始化 Sub2API

打开：

```text
https://sub.example.com
```

登录：

```text
邮箱：.env 中的 SUB2API_ADMIN_EMAIL
密码：.env 中的 SUB2API_ADMIN_PASSWORD
```

后台完成：

1. 修改管理员资料。
2. 添加上游账号。
3. 配置产品、模型、价格、限流。
4. 创建一个专门给 NewAPI 调用的内部用户，例如 `newapi-upstream`。
5. 给该用户创建 API Key，例如：

```text
sk-sub2api-xxxxxxxx
```

建议限制：

```text
用户并发：按你的上游账号池能力设置
单账号并发：保守设置，避免被上游风控
每日额度：先小后大
模型权限：只开放你确认可用的模型
```

---

## 14. Sub2API 配置上游账号

根据你合法拥有的资源添加上游，例如：

1. Anthropic API Key
2. OpenAI API Key
3. Gemini API Key
4. Azure OpenAI
5. AWS Bedrock
6. Google Vertex
7. Claude Code / Codex / Gemini CLI 订阅类 OAuth 账号
8. 其他兼容服务

注意：

- 商业公开服务不要依赖个人订阅账号池，风险很高。
- 订阅类账号更适合内部团队共享或测试。
- 对外收费应优先使用正式 API、企业协议或合法授权渠道。

---

## 15. 测试 Sub2API

### 15.1 测试 OpenAI 兼容 models

```bash
curl https://sub.example.com/v1/models \
  -H "Authorization: Bearer sk-sub2api-xxxxxxxx"
```

如果 Sub2API 不暴露公网，可以在服务器内部测试：

```bash
docker run --rm --network ai-gateway_ai-net curlimages/curl:latest \
  http://sub2api:8080/v1/models \
  -H "Authorization: Bearer sk-sub2api-xxxxxxxx"
```

实际 Docker Compose 网络名可能不同，可用下面命令查看：

```bash
docker network ls
```

### 15.2 测试 OpenAI Chat Completions

```bash
curl https://sub.example.com/v1/chat/completions \
  -H "Authorization: Bearer sk-sub2api-xxxxxxxx" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-4.1",
    "messages": [
      {"role": "user", "content": "say hi"}
    ],
    "stream": false
  }'
```

### 15.3 测试 Claude Messages

```bash
curl https://sub.example.com/v1/messages \
  -H "x-api-key: sk-sub2api-xxxxxxxx" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d '{
    "model": "claude-sonnet-4-5",
    "max_tokens": 100,
    "messages": [
      {"role": "user", "content": "say hi"}
    ]
  }'
```

### 15.4 测试流式响应

```bash
curl -N https://sub.example.com/v1/chat/completions \
  -H "Authorization: Bearer sk-sub2api-xxxxxxxx" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-4.1",
    "messages": [
      {"role": "user", "content": "从1数到10"}
    ],
    "stream": true
  }'
```

如果流式卡住，优先检查：

```text
Caddy 反代是否正常
Sub2API 日志是否有超时
上游账号是否可用
模型名是否正确
```

---

## 16. NewAPI 接入 Sub2API 作为上游渠道

进入 NewAPI 后台：

```text
渠道管理 -> 添加渠道
```

### 16.1 OpenAI 兼容渠道

适合：Codex、OpenAI SDK、Chat Completions、Responses 类接口。

配置示例：

```text
渠道类型：OpenAI / OpenAI Compatible
渠道名称：Sub2API-OpenAI
Base URL：http://sub2api:8080
API Key：sk-sub2api-xxxxxxxx
模型：gpt-4.1,gpt-4.1-mini,gpt-5,gpt-5-mini,codex-mini-latest
分组：default,vip,internal
权重：100
状态：启用
```

如果 NewAPI 要通过公网访问 Sub2API：

```text
Base URL：https://sub.example.com
```

但更推荐 Docker 内网：

```text
Base URL：http://sub2api:8080
```

### 16.2 Claude Messages 渠道

适合：Claude Code、Anthropic SDK、Claude Messages API。

配置示例：

```text
渠道类型：Claude / Anthropic / Claude Messages
渠道名称：Sub2API-Claude
Base URL：http://sub2api:8080
API Key：sk-sub2api-xxxxxxxx
模型：claude-sonnet-4-5,claude-opus-4-1,claude-haiku-4-5
分组：default,vip,internal
权重：100
状态：启用
```

注意：

- 模型名必须和 Sub2API 侧可用模型一致。
- Claude Code 对 `tool_use`、streaming event、beta header、长上下文很敏感，必须实际跑 Claude Code 验证。

---

## 17. 在 NewAPI 创建用户令牌

NewAPI 后台：

```text
用户管理 -> 创建用户
令牌管理 -> 给用户创建令牌
```

建议：

```text
普通用户：只开放必要模型
内部测试用户：开放全部测试模型
单 token 限额：先小后大
过期时间：按套餐设置
IP 白名单：企业用户可开启
```

拿到 NewAPI 发出的用户 key，例如：

```text
sk-newapi-user-xxxxxxxx
```

---

## 18. 测试 NewAPI 对外接口

### 18.1 OpenAI Chat Completions

```bash
curl https://api.example.com/v1/chat/completions \
  -H "Authorization: Bearer sk-newapi-user-xxxxxxxx" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-4.1",
    "messages": [
      {"role": "user", "content": "say hi"}
    ],
    "stream": false
  }'
```

### 18.2 OpenAI 流式

```bash
curl -N https://api.example.com/v1/chat/completions \
  -H "Authorization: Bearer sk-newapi-user-xxxxxxxx" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-4.1",
    "messages": [
      {"role": "user", "content": "从1数到10"}
    ],
    "stream": true
  }'
```

### 18.3 Claude Messages

```bash
curl https://api.example.com/v1/messages \
  -H "x-api-key: sk-newapi-user-xxxxxxxx" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d '{
    "model": "claude-sonnet-4-5",
    "max_tokens": 100,
    "messages": [
      {"role": "user", "content": "say hi"}
    ]
  }'
```

如果 Claude Messages 不通，但 OpenAI Chat 通，说明 NewAPI 渠道类型、模型映射或 Sub2API Claude 侧配置有问题。

---

## 19. Claude Code 客户端接入

用户本机设置：

```bash
export ANTHROPIC_BASE_URL=https://api.example.com
export ANTHROPIC_API_KEY=sk-newapi-user-xxxxxxxx
claude
```

或者一次性运行：

```bash
ANTHROPIC_BASE_URL=https://api.example.com \
ANTHROPIC_API_KEY=sk-newapi-user-xxxxxxxx \
claude
```

测试：

```bash
claude -p "用一句话介绍你自己" --max-turns 1
```

如果 Claude Code 报错，重点检查：

```text
/v1/messages 是否可用
anthropic-version header 是否正确传递
模型名是否在 NewAPI 和 Sub2API 两边都配置
流式事件是否被代理正确转发
Sub2API 上游账号是否支持对应 Claude 模型
```

---

## 20. Codex 客户端接入

用户本机设置：

```bash
export OPENAI_BASE_URL=https://api.example.com/v1
export OPENAI_API_KEY=sk-newapi-user-xxxxxxxx
codex
```

或执行任务：

```bash
OPENAI_BASE_URL=https://api.example.com/v1 \
OPENAI_API_KEY=sk-newapi-user-xxxxxxxx \
codex exec "用一句话介绍你自己"
```

Codex 可能依赖 OpenAI Responses API。如果 Chat Completions 可用但 Codex 不可用，检查：

```text
NewAPI 是否支持 /v1/responses
Sub2API 是否支持 /v1/responses
模型是否支持 Codex CLI 当前需要的字段
是否发生工具调用字段转换错误
```

---

## 21. Cherry Studio / OpenAI SDK 接入

OpenAI Compatible：

```text
Base URL: https://api.example.com/v1
API Key: sk-newapi-user-xxxxxxxx
Model: gpt-4.1 或你在 NewAPI 配置的模型名
```

Anthropic Compatible：

```text
Base URL: https://api.example.com
API Key: sk-newapi-user-xxxxxxxx
Model: claude-sonnet-4-5
```

---

## 22. 生产环境必要配置

### 22.1 NewAPI 安全项

建议：

```text
关闭开放注册
管理员启用强密码
只给用户开放需要的模型
分组限流
用户余额限制
令牌过期时间
日志保留策略
错误日志开启
```

### 22.2 Sub2API 安全项

建议：

```text
不要公开 Sub2API，或只允许管理员 IP
NewAPI 专用 API Key 单独创建
上游账号设置并发上限
高价值账号单独分组
开启异常账号自动熔断
限制每用户并发和每日额度
```

### 22.3 Caddy / 网络

建议：

```text
只开放 80/443
不要映射 PostgreSQL 和 Redis 到公网
Caddy request_body 设置 256MB
开启日志轮转
使用 Cloudflare 时注意真实 IP 头
```

### 22.4 服务器防火墙

Ubuntu UFW 示例：

```bash
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
sudo ufw status
```

---

## 23. 监控和排障命令

查看容器：

```bash
docker compose ps
```

查看日志：

```bash
docker compose logs -f new-api
docker compose logs -f sub2api
docker compose logs -f caddy
```

重启单个服务：

```bash
docker compose restart new-api
docker compose restart sub2api
docker compose restart caddy
```

更新镜像：

```bash
cd /opt/ai-gateway
docker compose pull
docker compose up -d
```

查看资源：

```bash
docker stats
```

查看磁盘：

```bash
df -h
du -sh /opt/ai-gateway/*
```

---

## 24. 备份和恢复

### 24.1 备份 PostgreSQL

```bash
mkdir -p /opt/ai-gateway/backups

docker exec ai-postgres pg_dump -U postgres newapi > /opt/ai-gateway/backups/newapi_$(date +%F).sql
docker exec ai-postgres pg_dump -U postgres sub2api > /opt/ai-gateway/backups/sub2api_$(date +%F).sql
```

### 24.2 备份数据目录

```bash
tar czf /opt/ai-gateway/backups/files_$(date +%F).tar.gz \
  /opt/ai-gateway/.env \
  /opt/ai-gateway/docker-compose.yml \
  /opt/ai-gateway/caddy \
  /opt/ai-gateway/newapi \
  /opt/ai-gateway/sub2api \
  /opt/ai-gateway/initdb
```

### 24.3 恢复数据库

谨慎操作，恢复前先停服务或确认无写入：

```bash
docker compose stop new-api sub2api

docker exec -i ai-postgres psql -U postgres newapi < /opt/ai-gateway/backups/newapi_YYYY-MM-DD.sql
docker exec -i ai-postgres psql -U postgres sub2api < /opt/ai-gateway/backups/sub2api_YYYY-MM-DD.sql

docker compose start new-api sub2api
```

---

## 25. 常见问题

### 25.1 Caddy 证书申请失败

检查：

```text
DNS 是否解析到服务器
80/443 是否开放
服务器是否被 Cloudflare 代理干扰
Caddy 日志是否有 ACME 报错
```

命令：

```bash
docker compose logs -f caddy
```

### 25.2 NewAPI 无法连接数据库

检查：

```text
POSTGRES_PASSWORD 是否一致
initdb 是否成功创建 newapi 用户和数据库
PostgreSQL 是否首次启动后才修改过 initdb 脚本
```

命令：

```bash
docker compose logs -f postgres
docker compose logs -f new-api
```

### 25.3 Sub2API 后台登录失败

检查：

```text
AUTO_SETUP 是否为 true
ADMIN_EMAIL / ADMIN_PASSWORD 是否正确
JWT_SECRET 是否固定
Sub2API 日志是否显示初始化成功
```

### 25.4 Claude Code 卡住或 stream disconnected

重点检查：

```text
Claude Messages API 是否通
流式 SSE 是否通
Caddy 是否中断长连接
STREAMING_TIMEOUT 是否过短
Sub2API 上游账号是否 429/封禁/额度不足
模型名是否真实存在
```

建议 NewAPI：

```text
STREAMING_TIMEOUT=600
RELAY_TIMEOUT=0
```

### 25.5 Codex 能聊天但不能执行

可能原因：

```text
Codex CLI 使用 /v1/responses，而链路只支持 /v1/chat/completions
工具调用字段不兼容
模型名不支持 Codex agent 场景
NewAPI 到 Sub2API 的渠道类型选错
```

排查：

```bash
curl https://api.example.com/v1/models \
  -H "Authorization: Bearer sk-newapi-user-xxxxxxxx"

curl https://api.example.com/v1/responses \
  -H "Authorization: Bearer sk-newapi-user-xxxxxxxx" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-4.1",
    "input": "say hi"
  }'
```

### 25.6 用户说扣费但没返回

必须查三层日志：

```text
NewAPI 用户日志：是否扣费、请求 ID、返回状态
Sub2API 调度日志：是否转发成功、用哪个账号、上游错误
Caddy 日志：客户端是否提前断开、是否 499/502/504
```

运营建议：

```text
对失败请求做自动补偿策略
保留请求 ID 给客服查询
设置上游失败不扣费或部分扣费规则
```

---

## 26. 上线前检查清单

上线前逐项确认：

```text
[ ] DNS 已解析到服务器
[ ] 80/443 可访问
[ ] Caddy 自动签发 HTTPS 成功
[ ] NewAPI 可登录
[ ] Sub2API 可登录，或已限制管理员 IP
[ ] PostgreSQL 未暴露公网
[ ] Redis 未暴露公网
[ ] NewAPI 开放注册已关闭或已有风控
[ ] NewAPI 创建了测试用户和测试 token
[ ] Sub2API 创建了 NewAPI 专用上游 token
[ ] Sub2API 上游账号测试通过
[ ] NewAPI OpenAI Chat 测试通过
[ ] NewAPI OpenAI stream 测试通过
[ ] NewAPI Claude Messages 测试通过
[ ] Claude Code 实机测试通过
[ ] Codex 实机测试通过
[ ] 日志路径正常写入
[ ] 备份脚本已测试
[ ] 设置了用户额度和并发限制
[ ] 明确了失败请求补偿规则
```

---

## 27. 推荐运营策略

如果只是内部团队：

```text
NewAPI 开 3 个分组：default / vip / internal
每人独立 token
Sub2API 账号池按模型和供应商拆分
每周检查错误率和账号健康
```

如果准备商业化：

```text
不要先做公开大规模售卖
先灰度 10-30 个真实用户
指标看：请求成功率、首 token 延迟、平均成本、毛利、退款率、客服工单量
成功率低于 97% 不建议扩大
没有自动补偿和客服后台不建议收大量用户
```

关键指标：

```text
请求成功率
流式中断率
上游 429/529 比例
用户平均成本
单模型毛利
Claude Code / Codex 实际完成率
客服工单率
退款率
```

---

## 28. 结论

NewAPI + Sub2API 的可行落地方式是：

```text
NewAPI 对外做商业和用户层；
Sub2API 对内做上游账号池和 Coding Agent 资源调度；
用户永远只拿 NewAPI 的 key；
Sub2API 尽量不直接暴露公网。
```

这套组合能快速上线，但真正难点不在部署，而在：

```text
上游资源合法性
Claude Code / Codex 协议兼容
流式稳定性
账号池风控
计费争议处理
失败补偿
客服和日志追踪
```

先做内部可用，再灰度小规模用户，最后再考虑公开运营。
