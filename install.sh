#!/usr/bin/env bash
# ==============================================================================
#  91-MVP · 一键安装脚本（免 Docker / 兼容 Docker 双模式）
#  ------------------------------------------------------------------------------
#  默认：免 Docker，直接运行 Go 二进制 + 前端静态文件
#  可选：USE_DOCKER=1 切换到 Docker 部署
#  支持：Debian 11/12 / Ubuntu 22.04+
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

# ---------- 配置 ----------
APP_NAME="video-site-91"
APP_USER="video91"
APP_PORT="${APP_PORT:-9191}"
APP_DIR="/opt/$APP_NAME"
APP_DATA="/var/lib/$APP_NAME"
APP_LOG="/var/log/$APP_NAME"
REPO_URL="${REPO_URL:-https://github.com/tntcmpy17/91-mvp.git}"
TARBALL_URL="${TARBALL_URL:-https://github.com/tntcmpy17/91-mvp/releases/latest/download/91-mvp.tar.gz}"

# ---------- 默认无 Docker ----------
USE_DOCKER="${USE_DOCKER:-0}"
GO_VERSION="1.23.4"
NODE_VERSION="20"

# ============================================================================
#  工具函数
# ============================================================================

check_root() {
  if [ "$EUID" -ne 0 ]; then
    warn "需要 root 权限，将自动在需要时使用 sudo"
    SUDO="sudo"
  else
    SUDO=""
  fi
}

detect_os() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID="$ID"
    OS_VERSION_ID="$VERSION_ID"
  else
    err "无法识别系统"; exit 1
  fi

  case "$OS_ID" in
    debian)
      [ "$OS_VERSION_ID" -ge 11 ] || { err "需要 Debian 11+，当前 $OS_VERSION_ID"; exit 1; }
      ;;
    ubuntu)
      apt-get install -y software-properties-common >/dev/null 2>&1 || true
      add-apt-repository -y ppa:ubuntu-toolchain-r/test >/dev/null 2>&1 || true
      ;;
    *)
      warn "未测试的发行版：$OS_ID，可能可以工作"
      ;;
  esac
  ok "系统识别：$OS_ID $OS_VERSION_ID"
}

# ============================================================================
#  基础依赖安装
# ============================================================================

install_basics() {
  info "安装基础依赖..."
  $SUDO apt-get update -y >/dev/null 2>&1
  $SUDO apt-get install -y curl wget tar ca-certificates git build-essential ffmpeg \
    >/dev/null 2>&1
  ok "基础依赖已就绪"
}

# ============================================================================
#  Go 安装（无 Docker 模式必需）
# ============================================================================

need_go() {
  command -v go >/dev/null 2>&1 || return 0
  local v
  v=$(go version 2>/dev/null | awk '{print $3}' | sed 's/go//')
  local major
  major=$(echo "$v" | cut -d. -f1)
  [ "${major:-0}" -ge 1 ] && return 1
  return 0
}

install_go() {
  info "安装 Go $GO_VERSION..."
  cd /tmp
  if ! wget -q "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" -O go.tar.gz; then
    err "下载 Go 失败，请检查网络"
    exit 1
  fi
  $SUDO tar -C /usr/local -xzf go.tar.gz
  rm -f go.tar.gz

  # 加到 PATH
  cat > /etc/profile.d/go.sh <<'EOF'
export PATH=$PATH:/usr/local/go/bin
export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin
EOF
  chmod +x /etc/profile.d/go.sh

  # 链接到 /usr/local/bin
  $SUDO ln -sf /usr/local/go/bin/go /usr/local/bin/go
  $SUDO ln -sf /usr/local/go/bin/gofmt /usr/local/bin/gofmt

  ok "Go 安装完成：$(go version)"
}

# ============================================================================
#  Node.js 安装（无 Docker 模式构建前端用）
# ============================================================================

need_node() {
  command -v node >/dev/null 2>&1 || return 0
  local v
  v=$(node --version 2>/dev/null | sed 's/v//' | cut -d. -f1)
  [ "${v:-0}" -ge "$NODE_VERSION" ] && return 1
  return 0
}

