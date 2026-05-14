# NewAPI + Sub2API 小白一键部署操作手册

> 目标：让你不需要再查资料，按顺序复制命令、填写域名和密码，就能把 NewAPI + Sub2API 中转站基础环境跑起来。
>
> 你需要提前准备：
>
> 1. 一台海外 VPS 服务器，例如 Ubuntu 22.04 / 24.04。
> 2. 一个域名，例如 `example.com`。
> 3. 你能登录域名解析后台。
> 4. 你能通过 SSH 登录服务器。
> 5. 合法可用的上游 API Key 或账号资源。没有上游资源，部署成功也无法真正调用模型。

---

## 0. 你最后会得到什么

部署完成后：

```text
https://api.你的域名.com
```

这是 NewAPI，对外给用户使用。

可选：

```text
https://sub.你的域名.com
```

这是 Sub2API 管理后台，只建议你自己访问，不建议公开给用户。

架构是：

```text
用户客户端
  ↓
NewAPI：发用户 key、计费、限流、日志
  ↓
Sub2API：管理上游账号池
  ↓
OpenAI / Claude / Gemini / 其他合法上游
```

---

## 1. 你需要准备的信息

先把下面这些信息填好，后面会反复用到。

### 1.1 服务器信息

```text
服务器 IP：________________________
服务器 SSH 用户名：root 或 ubuntu 或其他：________________________
服务器 SSH 密码或密钥：自己保存好
```

### 1.2 域名信息

假设你的主域名是：

```text
example.com
```

建议使用两个子域名：

```text
api.example.com    给 NewAPI 使用，对外服务
sub.example.com    给 Sub2API 后台使用，可选
```

把你的实际域名写在这里：

```text
NewAPI 域名：________________________
Sub2API 域名：________________________
```

如果你不想公开 Sub2API 后台，Sub2API 域名也可以先不配置。

---

## 2. 购买服务器后的第一步：登录服务器

### 2.1 Windows 用户

打开 PowerShell。

如果你的服务器用户名是 root，IP 是 `1.2.3.4`，输入：

```bash
ssh root@1.2.3.4
```

如果用户名是 ubuntu：

```bash
ssh ubuntu@1.2.3.4
```

第一次连接会提示：

```text
Are you sure you want to continue connecting (yes/no/[fingerprint])?
```

输入：

```text
yes
```

然后输入服务器密码。

### 2.2 macOS 用户

打开 Terminal，命令同上：

```bash
ssh root@你的服务器IP
```

### 2.3 登录成功的样子

你会看到类似：

```text
root@xxx:~#
```

或：

```text
ubuntu@xxx:~$
```

只要进入这个界面，说明已经登录服务器。

---

## 3. 域名解析设置

这一步在你的域名服务商后台操作，不是在服务器里操作。

### 3.1 添加 NewAPI 域名解析

进入域名 DNS 解析页面，添加一条记录：

```text
类型：A
主机记录：api
记录值：你的服务器 IP
TTL：默认即可
```

例如你的域名是 `example.com`，服务器 IP 是 `1.2.3.4`：

```text
A    api    1.2.3.4
```

最终访问地址就是：

```text
api.example.com
```

### 3.2 添加 Sub2API 域名解析，可选

如果你想通过网页访问 Sub2API 后台，添加：

```text
类型：A
主机记录：sub
记录值：你的服务器 IP
TTL：默认即可
```

最终访问地址：

```text
sub.example.com
```

如果你不知道要不要暴露 Sub2API，建议先暴露，但部署脚本里选择“限制管理员 IP 访问”。

### 3.3 检查解析是否生效

在你自己的电脑终端执行：

```bash
ping api.example.com
```

把 `api.example.com` 改成你的实际域名。

如果看到返回的 IP 是你的服务器 IP，说明生效。

如果没有生效，等 5-30 分钟再试。

---

## 4. 把一键部署脚本上传到服务器

你本地已经有脚本：

```text
/home/kyle/test/AnythingElse/deploy-newapi-sub2api.sh
```

如果你是在当前这台机器上操作，可以直接复制脚本内容到服务器。

### 4.1 方式 A：用 scp 上传，推荐

在你本地电脑终端执行：

```bash
scp /home/kyle/test/AnythingElse/deploy-newapi-sub2api.sh root@你的服务器IP:/root/
```

如果你的服务器用户名不是 root，例如 ubuntu：

