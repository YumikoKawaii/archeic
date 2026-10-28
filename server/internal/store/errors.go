package store

import (
	"errors"

	"github.com/go-sql-driver/mysql"
)

var (
	ErrConflict         = errors.New("already exists")
	ErrInvalidReference = errors.New("invalid reference")
)

const (
	mysqlDuplicateEntry = 1062
	mysqlNoReferenced   = 1452
)

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
