# NewAPI + Sub2API 部署后人工操作清单

> 本文档配合一键部署脚本使用：`deploy-newapi-sub2api.sh`。
>
> 脚本只负责把基础服务跑起来：Caddy、NewAPI、Sub2API、PostgreSQL、Redis。
> 业务配置、上游账号、模型、计费、用户、风控和客户端验证必须人工完成。

---

## 0. 一键部署脚本路径

当前已生成脚本：

```text
/home/kyle/test/AnythingElse/deploy-newapi-sub2api.sh
```

复制到服务器后执行：

```bash
scp /home/kyle/test/AnythingElse/deploy-newapi-sub2api.sh root@你的服务器IP:/root/
ssh root@你的服务器IP
bash /root/deploy-newapi-sub2api.sh
```

服务器部署目录：

```text
/opt/ai-gateway
```

主要文件：

```text
/opt/ai-gateway/.env
/opt/ai-gateway/docker-compose.yml
/opt/ai-gateway/caddy/Caddyfile
/opt/ai-gateway/backup.sh
```

---

## 1. DNS 和 HTTPS 检查

### 1.1 配置 DNS

在域名服务商处添加 A 记录：

```text
api.example.com -> 服务器公网 IP
sub.example.com -> 服务器公网 IP，可选，仅当你选择暴露 Sub2API 后台
```

如果你不准备暴露 Sub2API 后台，只需要：

```text
api.example.com -> 服务器公网 IP
```

### 1.2 检查 DNS 是否生效

在本机或服务器执行：

```bash
ping api.example.com
ping sub.example.com
```

或：

```bash
nslookup api.example.com
nslookup sub.example.com
```

### 1.3 检查 HTTPS 证书

浏览器访问：

```text
https://api.example.com
https://sub.example.com
```

服务器查看 Caddy 日志：

```bash
cd /opt/ai-gateway
docker compose logs -f caddy
```

如果证书签发失败，优先检查：

```text
[ ] 域名是否解析到当前服务器
[ ] 80 和 443 端口是否开放
[ ] 云厂商安全组是否放行 80/443
[ ] 本机防火墙是否放行 80/443
[ ] Cloudflare 是否开启了错误的 SSL 模式
```

---

## 2. 服务器防火墙设置

执行：

```bash
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
sudo ufw status
```

不要开放这些端口到公网：

```text
3000  NewAPI 容器端口
8080  Sub2API 容器端口
5432  PostgreSQL
6379  Redis
```

检查监听端口：

```bash
ss -tulpn
```

---

## 3. NewAPI 初始化

访问：

```text
https://api.example.com
```

### 3.1 初始化管理员

手动完成：

```text
[ ] 创建或登录管理员账号
[ ] 修改默认管理员密码
[ ] 保存管理员账号到密码管理器
```

### 3.2 基础系统设置

NewAPI 后台建议配置：

```text
[ ] 设置站点名称
[ ] 设置前端地址：https://api.example.com
[ ] 关闭开放注册，除非你明确要公开注册
[ ] 设置默认用户分组
[ ] 设置日志保留策略
[ ] 开启错误日志
[ ] 检查时区是否为 Asia/Shanghai
```

### 3.3 用户分组规划

建议先建三个分组：

```text
default   普通用户
vip       高额度用户
internal  内部测试和管理员
```

每个分组后续要配置：

```text
[ ] 可用模型
[ ] 模型倍率
[ ] 请求频率限制
[ ] Token 额度限制
[ ] 是否允许高成本模型
```

### 3.4 创建测试用户和测试 Token

手动完成：

```text
[ ] 创建测试用户：test@example.com
[ ] 给测试用户分配 default 或 internal 分组
[ ] 创建 API Token
[ ] 记录 token，例如 sk-newapi-user-xxxx
```

这个 token 后面用于测试 NewAPI 对外接口。

---

## 4. Sub2API 初始化

如果脚本中选择暴露 Sub2API 后台，访问：

```text
https://sub.example.com
```

如果没有暴露公网，你需要通过以下方式之一访问：

```text
方案 A：临时在 Caddyfile 增加 sub.example.com，并限制管理员 IP
方案 B：SSH tunnel 转发本地端口到服务器
方案 C：在服务器内网环境访问
```

SSH tunnel 示例，前提是服务器本地可以访问 Sub2API：

```bash
ssh -L 18080:127.0.0.1:8080 root@你的服务器IP
```

但本部署默认 Sub2API 只在 Docker 网络里，不映射宿主机 8080。若要使用 SSH tunnel，需要临时修改 compose 映射或使用 Caddy 限 IP 访问。