```bash
scp /home/kyle/test/AnythingElse/deploy-newapi-sub2api.sh ubuntu@你的服务器IP:/home/ubuntu/
```

### 4.2 方式 B：服务器里直接新建文件

如果你不会 scp，可以登录服务器后执行：

```bash
nano deploy-newapi-sub2api.sh
```

然后把脚本内容粘贴进去。

保存方式：

```text
Ctrl + O
回车
Ctrl + X
```

---

## 5. 执行一键部署脚本

登录服务器后，进入脚本所在目录。

如果你上传到了 root 目录：

```bash
cd /root
```

给脚本执行权限：

```bash
chmod +x deploy-newapi-sub2api.sh
```

执行脚本：

```bash
bash deploy-newapi-sub2api.sh
```

如果提示权限问题，执行：

```bash
sudo bash deploy-newapi-sub2api.sh
```

---

## 6. 脚本运行时怎么填写

脚本会问你几个问题。下面逐个解释。

### 6.1 输入 NewAPI 对外域名

提示类似：

```text
请输入 NewAPI 对外域名，例如 api.example.com:
```

你输入你的域名，例如：

```text
api.example.com
```

不要带 `https://`，只填域名。

正确：

```text
api.example.com
```

错误：

```text
https://api.example.com
```

### 6.2 是否暴露 Sub2API 管理后台

提示：

```text
是否暴露 Sub2API 管理后台域名？不建议公开暴露。[y/N]:
```

小白建议输入：

```text
y
```

因为你需要网页后台配置上游账号。

但后面一定要选择“限制管理员 IP 访问”。

### 6.3 输入 Sub2API 域名

如果上一步输入了 `y`，会提示：

```text
请输入 Sub2API 管理后台域名，例如 sub.example.com:
```

输入：

```text
sub.example.com
```

同样不要带 `https://`。

### 6.4 是否限制管理员 IP

提示：

```text
是否限制 Sub2API 后台只允许一个管理员 IP 访问？[Y/n]:
```

小白建议直接回车，表示使用默认 `Y`。

也可以输入：

```text
y
```

### 6.5 输入你的公网 IP

脚本会提示：

```text
请输入允许访问 Sub2API 后台的管理员公网 IP:
```

你的公网 IP 可以这样查：

打开浏览器访问：

```text
https://ip.sb
```

或者：

```text
https://ifconfig.me
```

看到的 IP 填进去，例如：

```text
8.8.8.8
```

注意：

如果你家宽带 IP 经常变化，后面可能会访问不了 Sub2API，需要重新改 Caddyfile。

### 6.6 输入 Sub2API 管理员邮箱

提示：

```text
请输入 Sub2API 管理员邮箱 [admin@example.com]:
```

输入你的邮箱，例如：

```text
admin@yourdomain.com
```

### 6.7 输入 PostgreSQL 密码

提示：

```text
请输入 PostgreSQL 密码 [留空自动生成]:
```

小白建议直接回车，让脚本自动生成。

### 6.8 输入 Redis 密码

提示：

```text
请输入 Redis 密码 [留空自动生成]:
```

小白建议直接回车。

### 6.9 输入 Sub2API 管理员密码

提示：

```text
请输入 Sub2API 管理员密码 [留空自动生成]:
```

你可以自己输入一个强密码。

也可以直接回车自动生成。

注意：

脚本结束时会显示 Sub2API 管理员邮箱和密码。请复制保存。

---

## 7. 部署完成后怎么判断成功

脚本结束后，会显示类似：

```text
部署脚本执行完成。
NewAPI 地址：
  https://api.example.com

Sub2API：
  https://sub.example.com
```

### 7.1 查看容器状态

执行：

```bash
cd /opt/ai-gateway
docker compose ps
```

你应该看到这些服务：

```text
ai-caddy
new-api
sub2api
ai-postgres
ai-redis
```

状态应该是：

```text
Up
```

如果某个不是 Up，看日志：

```bash
docker compose logs -f 服务名
```

例如：

```bash
docker compose logs -f new-api
```

### 7.2 浏览器访问 NewAPI

打开：

```text
https://api.example.com
```

如果能打开页面，说明 NewAPI 起来了。

如果打不开，执行：

```bash
cd /opt/ai-gateway
docker compose logs -f caddy
```

常见原因：

```text
DNS 没生效
80/443 没开放
域名填错
Cloudflare SSL 模式错误
```

