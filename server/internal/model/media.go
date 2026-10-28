package model

import (
	"strings"
	"time"
)

const (
	KindImage = "image"
	KindVideo = "video"
)

type Media struct {
	ID          string
	Name        string
	Kind        string
	ContentType string
	Size        int64
	ObjectKey   string
	CreatedAt   time.Time
}

type MediaFilter struct {
	Kind         string
	CollectionID string
}

func KindOf(contentType string) string {
	switch {
	case strings.HasPrefix(contentType, "image/"):
		return KindImage
	case strings.HasPrefix(contentType, "video/"):
		return KindVideo
	}
	return ""
}
