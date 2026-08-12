import { useEffect, useRef, useState } from 'react'
import { useParams, Link } from 'react-router-dom'
import { ArrowLeft, Download } from 'lucide-react'
import Artplayer from 'artplayer'
import Hls from 'hls.js'
import { api, type Video } from '../lib/api'

export default function VideoDetail() {
  const { id } = useParams<{ id: string }>()
  const videoId = Number(id)
  const [video, setVideo] = useState<Video | null>(null)
  const [error, setError] = useState('')
  const playerRef = useRef<HTMLDivElement>(null)
  const artRef = useRef<Artplayer | null>(null)

  useEffect(() => {
    api.getVideo(videoId)
      .then(setVideo)
      .catch((e: unknown) => setError(e instanceof Error ? e.message : '加载失败'))
  }, [videoId])

  useEffect(() => {
    if (!video || !playerRef.current) return

    const streamUrl = api.streamUrl(video.id)
    const isHls = video.mime_type === 'application/x-mpegURL' || streamUrl.includes('.m3u8')

    const art = new Artplayer({
      container: playerRef.current,
      url: streamUrl,
      title: video.name,
      volume: 0.8,
      isLive: false,
      muted: false,
      autoplay: false,
      pip: true,
      screenshot: true,
      setting: true,
      playbackRate: true,
      aspectRatio: true,
      fullscreen: true,
      miniProgressBar: true,
      autoMini: true,
      // HLS support
      ...(isHls && {
        type: 'm3u8',
        customType: {
          m3u8: (video: HTMLVideoElement, url: string) => {
            if (Hls.isSupported()) {
              const hls = new Hls()
              hls.loadSource(url)
              hls.attachMedia(video)
              return () => hls.destroy()
            }
          },
        },
      }),
    })

    artRef.current = art
    return () => {
      art.destroy()
      artRef.current = null
    }
  }, [video])

  if (error) {
    return (
      <div className="p-8 text-center">
        <div className="text-red-500 mb-4">{error}</div>
        <Link to="/" className="text-bili-blue hover:underline">返回首页</Link>
      </div>
    )
  }

  if (!video) {
    return (
      <div className="p-8 text-center">
        <div className="animate-pulse">加载中...</div>
      </div>
    )
  }

  return (
    <main className="flex-1 min-w-0">
      <div className="max-w-7xl mx-auto px-4 py-4">
        <Link to="/" className="inline-flex items-center gap-1 text-sm text-bili-500 hover:text-bili-blue mb-4">
          <ArrowLeft className="w-4 h-4" />
          返回
        </Link>

        <div className="grid lg:grid-cols-3 gap-6">
          <div className="lg:col-span-2">
            <div className="aspect-video bg-black rounded-lg overflow-hidden">
              <div ref={playerRef} className="w-full h-full" />
            </div>

            <div className="mt-4">
              <h1 className="text-xl font-medium text-bili-800">{video.name}</h1>
              <div className="mt-2 flex flex-wrap gap-4 text-sm text-bili-400">
                <span>类型：{video.mime_type}</span>
                <span>大小：{formatSize(video.size)}</span>
                {video.duration > 0 && <span>时长：{formatDuration(video.duration)}</span>}
                <span>添加时间：{new Date(video.created_at).toLocaleString('zh-CN')}</span>
              </div>
            </div>
          </div>

          <aside>
            <div className="bg-white rounded-lg p-4">
              <h3 className="text-sm font-medium mb-3">播放选项</h3>
              <div className="space-y-2">
                <a
                  href={api.streamUrl(video.id)}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="block px-3 py-2 text-sm text-center bg-bili-50 hover:bg-bili-100 rounded-lg"
                >
                  直接播放（代理模式）
                </a>
                <a
                  href={api.redirectUrl(video.id)}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="block px-3 py-2 text-sm text-center bg-bili-blue text-white hover:bg-bili-blue/90 rounded-lg"
                >
                  302 重定向（不消耗服务器流量）
                </a>
                <a
                  href={api.streamUrl(video.id)}
                  download={video.name}
                  className="flex items-center justify-center gap-1 px-3 py-2 text-sm text-center bg-bili-50 hover:bg-bili-100 rounded-lg"
                >
                  <Download className="w-3 h-3" />
                  下载视频
                </a>
              </div>

              <div className="mt-4 pt-4 border-t border-bili-100 text-xs text-bili-400 space-y-1">
                <p>💡 302 重定向模式：服务器不做代理，浏览器直连网盘，<strong>不消耗服务器流量</strong></p>
                <p>⚠️ 仅 WebDAV 网盘支持 302 模式</p>
              </div>
            </div>
          </aside>
        </div>
      </div>
    </main>
  )
}

function formatSize(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`
  if (bytes < 1024 * 1024 * 1024) return `${(bytes / 1024 / 1024).toFixed(1)} MB`
  return `${(bytes / 1024 / 1024 / 1024).toFixed(2)} GB`
}

function formatDuration(seconds: number): string {
  const h = Math.floor(seconds / 3600)
  const m = Math.floor((seconds % 3600) / 60)
  const s = Math.floor(seconds % 60)
  if (h > 0) return `${h}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`
  return `${m}:${String(s).padStart(2, '0')}`
}