---

## 8. NewAPI 后台怎么操作

> 下面是人工操作，脚本不能替你做。

打开：

```text
https://api.example.com
```

### 8.1 创建或登录管理员

根据页面提示创建管理员账号。

完成后，先做这些：

```text
[ ] 修改管理员密码
[ ] 保存管理员账号密码
[ ] 关闭开放注册
```

如果你找不到“开放注册”，通常在：

```text
系统设置 / 站点设置 / 用户设置
```

不同版本 UI 名称可能略有变化。

### 8.2 创建分组

建议创建：

```text
default
vip
internal
```

含义：

```text
default：普通用户
vip：高额度用户
internal：你自己测试用
```

### 8.3 创建测试用户

创建一个用户，例如：

```text
test@example.com
```

分组选择：

```text
internal
```

### 8.4 创建用户 Token

在 NewAPI 里给测试用户创建一个 Token。

复制保存，格式类似：

```text
sk-xxxxxxxxxxxxxxxx
```

这个是给客户端使用的 key。

不要把 Sub2API 的 key 给用户。

---

## 9. Sub2API 后台怎么操作

打开：

```text
https://sub.example.com
```

如果你设置了管理员 IP 限制，只有你的公网 IP 能打开。

登录：

```text
邮箱：脚本里填写的 SUB2API_ADMIN_EMAIL
密码：脚本结束时显示的密码，或你自己填写的密码
```

如果忘了，可以在服务器查看：

```bash
sudo grep SUB2API_ADMIN /opt/ai-gateway/.env
```

### 9.1 添加上游账号

进入 Sub2API 后台，找到类似：

```text
账号管理
渠道管理
上游账号
Provider
Account
```

不同版本叫法可能不同。

你需要添加你合法拥有的上游资源，例如：

```text
OpenAI API Key
Anthropic API Key
Gemini API Key
Azure OpenAI
Claude Code / Codex / Gemini CLI OAuth 账号
```

如果你还没有任何上游 key，这一步无法继续提供真实模型服务。

### 9.2 配置模型

添加或确认模型名，例如：

```text
gpt-4.1
gpt-4.1-mini
codex-mini-latest
claude-sonnet-4-5
claude-opus-4-1
gemini-2.5-pro
gemini-2.5-flash
```

注意：

实际模型名必须以上游和 Sub2API 支持为准。

### 9.3 创建给 NewAPI 使用的专用 Key

在 Sub2API 里创建一个用户，建议名字：

```text
newapi-upstream
```

给它创建一个 API Key，保存下来：

```text
sk-sub2api-xxxxxxxx
```

这个 key 后面填到 NewAPI 渠道里。

不要给最终用户。

---

## 10. 在 NewAPI 里添加 Sub2API 渠道

回到 NewAPI 后台：

```text
https://api.example.com
```

找到：

```text
渠道管理 -> 添加渠道
```

### 10.1 添加 OpenAI / Codex 渠道

配置示例：

```text
渠道类型：OpenAI 或 OpenAI Compatible
渠道名称：Sub2API-OpenAI
Base URL：http://sub2api:8080
API Key：刚才 Sub2API 里创建的 sk-sub2api-xxxx
模型：gpt-4.1,gpt-4.1-mini,codex-mini-latest
分组：default,vip,internal
权重：100
状态：启用
```

最容易填错的是 Base URL。

这里不要填公网域名，优先填：

```text
http://sub2api:8080
```

因为 NewAPI 和 Sub2API 在同一个 Docker 网络里。

### 10.2 添加 Claude / Claude Code 渠道

再添加一个渠道：

```text
渠道类型：Claude / Anthropic / Claude Messages
渠道名称：Sub2API-Claude
Base URL：http://sub2api:8080
API Key：刚才 Sub2API 里创建的 sk-sub2api-xxxx
模型：claude-sonnet-4-5,claude-opus-4-1
分组：default,vip,internal
权重：100
状态：启用
```

如果你没有 Claude 上游账号，可以先不添加 Claude 渠道。

---

## 11. 配置模型价格和额度

NewAPI 后台里找到类似：

```text
模型倍率
倍率设置
计费设置
```

先不要复杂定价，小白建议：

```text
测试阶段：只给自己小额度
不要开放充值
不要开放注册
不要公开售卖
```

先给测试用户一点额度，例如：

```text
1 元 / 5 元 / 10 元等值额度
```

