package main

import (
	"bytes"
	"encoding/xml"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"path"
	"path/filepath"
	"strings"
	"time"
)

// WebDAV XML response structures
type multistatus struct {
	XMLName   xml.Name   `xml:"D:multistatus"`
	Responses []response `xml:"D:response"`
	XmlnsD    string     `xml:"xmlns:D,attr"`
}

type response struct {
	Href     string   `xml:"D:href"`
	PropStat propStat `xml:"D:propstat"`
}

type propStat struct {
	Prop   prop   `xml:"D:prop"`
	Status string `xml:"D:status"`
}

type prop struct {
	ResourceType resourceType `xml:"D:resourcetype"`
	ContentLen   string       `xml:"D:getcontentlength"`
	ContentType  string       `xml:"D:getcontenttype"`
	LastModified string       `xml:"D:getlastmodified"`
}

type resourceType struct {
	Collection *struct{} `xml:"D:collection"`
}

type WebDAVItem struct {
	Path        string
	Name        string
	IsDir       bool
	Size        int64
	ContentType string
	Modified    time.Time
}

type WebDAVClient struct {
	BaseURL    string
	Username   string
	Password   string
	HTTPClient *http.Client
}

func NewWebDAVClient(baseURL, username, password string) (*WebDAVClient, error) {
	if _, err := url.Parse(baseURL); err != nil {
		return nil, fmt.Errorf("invalid URL: %w", err)
	}
	return &WebDAVClient{
		BaseURL:  strings.TrimRight(baseURL, "/"),
		Username: username,
		Password: password,
		HTTPClient: &http.Client{
			Timeout: 30 * time.Second,
		},
	}, nil
}

// doRequest sends a WebDAV request with optional body
func (c *WebDAVClient) doRequest(method, p string, body io.Reader, depth string) (*http.Response, error) {
	u := c.BaseURL + p
	req, err := http.NewRequest(method, u, body)
	if err != nil {
		return nil, err
	}
	if c.Username != "" {
		req.SetBasicAuth(c.Username, c.Password)
	}
	if depth != "" {
		req.Header.Set("Depth", depth)
	}
	req.Header.Set("Content-Type", "application/xml")
	return c.HTTPClient.Do(req)
}

// List returns all items in a directory
func (c *WebDAVClient) List(p string) ([]WebDAVItem, error) {
	body := `<?xml version="1.0" encoding="utf-8" ?>
	<D:propfind xmlns:D="DAV:">
		<D:prop>
			<D:resourcetype/>
			<D:getcontentlength/>
			<D:getcontenttype/>
			<D:getlastmodified/>
		</D:prop>
	</D:propfind>`

	resp, err := c.doRequest("PROPFIND", p, strings.NewReader(body), "1")
	if err != nil {
		return nil, fmt.Errorf("propfind failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusMultiStatus && resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("propfind status %d", resp.StatusCode)
	}

	data, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	var ms multistatus
	if err := xml.Unmarshal(data, &ms); err != nil {
		return nil, fmt.Errorf("xml unmarshal failed: %w", err)
	}

	basePrefix := c.BaseURL
	var items []WebDAVItem

	for _, r := range ms.Responses {
		href := r.Href
		// Handle absolute vs relative URL
		if strings.HasPrefix(href, "http") {
			if !strings.HasPrefix(href, basePrefix) {
				continue
			}
			href = strings.TrimPrefix(href, basePrefix)
		}
		href, _ = url.PathUnescape(href)
		href = path.Clean(href)

		name := path.Base(href)
		isDir := r.PropStat.Prop.ResourceType.Collection != nil

		size := parseInt64(r.PropStat.Prop.ContentLen)
		mod := parseTime(r.PropStat.Prop.LastModified)

		items = append(items, WebDAVItem{
			Path:        href,
			Name:        name,
			IsDir:       isDir,
			Size:        size,
			ContentType: r.PropStat.Prop.ContentType,
			Modified:    mod,
		})
	}

	return items, nil
}

// GetStream returns a stream of the file (for proxy mode)
func (c *WebDAVClient) GetStream(p string) (io.ReadCloser, error) {
	resp, err := c.doRequest("GET", p, nil, "")
	if err != nil {
		return nil, err
	}
	if resp.StatusCode != http.StatusOK {
		resp.Body.Close()
		return nil, fmt.Errorf("get status %d", resp.StatusCode)
	}
	return resp.Body, nil
}

// GetRedirectURL returns the 302 redirect URL (for direct mode)
func (c *WebDAVClient) GetRedirectURL(p string) (string, error) {
	u := c.BaseURL + p
	req, err := http.NewRequest("HEAD", u, nil)
	if err != nil {
		return "", err
	}
	if c.Username != "" {
		req.SetBasicAuth(c.Username, c.Password)
	}
	resp, err := c.HTTPClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	if resp.StatusCode == http.StatusOK || resp.StatusCode == http.StatusFound {
		return resp.Request.URL.String(), nil
	}
	return "", fmt.Errorf("status %d", resp.StatusCode)
}

// ScanRecursive walks the tree and yields video files
func (c *WebDAVClient) ScanRecursive(rootPath string, videoExts []string) ([]WebDAVItem, error) {
	var videos []WebDAVItem
	err := c.walk(rootPath, videoExts, &videos)
	return videos, err
}

func (c *WebDAVClient) walk(p string, videoExts []string, out *[]WebDAVItem) error {
	items, err := c.List(p)
	if err != nil {
		return err
	}
	for _, item := range items {
		// Skip current dir entry
		if item.Path == p || item.Name == "." || item.Name == "" {
			continue
		}
		if item.IsDir {
			if err := c.walk(item.Path, videoExts, out); err != nil {
				// Log but don't abort on single dir failure
				continue
			}
		} else {
			ext := strings.ToLower(filepath.Ext(item.Name))
			for _, ve := range videoExts {
				if ext == ve {
					*out = append(*out, item)
					break
				}
			}
		}
	}
	return nil
}

// Video extensions supported
var DefaultVideoExts = []string{
	".mp4", ".mkv", ".webm", ".avi", ".mov", ".m4v", ".flv", ".wmv", ".ts", ".m3u8",
}

// helpers
func parseInt64(s string) int64 {
	if s == "" {
		return 0
	}
	var n int64
	fmt.Sscanf(s, "%d", &n)
	return n
}

func parseTime(s string) time.Time {
	if s == "" {
		return time.Time{}
	}
	t, err := time.Parse(time.RFC1123, s)
	if err != nil {
		t, _ = time.Parse("Mon, 02 Jan 2006 15:04:05 GMT", s)
	}
	return t
}

var _ = bytes.NewReader // keep import
var ErrNotFound = errors.New("not found")
