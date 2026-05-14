# NewAPI + Sub2API 小白一键部署手册

这份文档按“先下载一键部署脚本，再执行脚本”的方式写。你可以从上到下照着做，不需要先懂 Docker、Caddy、PostgreSQL、Redis。

重要提醒：

- 本项目只负责帮你部署 NewAPI + Sub2API 基础环境。
- 你还需要自己准备合法的上游 API Key 或账号资源，否则部署成功也不能真正调用模型。
- 不建议把个人订阅账号包装成公开商业中转服务。公开运营涉及上游服务条款、备案、实名、内容安全、日志留存、支付、税务和用户隐私等问题。

---

## 0. 最终会部署出什么

部署完成后，你会有：

```text
https://api.你的域名.com
```

这是 NewAPI，对外给用户、Claude Code、Codex、Cherry Studio、OpenAI SDK 使用。

可选：

```text
https://sub.你的域名.com
```

这是 Sub2API 管理后台，用来配置上游账号池。建议只允许你自己的 IP 访问，不要公开给普通用户。

整体链路：

```text
用户客户端 / Claude Code / Codex
  ↓
NewAPI：用户 key、额度、计费、渠道、日志
  ↓
Sub2API：上游账号池、订阅额度、账号调度
  ↓
OpenAI / Claude / Gemini / Azure / 其他合法上游
```

---

## 1. 开始前你需要准备

### 1.1 一台服务器

推荐：

```text
系统：Ubuntu 22.04 或 Ubuntu 24.04
最低配置：2 核 CPU / 4GB 内存 / 40GB 硬盘
推荐配置：4 核 CPU / 8GB 内存 / 80GB 硬盘
地区：新加坡、日本、美国西海岸等网络稳定地区
```

你需要知道：

```text
服务器公网 IP：____________________
SSH 用户名：root 或 ubuntu 或其他：____________________
SSH 密码或密钥：自己保存好
```

### 1.2 一个域名

例如你的主域名是：

```text
example.com
```

建议准备两个子域名：

```text
api.example.com    NewAPI 对外入口
sub.example.com    Sub2API 后台，可选
```

把你的实际域名写下来：

```text
NewAPI 域名：____________________
Sub2API 域名：____________________
```

注意：后面执行脚本时，只填域名，不要带 `https://`。

正确：

```text
api.example.com
```

错误：

```text
https://api.example.com
```

---

## 2. 设置域名解析

这一步在你的域名服务商后台操作，不是在服务器里操作。

### 2.1 添加 NewAPI 解析

添加一条 A 记录：

```text
类型：A
主机记录：api
记录值：你的服务器公网 IP
TTL：默认
```

例如：

```text
A    api    1.2.3.4
```

### 2.2 添加 Sub2API 解析，可选但推荐新手先加

添加一条 A 记录：

```text
类型：A
主机记录：sub
记录值：你的服务器公网 IP
TTL：默认
```

例如：

```text
A    sub    1.2.3.4
```

Sub2API 后台建议后面用脚本限制“只有你的公网 IP 能访问”。

### 2.3 检查解析是否生效

在你电脑的终端里执行：

```bash
ping api.example.com
```

把 `api.example.com` 换成你的真实域名。

如果返回的 IP 是你的服务器 IP，就说明生效了。如果没生效，等 5-30 分钟再试。

---

## 3. 登录服务器

Windows 用户打开 PowerShell；macOS 用户打开 Terminal。

如果服务器用户名是 root：

```bash
ssh root@你的服务器IP
```

如果服务器用户名是 ubuntu：

```bash
ssh ubuntu@你的服务器IP
```

第一次连接会问：

```text
Are you sure you want to continue connecting?
```

输入：

```text
yes
```

登录成功后，你会看到类似：

```text
root@xxx:~#
```

或：

```text
ubuntu@xxx:~$
```

---

## 4. 一键下载并执行部署脚本

登录服务器后，复制下面整段命令执行：

```bash
curl -fsSL https://raw.githubusercontent.com/springkai66/newapi-sub2api-deploy/master/deploy-newapi-sub2api.sh -o /tmp/deploy-newapi-sub2api.sh \
  && chmod +x /tmp/deploy-newapi-sub2api.sh \
  && sudo bash /tmp/deploy-newapi-sub2api.sh
```

如果你当前就是 root 用户，也可以执行：

```bash
curl -fsSL https://raw.githubusercontent.com/springkai66/newapi-sub2api-deploy/master/deploy-newapi-sub2api.sh -o /tmp/deploy-newapi-sub2api.sh \
  && chmod +x /tmp/deploy-newapi-sub2api.sh \
  && bash /tmp/deploy-newapi-sub2api.sh
```

