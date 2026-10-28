package model

import (
	"slices"
	"time"
)

const PositionGap = 1024

type Collection struct {
	ID         string
	CategoryID string
	ParentID   *string
	Name       string
	CoverID    *string
	CreatedAt  time.Time
	UpdatedAt  time.Time
}

type Item struct {
	CollectionID string
	MediaID      string
	Position     int32
}

type Items []Item

func (items Items) Move(mediaID string, index int) (Items, bool) {
	from := slices.IndexFunc(items, func(it Item) bool { return it.MediaID == mediaID })
	if from < 0 {
		return nil, false
	}
	moving := items[from]
	rest := slices.Delete(slices.Clone(items), from, from+1)
	index = max(0, min(index, len(rest)))

	prev := int32(0)
	if index > 0 {
		prev = rest[index-1].Position
	}
	next := prev + 2*PositionGap
	if index < len(rest) {
		next = rest[index].Position
	}
	if next-prev > 1 {
		moving.Position = prev + (next-prev)/2
		return Items{moving}, true
	}

	rest = slices.Insert(rest, index, moving)
	for i := range rest {
		rest[i].Position = int32(i+1) * PositionGap
	}
	return rest, true
}
