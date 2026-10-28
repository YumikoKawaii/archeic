package store

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"time"
)

type Collection struct {
	ID         string
	CategoryID string
	ParentID   *string
	Name       string
	CoverID    *string
	CreatedAt  time.Time
	UpdatedAt  time.Time
}

const collectionColumns = `id, category_id, parent_id, name, cover_id, created_at, updated_at`

func scanCollection(row interface{ Scan(...any) error }) (*Collection, error) {
	var (
		c             Collection
		parent, cover sql.NullString
	)
	if err := row.Scan(&c.ID, &c.CategoryID, &parent, &c.Name, &cover, &c.CreatedAt, &c.UpdatedAt); err != nil {
		return nil, err
	}
	if parent.Valid {
		c.ParentID = &parent.String
	}
	if cover.Valid {
		c.CoverID = &cover.String
	}
	return &c, nil
}

func (s *Store) CreateCollection(ctx context.Context, c *Collection) error {
	if c.ParentID != nil {
		if err := s.checkParent(ctx, c.CategoryID, c.ID, *c.ParentID); err != nil {
			return err
		}
	}
	now := time.Now().UTC()
	c.CreatedAt, c.UpdatedAt = now, now
	_, err := s.db.ExecContext(ctx,
		`INSERT INTO collections (`+collectionColumns+`) VALUES (?, ?, ?, ?, ?, ?, ?)`,
		c.ID, c.CategoryID, c.ParentID, c.Name, c.CoverID, c.CreatedAt, c.UpdatedAt)
	return translate(err)
}

func (s *Store) ListCollections(ctx context.Context, categoryID string, parentID *string) ([]Collection, error) {
	q := `SELECT ` + collectionColumns + ` FROM collections WHERE category_id = ? AND parent_id `
	args := []any{categoryID}
	if parentID == nil {
		q += `IS NULL`
	} else {
		q += `= ?`
		args = append(args, *parentID)
	}
	q += ` ORDER BY name`
	rows, err := s.db.QueryContext(ctx, q, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []Collection{}
	for rows.Next() {
		c, err := scanCollection(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *c)
	}
	return out, rows.Err()
}

func (s *Store) GetCollection(ctx context.Context, id string) (*Collection, error) {
	c, err := scanCollection(s.db.QueryRowContext(ctx, `SELECT `+collectionColumns+` FROM collections WHERE id = ?`, id))
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	return c, err
}

func (s *Store) UpdateCollection(ctx context.Context, c *Collection) error {
	if c.ParentID != nil {
		if err := s.checkParent(ctx, c.CategoryID, c.ID, *c.ParentID); err != nil {
			return err
		}
	}
	c.UpdatedAt = time.Now().UTC()
	res, err := s.db.ExecContext(ctx,
		`UPDATE collections SET parent_id = ?, name = ?, cover_id = ?, updated_at = ? WHERE id = ?`,
		c.ParentID, c.Name, c.CoverID, c.UpdatedAt, c.ID)
	if err != nil {
		return translate(err)
	}
	return requireAffected(res)
}

func (s *Store) DeleteCollection(ctx context.Context, id string) error {
	res, err := s.db.ExecContext(ctx, `DELETE FROM collections WHERE id = ?`, id)
	if err != nil {
		return err
	}
	return requireAffected(res)
}

func (s *Store) checkParent(ctx context.Context, categoryID, id, parentID string) error {
	var parentCategory string
	err := s.db.QueryRowContext(ctx, `SELECT category_id FROM collections WHERE id = ?`, parentID).Scan(&parentCategory)
	if errors.Is(err, sql.ErrNoRows) {
		return fmt.Errorf("%w: parent %s does not exist", ErrInvalidReference, parentID)
	}
	if err != nil {
		return err
	}
	if parentCategory != categoryID {
		return fmt.Errorf("%w: parent belongs to another category", ErrInvalidReference)
	}
	var cycles int
	err = s.db.QueryRowContext(ctx, `WITH RECURSIVE subtree AS (
			SELECT id FROM collections WHERE id = ?
			UNION ALL
			SELECT c.id FROM collections c JOIN subtree t ON c.parent_id = t.id
		)
		SELECT COUNT(*) FROM subtree WHERE id = ?`, id, parentID).Scan(&cycles)
	if err != nil {
		return err
	}
	if cycles > 0 || id == parentID {
		return fmt.Errorf("%w: parent is inside this collection", ErrInvalidReference)
	}
	return nil
}
