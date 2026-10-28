package repository

import (
	"context"
	"database/sql"

	"github.com/yumikokawaii/archeic/internal/model"
)

type CollectionRepository struct {
	db DBTX
}

const collectionColumns = `id, category_id, parent_id, name, cover_id, created_at, updated_at`

func scanCollection(row scanner) (*model.Collection, error) {
	var (
		c             model.Collection
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

func (r *CollectionRepository) Create(ctx context.Context, c *model.Collection) error {
	_, err := r.db.ExecContext(ctx,
		`INSERT INTO collections (`+collectionColumns+`) VALUES (?, ?, ?, ?, ?, ?, ?)`,
		c.ID, c.CategoryID, c.ParentID, c.Name, c.CoverID, c.CreatedAt, c.UpdatedAt)
	return translate(err)
}

func (r *CollectionRepository) List(ctx context.Context, categoryID string, parentID *string) ([]model.Collection, error) {
	q := `SELECT ` + collectionColumns + ` FROM collections WHERE category_id = ? AND parent_id `
	args := []any{categoryID}
	if parentID == nil {
		q += `IS NULL`
	} else {
		q += `= ?`
		args = append(args, *parentID)
	}
	return r.query(ctx, q+` ORDER BY name`, args...)
}

func (r *CollectionRepository) ListByMedia(ctx context.Context, mediaID string) ([]model.Collection, error) {
	return r.query(ctx, `SELECT `+collectionColumns+` FROM collections WHERE id IN (SELECT collection_id FROM items WHERE media_id = ?) ORDER BY name`, mediaID)
}

func (r *CollectionRepository) query(ctx context.Context, q string, args ...any) ([]model.Collection, error) {
	rows, err := r.db.QueryContext(ctx, q, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []model.Collection{}
	for rows.Next() {
		c, err := scanCollection(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *c)
	}
	return out, rows.Err()
}

func (r *CollectionRepository) Get(ctx context.Context, id string) (*model.Collection, error) {
	c, err := scanCollection(r.db.QueryRowContext(ctx, `SELECT `+collectionColumns+` FROM collections WHERE id = ?`, id))
	return c, notFound(err)
}

func (r *CollectionRepository) Update(ctx context.Context, c *model.Collection) error {
	res, err := r.db.ExecContext(ctx,
		`UPDATE collections SET parent_id = ?, name = ?, cover_id = ?, updated_at = ? WHERE id = ?`,
		c.ParentID, c.Name, c.CoverID, c.UpdatedAt, c.ID)
	if err != nil {
		return translate(err)
	}
	return requireAffected(res)
}

func (r *CollectionRepository) Delete(ctx context.Context, id string) error {
	res, err := r.db.ExecContext(ctx, `DELETE FROM collections WHERE id = ?`, id)
	if err != nil {
		return err
	}
	return requireAffected(res)
}

func (r *CollectionRepository) InSubtree(ctx context.Context, rootID, id string) (bool, error) {
	var n int
	err := r.db.QueryRowContext(ctx, `WITH RECURSIVE subtree AS (
			SELECT id FROM collections WHERE id = ?
			UNION ALL
			SELECT c.id FROM collections c JOIN subtree t ON c.parent_id = t.id
		)
		SELECT COUNT(*) FROM subtree WHERE id = ?`, rootID, id).Scan(&n)
	return n > 0, err
}
