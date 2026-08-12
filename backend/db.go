package main

import (
	"database/sql"
	"log"
	"time"

	_ "modernc.org/sqlite"
)

type Video struct {
	ID         int64     `json:"id"`
	Path       string    `json:"path"`
	Name       string    `json:"name"`
	Size       int64     `json:"size"`
	MimeType   string    `json:"mime_type"`
	Duration   int       `json:"duration"`
	Width      int       `json:"width"`
	Height     int       `json:"height"`
	CoverPath  string    `json:"cover_path"`
	SourceID   int64     `json:"source_id"`
	CreatedAt  time.Time `json:"created_at"`
}

type Source struct {
	ID        int64     `json:"id"`
	Name      string    `json:"name"`
	Type      string    `json:"type"` // webdav
	URL       string    `json:"url"`
	Username  string    `json:"username"`
	Password  string    `json:"-"`
	BasePath  string    `json:"base_path"`
	CreatedAt time.Time `json:"created_at"`
}

type DB struct {
	conn *sql.DB
}

func InitDB(path string) (*DB, error) {
	conn, err := sql.Open("sqlite", path)
	if err != nil {
		return nil, err
	}

	db := &DB{conn: conn}
	if err := db.migrate(); err != nil {
		return nil, err
	}
	return db, nil
}

func (db *DB) migrate() error {
	schema := `
	CREATE TABLE IF NOT EXISTS sources (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		name TEXT NOT NULL,
		type TEXT NOT NULL,
		url TEXT NOT NULL,
		username TEXT,
		password TEXT,
		base_path TEXT DEFAULT '/',
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
	);

	CREATE TABLE IF NOT EXISTS videos (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		path TEXT NOT NULL,
		name TEXT NOT NULL,
		size INTEGER DEFAULT 0,
		mime_type TEXT,
		duration INTEGER DEFAULT 0,
		width INTEGER DEFAULT 0,
		height INTEGER DEFAULT 0,
		cover_path TEXT,
		source_id INTEGER NOT NULL,
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
		UNIQUE(source_id, path),
		FOREIGN KEY (source_id) REFERENCES sources(id) ON DELETE CASCADE
	);

	CREATE INDEX IF NOT EXISTS idx_videos_source ON videos(source_id);
	CREATE INDEX IF NOT EXISTS idx_videos_created ON videos(created_at DESC);
	`
	_, err := db.conn.Exec(schema)
	return err
}

func (db *DB) Close() error {
	return db.conn.Close()
}

// Source CRUD
func (db *DB) CreateSource(s *Source) error {
	res, err := db.conn.Exec(
		`INSERT INTO sources (name, type, url, username, password, base_path) VALUES (?, ?, ?, ?, ?, ?)`,
		s.Name, s.Type, s.URL, s.Username, s.Password, s.BasePath,
	)
	if err != nil {
		return err
	}
	id, _ := res.LastInsertId()
	s.ID = id
	return nil
}

func (db *DB) ListSources() ([]Source, error) {
	rows, err := db.conn.Query(`SELECT id, name, type, url, username, base_path, created_at FROM sources ORDER BY id`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var sources []Source
	for rows.Next() {
		var s Source
		if err := rows.Scan(&s.ID, &s.Name, &s.Type, &s.URL, &s.Username, &s.BasePath, &s.CreatedAt); err != nil {
			return nil, err
		}
		sources = append(sources, s)
	}
	return sources, nil
}

func (db *DB) GetSource(id int64) (*Source, error) {
	var s Source
	err := db.conn.QueryRow(
		`SELECT id, name, type, url, username, password, base_path, created_at FROM sources WHERE id = ?`, id,
	).Scan(&s.ID, &s.Name, &s.Type, &s.URL, &s.Username, &s.Password, &s.BasePath, &s.CreatedAt)
	if err != nil {
		return nil, err
	}
	return &s, nil
}

func (db *DB) DeleteSource(id int64) error {
	_, err := db.conn.Exec(`DELETE FROM sources WHERE id = ?`, id)
	return err
}

// Video CRUD
func (db *DB) UpsertVideo(v *Video) error {
	res, err := db.conn.Exec(`
		INSERT INTO videos (path, name, size, mime_type, source_id)
		VALUES (?, ?, ?, ?, ?)
		ON CONFLICT(source_id, path) DO UPDATE SET
			name = excluded.name,
			size = excluded.size,
			mime_type = excluded.mime_type
	`, v.Path, v.Name, v.Size, v.MimeType, v.SourceID)
	if err != nil {
		return err
	}
	id, _ := res.LastInsertId()
	v.ID = id
	return nil
}

func (db *DB) ListVideos(sourceID int64, limit, offset int) ([]Video, error) {
	rows, err := db.conn.Query(`
		SELECT id, path, name, size, mime_type, duration, width, height, cover_path, source_id, created_at
		FROM videos
		WHERE source_id = ?
		ORDER BY created_at DESC
		LIMIT ? OFFSET ?
	`, sourceID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var videos []Video
	for rows.Next() {
		var v Video
		if err := rows.Scan(&v.ID, &v.Path, &v.Name, &v.Size, &v.MimeType, &v.Duration, &v.Width, &v.Height, &v.CoverPath, &v.SourceID, &v.CreatedAt); err != nil {
			return nil, err
		}
		videos = append(videos, v)
	}
	return videos, nil
}

func (db *DB) GetVideo(id int64) (*Video, error) {
	var v Video
	err := db.conn.QueryRow(`
		SELECT id, path, name, size, mime_type, duration, width, height, cover_path, source_id, created_at
		FROM videos WHERE id = ?
	`, id).Scan(&v.ID, &v.Path, &v.Name, &v.Size, &v.MimeType, &v.Duration, &v.Width, &v.Height, &v.CoverPath, &v.SourceID, &v.CreatedAt)
	if err != nil {
		return nil, err
	}
	return &v, nil
}

func (db *DB) CountVideos(sourceID int64) (int, error) {
	var n int
	err := db.conn.QueryRow(`SELECT COUNT(*) FROM videos WHERE source_id = ?`, sourceID).Scan(&n)
	return n, err
}

// Helper for safe close
func safeClose(rows *sql.Rows) {
	if err := rows.Close(); err != nil {
		log.Printf("rows close error: %v", err)
	}
}
