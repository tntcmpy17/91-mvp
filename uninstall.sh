#!/usr/bin/env bash
# ==============================================================================
#  91-MVP · 一键卸载脚本
#  ------------------------------------------------------------------------------
#  作用：停止并删除容器、镜像、数据（可选）
#  注意：默认保留数据目录，如需彻底删除请加 --purge
# ==============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${YELLOW}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[ OK ]${NC} $*"; }
err()   { echo -e "${RED}[FAIL]${NC} $*"; }

if [ "$EUID" -ne 0 ]; then
  SUDO="sudo"
else
  SUDO=""
fi

PURGE=0
if [ "${1:-}" = "--purge" ]; then
  PURGE=1
fi

APP_DIR="${APP_DIR:-$HOME/video-site-91}"
APP_NAME="video-site-91"

# 询问确认
echo
info "即将卸载 $APP_NAME（位置：$APP_DIR）"
if [ $PURGE -eq 1 ]; then
  err "⚠️  --purge 模式：数据目录也会被删除，无法恢复！"
fi
read -p "确认继续？[y/N] " yn
[[ "$yn" =~ ^[Yy]$ ]] || { echo "已取消"; exit 0; }

# 1. 停止并删除容器
if [ -f "$APP_DIR/docker-compose.yml" ]; then
  info "停止并删除容器..."
  cd "$APP_DIR"
  $SUDO docker compose down --remove-orphans 2>/dev/null || true
else
  info "docker-compose.yml 不存在，直接尝试通过容器名停止..."
  $SUDO docker stop "$APP_NAME" 2>/dev/null || true
  $SUDO docker rm "$APP_NAME" 2>/dev/null || true
fi
ok "容器已清理"

# 2. 删除镜像
info "删除 Docker 镜像..."
$SUDO docker rmi "${APP_NAME// /_}-video-site-91" 2>/dev/null || true
$SUDO docker images --format "{{.Repository}}:{{.Tag}}" | grep -i "video-site-91\|91-mvp" | xargs -r $SUDO docker rmi 2>/dev/null || true
ok "镜像已清理"

# 3. 删除项目目录
if [ $PURGE -eq 1 ]; then
  info "彻底删除项目目录和数据..."
  rm -rf "$APP_DIR"
  ok "已删除 $APP_DIR"
else
  info "保留项目目录 $APP_DIR（如需彻底删除请加 --purge）"
fi

echo
ok "卸载完成 ✓"
