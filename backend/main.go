package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"
)

type Server struct {
	db       *DB
	distDir  string
	dataDir  string
}

type APIResponse struct {
	OK    bool        `json:"ok"`
	Data  interface{} `json:"data,omitempty"`
	Error string      `json:"error,omitempty"`
}

func writeJSON(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(APIResponse{OK: status < 400, Data: data})
}

func writeError(w http.ResponseWriter, status int, msg string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(APIResponse{OK: false, Error: msg})
}

func main() {
	addr := flag.String("addr", ":9191", "listen address")
	dataDir := flag.String("data", "./data", "data directory")
	distDir := flag.String("dist", "./dist", "frontend dist directory")
	flag.Parse()

	if err := os.MkdirAll(*dataDir, 0755); err != nil {
		log.Fatal(err)
	}

	db, err := InitDB(filepath.Join(*dataDir, "video-site.db"))
	if err != nil {
		log.Fatalf("init db: %v", err)
	}
	defer db.Close()

	s := &Server{
		db:      db,
		distDir: *distDir,
		dataDir: *dataDir,
	}

	r := chi.NewRouter()
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)
	r.Use(middleware.Timeout(60 * time.Second))
	r.Use(cors.Handler(cors.Options{
		AllowedOrigins: []string{"*"},
		AllowedMethods: []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders: []string{"*"},
	}))

	// API routes
	r.Route("/api", func(r chi.Router) {
		r.Get("/sources", s.handleListSources)
		r.Post("/sources", s.handleCreateSource)
		r.Delete("/sources/{id}", s.handleDeleteSource)
		r.Post("/sources/{id}/scan", s.handleScanSource)

		r.Get("/sources/{id}/videos", s.handleListVideos)
		r.Get("/videos/{id}", s.handleGetVideo)
		r.Get("/videos/{id}/stream", s.handleStreamVideo)
		r.Get("/videos/{id}/redirect", s.handleRedirectVideo)
	})

	// Serve frontend
	if _, err := os.Stat(*distDir); err == nil {
		r.Handle("/*", spaHandler(*distDir))
	}

	log.Printf("listening on %s, data=%s, dist=%s", *addr, *dataDir, *distDir)
	log.Fatal(http.ListenAndServe(*addr, r))
}

// spaHandler serves a single-page app from the dist directory
func spaHandler(distDir string) http.Handler {
	fs := http.Dir(distDir)
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		path := strings.TrimPrefix(r.URL.Path, "/")
		if path == "" {
			path = "index.html"
		}
		f, err := fs.Open(path)
		if err != nil {
			// fallback to index.html for SPA routing
			f, err = fs.Open("index.html")
			if err != nil {
				http.NotFound(w, r)
				return
			}
		}
		defer f.Close()
		stat, _ := f.Stat()
		if stat != nil && !stat.IsDir() {
			if strings.HasSuffix(path, ".js") {
				w.Header().Set("Content-Type", "application/javascript")
			} else if strings.HasSuffix(path, ".css") {
				w.Header().Set("Content-Type", "text/css")
			}
		}
		http.ServeContent(w, r, path, stat.ModTime(), readSeeker(f))
	})
}

func readSeeker(f http.File) io.ReadSeeker {
	// http.File is already a ReadSeeker; cast
	return f.(io.ReadSeeker)
}

// === Source handlers ===

func (s *Server) handleListSources(w http.ResponseWriter, r *http.Request) {
	sources, err := s.db.ListSources()
	if err != nil {
		writeError(w, 500, err.Error())
		return
	}
	writeJSON(w, 200, sources)
}

func (s *Server) handleCreateSource(w http.ResponseWriter, r *http.Request) {
	var src Source
	if err := json.NewDecoder(r.Body).Decode(&src); err != nil {
		writeError(w, 400, "invalid json")
		return
	}
	if src.URL == "" || src.Name == "" {
		writeError(w, 400, "name and url required")
		return
	}
	if src.Type == "" {
		src.Type = "webdav"
	}
	if src.BasePath == "" {
		src.BasePath = "/"
	}
	if err := s.db.CreateSource(&src); err != nil {
		writeError(w, 500, err.Error())
		return
	}
	writeJSON(w, 200, src)
}