install_node() {
  info "安装 Node.js $NODE_VERSION..."
  # 用 NodeSource 源
  curl -fsSL "https://deb.nodesource.com/setup_${NODE_VERSION}.x" | $SUDO bash - >/dev/null 2>&1
  $SUDO apt-get install -y nodejs >/dev/null 2>&1

  # 装 pnpm（项目用 npm 也行，但 pnpm 更快）
  if ! command -v pnpm >/dev/null; then
    $SUDO npm install -g pnpm >/dev/null 2>&1 || true
  fi

  ok "Node.js $(node --version) + npm $(npm --version)"
}

# ============================================================================
#  代码获取
# ============================================================================

fetch_source() {
  echo
  info "==================== 获取项目代码 ===================="

  if [ -n "${CHOICE:-}" ]; then
    info "使用环境变量 CHOICE=$CHOICE"
  else
    echo "请选择获取方式："
    echo "  1) Git 克隆（推荐）"
    echo "  2) 下载 Release tar.gz 包"
    echo "  3) 使用当前目录（本地已有代码）"
    echo
    read -p "请输入 [1/2/3]，默认 3: " CHOICE
    CHOICE="${CHOICE:-3}"
  fi

  case "$CHOICE" in
    1)
      info "克隆仓库 $REPO_URL ..."
      $SUDO apt-get install -y git >/dev/null 2>&1 || true
      TMP_DIR=$(mktemp -d)
      git clone "$REPO_URL" "$TMP_DIR" || {
        err "克隆失败"; rm -rf "$TMP_DIR"; exit 1;
      }
      SOURCE_FILE="git"
      COPY_FROM="$TMP_DIR"
      ;;
    2)
      info "下载 $TARBALL_URL ..."
      TMP_DIR=$(mktemp -d)
      cd "$TMP_DIR"
      if curl -fsSL -o app.tar.gz "$TARBALL_URL"; then
        tar -xzf app.tar.gz
        rm -f app.tar.gz
        SOURCE_FILE="tarball"
        COPY_FROM="$TMP_DIR"
      else
        err "下载失败"; rm -rf "$TMP_DIR"; exit 1
      fi
      ;;
    3)
      # 检查当前目录是否为 91-mvp 项目
      # 关键特征文件：docker-compose.yml + backend/ + package.json
      if [ -f "./docker-compose.yml" ] && [ -d "./backend" ] && [ -f "./package.json" ]; then
        COPY_FROM="$(pwd)"
        SOURCE_FILE="local"
      else
        # 尝试自动定位：脚本所在目录的父目录/同级
        # 优先用 $0（执行时的脚本路径），兜底用 BASH_SOURCE
        local _script="${0:-${BASH_SOURCE[0]}}"
        local SCRIPT_DIR
        if [ -n "$_script" ] && [ -f "$_script" ]; then
          SCRIPT_DIR="$(cd "$(dirname "$_script")" && pwd)"
        else
          SCRIPT_DIR="$(pwd)"
        fi

        for cand in \
          "$SCRIPT_DIR" \
          "$SCRIPT_DIR/91-mvp" \
          "$(dirname "$SCRIPT_DIR")/91-mvp" \
          "$SCRIPT_DIR/.."; do
          if [ -f "$cand/docker-compose.yml" ] && [ -d "$cand/backend" ] && [ -f "$cand/package.json" ]; then
            warn "在 $cand 找到了项目，自动切换到该目录"
            COPY_FROM="$cand"
            SOURCE_FILE="local"
            cd "$cand"
            break
          fi
        done

        if [ -z "${COPY_FROM:-}" ]; then
          err "当前目录不是 91-mvp 项目（缺少 docker-compose.yml 或 backend/）"
          err "脚本所在目录: $SCRIPT_DIR"
          err "当前目录: $(pwd)"
          err "请确认："
          err "  1) cd 进入 91-mvp 项目目录后再运行 install.sh"
          err "  2) 或者选 1/2 重新拉取代码"
          exit 1
        fi
      fi
      ;;
    *)
      err "无效选项：$CHOICE"; exit 1 ;;
  esac

  ok "代码就绪：$COPY_FROM（来源：$SOURCE_FILE）"
}

