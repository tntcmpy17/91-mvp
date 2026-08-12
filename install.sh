#!/usr/bin/env bash
# ==============================================================================
#  91-MVP · Debian 12 一键安装脚本
#  ------------------------------------------------------------------------------
#  作用：自动安装 Docker → 拉取/解压项目 → 构建并启动 → 打印后续指引
#  支持：Debian 11/12 / Ubuntu 22.04+
#  作者：tntcmpy17
# ==============================================================================

set -e

# ---------- 颜色 ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[ OK ]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()   { echo -e "${RED}[FAIL]${NC} $*"; }

# ---------- 默认值 ----------
APP_NAME="video-site-91"
APP_PORT="9191"
APP_DIR="$HOME/$APP_NAME"
REPO_URL="${REPO_URL:-https://github.com/tntcmpy17/91-mvp.git}"
TARBALL_URL="${TARBALL_URL:-https://github.com/tntcmpy17/91-mvp/releases/latest/download/91-mvp.tar.gz}"
USE_GIT="${USE_GIT:-auto}"   # auto | yes | no

# ---------- 阶段标记 ----------
DOCKER_INSTALLED=0
SOURCE_FILE=""  # git | tarball | local

# ============================================================================
#  工具函数
# ============================================================================

check_root() {
  if [ "$EUID" -ne 0 ]; then
    warn "检测到非 root 用户，将自动在需要时使用 sudo"
    SUDO="sudo"
  else
    SUDO=""
  fi
}

detect_os() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID="$ID"
    OS_VERSION="$VERSION_CODENAME"
    OS_VERSION_ID="$VERSION_ID"
  else
    err "无法识别系统，请使用 Debian 11+/Ubuntu 22.04+"
    exit 1
  fi

  case "$OS_ID" in
    debian)
      if [ "$OS_VERSION_ID" -lt 11 ]; then
        err "需要 Debian 11+，当前 $OS_VERSION $OS_VERSION_ID"
        exit 1
      fi
      ;;
    ubuntu)
      if [ "$OS_VERSION_ID" \< "22.04" ]; then
        err "需要 Ubuntu 22.04+，当前 $OS_VERSION $OS_VERSION_ID"
        exit 1
      fi
      ;;
    *)
      warn "未测试的发行版：$OS_ID $OS_VERSION，可能可以工作但不在支持列表"
      ;;
  esac
  ok "系统识别：$OS_ID $OS_VERSION ($OS_VERSION_ID)"
}

has_docker() {
  command -v docker >/dev/null 2>&1 && docker version >/dev/null 2>&1
}

install_docker() {
  info "开始安装 Docker..."
  $SUDO apt-get update -y >/dev/null 2>&1
  $SUDO apt-get install -y ca-certificates curl gnupg >/dev/null 2>&1

  # 1. 旧版本清理（忽略错误）
  $SUDO apt-get remove -y docker docker-engine docker.io containerd runc >/dev/null 2>&1 || true

  # 2. 添加 Docker 官方 GPG key
  $SUDO install -m 0755 -d /etc/apt/keyrings
  if ! curl -fsSL "https://download.docker.com/linux/$OS_ID/gpg" | \
       $SUDO gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes 2>/dev/null; then
    err "下载 Docker GPG key 失败，请检查网络"
    exit 1
  fi
  $SUDO chmod a+r /etc/apt/keyrings/docker.gpg

  # 3. 添加 apt 源
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS_ID \
    $OS_VERSION stable" | \
    $SUDO tee /etc/apt/sources.list.d/docker.list >/dev/null

  # 4. 装
  $SUDO apt-get update -y >/dev/null 2>&1
  $SUDO apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null 2>&1

  # 5. 启动服务
  $SUDO systemctl enable docker >/dev/null 2>&1 || warn "无法 enable docker（容器环境正常）"
  $SUDO systemctl start docker >/dev/null 2>&1 || warn "无法 start docker（容器环境正常）"

  if has_docker; then
    DOCKER_INSTALLED=1
    ok "Docker 安装完成：$(docker --version)"
    ok "Docker Compose：$(docker compose version)"
  else
    err "Docker 安装失败，请手动检查"
    exit 1
  fi
}

