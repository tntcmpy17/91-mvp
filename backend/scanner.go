package main

import (
	"log"
	"path"
)

func (s *Server) scanSource(sourceID int64) error {
	src, err := s.db.GetSource(sourceID)
	if err != nil {
		return err
	}

	client, err := NewWebDAVClient(src.URL, src.Username, src.Password)
	if err != nil {
		return err
	}

	log.Printf("[scanner] scanning source %d (%s) at %s%s", src.ID, src.Name, src.URL, src.BasePath)

	base := src.BasePath
	if base == "" {
		base = "/"
	}

	items, err := client.ScanRecursive(base, DefaultVideoExts)
	if err != nil {
		return err
	}

	log.Printf("[scanner] found %d videos in source %d", len(items), src.ID)

	for _, item := range items {
		mime := item.ContentType
		if mime == "" {
			mime = "video/mp4"
		}
		v := &Video{
			Path:     item.Path,
			Name:     item.Name,
			Size:     item.Size,
			MimeType: mime,
			SourceID: src.ID,
		}
		if err := s.db.UpsertVideo(v); err != nil {
			log.Printf("[scanner] upsert failed for %s: %v", item.Path, err)
		}
	}

	// Clear videos that no longer exist
	if err := s.cleanupMissingVideos(src.ID, items); err != nil {
		log.Printf("[scanner] cleanup failed: %v", err)
	}

	return nil
}

func (s *Server) cleanupMissingVideos(sourceID int64, current []WebDAVItem) error {
	existing, err := s.db.ListVideos(sourceID, 10000, 0)
	if err != nil {
		return err
	}

	currentPaths := make(map[string]bool)
	for _, item := range current {
		currentPaths[path.Clean(item.Path)] = true
	}

	for _, v := range existing {
		if !currentPaths[path.Clean(v.Path)] {
			log.Printf("[scanner] removing missing video %d (%s)", v.ID, v.Path)
			if _, err := s.db.conn.Exec(`DELETE FROM videos WHERE id = ?`, v.ID); err != nil {
				return err
			}
		}
	}
	return nil
}
