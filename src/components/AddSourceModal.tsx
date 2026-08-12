import { useState } from 'react'
import { X } from 'lucide-react'
import { api, type Source } from '../lib/api'

interface Props {
  open: boolean
  onClose: () => void
  onCreated: (s: Source) => void
}

export default function AddSourceModal({ open, onClose, onCreated }: Props) {
  const [name, setName] = useState('')
  const [url, setUrl] = useState('')
  const [username, setUsername] = useState('')
  const [password, setPassword] = useState('')
  const [basePath, setBasePath] = useState('/')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')

  const submit = async () => {
    setError('')
    if (!name || !url) {
      setError('名称和地址必填')
      return
    }
    setLoading(true)
    try {
      const source = await api.createSource({ name, url, username, password, base_path: basePath, type: 'webdav' })
      onCreated(source)
      onClose()
      // reset
      setName(''); setUrl(''); setUsername(''); setPassword(''); setBasePath('/')
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : '未知错误')
    } finally {
      setLoading(false)
    }
  }

  if (!open) return null

  return (
    <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4" onClick={onClose}>
      <div className="bg-white rounded-xl max-w-md w-full p-6" onClick={(e) => e.stopPropagation()}>
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-lg font-medium">添加网盘源</h2>
          <button onClick={onClose} className="p-1 hover:bg-bili-50 rounded"><X className="w-5 h-5" /></button>
        </div>

        <div className="space-y-3">
          <div>
            <label className="block text-sm text-bili-500 mb-1">名称</label>
            <input
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="我的网盘"
              className="w-full px-3 py-2 bg-bili-50 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-bili-blue/30"
            />
          </div>
          <div>
            <label className="block text-sm text-bili-500 mb-1">WebDAV 地址</label>
            <input
              value={url}
              onChange={(e) => setUrl(e.target.value)}
              placeholder="https://dav.example.com/dav"
              className="w-full px-3 py-2 bg-bili-50 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-bili-blue/30"
            />
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-sm text-bili-500 mb-1">用户名</label>
              <input
                value={username}
                onChange={(e) => setUsername(e.target.value)}
                placeholder="可选"
                className="w-full px-3 py-2 bg-bili-50 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-bili-blue/30"
              />
            </div>
            <div>
              <label className="block text-sm text-bili-500 mb-1">密码</label>
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="可选"
                className="w-full px-3 py-2 bg-bili-50 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-bili-blue/30"
              />
            </div>
          </div>
          <div>
            <label className="block text-sm text-bili-500 mb-1">起始路径</label>
            <input
              value={basePath}
              onChange={(e) => setBasePath(e.target.value)}
              placeholder="/"
              className="w-full px-3 py-2 bg-bili-50 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-bili-blue/30"
            />
          </div>

          {error && <div className="text-sm text-red-500 bg-red-50 px-3 py-2 rounded">{error}</div>}

          <button
            onClick={submit}
            disabled={loading}
            className="w-full py-2 bg-bili-blue text-white rounded-lg text-sm font-medium hover:bg-bili-blue/90 disabled:opacity-50"
          >
            {loading ? '添加中...' : '添加'}
          </button>
        </div>

        <div className="mt-4 p-3 bg-bili-50 rounded-lg text-xs text-bili-500">
          💡 支持任何 WebDAV 协议的网盘：Nextcloud、ownCloud、坚果云、群晖、威联通等
        </div>
      </div>
    </div>
  )
}
