package store

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"strings"
	"time"

	_ "github.com/go-sql-driver/mysql"
)

var ErrNotFound = errors.New("not found")

const (
	KindImage = "image"
	KindVideo = "video"
)

func KindOf(contentType string) string {
	switch {
	case strings.HasPrefix(contentType, "image/"):
		return KindImage
	case strings.HasPrefix(contentType, "video/"):
		return KindVideo
	}
	return ""
}

type Media struct {
	ID          string    `json:"id"`
	Name        string    `json:"name"`
	Kind        string    `json:"kind"`
	ContentType string    `json:"contentType"`
	Size        int64     `json:"size"`
	ObjectKey   string    `json:"-"`
	CreatedAt   time.Time `json:"createdAt"`
}

type Store struct {
	db *sql.DB
}

func Open(dsn string) (*Store, error) {
	db, err := sql.Open("mysql", dsn)
	if err != nil {
		return nil, fmt.Errorf("opening mysql: %w", err)
	}
	for range 30 {
		if err = db.Ping(); err == nil {
			return &Store{db: db}, nil
		}
		time.Sleep(2 * time.Second)
	}
	return nil, fmt.Errorf("pinging mysql: %w", err)
}

func (s *Store) Close() error { return s.db.Close() }

func (s *Store) Migrate(ctx context.Context) error {
	for _, stmt := range schema {
		if _, err := s.db.ExecContext(ctx, stmt); err != nil {
			return fmt.Errorf("migrating: %w", err)
		}
	}
	return nil
}

func (s *Store) Create(ctx context.Context, m *Media) error {
	_, err := s.db.ExecContext(ctx,
		`INSERT INTO media (id, name, kind, content_type, size, object_key, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)`,
		m.ID, m.Name, m.Kind, m.ContentType, m.Size, m.ObjectKey, m.CreatedAt)
	return err
}

type MediaFilter struct {
	Kind         string
	CollectionID string
}

func (s *Store) List(ctx context.Context, f MediaFilter) ([]Media, error) {
	q := `SELECT m.id, m.name, m.kind, m.content_type, m.size, m.object_key, m.created_at FROM media m`
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
	q += order
	rows, err := s.db.QueryContext(ctx, q, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []Media{}
	for rows.Next() {
		var m Media
		if err := rows.Scan(&m.ID, &m.Name, &m.Kind, &m.ContentType, &m.Size, &m.ObjectKey, &m.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, m)
	}
	return out, rows.Err()
}

func (s *Store) Get(ctx context.Context, id string) (*Media, error) {
	var m Media
	err := s.db.QueryRowContext(ctx,
		`SELECT id, name, kind, content_type, size, object_key, created_at FROM media WHERE id = ?`, id).
		Scan(&m.ID, &m.Name, &m.Kind, &m.ContentType, &m.Size, &m.ObjectKey, &m.CreatedAt)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	return &m, nil
}

func (s *Store) Delete(ctx context.Context, id string) error {
	_, err := s.db.ExecContext(ctx, `DELETE FROM media WHERE id = ?`, id)
	return err
}