目的是防止配置错了被刷爆。

---

## 12. 第一次接口测试

把下面命令里的内容替换掉：

```text
api.example.com -> 你的 NewAPI 域名
sk-newapi-user-xxxx -> NewAPI 给测试用户创建的 token
```

### 12.1 测试 OpenAI 聊天

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

成功时会返回一段 JSON，里面有模型回答。

如果报错：

```text
model not found：模型名没配对
invalid token：NewAPI 用户 token 错了
channel not found：NewAPI 渠道没启用或分组不匹配
upstream error：Sub2API 或上游账号有问题
```

### 12.2 测试流式输出

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

成功时会陆续输出，不是等很久一次性输出。

### 12.3 测试 Claude Messages

如果你配置了 Claude 渠道，执行：

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

## 13. Claude Code 怎么接入

在你自己的电脑上执行：

```bash
export ANTHROPIC_BASE_URL=https://api.example.com
export ANTHROPIC_API_KEY=sk-newapi-user-xxxx
```

替换成你的实际域名和 NewAPI 用户 token。

测试：

```bash
claude -p "用一句话介绍你自己" --max-turns 1
```

如果你还没安装 Claude Code：

```bash
npm install -g @anthropic-ai/claude-code
```

如果没有 npm，需要先安装 Node.js。小白建议用官方 Node.js 安装包或服务器系统包，但这属于客户端环境，不是中转站部署本身。

---

## 14. Codex 怎么接入

在你自己的电脑上执行：

```bash
export OPENAI_BASE_URL=https://api.example.com/v1
export OPENAI_API_KEY=sk-newapi-user-xxxx
```

测试：

```bash
codex exec "用一句话介绍你自己"
```

如果还没安装 Codex：

```bash
npm install -g @openai/codex
```

注意：

Codex 可能依赖 `/v1/responses`。如果普通 OpenAI 聊天能用但 Codex 不能用，要检查 NewAPI 和 Sub2API 是否支持 Responses API。

---

## 15. 日常运维命令

所有命令都在服务器执行。

进入目录：

```bash
cd /opt/ai-gateway
```

查看服务状态：

```bash
docker compose ps
```

查看 NewAPI 日志：

```bash
docker compose logs -f new-api
```

查看 Sub2API 日志：

```bash
docker compose logs -f sub2api
```

查看 Caddy 日志：

```bash
docker compose logs -f caddy
```

重启 NewAPI：

```bash
docker compose restart new-api
```

重启 Sub2API：

```bash
docker compose restart sub2api
```

全部重启：

```bash
docker compose restart
```

更新镜像：

```bash
cd /opt/ai-gateway
docker compose pull
docker compose up -d
```

---

## 16. 备份怎么做

脚本已经生成备份脚本：

```text
/opt/ai-gateway/backup.sh
```

手动备份：

```bash
bash /opt/ai-gateway/backup.sh
```

查看备份文件：

```bash
ls -lh /opt/ai-gateway/backups
```

设置每天自动备份：

```bash
crontab -e
```

如果第一次打开，系统会让你选择编辑器。小白建议选 `nano`。

添加一行：

```cron
0 3 * * * /bin/bash /opt/ai-gateway/backup.sh >> /opt/ai-gateway/backups/backup.log 2>&1
```

保存：

```text
Ctrl + O
回车
Ctrl + X
```

---

## 17. 常见问题和解决办法

### 17.1 浏览器打不开 https://api.example.com

按顺序检查：

```bash
ping api.example.com
```

如果 IP 不对，说明 DNS 没配好或没生效。

查看 Caddy 日志：

```bash
cd /opt/ai-gateway
docker compose logs -f caddy
```

检查服务器是否开放端口：

```bash
sudo ufw status
```

云服务器后台安全组也要放行：

```text
80/tcp
443/tcp
```

### 17.2 NewAPI 页面能打开，但接口报 model not found

原因通常是：

```text
NewAPI 渠道里模型名没填
Sub2API 里模型名不同
用户分组没有权限使用该模型
```

解决：

```text
[ ] 检查 NewAPI 渠道模型列表
[ ] 检查 Sub2API 模型名称
[ ] 检查测试用户分组
[ ] 检查模型倍率是否配置
```

### 17.3 invalid token

可能是：

```text
你用了 Sub2API key 去请求 NewAPI
你复制错了 NewAPI 用户 token
Header 写错
```

