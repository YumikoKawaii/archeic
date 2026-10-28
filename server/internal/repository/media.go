package repository

import (
	"context"
	"strings"

	"github.com/yumikokawaii/archeic/internal/model"
)

type MediaRepository struct {
	db DBTX
}

const mediaColumns = `m.id, m.name, m.kind, m.content_type, m.size, m.object_key, m.created_at`

func scanMedia(row scanner) (*model.Media, error) {
	var m model.Media
	if err := row.Scan(&m.ID, &m.Name, &m.Kind, &m.ContentType, &m.Size, &m.ObjectKey, &m.CreatedAt); err != nil {
		return nil, err
	}
	return &m, nil
}

func (r *MediaRepository) Create(ctx context.Context, m *model.Media) error {
	_, err := r.db.ExecContext(ctx,
		`INSERT INTO media (id, name, kind, content_type, size, object_key, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)`,
		m.ID, m.Name, m.Kind, m.ContentType, m.Size, m.ObjectKey, m.CreatedAt)
	return translate(err)
}

func (r *MediaRepository) List(ctx context.Context, f model.MediaFilter) ([]model.Media, error) {
	q := `SELECT ` + mediaColumns + ` FROM media m`
	var (
		where []string
		args  []any
	)
	order := ` ORDER BY m.created_at DESC`
	if f.CollectionID != "" {
		q += ` JOIN items i ON i.media_id = m.id`
		where = append(where, `i.collection_id = ?`)
		args = append(args, f.CollectionID)
		order = ` ORDER BY i.position`
	}
	if f.Kind != "" {
		where = append(where, `m.kind = ?`)
		args = append(args, f.Kind)
	}
	if len(where) > 0 {
		q += ` WHERE ` + strings.Join(where, ` AND `)
	}
	rows, err := r.db.QueryContext(ctx, q+order, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []model.Media{}
	for rows.Next() {
		m, err := scanMedia(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *m)
	}
	return out, rows.Err()
}

func (r *MediaRepository) Get(ctx context.Context, id string) (*model.Media, error) {
	m, err := scanMedia(r.db.QueryRowContext(ctx, `SELECT `+mediaColumns+` FROM media m WHERE m.id = ?`, id))
	return m, notFound(err)
}

func (r *MediaRepository) Delete(ctx context.Context, id string) error {
	res, err := r.db.ExecContext(ctx, `DELETE FROM media WHERE id = ?`, id)
	if err != nil {
		return err
	}
	return requireAffected(res)
}
