package repository

import (
	"context"

	"github.com/yumikokawaii/archeic/internal/model"
)

type CategoryRepository struct {
	db DBTX
}

const categoryColumns = `id, slug, name, layout, position, created_at, updated_at`

func scanCategory(row scanner) (*model.Category, error) {
	var c model.Category
	if err := row.Scan(&c.ID, &c.Slug, &c.Name, &c.Layout, &c.Position, &c.CreatedAt, &c.UpdatedAt); err != nil {
		return nil, err
	}
	return &c, nil
}

func (r *CategoryRepository) Create(ctx context.Context, c *model.Category) error {
	_, err := r.db.ExecContext(ctx,
		`INSERT INTO categories (`+categoryColumns+`) VALUES (?, ?, ?, ?, ?, ?, ?)`,
		c.ID, c.Slug, c.Name, c.Layout, c.Position, c.CreatedAt, c.UpdatedAt)
	return translate(err)
}

func (r *CategoryRepository) List(ctx context.Context) ([]model.Category, error) {
	rows, err := r.db.QueryContext(ctx, `SELECT `+categoryColumns+` FROM categories ORDER BY position, name`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []model.Category{}
	for rows.Next() {
		c, err := scanCategory(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *c)
	}
	return out, rows.Err()
}

func (r *CategoryRepository) Get(ctx context.Context, id string) (*model.Category, error) {
	c, err := scanCategory(r.db.QueryRowContext(ctx, `SELECT `+categoryColumns+` FROM categories WHERE id = ?`, id))
	return c, notFound(err)
}

func (r *CategoryRepository) Update(ctx context.Context, c *model.Category) error {
	res, err := r.db.ExecContext(ctx,
		`UPDATE categories SET slug = ?, name = ?, layout = ?, position = ?, updated_at = ? WHERE id = ?`,
		c.Slug, c.Name, c.Layout, c.Position, c.UpdatedAt, c.ID)
	if err != nil {
		return translate(err)
	}
	return requireAffected(res)
}

func (r *CategoryRepository) Delete(ctx context.Context, id string) error {
	res, err := r.db.ExecContext(ctx, `DELETE FROM categories WHERE id = ?`, id)
	if err != nil {
		return err
	}
	return requireAffected(res)
}