### 4.1 更安全的方式：先看脚本再执行

如果你想先检查脚本内容：

```bash
curl -fsSL https://raw.githubusercontent.com/springkai66/newapi-sub2api-deploy/master/deploy-newapi-sub2api.sh -o deploy-newapi-sub2api.sh
less deploy-newapi-sub2api.sh
sudo bash deploy-newapi-sub2api.sh
```

root 用户：

```bash
curl -fsSL https://raw.githubusercontent.com/springkai66/newapi-sub2api-deploy/master/deploy-newapi-sub2api.sh -o deploy-newapi-sub2api.sh
less deploy-newapi-sub2api.sh
bash deploy-newapi-sub2api.sh
```

### 4.2 为什么不用 curl | bash

不要用：

```bash
curl -fsSL https://raw.githubusercontent.com/springkai66/newapi-sub2api-deploy/master/deploy-newapi-sub2api.sh | bash
```

原因：这个部署脚本会问你域名、密码、管理员 IP 等问题，是交互式脚本。`curl | bash` 对交互输入不稳定。

推荐方式就是先下载：

```bash
curl -o /tmp/deploy.sh URL
```

再执行：

```bash
bash /tmp/deploy.sh
```

---

## 5. 脚本运行时每一步怎么填

### 5.1 NewAPI 域名

提示：

```text
请输入 NewAPI 对外域名，例如 api.example.com:
```

你填：

```text
api.你的域名.com
```

例如：

```text
api.example.com
```

不要带 `https://`。

### 5.2 是否暴露 Sub2API 后台

提示：

```text
是否暴露 Sub2API 管理后台域名？不建议公开暴露。[y/N]:
```

新手建议填：

```text
y
```

因为你后面需要进后台配置上游账号。

### 5.3 Sub2API 域名

提示：

```text
请输入 Sub2API 管理后台域名，例如 sub.example.com:
```

你填：

```text
sub.你的域名.com
```

例如：

```text
sub.example.com
```

### 5.4 是否限制 Sub2API 后台只允许你的 IP 访问

提示：

```text
是否限制 Sub2API 后台只允许一个管理员 IP 访问？[Y/n]:
```

新手建议直接回车，使用默认 `Y`。

### 5.5 管理员公网 IP 怎么查

打开浏览器访问：

```text
https://ip.sb
```

或：

```text
https://ifconfig.me
```

页面显示的 IP 就是你的公网 IP。

脚本提示时填进去：

```text
请输入允许访问 Sub2API 后台的管理员公网 IP:
```

注意：如果你家宽带公网 IP 经常变化，以后可能会访问不了 Sub2API 后台，需要修改 Caddyfile 里的 IP。

### 5.6 Sub2API 管理员邮箱

提示：

```text
请输入 Sub2API 管理员邮箱 [admin@example.com]:
```

输入你的邮箱，例如：

```text
admin@example.com
```

### 5.7 PostgreSQL / Redis / 管理员密码

脚本会问：

```text
请输入 PostgreSQL 密码 [留空自动生成]:
请输入 Redis 密码 [留空自动生成]:
请输入 Sub2API 管理员密码 [留空自动生成]:
```

新手建议全部直接回车，让脚本自动生成。

脚本结束时会显示 Sub2API 管理员邮箱和密码，请复制保存。

---

## 6. 脚本会安装和生成什么

脚本会安装 Docker，并在服务器创建：

```text
/opt/ai-gateway
```

里面有：

```text
/opt/ai-gateway/.env
/opt/ai-gateway/docker-compose.yml
/opt/ai-gateway/caddy/Caddyfile
/opt/ai-gateway/initdb/01-init.sql
/opt/ai-gateway/backup.sh
```

会启动这些容器：

```text
ai-caddy
new-api
sub2api
ai-postgres
ai-redis
```

---

## 7. 部署完成后怎么确认成功

执行：

```bash
cd /opt/ai-gateway
docker compose ps
```

你应该看到这些服务都是 `Up`：

```text
ai-caddy
new-api
sub2api
ai-postgres
ai-redis
```

然后浏览器打开：

```text
https://api.你的域名.com
```

如果能打开 NewAPI 页面，说明基础部署成功。

如果你暴露了 Sub2API 后台，也打开：

```text
https://sub.你的域名.com
```

如果打不开，查看日志：

```bash
cd /opt/ai-gateway
docker compose logs -f caddy
```

最常见原因：

```text
DNS 没生效
80/443 没开放
域名填错
服务器安全组没放行 80/443
```

---

## 8. 部署后必须手动完成的事情

脚本只能把系统跑起来，不能替你配置业务。

### 8.1 初始化 NewAPI

打开：