### 4.1 登录管理员

登录信息来自脚本执行时输入或自动生成的值：

```text
邮箱：SUB2API_ADMIN_EMAIL
密码：SUB2API_ADMIN_PASSWORD
```

可在服务器查看：

```bash
sudo grep SUB2API_ADMIN /opt/ai-gateway/.env
```

登录后手动完成：

```text
[ ] 修改管理员资料
[ ] 确认管理员密码足够强
[ ] 如支持 2FA，开启 2FA
[ ] 检查系统时区
```

---

## 5. Sub2API 添加上游账号资源

这是最关键的人工环节。

你需要在 Sub2API 后台添加合法上游资源，例如：

```text
[ ] Anthropic API Key
[ ] OpenAI API Key
[ ] Gemini API Key
[ ] Azure OpenAI
[ ] AWS Bedrock
[ ] Google Vertex
[ ] Claude Code / Codex / Gemini CLI 订阅类 OAuth 账号
[ ] 其他 OpenAI-compatible / Claude-compatible 上游
```

### 5.1 上游账号配置原则

建议：

```text
[ ] 每种供应商单独分组
[ ] 高价值账号不要和测试账号混用
[ ] 每个账号设置保守并发
[ ] 每个账号设置每日额度
[ ] 开启失败熔断或自动禁用异常账号
[ ] 记录账号来源、成本、额度、到期时间
```

不要做：

```text
[ ] 不要把个人订阅账号直接公开转售
[ ] 不要把所有用户流量打到一个上游账号
[ ] 不要无限并发
[ ] 不要把上游真实 key 暴露给用户
```

### 5.2 模型命名建议

NewAPI 和 Sub2API 两边模型名最好保持一致，减少映射错误：

```text
claude-sonnet-4-5
gpt-4.1
gpt-4.1-mini
gpt-5
gpt-5-mini
codex-mini-latest
gemini-2.5-pro
gemini-2.5-flash
```

实际名称以你的 Sub2API 和上游支持为准。

---

## 6. Sub2API 创建给 NewAPI 使用的专用 API Key

在 Sub2API 中创建一个内部用户：

```text
用户名称：newapi-upstream
用途：只给 NewAPI 调用
```

给该用户创建 API Key：

```text
sk-sub2api-xxxxxxxx
```

建议限制：

```text
[ ] 只开放 NewAPI 需要售卖或内部使用的模型
[ ] 设置总额度
[ ] 设置每日额度
[ ] 设置最大并发
[ ] 设置 RPM / TPM 限流
[ ] 备注用途：NewAPI upstream only
```

这个 key 只填到 NewAPI 渠道里，不给终端用户。

---

## 7. NewAPI 添加 Sub2API 渠道

进入 NewAPI 后台：

```text
渠道管理 -> 添加渠道
```

### 7.1 添加 OpenAI / Codex 兼容渠道

适合：

```text
OpenAI SDK
Codex CLI
Chat Completions
Responses API
Cherry Studio OpenAI-compatible
```

配置：

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

注意：

```text
Base URL 推荐用 Docker 内网：http://sub2api:8080
不要优先用 https://sub.example.com，因为绕一圈公网更慢也更容易出问题。
```

### 7.2 添加 Claude / Claude Code 渠道

适合：

```text
Claude Code
Anthropic SDK
Claude Messages API
```

配置：

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

```text
[ ] 模型名必须在 NewAPI 和 Sub2API 两边一致
[ ] Claude Code 必须实际测试 tool_use 和 stream
[ ] 普通聊天能用不代表 Claude Code 一定能用
```

---

## 8. 配置 NewAPI 模型倍率和额度

### 8.1 模型倍率

手动配置每个模型的价格倍率：

```text
[ ] claude-sonnet-4-5
[ ] claude-opus-4-1
[ ] claude-haiku-4-5
[ ] gpt-4.1
[ ] gpt-4.1-mini
[ ] gpt-5
[ ] gpt-5-mini
[ ] codex-mini-latest
[ ] gemini-2.5-pro
[ ] gemini-2.5-flash
```

建议先保守定价，不要低于真实成本。

你至少要估算：

```text
上游 input token 成本
上游 output token 成本
cache token 成本
reasoning token 成本
订阅账号摊销成本
失败重试成本
支付手续费
客服和退款成本
```

### 8.2 用户额度

建议初始策略：

```text
测试用户：小额度，例如 1-5 元等值额度
内部用户：按人设置额度
公开用户：先不开自动充值，人工审核
```

