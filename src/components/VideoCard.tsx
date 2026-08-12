import { Play } from 'lucide-react'
import { Link } from 'react-router-dom'
import type { Video } from '../lib/api'

interface VideoCardProps {
  video: Video
}

const formatSize = (bytes: number): string => {
  if (bytes < 1024) return `${bytes} B`
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`
  if (bytes < 1024 * 1024 * 1024) return `${(bytes / 1024 / 1024).toFixed(1)} MB`
  return `${(bytes / 1024 / 1024 / 1024).toFixed(2)} GB`
}

const formatDate = (iso: string): string => {
  try {
    const d = new Date(iso)
    return d.toLocaleDateString('zh-CN', { month: '2-digit', day: '2-digit' })
  } catch {
    return ''
  }
}

export default function VideoCard({ video }: VideoCardProps) {
  return (
    <Link to={`/video/${video.id}`} className="video-card group">
      <div className="relative aspect-video bg-gradient-to-br from-bili-blue/10 to-bili-pink/10 overflow-hidden">
        <div className="absolute inset-0 flex items-center justify-center">
          <Play className="w-16 h-16 text-bili-blue/30 group-hover:text-bili-blue/60 group-hover:scale-110 transition-all" />
        </div>
        <div className="cover-overlay" />
        <div className="duration-badge">{formatSize(video.size)}</div>
        <div className="absolute top-2 left-2 flex items-center gap-1 bg-black/60 text-white text-xs px-1.5 py-0.5 rounded">
          <Play className="w-3 h-3 fill-current" />
          <span>视频</span>
        </div>
      </div>
      <div className="p-3">
        <h3 className="text-sm font-medium text-bili-800 line-clamp-2 leading-snug min-h-[2.5em]">
          {video.name}
        </h3>
        <div className="mt-2 flex items-center justify-between text-xs text-bili-400">
          <span className="truncate">{video.mime_type}</span>
          <span>{formatDate(video.created_at)}</span>
        </div>
      </div>
    </Link>
  )
}
