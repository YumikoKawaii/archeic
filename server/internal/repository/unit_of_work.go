package repository

import (
	"context"
	"database/sql"
	"fmt"
)

type UnitOfWork struct {
	db    DBTX
	sqlDB *sql.DB
}

func NewUnitOfWork(db *sql.DB) *UnitOfWork {
	return &UnitOfWork{db: db, sqlDB: db}
}

func (u *UnitOfWork) Media() *MediaRepository           { return &MediaRepository{db: u.db} }
func (u *UnitOfWork) Category() *CategoryRepository     { return &CategoryRepository{db: u.db} }
func (u *UnitOfWork) Collection() *CollectionRepository { return &CollectionRepository{db: u.db} }
func (u *UnitOfWork) Item() *ItemRepository             { return &ItemRepository{db: u.db} }

func (u *UnitOfWork) Tx(ctx context.Context, fn func(*UnitOfWork) error) error {
	if u.sqlDB == nil {
		return fn(u)
	}
	tx, err := u.sqlDB.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("begin tx: %w", err)
	}
	if err := fn(&UnitOfWork{db: tx}); err != nil {
		if rbErr := tx.Rollback(); rbErr != nil {
			return fmt.Errorf("%w (rollback: %v)", err, rbErr)
		}
		return err
	}
	if err := tx.Commit(); err != nil {
		return fmt.Errorf("commit tx: %w", err)
	}
	return nil
}
