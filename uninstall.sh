#!/usr/bin/env bash
# ==============================================================================
#  91-MVP · 一键卸载脚本（兼容 Docker + 原生双模式）
# ==============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${YELLOW}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[ OK ]${NC} $*"; }
err()   { echo -e "${RED}[FAIL]${NC} $*"; }

if [ "$EUID" -ne 0 ]; then SUDO="sudo"; else SUDO=""; fi

PURGE=0
if [ "${1:-}" = "--purge" ]; then PURGE=1; fi

APP_NAME="video-site-91"
APP_USER="video91"
APP_DIR="/opt/$APP_NAME"
APP_DATA="/var/lib/$APP_NAME"
APP_LOG="/var/log/$APP_NAME"

echo
info "即将卸载 $APP_NAME"
if [ $PURGE -eq 1 ]; then
  err "--purge 模式：所有数据和用户都会被删除"
fi
read -p "确认继续？[y/N] " yn
[[ "$yn" =~ ^[Yy]$ ]] || { echo "已取消"; exit 0; }

# 1. 停止 systemd 服务
if systemctl list-unit-files | grep -q "^${APP_NAME}.service"; then
  info "停止 systemd 服务..."
  $SUDO systemctl stop "$APP_NAME" 2>/dev/null || true
  $SUDO systemctl disable "$APP_NAME" 2>/dev/null || true
  $SUDO rm -f /etc/systemd/system/${APP_NAME}.service
  $SUDO systemctl daemon-reload
  ok "systemd 服务已清理"
fi

# 2. 停止 Docker（如有）
if command -v docker >/dev/null && [ -f "$APP_DIR/docker-compose.yml" ]; then
  info "停止 Docker 容器..."
  cd "$APP_DIR"
  $SUDO docker compose down --remove-orphans 2>/dev/null || true
  $SUDO docker images --format "{{.Repository}}:{{.Tag}}" | \
    grep -i "video-site-91\|91-mvp" | xargs -r $SUDO docker rmi 2>/dev/null || true
  ok "Docker 资源已清理"
fi

# 3. 删除安装目录
if [ -d "$APP_DIR" ]; then
  info "删除安装目录 $APP_DIR..."
  $SUDO rm -rf "$APP_DIR"
fi

# 4. 处理数据和日志
if [ $PURGE -eq 1 ]; then
  info "删除数据目录..."
  $SUDO rm -rf "$APP_DATA" "$APP_LOG"
  if id "$APP_USER" >/dev/null 2>&1; then
    $SUDO userdel "$APP_USER" 2>/dev/null || true
    info "已删除用户 $APP_USER"
  fi
  ok "已彻底清理"
else
  info "保留数据：$APP_DATA（如需删除请加 --purge）"
  info "保留日志：$APP_LOG"
fi

echo
ok "卸载完成 ✓"
