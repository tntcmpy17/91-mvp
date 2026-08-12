import { useEffect, useState } from 'react'
import VideoCard from '../components/VideoCard'
import { api, type Video, type Source } from '../lib/api'

interface Props {
  sources: Source[]
  activeSourceId: number | 'home'
}

export default function Home({ sources, activeSourceId }: Props) {
  const [videos, setVideos] = useState<Video[]>([])
  const [loading, setLoading] = useState(false)
  const [scanning, setScanning] = useState(false)
  const [error, setError] = useState('')

  const loadVideos = async () => {
    setLoading(true)
    setError('')
    try {
      const sourceIds = activeSourceId === 'home'
        ? sources.map((s) => s.id)
        : [activeSourceId]
      const all: Video[] = []
      for (const id of sourceIds) {
        const vs = await api.listVideos(id, 100, 0)
        all.push(...vs)
      }
      // sort by created_at desc
      all.sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime())
      setVideos(all)
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : '加载失败')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    loadVideos()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [activeSourceId, sources.length])

  const handleScan = async () => {
    const targets = activeSourceId === 'home'
      ? sources
      : sources.filter((s) => s.id === activeSourceId)
    if (targets.length === 0) return
    setScanning(true)
    try {
      for (const s of targets) {
        await api.scanSource(s.id)
      }
      // wait a bit then reload
      setTimeout(() => {
        loadVideos()
        setScanning(false)
      }, 3000)
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : '扫描失败')
      setScanning(false)
    }
  }

  return (
    <main className="flex-1 min-w-0">
      <div className="sticky top-14 bg-white border-b border-bili-100 z-30">
        <div className="max-w-7xl mx-auto px-4 py-3 flex items-center justify-between">
          <h2 className="text-lg font-medium">
            {activeSourceId === 'home'
              ? '全部视频'
              : sources.find((s) => s.id === activeSourceId)?.name || '视频列表'}
          </h2>
          <div className="text-sm text-bili-400">
            共 {videos.length} 个视频
            {scanning && <span className="ml-2 text-bili-blue">扫描中...</span>}
          </div>
        </div>
      </div>

      <div className="p-4 max-w-7xl mx-auto">
        {error && <div className="bg-red-50 text-red-600 px-4 py-3 rounded-lg mb-4">{error}</div>}

        {sources.length === 0 ? (
          <EmptyGuide />
        ) : loading ? (
          <Skeleton />
        ) : videos.length === 0 ? (
          <NoVideos onScan={handleScan} scanning={scanning} />
        ) : (
          <div className="video-grid">
            {videos.map((v) => <VideoCard key={v.id} video={v} />)}
          </div>
        )}
      </div>
    </main>
  )
}

function EmptyGuide() {
  return (
    <div className="py-20 text-center">
      <div className="text-6xl mb-4">📁</div>
      <h3 className="text-lg text-bili-500 mb-2">还没有网盘源</h3>
      <p className="text-sm text-bili-400 mb-4">点击右上角"添加网盘"，配置你的 WebDAV 网盘</p>
      <div className="max-w-md mx-auto text-left bg-white p-4 rounded-lg text-sm text-bili-600 space-y-2">
        <p><strong>支持的服务：</strong></p>
        <ul className="list-disc list-inside text-bili-500 space-y-1">
          <li>Nextcloud / ownCloud（自建）</li>
          <li>坚果云（国产）</li>
          <li>群晖 / 威联通 NAS</li>
          <li>任何支持 WebDAV 协议的网盘</li>
        </ul>
      </div>
    </div>
  )
}

function NoVideos({ onScan, scanning }: { onScan: () => void; scanning: boolean }) {
  return (
    <div className="py-20 text-center">
      <div className="text-6xl mb-4">🎬</div>
      <h3 className="text-lg text-bili-500 mb-2">还没有视频</h3>
      <p className="text-sm text-bili-400 mb-4">点击下方按钮扫描网盘中的视频文件</p>
      <button
        onClick={onScan}
        disabled={scanning}
        className="px-6 py-2 bg-bili-blue text-white rounded-lg text-sm font-medium hover:bg-bili-blue/90 disabled:opacity-50"
      >
        {scanning ? '扫描中...' : '立即扫描'}
      </button>
    </div>
  )
}

function Skeleton() {
  return (
    <div className="video-grid">
      {Array.from({ length: 12 }).map((_, i) => (
        <div key={i} className="animate-pulse">
          <div className="aspect-video bg-bili-100 rounded-lg" />
          <div className="mt-3 p-3 space-y-2">
            <div className="h-4 bg-bili-100 rounded w-full" />
            <div className="h-3 bg-bili-100 rounded w-2/3" />
          </div>
        </div>
      ))}
    </div>
  )
}
