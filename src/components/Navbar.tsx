import { Search, FolderPlus, RefreshCw, Menu } from 'lucide-react'

interface NavbarProps {
  onSearch?: (q: string) => void
  onAddSource?: () => void
  onScan?: () => void
  onMenuClick?: () => void
  scanning?: boolean
}

export default function Navbar({ onSearch, onAddSource, onScan, onMenuClick, scanning }: NavbarProps) {
  return (
    <header className="sticky top-0 z-50 bg-white/95 backdrop-blur-sm border-b border-bili-100">
      <div className="max-w-7xl mx-auto px-4 h-14 flex items-center gap-4">
        <div className="flex items-center gap-3">
          {onMenuClick && (
            <button onClick={onMenuClick} className="lg:hidden p-2 hover:bg-bili-50 rounded-lg">
              <Menu className="w-5 h-5" />
            </button>
          )}
          <a href="/" className="flex items-center gap-2">
            <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-bili-blue to-bili-pink flex items-center justify-center text-white font-bold text-sm">
              91
            </div>
            <span className="hidden sm:inline font-medium text-bili-800">视频站</span>
          </a>
        </div>

        <form
          onSubmit={(e) => {
            e.preventDefault()
            const fd = new FormData(e.currentTarget)
            onSearch?.(String(fd.get('q') || ''))
          }}
          className="flex-1 max-w-xl"
        >
          <div className="relative">
            <input
              name="q"
              placeholder="搜索视频..."
              className="w-full pl-4 pr-12 py-2 bg-bili-50 border border-transparent rounded-full text-sm focus:outline-none focus:bg-white focus:border-bili-blue/30 transition-all"
            />
            <button type="submit" className="absolute right-1 top-1/2 -translate-y-1/2 p-2 text-bili-400 hover:text-bili-blue">
              <Search className="w-4 h-4" />
            </button>
          </div>
        </form>

        <div className="flex items-center gap-1">
          {onScan && (
            <button
              onClick={onScan}
              disabled={scanning}
              className="flex items-center gap-1.5 px-3 py-1.5 text-sm text-bili-500 hover:bg-bili-50 rounded-lg disabled:opacity-50"
            >
              <RefreshCw className={`w-4 h-4 ${scanning ? 'animate-spin' : ''}`} />
              <span className="hidden sm:inline">{scanning ? '扫描中' : '扫描'}</span>
            </button>
          )}
          {onAddSource && (
            <button
              onClick={onAddSource}
              className="flex items-center gap-1.5 px-3 py-1.5 text-sm text-white bg-bili-blue hover:bg-bili-blue/90 rounded-lg"
            >
              <FolderPlus className="w-4 h-4" />
              <span className="hidden sm:inline">添加网盘</span>
            </button>
          )}
        </div>
      </div>
    </header>
  )
}
