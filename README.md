# NewAPI + Sub2API 一键部署

这是一个面向小白的 NewAPI + Sub2API 中转站部署项目。

目标：用一条命令在 Ubuntu 服务器上部署：

- Caddy：HTTPS 反向代理
- NewAPI：对外 API 入口、用户、令牌、余额、渠道、倍率、日志
- Sub2API：上游账号池、订阅额度、Claude Code / Codex / Gemini 等资源调度
- PostgreSQL：数据库
- Redis：缓存和限流相关状态

> 适用场景：合法授权的内部 AI API 网关、团队额度分发、多模型统一入口、Claude Code / Codex / Gemini 等 Coding Agent 工具接入。
>
> 不建议把个人订阅账号包装成公开商业中转服务。公开运营涉及上游 ToS、备案、实名、内容安全、日志留存、支付、税务和用户隐私等合规问题。

---

## 1. 你需要先准备什么

在执行部署命令前，请先准备：

1. 一台 Ubuntu 22.04 / 24.04 服务器
2. 一个域名
3. 已经把域名解析到服务器 IP
4. 服务器 80/443 端口已开放
5. 合法可用的上游 API Key 或账号资源

推荐服务器配置：

```text
最低：2C4G / 40GB SSD
推荐：4C8G / 80GB SSD
系统：Ubuntu 22.04 或 24.04
地区：新加坡、日本、美国西海岸等网络稳定地区
```

推荐域名：

```text
api.example.com    NewAPI，对外使用
sub.example.com    Sub2API 后台，可选，建议限制管理员 IP
```

---

## 2. 快速安装

在服务器上执行：

```bash
curl -fsSL https://raw.githubusercontent.com/springkai66/newapi-sub2api-deploy/main/deploy-newapi-sub2api.sh -o /tmp/deploy-newapi-sub2api.sh \
  && chmod +x /tmp/deploy-newapi-sub2api.sh \
  && sudo bash /tmp/deploy-newapi-sub2api.sh
```

如果你本来就是 root 用户，也可以执行：

```bash
curl -fsSL https://raw.githubusercontent.com/springkai66/newapi-sub2api-deploy/main/deploy-newapi-sub2api.sh -o /tmp/deploy-newapi-sub2api.sh \
  && chmod +x /tmp/deploy-newapi-sub2api.sh \
  && bash /tmp/deploy-newapi-sub2api.sh
```

---

## 3. 更安全的安装方式

如果你想先看脚本内容，再执行：

```bash
curl -fsSL https://raw.githubusercontent.com/springkai66/newapi-sub2api-deploy/main/deploy-newapi-sub2api.sh -o deploy-newapi-sub2api.sh
less deploy-newapi-sub2api.sh
sudo bash deploy-newapi-sub2api.sh
```

或 root 用户：

```bash
curl -fsSL https://raw.githubusercontent.com/springkai66/newapi-sub2api-deploy/main/deploy-newapi-sub2api.sh -o deploy-newapi-sub2api.sh
less deploy-newapi-sub2api.sh
bash deploy-newapi-sub2api.sh
```

---

## 4. 为什么不用 curl | bash

本项目部署脚本是交互式脚本，会询问：

- NewAPI 域名
- 是否暴露 Sub2API 后台
- Sub2API 域名
- 是否限制管理员 IP
- 数据库密码
- Redis 密码
- Sub2API 管理员邮箱和密码

所以不推荐：

```bash
curl -fsSL https://xxx/install.sh | bash
```

原因是 `curl | bash` 对交互式 `read` 不够稳定。

推荐方式是：

```bash
curl -o /tmp/deploy.sh URL && bash /tmp/deploy.sh
```

---

## 5. 脚本会安装什么

脚本会在服务器上创建：

```text
/opt/ai-gateway
```

并生成：

```text
/opt/ai-gateway/.env
/opt/ai-gateway/docker-compose.yml
/opt/ai-gateway/caddy/Caddyfile
/opt/ai-gateway/initdb/01-init.sql
/opt/ai-gateway/backup.sh
```

启动的容器：

```text
ai-caddy
new-api
sub2api
ai-postgres
ai-redis
```

---

## 6. 部署时怎么填写

脚本会一步步提示你填写。

### 6.1 NewAPI 域名

只填域名，不要带 `https://`。

正确：

```text
api.example.com
```

错误：

```text
https://api.example.com
```

### 6.2 是否暴露 Sub2API 后台

小白建议先选择：

```text
y
```

因为你需要进入后台配置上游账号。

但强烈建议后续选择“限制管理员 IP 访问”。

### 6.3 是否限制 Sub2API 后台管理员 IP

建议直接回车，使用默认 `Y`。

你可以通过下面网站查看自己的公网 IP：

```text
https://ip.sb
https://ifconfig.me
```

### 6.4 数据库和 Redis 密码

小白建议直接回车，让脚本自动生成。

脚本会把结果写入：

```text
/opt/ai-gateway/.env
```

---

## 7. 部署完成后必须手动做什么

脚本只负责把基础服务跑起来。下面这些必须人工完成。

### 7.1 登录 NewAPI

访问：

```text
https://api.example.com
```

完成：

```text
[ ] 创建或登录管理员
[ ] 修改管理员密码
[ ] 关闭开放注册
[ ] 创建用户分组：default / vip / internal
[ ] 创建测试用户
[ ] 给测试用户创建 API Token
[ ] 配置模型倍率和额度
```