```text
https://api.你的域名.com
```

完成：

```text
[ ] 创建或登录管理员账号
[ ] 修改管理员密码
[ ] 关闭开放注册
[ ] 创建用户分组：default / vip / internal
[ ] 创建测试用户
[ ] 给测试用户创建 API Token
[ ] 设置模型倍率和额度
```

测试用户 token 类似：

```text
sk-newapi-user-xxxx
```

这是给 Claude Code、Codex、用户客户端使用的 key。

### 8.2 初始化 Sub2API

打开：

```text
https://sub.你的域名.com
```

登录：

```text
邮箱：脚本里填的 Sub2API 管理员邮箱
密码：脚本结束时显示的密码，或你自己输入的密码
```

如果忘了，可以在服务器查看：

```bash
sudo grep SUB2API_ADMIN /opt/ai-gateway/.env
```

进入后台后完成：

```text
[ ] 添加合法上游 API Key 或 OAuth 账号资源
[ ] 配置模型
[ ] 创建一个专门给 NewAPI 使用的用户，例如 newapi-upstream
[ ] 给这个用户创建 API Key
```

Sub2API 给 NewAPI 的 key 类似：

```text
sk-sub2api-xxxx
```

这个 key 只填到 NewAPI 渠道里，不要发给最终用户。

### 8.3 在 NewAPI 添加 Sub2API 渠道

进入 NewAPI：

```text
渠道管理 -> 添加渠道
```

OpenAI / Codex 渠道：

```text
渠道类型：OpenAI / OpenAI Compatible
渠道名称：Sub2API-OpenAI
Base URL：http://sub2api:8080
API Key：Sub2API 给 NewAPI 的专用 key
模型：gpt-4.1,gpt-4.1-mini,codex-mini-latest 等
分组：default,vip,internal
状态：启用
```

Claude / Claude Code 渠道：

```text
渠道类型：Claude / Anthropic / Claude Messages
渠道名称：Sub2API-Claude
Base URL：http://sub2api:8080
API Key：Sub2API 给 NewAPI 的专用 key
模型：claude-sonnet-4-5 等
分组：default,vip,internal
状态：启用
```

注意：Base URL 推荐填 Docker 内网地址：

```text
http://sub2api:8080
```

不要优先填公网 `https://sub.你的域名.com`。

---

## 9. 测试 NewAPI 是否能用

下面命令里的内容要替换：

```text
api.example.com -> 你的 NewAPI 域名
sk-newapi-user-xxxx -> NewAPI 给测试用户创建的 token
```

### 9.1 测试 OpenAI Chat

```bash
curl https://api.example.com/v1/chat/completions   -H "Authorization: Bearer sk-newapi-user-xxxx"   -H "Content-Type: application/json"   -d '{
    "model": "gpt-4.1",
    "messages": [{"role": "user", "content": "say hi"}],
    "stream": false
  }'
```

成功时会返回 JSON，里面有模型回答。

### 9.2 测试流式输出

```bash
curl -N https://api.example.com/v1/chat/completions   -H "Authorization: Bearer sk-newapi-user-xxxx"   -H "Content-Type: application/json"   -d '{
    "model": "gpt-4.1",
    "messages": [{"role": "user", "content": "从1数到10"}],
    "stream": true
  }'
```

成功时会一段一段输出，而不是卡很久一次性返回。

### 9.3 测试 Claude Messages

如果你配置了 Claude 渠道：

```bash
curl https://api.example.com/v1/messages   -H "x-api-key: sk-newapi-user-xxxx"   -H "anthropic-version: 2023-06-01"   -H "content-type: application/json"   -d '{
    "model": "claude-sonnet-4-5",
    "max_tokens": 100,
    "messages": [{"role": "user", "content": "say hi"}]
  }'
```

---

## 10. Claude Code 怎么接入

在你的电脑上执行：

```bash
export ANTHROPIC_BASE_URL=https://api.example.com
export ANTHROPIC_API_KEY=sk-newapi-user-xxxx

claude -p "用一句话介绍你自己" --max-turns 1
```

替换：

```text
api.example.com -> 你的 NewAPI 域名
sk-newapi-user-xxxx -> NewAPI 给用户创建的 token
```

---

## 11. Codex 怎么接入

在你的电脑上执行：

```bash
export OPENAI_BASE_URL=https://api.example.com/v1
export OPENAI_API_KEY=sk-newapi-user-xxxx

codex exec "用一句话介绍你自己"
```

如果普通 OpenAI Chat 能用但 Codex 不能用，重点检查 NewAPI / Sub2API 是否支持 `/v1/responses`。

---

## 12. Cloudflare 要不要用

不必须。

新手建议：

