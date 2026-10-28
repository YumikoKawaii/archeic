package store

import (
	"context"
	"database/sql"
	"errors"
	"time"
)

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

const categoryColumns = `id, slug, name, layout, position, created_at, updated_at`

func scanCategory(row interface{ Scan(...any) error }) (*Category, error) {
	var c Category
	if err := row.Scan(&c.ID, &c.Slug, &c.Name, &c.Layout, &c.Position, &c.CreatedAt, &c.UpdatedAt); err != nil {
		return nil, err
	}
	return &c, nil
}

func (s *Store) CreateCategory(ctx context.Context, c *Category) error {
	now := time.Now().UTC()
	c.CreatedAt, c.UpdatedAt = now, now
	_, err := s.db.ExecContext(ctx,
		`INSERT INTO categories (`+categoryColumns+`) VALUES (?, ?, ?, ?, ?, ?, ?)`,
		c.ID, c.Slug, c.Name, c.Layout, c.Position, c.CreatedAt, c.UpdatedAt)
	return translate(err)
}

func (s *Store) ListCategories(ctx context.Context) ([]Category, error) {
	rows, err := s.db.QueryContext(ctx, `SELECT `+categoryColumns+` FROM categories ORDER BY position, name`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []Category{}
	for rows.Next() {
		c, err := scanCategory(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *c)
	}
	return out, rows.Err()
}

func (s *Store) GetCategory(ctx context.Context, id string) (*Category, error) {
	c, err := scanCategory(s.db.QueryRowContext(ctx, `SELECT `+categoryColumns+` FROM categories WHERE id = ?`, id))
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	return c, err
}

func (s *Store) UpdateCategory(ctx context.Context, c *Category) error {
	c.UpdatedAt = time.Now().UTC()
	res, err := s.db.ExecContext(ctx,
		`UPDATE categories SET slug = ?, name = ?, layout = ?, position = ?, updated_at = ? WHERE id = ?`,
		c.Slug, c.Name, c.Layout, c.Position, c.UpdatedAt, c.ID)
	if err != nil {
		return translate(err)
	}
	return requireAffected(res)
}

func (s *Store) DeleteCategory(ctx context.Context, id string) error {
	res, err := s.db.ExecContext(ctx, `DELETE FROM categories WHERE id = ?`, id)
	if err != nil {
		return err
	}
	return requireAffected(res)
}

func requireAffected(res sql.Result) error {
	n, err := res.RowsAffected()
	if err != nil {
		return err
	}
	if n == 0 {
		return ErrNotFound
	}
	return nil
}
