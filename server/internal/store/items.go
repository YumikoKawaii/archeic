package store

import (
	"context"
	"database/sql"
	"fmt"
	"slices"
	"strings"
)

const positionGap = 1024

func (s *Store) AddItems(ctx context.Context, collectionID string, mediaIDs []string) error {
	return s.tx(ctx, func(tx *sql.Tx) error {
		var last int32
		err := tx.QueryRowContext(ctx,
			`SELECT COALESCE(MAX(position), 0) FROM items WHERE collection_id = ? FOR UPDATE`, collectionID).Scan(&last)
		if err != nil {
			return err
		}
		for _, id := range mediaIDs {
			last += positionGap
			_, err := tx.ExecContext(ctx,
				`INSERT INTO items (collection_id, media_id, position) VALUES (?, ?, ?)
				ON DUPLICATE KEY UPDATE position = position`, collectionID, id, last)
			if err != nil {
				return translate(err)
			}
		}
		return nil
	})
}

func (s *Store) RemoveItems(ctx context.Context, collectionID string, mediaIDs []string) error {
	if len(mediaIDs) == 0 {
		return nil
	}
	args := make([]any, 0, len(mediaIDs)+1)
	args = append(args, collectionID)
	for _, id := range mediaIDs {
		args = append(args, id)
	}
	placeholders := strings.TrimSuffix(strings.Repeat("?,", len(mediaIDs)), ",")
	_, err := s.db.ExecContext(ctx,
		`DELETE FROM items WHERE collection_id = ? AND media_id IN (`+placeholders+`)`, args...)
	return err
}

func (s *Store) MoveItem(ctx context.Context, collectionID, mediaID string, index int) error {
	return s.tx(ctx, func(tx *sql.Tx) error {
		ids, positions, err := lockItems(ctx, tx, collectionID)
		if err != nil {
			return err
		}
		from := slices.Index(ids, mediaID)
		if from < 0 {
			return ErrNotFound
		}
		ids = slices.Delete(ids, from, from+1)
		positions = slices.Delete(positions, from, from+1)
		index = max(0, min(index, len(ids)))

		prev := int32(0)
		if index > 0 {
			prev = positions[index-1]
		}
		next := prev + 2*positionGap
		if index < len(positions) {
			next = positions[index]
		}
		if next-prev > 1 {
			_, err := tx.ExecContext(ctx,
				`UPDATE items SET position = ? WHERE collection_id = ? AND media_id = ?`,
				prev+(next-prev)/2, collectionID, mediaID)
			return err
		}

		ids = slices.Insert(ids, index, mediaID)
		for i, id := range ids {
			_, err := tx.ExecContext(ctx,
				`UPDATE items SET position = ? WHERE collection_id = ? AND media_id = ?`,
				int32(i+1)*positionGap, collectionID, id)
			if err != nil {
				return err
			}
		}
		return nil
	})
}

func lockItems(ctx context.Context, tx *sql.Tx, collectionID string) ([]string, []int32, error) {
	rows, err := tx.QueryContext(ctx,
		`SELECT media_id, position FROM items WHERE collection_id = ? ORDER BY position FOR UPDATE`, collectionID)
	if err != nil {
		return nil, nil, err
	}
	defer rows.Close()
	var (
		ids       []string
		positions []int32
	)
	for rows.Next() {
		var (
			id  string
			pos int32
		)
		if err := rows.Scan(&id, &pos); err != nil {
			return nil, nil, err
		}
		ids = append(ids, id)
		positions = append(positions, pos)
	}
	return ids, positions, rows.Err()
}

func (s *Store) tx(ctx context.Context, fn func(*sql.Tx) error) error {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("beginning tx: %w", err)
	}
	if err := fn(tx); err != nil {
		_ = tx.Rollback()
		return err
	}
	return tx.Commit()
}