NewAPI 对外 OpenAI 接口用：

```text
Authorization: Bearer sk-newapi-user-xxxx
```

Claude Messages 接口用：

```text
x-api-key: sk-newapi-user-xxxx
```

### 17.4 Claude Code 卡住

常见原因：

```text
Claude 渠道类型选错
/v1/messages 不通
流式响应被中断
模型不支持工具调用
上游账号额度不足或被限流
```

先测试：

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

这个不通，Claude Code 一定不通。

### 17.5 Codex 不能用

先测试普通 OpenAI 接口：

```bash
curl https://api.example.com/v1/chat/completions \
  -H "Authorization: Bearer sk-newapi-user-xxxx" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-4.1",
    "messages": [{"role": "user", "content": "say hi"}]
  }'
```

如果普通接口通，但 Codex 不通，可能是 Responses API 不兼容。

测试：

```bash
curl https://api.example.com/v1/responses \
  -H "Authorization: Bearer sk-newapi-user-xxxx" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-4.1",
    "input": "say hi"
  }'
```

---

## 18. 小白推荐上线顺序

不要部署完就公开卖。

建议：

```text
第 1 天：只自己测试
第 2-3 天：给 3 个朋友测试
第 4-7 天：给 10-30 个小范围用户测试
稳定后：再考虑开放注册或售卖
```

必须观察：

```text
[ ] 请求成功率
[ ] Claude Code 是否经常卡住
[ ] Codex 是否能完成任务
[ ] 用户是否经常报错
[ ] 上游账号是否频繁 429
[ ] 是否有扣费争议
[ ] 每天真实成本是多少
```

如果成功率低于 97%，不要扩大。

---

## 19. 你最容易搞混的三个 key

### 19.1 上游真实 API Key

例如 OpenAI / Claude / Gemini 的 key。

放在哪里：

```text
Sub2API 后台
```

给谁用：

```text
只给 Sub2API 用
```

### 19.2 Sub2API 给 NewAPI 的 key

格式类似：

```text
sk-sub2api-xxxx
```

放在哪里：

```text
NewAPI 渠道配置里
```

给谁用：

```text
只给 NewAPI 用
```

### 19.3 NewAPI 给最终用户的 key

格式类似：

```text
sk-newapi-user-xxxx
```

放在哪里：

```text
用户客户端、Claude Code、Codex、Cherry Studio
```

给谁用：

```text
最终用户使用
```

千万不要把上游真实 key 或 Sub2API key 发给用户。

---

## 20. 最终检查清单

按顺序打勾：

```text
[ ] 我能 SSH 登录服务器
[ ] api 子域名已解析到服务器 IP
[ ] sub 子域名已解析到服务器 IP，若使用
[ ] 脚本已成功执行
[ ] docker compose ps 里所有容器都是 Up
[ ] https://api.example.com 能打开
[ ] https://sub.example.com 能打开，若使用
[ ] NewAPI 管理员已创建
[ ] NewAPI 已关闭开放注册
[ ] NewAPI 已创建测试用户
[ ] NewAPI 已创建测试用户 token
[ ] Sub2API 管理员能登录
[ ] Sub2API 已添加上游账号
[ ] Sub2API 已创建给 NewAPI 使用的 key
[ ] NewAPI 已添加 OpenAI 渠道
[ ] NewAPI 已添加 Claude 渠道，若使用 Claude
[ ] OpenAI curl 测试通过
[ ] Claude Messages curl 测试通过，若使用 Claude
[ ] 流式 curl 测试通过
[ ] Claude Code 实机测试通过
[ ] Codex 实机测试通过
[ ] backup.sh 手动备份成功
[ ] crontab 自动备份已配置
[ ] 防火墙只开放 22/80/443
```

---

## 21. 如果你卡住了，该提供哪些信息方便排查

不要只说“不能用”。请提供：

```text
1. 卡在哪一步
2. 你访问的域名，不要发真实 key
3. 报错截图或完整错误文本
4. docker compose ps 输出
5. 相关日志：
   docker compose logs --tail=100 caddy
   docker compose logs --tail=100 new-api
   docker compose logs --tail=100 sub2api
6. 你测试的 curl 命令，记得把 key 打码
```

获取状态：

```bash
cd /opt/ai-gateway
docker compose ps
docker compose logs --tail=100 caddy
docker compose logs --tail=100 new-api
docker compose logs --tail=100 sub2api
```