不要一开始就给大额度，避免配置错误导致被刷。

---

## 9. 接口测试

下面所有测试都走 NewAPI 对外域名，而不是直接走 Sub2API。

### 9.1 测试 models

```bash
curl https://api.example.com/v1/models \
  -H "Authorization: Bearer sk-newapi-user-xxxx"
```

### 9.2 测试 OpenAI Chat Completions

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

预期：返回正常文本。

### 9.3 测试 OpenAI 流式

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

预期：持续输出 SSE chunk，而不是等很久一次性返回。

### 9.4 测试 Claude Messages

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

预期：返回 Claude Messages 格式响应。

### 9.5 测试 Claude 流式

```bash
curl -N https://api.example.com/v1/messages \
  -H "x-api-key: sk-newapi-user-xxxx" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d '{
    "model": "claude-sonnet-4-5",
    "max_tokens": 200,
    "stream": true,
    "messages": [
      {"role": "user", "content": "从1数到10"}
    ]
  }'
```

预期：返回 Claude SSE event。

---

## 10. Claude Code 实机测试

在用户机器上配置：

```bash
export ANTHROPIC_BASE_URL=https://api.example.com
export ANTHROPIC_API_KEY=sk-newapi-user-xxxx
```

测试普通请求：

```bash
claude -p "用一句话介绍你自己" --max-turns 1
```

测试代码代理能力：

```bash
mkdir -p /tmp/claude-code-test
cd /tmp/claude-code-test
git init
printf 'def add(a, b):\n    return a + b\n' > calc.py
claude -p "阅读 calc.py，为 add 函数写一个简单测试文件" --max-turns 5
```

检查：

```text
[ ] Claude Code 能正常启动
[ ] 能正常读取文件
[ ] 能正常写文件
[ ] 没有 stream disconnected
[ ] 没有 invalid API response
[ ] NewAPI 日志中有记录
[ ] Sub2API 日志中有上游调用记录
```

如果失败，优先排查：

```text
[ ] NewAPI /v1/messages 是否通
[ ] Claude 渠道类型是否选对
[ ] 模型名是否一致
[ ] Sub2API 上游 Claude 账号是否可用
[ ] Caddy 是否中断长连接
[ ] STREAMING_TIMEOUT 是否过短
```

---

## 11. Codex 实机测试

在用户机器上配置：

```bash
export OPENAI_BASE_URL=https://api.example.com/v1
export OPENAI_API_KEY=sk-newapi-user-xxxx
```

测试：

```bash
mkdir -p /tmp/codex-test
cd /tmp/codex-test
git init
codex exec "创建一个 hello.py，运行后输出 hello codex"
```

检查：

```text
[ ] Codex 能正常启动
[ ] 能调用模型
[ ] 能写文件
[ ] 能完成任务
[ ] NewAPI 有日志
[ ] Sub2API 有日志
```

如果失败，重点排查：

```text
[ ] Codex 是否使用 /v1/responses
[ ] NewAPI 是否支持 /v1/responses
[ ] Sub2API 是否支持 /v1/responses
[ ] 模型是否支持 Codex agent 场景
[ ] 工具调用字段是否兼容
```

---

## 12. Cherry Studio / OpenAI SDK 测试

### 12.1 OpenAI Compatible

配置：

```text
Base URL：https://api.example.com/v1
API Key：sk-newapi-user-xxxx
Model：gpt-4.1 或你的模型名
```

### 12.2 Anthropic Compatible

配置：

```text
Base URL：https://api.example.com
API Key：sk-newapi-user-xxxx
Model：claude-sonnet-4-5 或你的模型名
```

检查：

```text
[ ] 普通聊天成功
[ ] 流式输出正常
[ ] 多轮上下文正常
[ ] 图片/文件等特殊能力按需测试
```

---

## 13. 备份计划

脚本已生成：

```text
/opt/ai-gateway/backup.sh
```

手动测试：

```bash
bash /opt/ai-gateway/backup.sh
ls -lh /opt/ai-gateway/backups
```

加入 crontab：

```bash
crontab -e
```

添加每天凌晨 3 点备份：

```cron
0 3 * * * /bin/bash /opt/ai-gateway/backup.sh >> /opt/ai-gateway/backups/backup.log 2>&1
```

建议：

```text
[ ] 定期把备份同步到另一台服务器或对象存储
[ ] 至少测试一次恢复流程
[ ] 不要只备份数据库，也要备份 .env 和 Caddyfile
```

---

## 14. 运营和风控手动配置

### 14.1 用户策略

