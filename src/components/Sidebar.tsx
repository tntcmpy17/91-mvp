import { Home, Folder, X, Trash2 } from 'lucide-react'
import type { Source } from '../lib/api'

interface SidebarProps {
  open: boolean
  onClose: () => void
  sources: Source[]
  activeId: number | 'home'
  onSelect: (id: number | 'home') => void
  onDelete?: (id: number) => void
}

export default function Sidebar({ open, onClose, sources, activeId, onSelect, onDelete }: SidebarProps) {
  return (
    <>
      {open && <div className="lg:hidden fixed inset-0 bg-black/50 z-40" onClick={onClose} />}
      <aside
        className={`
          fixed lg:sticky top-14 left-0 h-[calc(100vh-3.5rem)] w-56 bg-white border-r border-bili-100 z-40
          transition-transform duration-300 overflow-y-auto
          ${open ? 'translate-x-0' : '-translate-x-full lg:translate-x-0'}
        `}
      >
        <div className="flex items-center justify-between p-4 lg:hidden">
          <span className="font-medium">网盘源</span>
          <button onClick={onClose} className="p-1 hover:bg-bili-50 rounded">
            <X className="w-4 h-4" />
          </button>
        </div>

        <nav className="p-2 space-y-0.5">
          <button
            onClick={() => { onSelect('home'); onClose() }}
            className={`w-full flex items-center gap-3 px-3 py-2 rounded-lg text-sm transition-colors
              ${activeId === 'home' ? 'bg-bili-blue/10 text-bili-blue font-medium' : 'text-bili-600 hover:bg-bili-50'}`}
          >
            <Home className="w-4 h-4" />
            <span>首页</span>
          </button>

          <div className="px-3 pt-4 pb-2 text-xs text-bili-400 uppercase tracking-wider">网盘源</div>

          {sources.length === 0 ? (
            <div className="px-3 py-4 text-xs text-bili-400">还没有网盘源，点击右上角"添加网盘"</div>
          ) : (
            sources.map((src) => (
              <div
                key={src.id}
                className={`group flex items-center gap-2 px-3 py-2 rounded-lg text-sm transition-colors cursor-pointer
                  ${activeId === src.id ? 'bg-bili-blue/10 text-bili-blue font-medium' : 'text-bili-600 hover:bg-bili-50'}`}
              >
                <button
                  onClick={() => { onSelect(src.id); onClose() }}
                  className="flex items-center gap-3 flex-1 min-w-0"
                >
                  <Folder className="w-4 h-4 flex-shrink-0" />
                  <span className="truncate">{src.name}</span>
                </button>
                {onDelete && (
                  <button
                    onClick={(e) => { e.stopPropagation(); onDelete(src.id) }}
                    className="opacity-0 group-hover:opacity-100 p-1 hover:bg-red-50 hover:text-red-500 rounded transition-all"
                  >
                    <Trash2 className="w-3 h-3" />
                  </button>
                )}
              </div>
            ))
          )}
        </nav>
      </aside>
    </>
  )
}
