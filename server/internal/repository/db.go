package repository

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"time"

	"github.com/go-sql-driver/mysql"
	"github.com/golang-migrate/migrate/v4"
	migratemysql "github.com/golang-migrate/migrate/v4/database/mysql"
	_ "github.com/golang-migrate/migrate/v4/source/file"
)

var (
	ErrNotFound         = errors.New("not found")
	ErrConflict         = errors.New("already exists")
	ErrInvalidReference = errors.New("invalid reference")
)

const (
	mysqlDuplicateEntry = 1062
	mysqlNoReferenced   = 1452
)

type DBTX interface {
	ExecContext(ctx context.Context, query string, args ...any) (sql.Result, error)
	QueryContext(ctx context.Context, query string, args ...any) (*sql.Rows, error)
	QueryRowContext(ctx context.Context, query string, args ...any) *sql.Row
}

type scanner interface {
	Scan(dest ...any) error
}

func Open(dsn string) (*sql.DB, error) {
	db, err := sql.Open("mysql", dsn)
	if err != nil {
		return nil, fmt.Errorf("opening mysql: %w", err)
	}
	for range 30 {
		if err = db.Ping(); err == nil {
			return db, nil
		}
		time.Sleep(2 * time.Second)
	}
	return nil, fmt.Errorf("pinging mysql: %w", err)
}

func Migrate(db *sql.DB, dir, direction string) error {
	driver, err := migratemysql.WithInstance(db, &migratemysql.Config{})
	if err != nil {
		return fmt.Errorf("creating mysql driver: %w", err)
	}
	m, err := migrate.NewWithDatabaseInstance("file://"+dir, "mysql", driver)
	if err != nil {
		return fmt.Errorf("creating migrate instance: %w", err)
	}
	switch direction {
	case "up":
		err = m.Up()
	case "down":
		err = m.Down()
	default:
		return fmt.Errorf("invalid migration direction: %s (use 'up' or 'down')", direction)
	}
	if err != nil && !errors.Is(err, migrate.ErrNoChange) {
		return fmt.Errorf("migration %s failed: %w", direction, err)
	}
	return nil
}

func translate(err error) error {
	var me *mysql.MySQLError
	if !errors.As(err, &me) {
		return err
	}
	switch me.Number {
	case mysqlDuplicateEntry:
		return errors.Join(ErrConflict, err)
	case mysqlNoReferenced:
		return errors.Join(ErrInvalidReference, err)
	}
	return err
}

func notFound(err error) error {
	if errors.Is(err, sql.ErrNoRows) {
		return ErrNotFound
	}
	return err
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
