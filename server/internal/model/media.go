package model

import (
	"strconv"
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

var ThumbSizes = []int{512, 1280}

func ThumbSize(requested int) int {
	for _, s := range ThumbSizes {
		if requested <= s {
			return s
		}
	}
	return ThumbSizes[len(ThumbSizes)-1]
}

func (m *Media) ThumbKey(size int) string {
	return "thumb/" + m.ID + "-" + strconv.Itoa(size) + ".jpg"
}
