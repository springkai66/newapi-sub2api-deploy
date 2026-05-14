#!/usr/bin/env bash
set -Eeuo pipefail

# NewAPI + Sub2API 一键部署脚本
# 目标系统：Ubuntu 22.04 / 24.04
# 用法：
#   sudo bash deploy-newapi-sub2api.sh
# 或：
#   bash deploy-newapi-sub2api.sh
# 脚本会在 /opt/ai-gateway 生成 docker-compose.yml、.env、Caddyfile、PostgreSQL 初始化脚本。

APP_DIR="/opt/ai-gateway"

log() { printf '\033[1;32m[INFO]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m %s\n' "$*"; }
err() { printf '\033[1;31m[ERROR]\033[0m %s\n' "$*" >&2; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

rand_hex() {
  openssl rand -hex 32
}

ask_required() {
  local var_name="$1"
  local prompt="$2"
  local value=""
  while [[ -z "$value" ]]; do
    read -r -p "$prompt: " value
  done
  printf -v "$var_name" '%s' "$value"
}

ask_default() {
  local var_name="$1"
  local prompt="$2"
  local default_value="$3"
  local value=""
  read -r -p "$prompt [$default_value]: " value
  value="${value:-$default_value}"
  printf -v "$var_name" '%s' "$value"
}

ask_secret_default() {
  local var_name="$1"
  local prompt="$2"
  local default_value="$3"
  local value=""
  read -r -s -p "$prompt [留空自动生成]: " value
  printf '\n'
  value="${value:-$default_value}"
  printf -v "$var_name" '%s' "$value"
}

check_root_or_sudo() {
  if [[ "${EUID}" -ne 0 ]]; then
    if ! need_cmd sudo; then
      err "当前不是 root，且系统没有 sudo。请用 root 执行。"
      exit 1
    fi
  fi
}

as_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

install_docker_if_needed() {
  if need_cmd docker && docker compose version >/dev/null 2>&1; then
    log "Docker 和 Docker Compose 已安装。"
    return
  fi

  log "安装 Docker 和 Docker Compose 插件..."
  as_root apt-get update
  as_root apt-get install -y ca-certificates curl gnupg git openssl
  curl -fsSL https://get.docker.com | as_root bash
  as_root systemctl enable docker
  as_root systemctl start docker

  if ! docker compose version >/dev/null 2>&1; then
    err "Docker Compose 插件安装后仍不可用，请手动检查 Docker 安装。"
    exit 1
  fi
}

validate_domain() {
  local d="$1"
  if [[ ! "$d" =~ ^[A-Za-z0-9._-]+$ ]]; then
    err "域名格式看起来不正确：$d"
    exit 1
  fi
}

main() {
  check_root_or_sudo

  if ! need_cmd openssl; then
    as_root apt-get update
    as_root apt-get install -y openssl
  fi

  cat <<'BANNER'
============================================================
 NewAPI + Sub2API 一键部署脚本
============================================================
将创建：
  - Caddy HTTPS 反代
  - NewAPI
  - Sub2API
  - PostgreSQL
  - Redis

默认安装目录：/opt/ai-gateway
请先确保：
  1. 域名 A 记录已指向本服务器公网 IP
  2. 服务器 80/443 端口已开放
  3. 你拥有合法的上游 API Key 或账号资源
============================================================
BANNER

  ask_required DOMAIN_API "请输入 NewAPI 对外域名，例如 api.example.com"
  validate_domain "$DOMAIN_API"

  read -r -p "是否暴露 Sub2API 管理后台域名？不建议公开暴露。[y/N]: " EXPOSE_SUB_RAW
  EXPOSE_SUB_RAW="${EXPOSE_SUB_RAW:-N}"
  if [[ "$EXPOSE_SUB_RAW" =~ ^[Yy]$ ]]; then
    EXPOSE_SUB="yes"
    ask_required DOMAIN_SUB "请输入 Sub2API 管理后台域名，例如 sub.example.com"
    validate_domain "$DOMAIN_SUB"
    read -r -p "是否限制 Sub2API 后台只允许一个管理员 IP 访问？[Y/n]: " LIMIT_SUB_RAW
    LIMIT_SUB_RAW="${LIMIT_SUB_RAW:-Y}"
    if [[ "$LIMIT_SUB_RAW" =~ ^[Nn]$ ]]; then
      LIMIT_SUB="no"
      ADMIN_IP=""
      warn "你选择公开暴露 Sub2API 后台，请务必使用强密码和额外防护。"
    else
      LIMIT_SUB="yes"
      ask_required ADMIN_IP "请输入允许访问 Sub2API 后台的管理员公网 IP"
    fi
  else
    EXPOSE_SUB="no"
    DOMAIN_SUB=""
    LIMIT_SUB="no"
    ADMIN_IP=""
  fi

  ask_default SUB2API_ADMIN_EMAIL "请输入 Sub2API 管理员邮箱" "admin@example.com"

  POSTGRES_PASSWORD_AUTO="pg_$(rand_hex | cut -c1-24)"
  REDIS_PASSWORD_AUTO="redis_$(rand_hex | cut -c1-24)"
  SUB2API_ADMIN_PASSWORD_AUTO="admin_$(rand_hex | cut -c1-24)"

  ask_secret_default POSTGRES_PASSWORD "请输入 PostgreSQL 密码" "$POSTGRES_PASSWORD_AUTO"
  ask_secret_default REDIS_PASSWORD "请输入 Redis 密码" "$REDIS_PASSWORD_AUTO"
  ask_secret_default SUB2API_ADMIN_PASSWORD "请输入 Sub2API 管理员密码" "$SUB2API_ADMIN_PASSWORD_AUTO"

  NEWAPI_SESSION_SECRET="$(rand_hex)"
  NEWAPI_CRYPTO_SECRET="$(rand_hex)"
  SUB2API_JWT_SECRET="$(rand_hex)"
  SUB2API_TOTP_KEY="$(rand_hex)"
  TZ_VALUE="Asia/Shanghai"

  install_docker_if_needed

  log "创建目录：$APP_DIR"
  as_root mkdir -p "$APP_DIR"/{newapi/data,newapi/logs,sub2api/data,caddy/logs,initdb,backups}

  # 当前用户可读写部署目录，便于后续维护。
  if [[ -n "${SUDO_USER:-}" ]]; then
    as_root chown -R "$SUDO_USER:$SUDO_USER" "$APP_DIR"
  elif [[ "${EUID}" -ne 0 ]]; then
    as_root chown -R "$USER:$USER" "$APP_DIR"
  fi

  log "写入 .env"
  cat > "$APP_DIR/.env" <<EOF
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
REDIS_PASSWORD=${REDIS_PASSWORD}

NEWAPI_SESSION_SECRET=${NEWAPI_SESSION_SECRET}
NEWAPI_CRYPTO_SECRET=${NEWAPI_CRYPTO_SECRET}

SUB2API_ADMIN_EMAIL=${SUB2API_ADMIN_EMAIL}
SUB2API_ADMIN_PASSWORD=${SUB2API_ADMIN_PASSWORD}
SUB2API_JWT_SECRET=${SUB2API_JWT_SECRET}
SUB2API_TOTP_KEY=${SUB2API_TOTP_KEY}

DOMAIN_API=${DOMAIN_API}
DOMAIN_SUB=${DOMAIN_SUB}

TZ=${TZ_VALUE}
EOF

  chmod 600 "$APP_DIR/.env"

  log "写入 PostgreSQL 初始化脚本"
  cat > "$APP_DIR/initdb/01-init.sql" <<EOF
CREATE USER newapi WITH PASSWORD '${POSTGRES_PASSWORD}';
CREATE DATABASE newapi OWNER newapi;

CREATE USER sub2api WITH PASSWORD '${POSTGRES_PASSWORD}';
CREATE DATABASE sub2api OWNER sub2api;

GRANT ALL PRIVILEGES ON DATABASE newapi TO newapi;
GRANT ALL PRIVILEGES ON DATABASE sub2api TO sub2api;
EOF

  log "写入 docker-compose.yml"
  cat > "$APP_DIR/docker-compose.yml" <<'EOF'
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
EOF

  log "写入 Caddyfile"
  cat > "$APP_DIR/caddy/Caddyfile" <<EOF
${DOMAIN_API} {
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
EOF

  if [[ "$EXPOSE_SUB" == "yes" ]]; then
    if [[ "$LIMIT_SUB" == "yes" ]]; then
      cat >> "$APP_DIR/caddy/Caddyfile" <<EOF

${DOMAIN_SUB} {
    @not_allowed not remote_ip ${ADMIN_IP}
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

    log {
        output file /var/log/caddy/sub2api.log {
            roll_size 100mb
            roll_keep 10
            roll_keep_for 720h
        }
        format json
    }
}
EOF
    else
      cat >> "$APP_DIR/caddy/Caddyfile" <<EOF

${DOMAIN_SUB} {
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
EOF
    fi
  fi

  log "写入备份脚本"
  cat > "$APP_DIR/backup.sh" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
cd /opt/ai-gateway
mkdir -p backups
DATE="$(date +%F_%H%M%S)"
docker exec ai-postgres pg_dump -U postgres newapi > "backups/newapi_${DATE}.sql"
docker exec ai-postgres pg_dump -U postgres sub2api > "backups/sub2api_${DATE}.sql"
tar czf "backups/files_${DATE}.tar.gz" .env docker-compose.yml caddy initdb newapi sub2api backup.sh
printf 'Backup saved to /opt/ai-gateway/backups with timestamp %s\n' "$DATE"
EOF
  chmod +x "$APP_DIR/backup.sh"

  log "校验 Docker Compose 配置"
  (cd "$APP_DIR" && docker compose config >/tmp/ai-gateway-compose-check.yml)

  log "拉取镜像并启动服务"
  (cd "$APP_DIR" && docker compose pull && docker compose up -d)

  log "等待容器启动..."
  sleep 5
  (cd "$APP_DIR" && docker compose ps)

  cat <<EOF

============================================================
部署脚本执行完成。
============================================================
NewAPI 地址：
  https://${DOMAIN_API}

Sub2API：
EOF

  if [[ "$EXPOSE_SUB" == "yes" ]]; then
    cat <<EOF
  https://${DOMAIN_SUB}
  管理员邮箱：${SUB2API_ADMIN_EMAIL}
  管理员密码：${SUB2API_ADMIN_PASSWORD}
EOF
  else
    cat <<EOF
  未暴露公网域名。仅 Docker 内网可访问：
  http://sub2api:8080
  管理员邮箱：${SUB2API_ADMIN_EMAIL}
  管理员密码：${SUB2API_ADMIN_PASSWORD}
EOF
  fi

  cat <<EOF

部署目录：
  ${APP_DIR}

重要文件：
  ${APP_DIR}/.env
  ${APP_DIR}/docker-compose.yml
  ${APP_DIR}/caddy/Caddyfile
  ${APP_DIR}/backup.sh

查看日志：
  cd ${APP_DIR}
  docker compose logs -f caddy
  docker compose logs -f new-api
  docker compose logs -f sub2api

后续必须手动完成：
  1. 确认域名 DNS 已指向本服务器，否则 HTTPS 证书不会签发。
  2. 登录 NewAPI，初始化管理员、关闭开放注册、创建用户和 token。
  3. 登录 Sub2API，添加合法上游账号/API Key/OAuth 资源。
  4. 在 Sub2API 创建给 NewAPI 使用的专用 API Key。
  5. 在 NewAPI 渠道管理中添加 Sub2API 渠道：Base URL 用 http://sub2api:8080。
  6. 配置模型名、分组、倍率、限流和用户余额。
  7. 用 curl 测试 /v1/chat/completions、/v1/messages、流式响应。
  8. 实机测试 Claude Code 和 Codex。
  9. 设置防火墙、备份计划、监控和失败补偿规则。
============================================================
EOF
}

main "$@"
