package repository

import (
	"context"
	"strings"

	"github.com/yumikokawaii/archeic/internal/model"
)

type ItemRepository struct {
	db DBTX
}

func (r *ItemRepository) Add(ctx context.Context, it model.Item) error {
	_, err := r.db.ExecContext(ctx,
		`INSERT INTO items (collection_id, media_id, position) VALUES (?, ?, ?)
		ON DUPLICATE KEY UPDATE position = position`, it.CollectionID, it.MediaID, it.Position)
	return translate(err)
}

func (r *ItemRepository) LockList(ctx context.Context, collectionID string) (model.Items, error) {
	rows, err := r.db.QueryContext(ctx,
		`SELECT collection_id, media_id, position FROM items WHERE collection_id = ? ORDER BY position FOR UPDATE`, collectionID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out model.Items
	for rows.Next() {
		var it model.Item
		if err := rows.Scan(&it.CollectionID, &it.MediaID, &it.Position); err != nil {
			return nil, err
		}
		out = append(out, it)
	}
	return out, rows.Err()
}

func (r *ItemRepository) SetPosition(ctx context.Context, it model.Item) error {
	_, err := r.db.ExecContext(ctx,
		`UPDATE items SET position = ? WHERE collection_id = ? AND media_id = ?`, it.Position, it.CollectionID, it.MediaID)
	return err
}

func (r *ItemRepository) Remove(ctx context.Context, collectionID string, mediaIDs []string) error {
	if len(mediaIDs) == 0 {
		return nil
	}
	args := make([]any, 0, len(mediaIDs)+1)
	args = append(args, collectionID)
	for _, id := range mediaIDs {
		args = append(args, id)
	}
	placeholders := strings.TrimSuffix(strings.Repeat("?,", len(mediaIDs)), ",")
	_, err := r.db.ExecContext(ctx,
		`DELETE FROM items WHERE collection_id = ? AND media_id IN (`+placeholders+`)`, args...)
	return err
}