# 选择代码获取方式
fetch_source() {
  echo
  info "==================== 获取项目代码 ===================="

  # 优先用 ENV 配置，否则交互
  if [ -n "${CHOICE:-}" ]; then
    info "使用环境变量 CHOICE=$CHOICE"
  else
    echo "请选择获取方式："
    echo "  1) Git 克隆（推荐开发者）"
    echo "  2) 下载 Release tar.gz 包（推荐普通用户）"
    echo "  3) 使用当前目录（本地已有代码）"
    echo
    read -p "请输入 [1/2/3]，默认 2: " CHOICE
    CHOICE="${CHOICE:-2}"
  fi

  case "$CHOICE" in
    1)
      info "克隆仓库 $REPO_URL ..."
      $SUDO apt-get install -y git >/dev/null 2>&1 || true
      if [ -d "$APP_DIR/.git" ]; then
        warn "$APP_DIR 已是 git 仓库，跳过克隆"
      else
        git clone "$REPO_URL" "$APP_DIR" || {
          err "克隆失败，请检查网络或仓库地址"
          exit 1
        }
      fi
      SOURCE_FILE="git"
      ;;
    2)
      info "下载 $TARBALL_URL ..."
      mkdir -p "$APP_DIR"
      cd "$APP_DIR"
      if curl -fsSL -o app.tar.gz "$TARBALL_URL"; then
        tar -xzf app.tar.gz --strip-components=1
        rm -f app.tar.gz
        SOURCE_FILE="tarball"
      else
        warn "tar.gz 下载失败，尝试 git 兜底..."
        $SUDO apt-get install -y git >/dev/null 2>&1 || true
        git clone "$REPO_URL" "$APP_DIR.tmp" || {
          err "git 兜底也失败，请检查网络后重试"
          exit 1
        }
        rm -rf "$APP_DIR"
        mv "$APP_DIR.tmp" "$APP_DIR"
        SOURCE_FILE="git"
      fi
      ;;
    3)
      if [ -f "./docker-compose.yml" ]; then
        APP_DIR="$(pwd)"
        SOURCE_FILE="local"
      else
        err "当前目录不是 91-mvp 项目（缺少 docker-compose.yml）"
        exit 1
      fi
      ;;
    *)
      err "无效选项：$CHOICE"
      exit 1
      ;;
  esac

  ok "代码就绪：$APP_DIR（来源：$SOURCE_FILE）"
}

verify_source() {
  cd "$APP_DIR"
  for f in docker-compose.yml Dockerfile backend/go.mod src/main.tsx package.json; do
    if [ ! -f "$f" ] && [ ! -d "$(dirname "$f")" ]; then
      err "项目结构不完整，缺少：$f"
      exit 1
    fi
  done
  ok "项目结构校验通过"
}

# 端口占用检测
check_port() {
  if command -v ss >/dev/null && ss -tlnp 2>/dev/null | grep -q ":$APP_PORT "; then
    warn "端口 $APP_PORT 已被占用，启动后可能无法访问"
    read -p "是否继续？[y/N] " yn
    [[ "$yn" =~ ^[Yy]$ ]] || exit 1
  fi
}

build_and_start() {
  echo
  info "==================== 构建并启动 ===================="
  cd "$APP_DIR"

  # 拉镜像缓存
  $SUDO docker compose pull 2>/dev/null || true

  # 构建
  info "构建 Docker 镜像（首次约 3-5 分钟）..."
  $SUDO docker compose build

  # 后台启动
  info "启动服务..."
  $SUDO docker compose up -d

  # 等待就绪
  info "等待服务就绪..."
  for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
    sleep 3
    if curl -sf "http://localhost:$APP_PORT/api/sources" >/dev/null 2>&1; then
      ok "服务已就绪 ✓"
      return 0
    fi
    [ $i -eq 12 ] && warn "服务尚未响应，请稍后用 'docker compose logs' 查看"
  done
}

print_success() {
  echo
  echo -e "${GREEN}============================================================${NC}"
  echo -e "${GREEN}   91-MVP 部署成功！${NC}"
  echo -e "${GREEN}============================================================${NC}"
  echo
  echo "  访问地址："
  echo -e "    ${BLUE}http://服务器IP:$APP_PORT${NC}"
  echo -e "    ${BLUE}http://localhost:$APP_PORT${NC}（本机访问）"
  echo
  echo "  常用命令："
  echo "    cd $APP_DIR"
  echo "    sudo docker compose ps          # 查看运行状态"
  echo "    sudo docker compose logs -f     # 查看实时日志"
  echo "    sudo docker compose restart     # 重启"
  echo "    sudo docker compose down        # 停止"
  echo "    sudo docker compose up -d       # 启动"
  echo
  echo "  数据目录："
  echo "    $APP_DIR/data                  # SQLite 数据库"
  echo
  echo "  配置文件："
  echo "    $APP_DIR/docker-compose.yml"
  echo "    $APP_DIR/.env                  # 环境变量（首次启动后会自动生成）"
  echo
  echo -e "  ${YELLOW}下一步：${NC}"
  echo "    1. 浏览器打开上面的访问地址"
  echo "    2. 点击右上角「添加网盘」按钮"
  echo "    3. 填入你的 WebDAV 信息（Nextcloud/坚果云/群晖/ownCloud 等）"
  echo "    4. 添加后会自动扫描，扫描完成就能看片了"
  echo
  echo -e "  ${YELLOW}提示：${NC}"
  echo "    - 云服务器需要在安全组/防火墙开放 $APP_PORT 端口"
  echo "    - 建议配合 Nginx/Caddy 反向代理 + HTTPS（参见 README）"
  echo
}

# ============================================================================
#  主流程
# ============================================================================

main() {
  echo
  echo -e "${BLUE}============================================================${NC}"
  echo -e "${BLUE}   91-MVP · Debian 12 一键安装脚本${NC}"
  echo -e "${BLUE}============================================================${NC}"
  echo

  check_root
  detect_os

  # 装 Docker（已装则跳过）
  if has_docker; then
    ok "Docker 已安装：$(docker --version)"
  else
    install_docker
  fi

  # 获取代码
  fetch_source
  verify_source
  check_port

  # 构建启动
  build_and_start

  # 完成提示
  print_success
}

# 捕获 Ctrl+C
trap 'echo; err "用户中断"; exit 1' INT

main "$@"