# ============================================================================
#  Docker 部署路径
# ============================================================================

has_docker() {
  command -v docker >/dev/null 2>&1 && docker version >/dev/null 2>&1
}

install_docker() {
  info "安装 Docker..."
  $SUDO apt-get update -y >/dev/null 2>&1
  $SUDO apt-get install -y ca-certificates curl gnupg >/dev/null 2>&1
  $SUDO apt-get remove -y docker docker-engine docker.io containerd runc >/dev/null 2>&1 || true

  $SUDO install -m 0755 -d /etc/apt/keyrings
  curl -fsSL "https://download.docker.com/linux/$OS_ID/gpg" | \
    $SUDO gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes 2>/dev/null
  $SUDO chmod a+r /etc/apt/keyrings/docker.gpg

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS_ID \
    $OS_VERSION_ID stable" | \
    $SUDO tee /etc/apt/sources.list.d/docker.list >/dev/null

  $SUDO apt-get update -y >/dev/null 2>&1
  $SUDO apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null 2>&1

  $SUDO systemctl enable docker >/dev/null 2>&1 || true
  $SUDO systemctl start docker >/dev/null 2>&1 || true

  has_docker && ok "Docker 安装完成：$(docker --version)" || { err "Docker 安装失败"; exit 1; }
}

deploy_docker() {
  echo
  info "==================== Docker 部署 ===================="
  $SUDO mkdir -p "$APP_DATA"
  $SUDO cp -r "$COPY_FROM/." "$APP_DIR/"
  cd "$APP_DIR"

  $SUDO docker compose pull 2>/dev/null || true
  $SUDO docker compose build
  $SUDO docker compose up -d

  for i in 1 2 3 4 5 6 7 8 9 10; do
    sleep 3
    curl -sf "http://localhost:$APP_PORT/api/sources" >/dev/null 2>&1 && { ok "服务已就绪 ✓"; return; }
  done
  warn "服务未响应，请用 'docker compose logs' 查看"
}

# ============================================================================
#  无 Docker 部署路径
# ============================================================================

create_user() {
  info "创建专用用户 $APP_USER..."
  if ! id "$APP_USER" >/dev/null 2>&1; then
    $SUDO useradd --system --no-create-home --shell /usr/sbin/nologin "$APP_USER" || true
  fi
  ok "用户 $APP_USER 已就绪"
}

deploy_native() {
  echo
  info "==================== 原生部署（无 Docker） ===================="

  # 1. 准备目录
  $SUDO mkdir -p "$APP_DIR" "$APP_DATA" "$APP_LOG"
  $SUDO chown -R "$APP_USER":"$APP_USER" "$APP_DATA" "$APP_LOG"

  # 2. 复制代码
  info "复制代码到 $APP_DIR..."
  $SUDO mkdir -p "$APP_DIR"
  $SUDO cp -r "$COPY_FROM/." "$APP_DIR/"
  $SUDO chown -R root:root "$APP_DIR"

  cd "$APP_DIR"

  # 3. 构建前端
  info "构建前端（首次约 2-3 分钟）..."
  if [ -f package.json ]; then
    $SUDO -u root npm install --include=dev >/dev/null 2>&1 || {
      err "npm install 失败"; exit 1
    }
    $SUDO -u root npx vite build || {
      err "前端构建失败"; exit 1
    }
    ok "前端构建完成"
  fi

  # 4. 构建后端
  info "构建后端 Go 二进制..."
  cd "$APP_DIR/backend"
  export PATH=$PATH:/usr/local/go/bin
  $SUDO -u root go mod download 2>/dev/null || $SUDO -u root go mod tidy
  CGO_ENABLED=0 $SUDO -u root go build -trimpath -ldflags="-s -w" -o "$APP_DIR/server" . || {
    err "Go 构建失败"; exit 1
  }
  $SUDO chmod +x "$APP_DIR/server"
  ok "后端构建完成：$APP_DIR/server"

  # 5. 写 systemd 服务
  info "注册 systemd 服务..."
  $SUDO tee /etc/systemd/system/$APP_NAME.service >/dev/null <<EOF
[Unit]
Description=91 Video Site MVP
After=network.target

[Service]
Type=simple
User=$APP_USER
Group=$APP_USER
WorkingDirectory=$APP_DIR
ExecStart=$APP_DIR/server -addr :$APP_PORT -data $APP_DATA -dist $APP_DIR/dist
Restart=on-failure
RestartSec=5s
LimitNOFILE=65535
StandardOutput=append:$APP_LOG/server.log
StandardError=append:$APP_LOG/server.log

[Install]
WantedBy=multi-user.target
EOF

  $SUDO systemctl daemon-reload
  $SUDO systemctl enable "$APP_NAME" >/dev/null 2>&1
  $SUDO systemctl restart "$APP_NAME"

  # 6. 健康检查
  info "等待服务启动..."
  for i in 1 2 3 4 5 6 7 8 9 10; do
    sleep 2
    if curl -sf "http://localhost:$APP_PORT/api/sources" >/dev/null 2>&1; then
      ok "服务已就绪 ✓"
      return
    fi
  done
  warn "服务未立即响应，可通过 'systemctl status $APP_NAME' 查看"
}