### 7.2 登录 Sub2API

访问：

```text
https://sub.example.com
```

完成：

```text
[ ] 登录管理员
[ ] 添加合法上游 API Key 或账号资源
[ ] 配置模型
[ ] 创建专门给 NewAPI 使用的 API Key
```

### 7.3 在 NewAPI 里添加 Sub2API 渠道

OpenAI / Codex 渠道：

```text
渠道类型：OpenAI / OpenAI Compatible
Base URL：http://sub2api:8080
API Key：Sub2API 给 NewAPI 的专用 key
模型：gpt-4.1,gpt-4.1-mini,codex-mini-latest 等
```

Claude / Claude Code 渠道：

```text
渠道类型：Claude / Anthropic / Claude Messages
Base URL：http://sub2api:8080
API Key：Sub2API 给 NewAPI 的专用 key
模型：claude-sonnet-4-5 等
```

注意：NewAPI 到 Sub2API 推荐使用 Docker 内网地址：

```text
http://sub2api:8080
```

不要优先使用公网 `https://sub.example.com`。

---

## 8. 测试命令

把下面的：

```text
api.example.com
sk-newapi-user-xxxx
```

替换成你的真实 NewAPI 域名和 NewAPI 用户 Token。

### 8.1 OpenAI Chat Completions

```bash
curl https://api.example.com/v1/chat/completions \
  -H "Authorization: Bearer sk-newapi-user-xxxx" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-4.1",
    "messages": [
      {"role": "user", "content": "say hi"}
    ],
    "stream": false
  }'
```

### 8.2 OpenAI 流式

```bash
curl -N https://api.example.com/v1/chat/completions \
  -H "Authorization: Bearer sk-newapi-user-xxxx" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-4.1",
    "messages": [
      {"role": "user", "content": "从1数到10"}
    ],
    "stream": true
  }'
```

### 8.3 Claude Messages

```bash
curl https://api.example.com/v1/messages \
  -H "x-api-key: sk-newapi-user-xxxx" \
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

---

## 9. Claude Code 接入

用户本机执行：

```bash
export ANTHROPIC_BASE_URL=https://api.example.com
export ANTHROPIC_API_KEY=sk-newapi-user-xxxx

claude -p "用一句话介绍你自己" --max-turns 1
```

---

## 10. Codex 接入

用户本机执行：

```bash
export OPENAI_BASE_URL=https://api.example.com/v1
export OPENAI_API_KEY=sk-newapi-user-xxxx

codex exec "用一句话介绍你自己"
```

---

## 11. Cloudflare 是否必须

不必须。

小白建议：

```text
第一阶段：不用 Cloudflare，先 DNS 直连，把服务跑通。
第二阶段：稳定后再考虑 Cloudflare。
```

如果用 Cloudflare：

```text
SSL/TLS 选择 Full (strict)
api.example.com 可以后续开橙色云
sub.example.com 如果用 Caddy 限 IP，建议 DNS only
关闭 Rocket Loader / Auto Minify 等网页优化功能
开 Cloudflare 后必须重新测试流式、Claude Code、Codex
```

---

## 12. 常用运维命令

进入部署目录：

```bash
cd /opt/ai-gateway
```

查看状态：

```bash
docker compose ps
```

查看日志：

```bash
docker compose logs -f caddy
docker compose logs -f new-api
docker compose logs -f sub2api
```

重启服务：

```bash
docker compose restart
```

更新镜像：

```bash
docker compose pull
docker compose up -d
```

手动备份：

```bash
bash /opt/ai-gateway/backup.sh
```

---

## 13. 文档索引

本仓库包含：

```text
deploy-newapi-sub2api.sh              一键部署脚本
newapi-sub2api-beginner-guide.md      小白完整操作手册
newapi-sub2api-manual-steps.md        部署后人工操作清单
newapi-sub2api-relay-setup.md         完整技术方案和实操方案
one-command-install-guide.md          如何发布成一条命令安装
```

建议阅读顺序：

```text
1. README.md
2. newapi-sub2api-beginner-guide.md
3. newapi-sub2api-manual-steps.md
4. newapi-sub2api-relay-setup.md
```

---

## 14. 最终检查清单

```text
[ ] DNS 已解析到服务器
[ ] 80/443 已开放
[ ] 脚本执行完成
[ ] docker compose ps 全部 Up
[ ] https://api.example.com 能打开
[ ] NewAPI 管理员已创建
[ ] NewAPI 已关闭开放注册
[ ] Sub2API 上游账号已添加
[ ] Sub2API 给 NewAPI 的专用 key 已创建
[ ] NewAPI 已添加 Sub2API 渠道
[ ] OpenAI curl 测试通过
[ ] Claude Messages curl 测试通过，若使用 Claude
[ ] 流式测试通过
[ ] Claude Code 实机测试通过，若使用 Claude Code
[ ] Codex 实机测试通过，若使用 Codex
[ ] backup.sh 手动备份成功
```

---

## 15. 遇到问题时提供这些信息

请提供：

```text
1. 卡在哪一步
2. 报错截图或完整错误文本
3. docker compose ps 输出
4. 相关日志，不要发真实 API Key
```

获取日志：

```bash
cd /opt/ai-gateway
docker compose ps
docker compose logs --tail=100 caddy
docker compose logs --tail=100 new-api
docker compose logs --tail=100 sub2api
```