至少明确：

```text
[ ] 是否开放注册
[ ] 是否需要邀请码
[ ] 新用户默认额度
[ ] 单用户每日最大请求数
[ ] 单用户最大并发
[ ] 是否允许共享 token
[ ] 是否启用 IP 白名单
```

### 14.2 模型策略

至少明确：

```text
[ ] 哪些模型对普通用户开放
[ ] 哪些模型只给 VIP
[ ] 哪些模型只给 internal
[ ] 高成本模型是否单独限流
[ ] Claude Code / Codex 是否单独套餐
```

### 14.3 失败补偿规则

必须提前定：

```text
[ ] 上游 429 是否扣费
[ ] 上游 5xx 是否扣费
[ ] 客户端断开是否扣费
[ ] 流式中断如何补偿
[ ] Claude Code 执行一半失败如何处理
[ ] 用户申诉需要提供什么请求 ID
```

建议：

```text
失败请求尽量不扣费或自动补偿，否则客服成本会很高。
```

### 14.4 日志和隐私

至少明确：

```text
[ ] 是否保存 prompt 内容
[ ] 保存多久
[ ] 谁可以查看日志
[ ] 是否脱敏 API Key
[ ] 是否脱敏用户输入
[ ] 企业客户是否需要关闭内容日志
```

---

## 15. 小规模灰度流程

不要部署完马上公开卖。

建议节奏：

```text
第 1 阶段：自己测试 1 天
第 2 阶段：3-5 个熟人测试 2-3 天
第 3 阶段：10-30 个真实用户灰度 1 周
第 4 阶段：根据成功率和客服压力决定是否扩大
```

每阶段看这些指标：

```text
[ ] 总请求数
[ ] 成功率
[ ] 首 token 延迟
[ ] 平均完成耗时
[ ] 流式中断率
[ ] 上游 429/529 比例
[ ] Claude Code 完成率
[ ] Codex 完成率
[ ] 用户投诉数
[ ] 退款数
[ ] 单模型成本和毛利
```

扩大条件：

```text
[ ] 总成功率 >= 97%
[ ] Claude Code / Codex 可用性稳定
[ ] 有清晰失败补偿规则
[ ] 有日志查询能力
[ ] 有备份
[ ] 有基本客服处理流程
```

---

## 16. 常用运维命令

进入目录：

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
docker compose logs -f postgres
docker compose logs -f redis
```

重启服务：

```bash
docker compose restart new-api
docker compose restart sub2api
docker compose restart caddy
```

更新：

```bash
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

## 17. 最终上线检查清单

```text
[ ] DNS 已解析到服务器
[ ] HTTPS 证书正常
[ ] 80/443 开放
[ ] 3000/8080/5432/6379 未暴露公网
[ ] NewAPI 管理员密码已修改
[ ] NewAPI 开放注册已关闭或已有风控
[ ] NewAPI 用户分组已配置
[ ] NewAPI 模型倍率已配置
[ ] NewAPI 测试 token 已创建
[ ] Sub2API 管理员密码已修改
[ ] Sub2API 后台已限制管理员 IP，或确认风险可接受
[ ] Sub2API 上游账号已添加
[ ] Sub2API 给 NewAPI 的专用 key 已创建
[ ] NewAPI 已添加 Sub2API OpenAI 渠道
[ ] NewAPI 已添加 Sub2API Claude 渠道
[ ] /v1/models 测试通过
[ ] /v1/chat/completions 非流式测试通过
[ ] /v1/chat/completions 流式测试通过
[ ] /v1/messages 非流式测试通过
[ ] /v1/messages 流式测试通过
[ ] Claude Code 实机测试通过
[ ] Codex 实机测试通过
[ ] Cherry Studio 或 SDK 测试通过
[ ] backup.sh 手动备份成功
[ ] crontab 自动备份已配置
[ ] 失败补偿规则已确定
[ ] 用户额度和并发限制已配置
[ ] 日志和隐私策略已确定
[ ] 灰度用户名单已确定
```

---

## 18. 不建议省略的人工验证

以下步骤不要跳过：

```text
1. Claude Code 实机测试
2. Codex 实机测试
3. 流式响应测试
4. 上游 429/5xx 情况下的扣费检查
5. 用户余额不足时的行为检查
6. Sub2API 账号池单账号失效后的切换检查
7. 备份恢复测试
```

原因：

```text
普通 curl 聊天成功，不代表 Claude Code / Codex 能稳定工作。
Claude Code 和 Codex 对 streaming、tool call、长上下文和错误格式更敏感。
```