# ============================================================================
#  完成
# ============================================================================

print_success() {
  echo
  echo -e "${GREEN}============================================================${NC}"
  echo -e "${GREEN}   91-MVP 部署成功！${NC}"
  echo -e "${GREEN}============================================================${NC}"
  echo
  echo "  访问地址："
  echo -e "    ${BLUE}http://服务器IP:$APP_PORT${NC}"
  echo -e "    ${BLUE}http://localhost:$APP_PORT${NC}（本机）"
  echo
  echo "  服务管理（systemd）："
  echo "    sudo systemctl status $APP_NAME   # 查看状态"
  echo "    sudo systemctl restart $APP_NAME  # 重启"
  echo "    sudo systemctl stop $APP_NAME     # 停止"
  echo "    sudo journalctl -u $APP_NAME -f   # 实时日志"
  echo "    tail -f $APP_LOG/server.log       # 应用日志"
  echo
  echo "  数据目录："
  echo "    $APP_DATA                         # SQLite 数据库"
  echo
  echo "  安装目录："
  echo "    $APP_DIR"
  echo
  echo -e "  ${YELLOW}下一步：${NC}"
  echo "    1. 浏览器打开 http://服务器IP:$APP_PORT"
  echo "    2. 点击右上角「添加网盘」按钮"
  echo "    3. 填入 WebDAV 信息（Nextcloud/坚果云/群晖/ownCloud）"
  echo "    4. 自动扫描完成后即可看片"
  echo
  echo -e "  ${YELLOW}提示：${NC}"
  echo "    - 云服务器需要在安全组/防火墙开放 $APP_PORT 端口"
  echo "    - 升级：重新运行 install.sh 即可（会自动覆盖代码）"
  echo
}

# ============================================================================
#  主流程
# ============================================================================

main() {
  echo
  echo -e "${BLUE}============================================================${NC}"
  echo -e "${BLUE}   91-MVP · 一键安装脚本${NC}"
  echo -e "${BLUE}============================================================${NC}"
  echo

  check_root
  detect_os
  install_basics

  # 根据 USE_DOCKER 选择路径
  if [ "$USE_DOCKER" = "1" ] || [ "$USE_DOCKER" = "true" ]; then
    info "部署模式：Docker (USE_DOCKER=$USE_DOCKER)"
    if ! has_docker; then
      install_docker
    else
      ok "Docker 已安装：$(docker --version)"
    fi
    fetch_source
    deploy_docker
  else
    info "部署模式：原生 (免 Docker)"
    install_go
    install_node
    fetch_source
    create_user
    deploy_native
  fi

  print_success
}

trap 'echo; err "用户中断"; exit 1' INT

main "$@"
