# Stage 1: Build frontend
FROM node:24-slim AS frontend
WORKDIR /app

COPY package.json package-lock.json* ./
ENV NODE_ENV=development
RUN npm install --include=dev

COPY tsconfig.json vite.config.ts tailwind.config.js postcss.config.js index.html ./
COPY src/ src/

RUN npx vite build

# Stage 2: Build backend
FROM golang:1.23-bookworm AS backend
WORKDIR /app/backend

COPY backend/go.mod backend/go.sum* ./
RUN go mod download 2>/dev/null || go mod tidy

COPY backend/ ./
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/server .

# Stage 3: Runtime
FROM debian:bookworm-slim AS runtime
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl ffmpeg \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/video-site-91
COPY --from=backend /out/server ./server
COPY --from=frontend /app/dist ./dist

ENV VIDEO_PORT=9191 \
    VIDEO_DATA=/opt/video-site-91/data \
    VIDEO_DIST=/opt/video-site-91/dist

RUN mkdir -p /opt/video-site-91/data
VOLUME ["/opt/video-site-91/data"]
EXPOSE 9191

ENTRYPOINT ["/opt/video-site-91/server"]
CMD ["-addr", ":9191", "-data", "/opt/video-site-91/data", "-dist", "/opt/video-site-91/dist"]
