import { useEffect, useState } from 'react'
import { BrowserRouter, Routes, Route } from 'react-router-dom'
import Navbar from './components/Navbar'
import Sidebar from './components/Sidebar'
import AddSourceModal from './components/AddSourceModal'
import Home from './pages/Home'
import VideoDetail from './pages/VideoDetail'
import { api, type Source } from './lib/api'

function AppLayout() {
  const [sidebarOpen, setSidebarOpen] = useState(false)
  const [sources, setSources] = useState<Source[]>([])
  const [activeSourceId, setActiveSourceId] = useState<number | 'home'>('home')
  const [showAddModal, setShowAddModal] = useState(false)

  const loadSources = async () => {
    try {
      const ss = await api.listSources()
      setSources(ss)
    } catch (e) {
      console.error('加载网盘源失败:', e)
    }
  }

  useEffect(() => {
    loadSources()
  }, [])

  const handleSourceCreated = (s: Source) => {
    setSources((prev) => [...prev, s])
    // auto-scan
    api.scanSource(s.id).catch(() => {})
  }

  const handleDeleteSource = async (id: number) => {
    if (!confirm('确认删除这个网盘源？相关视频也会被删除。')) return
    try {
      await api.deleteSource(id)
      setSources((prev) => prev.filter((s) => s.id !== id))
      if (activeSourceId === id) setActiveSourceId('home')
    } catch (e) {
      alert('删除失败：' + (e instanceof Error ? e.message : '未知错误'))
    }
  }

  return (
    <div className="min-h-screen bg-bili-50">
      <Navbar
        onMenuClick={() => setSidebarOpen(true)}
        onAddSource={() => setShowAddModal(true)}
      />
      <div className="flex max-w-7xl mx-auto">
        <Sidebar
          open={sidebarOpen}
          onClose={() => setSidebarOpen(false)}
          sources={sources}
          activeId={activeSourceId}
          onSelect={setActiveSourceId}
          onDelete={handleDeleteSource}
        />
        <Routes>
          <Route path="/" element={<Home sources={sources} activeSourceId={activeSourceId} />} />
          <Route path="/video/:id" element={<VideoDetail />} />
        </Routes>
      </div>

      <AddSourceModal
        open={showAddModal}
        onClose={() => setShowAddModal(false)}
        onCreated={handleSourceCreated}
      />
    </div>
  )
}

export default function App() {
  return (
    <BrowserRouter>
      <AppLayout />
    </BrowserRouter>
  )
}
