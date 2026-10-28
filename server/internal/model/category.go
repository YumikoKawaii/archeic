package model

import "time"

const (
	LayoutGallery  = "gallery"
	LayoutLibrary  = "library"
	LayoutEpisodic = "episodic"
	LayoutTimeline = "timeline"
)

type Category struct {
	ID        string
	Slug      string
	Name      string
	Layout    string
	Position  int32
	CreatedAt time.Time
	UpdatedAt time.Time
}