```text
第一阶段：不要用 Cloudflare，直接 DNS 解析到服务器，先把服务跑通。
第二阶段：稳定后再考虑 Cloudflare。
```

如果用 Cloudflare：

```text
SSL/TLS 选择 Full (strict)
api 域名可以后续开橙色云
sub 域名如果用 Caddy 限 IP，建议 DNS only
关闭 Rocket Loader / Auto Minify 等网页优化功能
开 Cloudflare 后必须重新测试流式、Claude Code、Codex
```

---

## 13. 日常运维命令

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

重启全部服务：

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

设置每天自动备份：

```bash
crontab -e
```

加入：

```cron
0 3 * * * /bin/bash /opt/ai-gateway/backup.sh >> /opt/ai-gateway/backups/backup.log 2>&1
```

---

## 14. 三种 key 不要搞混

### 14.1 上游真实 API Key

例如 OpenAI、Claude、Gemini 的 key。

放在：

```text
Sub2API 后台
```

不要给用户。

### 14.2 Sub2API 给 NewAPI 的 key

格式类似：

```text
sk-sub2api-xxxx
```

放在：

```text
NewAPI 渠道配置
```

不要给用户。

### 14.3 NewAPI 给最终用户的 key

格式类似：

```text
sk-newapi-user-xxxx
```

放在：

```text
Claude Code / Codex / Cherry Studio / SDK
```

这个才是用户使用的 key。

---

## 15. 常见问题

### 15.1 页面打不开

检查：

```bash
ping api.example.com
cd /opt/ai-gateway
docker compose ps
docker compose logs -f caddy
```

常见原因：

```text
DNS 没生效
服务器安全组没开放 80/443
域名填错
```

### 15.2 model not found

常见原因：

```text
NewAPI 渠道模型名没填
Sub2API 模型名不一致
用户分组没有模型权限
模型倍率没配置
```

### 15.3 invalid token

常见原因：

```text
把 Sub2API key 当成 NewAPI 用户 key 用了
NewAPI 用户 token 复制错了
Header 写错了
```

OpenAI 接口：

```text
Authorization: Bearer sk-newapi-user-xxxx
```

Claude Messages 接口：

```text
x-api-key: sk-newapi-user-xxxx
```

### 15.4 Claude Code 卡住

先测试 `/v1/messages` curl。这个不通，Claude Code 一定不通。

常见原因：

```text
Claude 渠道类型选错
模型名不一致
上游 Claude 账号不可用
流式响应被中断
```

---

## 16. 本仓库文件说明

```text
README.md                              当前小白部署手册
deploy-newapi-sub2api.sh               一键部署脚本
newapi-sub2api-beginner-guide.md       小白完整操作手册
newapi-sub2api-manual-steps.md         部署后人工操作清单
newapi-sub2api-relay-setup.md          完整技术方案和实操方案
one-command-install-guide.md           一条命令安装发布说明
```

建议阅读顺序：

```text
1. README.md
2. newapi-sub2api-beginner-guide.md
3. newapi-sub2api-manual-steps.md
4. newapi-sub2api-relay-setup.md
```

---

## 17. 最终检查清单

```text
[ ] 已登录服务器
[ ] api 子域名已解析到服务器 IP
[ ] sub 子域名已解析到服务器 IP，若使用
[ ] 已执行一键部署命令
[ ] docker compose ps 全部 Up
[ ] https://api.你的域名.com 能打开
[ ] NewAPI 管理员已创建
[ ] NewAPI 已关闭开放注册
[ ] NewAPI 已创建测试用户 token
[ ] https://sub.你的域名.com 能打开，若使用
[ ] Sub2API 已添加上游账号
[ ] Sub2API 已创建给 NewAPI 使用的 key
[ ] NewAPI 已添加 Sub2API OpenAI 渠道
[ ] NewAPI 已添加 Sub2API Claude 渠道，若使用 Claude
[ ] OpenAI Chat curl 测试通过
[ ] 流式 curl 测试通过
[ ] Claude Messages curl 测试通过，若使用 Claude
[ ] Claude Code 实机测试通过，若使用 Claude Code
[ ] Codex 实机测试通过，若使用 Codex
[ ] backup.sh 手动备份成功
```

---

## 18. 如果卡住了，请提供这些信息

不要只说“不能用”。请提供：

```text
1. 卡在哪一步
2. 完整报错文本或截图
3. docker compose ps 输出
4. 最近日志
```

获取日志：

```bash
cd /opt/ai-gateway
docker compose ps
docker compose logs --tail=100 caddy
docker compose logs --tail=100 new-api
docker compose logs --tail=100 sub2api
```

注意：发日志前请打码真实 API Key。