func (s *Server) handleDeleteSource(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
	if err != nil {
		writeError(w, 400, "invalid id")
		return
	}
	if err := s.db.DeleteSource(id); err != nil {
		writeError(w, 500, err.Error())
		return
	}
	writeJSON(w, 200, map[string]string{"status": "deleted"})
}

func (s *Server) handleScanSource(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
	if err != nil {
		writeError(w, 400, "invalid id")
		return
	}
	go func() {
		if err := s.scanSource(id); err != nil {
			log.Printf("[scan] error: %v", err)
		}
	}()
	writeJSON(w, 200, map[string]string{"status": "scanning"})
}

// === Video handlers ===

func (s *Server) handleListVideos(w http.ResponseWriter, r *http.Request) {
	sourceID, err := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
	if err != nil {
		writeError(w, 400, "invalid source id")
		return
	}
	limit := 50
	offset := 0
	if l := r.URL.Query().Get("limit"); l != "" {
		if n, err := strconv.Atoi(l); err == nil {
			limit = n
		}
	}
	if o := r.URL.Query().Get("offset"); o != "" {
		if n, err := strconv.Atoi(o); err == nil {
			offset = n
		}
	}
	videos, err := s.db.ListVideos(sourceID, limit, offset)
	if err != nil {
		writeError(w, 500, err.Error())
		return
	}
	writeJSON(w, 200, videos)
}

func (s *Server) handleGetVideo(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
	if err != nil {
		writeError(w, 400, "invalid id")
		return
	}
	v, err := s.db.GetVideo(id)
	if err != nil {
		writeError(w, 404, "not found")
		return
	}
	writeJSON(w, 200, v)
}

// handleStreamVideo proxies video through server (consumes bandwidth)
func (s *Server) handleStreamVideo(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
	if err != nil {
		writeError(w, 400, "invalid id")
		return
	}
	v, err := s.db.GetVideo(id)
	if err != nil {
		writeError(w, 404, "not found")
		return
	}
	src, err := s.db.GetSource(v.SourceID)
	if err != nil {
		writeError(w, 500, err.Error())
		return
	}

	client, err := NewWebDAVClient(src.URL, src.Username, src.Password)
	if err != nil {
		writeError(w, 500, err.Error())
		return
	}

	stream, err := client.GetStream(v.Path)
	if err != nil {
		writeError(w, 502, err.Error())
		return
	}
	defer stream.Close()

	w.Header().Set("Content-Type", v.MimeType)
	w.Header().Set("Accept-Ranges", "bytes")
	if v.Size > 0 {
		w.Header().Set("Content-Length", strconv.FormatInt(v.Size, 10))
	}

	// Support Range requests
	rangeHeader := r.Header.Get("Range")
	if rangeHeader != "" {
		w.Header().Set("Content-Range", rangeHeader)
		w.WriteHeader(http.StatusPartialContent)
	}

	io.Copy(w, stream)
}

// handleRedirectVideo returns 302 to webdav direct URL (zero bandwidth)
func (s *Server) handleRedirectVideo(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
	if err != nil {
		writeError(w, 400, "invalid id")
		return
	}
	v, err := s.db.GetVideo(id)
	if err != nil {
		writeError(w, 404, "not found")
		return
	}
	src, err := s.db.GetSource(v.SourceID)
	if err != nil {
		writeError(w, 500, err.Error())
		return
	}

	client, err := NewWebDAVClient(src.URL, src.Username, src.Password)
	if err != nil {
		writeError(w, 500, err.Error())
		return
	}

	redirectURL, err := client.GetRedirectURL(v.Path)
	if err != nil {
		// Fallback to proxied stream
		http.Redirect(w, r, fmt.Sprintf("/api/videos/%d/stream", v.ID), http.StatusFound)
		return
	}

	http.Redirect(w, r, redirectURL, http.StatusFound)
}
