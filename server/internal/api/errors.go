package api

import (
	"errors"
	"fmt"

	"connectrpc.com/connect"
	"github.com/yumikokawaii/archeic/internal/repository"
)

func repoError(op string, err error) error {
	var ce *connect.Error
	switch {
	case errors.As(err, &ce):
		return ce
	case errors.Is(err, repository.ErrNotFound):
		return connect.NewError(connect.CodeNotFound, err)
	case errors.Is(err, repository.ErrConflict):
		return connect.NewError(connect.CodeAlreadyExists, err)
	case errors.Is(err, repository.ErrInvalidReference):
		return connect.NewError(connect.CodeInvalidArgument, err)
	}
	return connect.NewError(connect.CodeInternal, fmt.Errorf("%s: %w", op, err))
}

func invalid(msg string) error {
	return connect.NewError(connect.CodeInvalidArgument, errors.New(msg))
}
