export interface Source {
  id: number
  name: string
  type: string
  url: string
  username: string
  base_path: string
  created_at: string
}

export interface Video {
  id: number
  path: string
  name: string
  size: number
  mime_type: string
  duration: number
  width: number
  height: number
  cover_path: string
  source_id: number
  created_at: string
}

async function request<T>(url: string, options?: RequestInit): Promise<T> {
  const resp = await fetch(url, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...options?.headers,
    },
  })
  if (!resp.ok) {
    throw new Error(`HTTP ${resp.status}`)
  }
  const json = await resp.json()
  if (!json.ok) {
    throw new Error(json.error || 'Unknown error')
  }
  return json.data
}

export const api = {
  listSources: () => request<Source[]>('/api/sources'),
  createSource: (data: Partial<Source> & { password: string }) =>
    request<Source>('/api/sources', {
      method: 'POST',
      body: JSON.stringify(data),
    }),
  deleteSource: (id: number) =>
    request<{ status: string }>(`/api/sources/${id}`, { method: 'DELETE' }),
  scanSource: (id: number) =>
    request<{ status: string }>(`/api/sources/${id}/scan`, { method: 'POST' }),
  listVideos: (sourceId: number, limit = 50, offset = 0) =>
    request<Video[]>(`/api/sources/${sourceId}/videos?limit=${limit}&offset=${offset}`),
  getVideo: (id: number) => request<Video>(`/api/videos/${id}`),
  streamUrl: (id: number) => `/api/videos/${id}/stream`,
  redirectUrl: (id: number) => `/api/videos/${id}/redirect`,
}
