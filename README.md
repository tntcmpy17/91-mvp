# 91 视频站 MVP

> 私有部署的 WebDAV 视频站，支持 B 站风格界面 + 302 重定向低带宽播放

## ✨ 功能特性

- ✅ **WebDAV 网盘接入** — 支持 Nextcloud / ownCloud / 坚果云 / 群晖 / 威联通等所有 WebDAV 网盘
- ✅ **B 站风格界面** — 双列瀑布流、播放器、分类侧边栏
- ✅ **302 重定向播放** — 不消耗服务器带宽
- ✅ **代理播放** — 兼容所有浏览器/网盘
- ✅ **自动扫描** — 一键扫描网盘中的视频文件
- ✅ **响应式** — 桌面/手机/平板自适应

## 🚀 快速开始（Docker）

```bash
# 1. 创建目录
mkdir video-site-91 && cd video-site-91

# 2. 下载 docker-compose.yml
curl -fsSL https://raw.githubusercontent.com/your-repo/91-mvp/main/docker-compose.yml -o docker-compose.yml
# 或者手动复制本项目里的 docker-compose.yml

# 3. 启动
docker compose up -d

# 4. 访问
打开 http://服务器IP:9191

# 5. 点击右上角"添加网盘"，填入你的 WebDAV 信息：
#    名称：随便取
#    地址：https://your-webdav-server.com/dav
#    用户名/密码：你的 WebDAV 账号
#    起始路径：/（默认根目录）

# 6. 扫描完成后就能看视频了
```

## 🛠️ 本地开发

### 后端
```bash
cd backend
go mod download
go run .
# 监听 :9191
```

### 前端
```bash
npm install
npm run dev
# 访问 http://localhost:5173
# Vite 会代理 /api 到 :9191
```

## 🐧 Debian 12 部署

### 1. 装 Docker

```bash
sudo apt update
sudo apt install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

### 2. 部署项目

```bash
# 克隆代码
git clone https://github.com/your-repo/91-mvp.git
cd 91-mvp

# 启动
sudo docker compose up -d

# 查看日志
sudo docker compose logs -f

# 验证
curl http://localhost:9191/api/sources
```

### 3. 配置 WebDAV 网盘

访问 http://服务器IP:9191，点击"添加网盘"。

**常见 WebDAV 服务地址：**

| 服务 | 地址格式 |
|------|----------|
| 坚果云 | `https://dav.jianguoyun.com/dav/` |
| Nextcloud | `https://your-domain.com/remote.php/dav/files/username/` |
| ownCloud | `https://your-domain.com/remote.php/webdav/` |
| 群晖 NAS | `https://nas-ip:5006/` |
| 威联通 NAS | `https://nas-ip:8080/` |

## 📁 目录结构

```
91-mvp/
├── backend/                # Go 后端
│   ├── main.go            # API + 路由
│   ├── webdav.go          # WebDAV 客户端
│   ├── scanner.go         # 视频扫描
│   ├── db.go              # SQLite
│   └── go.mod
├── src/                    # React 前端
│   ├── App.tsx
│   ├── components/
│   ├── pages/
│   └── lib/
├── Dockerfile
└── docker-compose.yml
```

## 🔌 API 文档

```
GET    /api/sources                  # 列出所有网盘源
POST   /api/sources                  # 添加网盘源
DELETE /api/sources/:id              # 删除网盘源
POST   /api/sources/:id/scan         # 触发扫描
GET    /api/sources/:id/videos       # 列出视频
GET    /api/videos/:id               # 获取视频详情
GET    /api/videos/:id/stream        # 代理播放（消耗服务器流量）
GET    /api/videos/:id/redirect      # 302 重定向（不消耗流量）
```

## ⚠️ 法律声明

本项目仅供个人学习/研究使用，请勿用于传播盗版资源。

## 📝 License

MIT
