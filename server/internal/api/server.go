package api

import (
	"context"
	"io"
	"log/slog"
	"net/http"

	"connectrpc.com/connect"
	"github.com/yumikokawaii/archeic/gen/archeic/v1/archeicv1connect"
	"github.com/yumikokawaii/archeic/internal/repository"
)

type Blobs interface {
	Put(ctx context.Context, key string, r io.Reader, size int64, contentType string) error
	Open(ctx context.Context, key string) (io.ReadSeekCloser, error)
	Remove(ctx context.Context, key string) error
}

type Server struct {
	uow   *repository.UnitOfWork
	blobs Blobs
	log   *slog.Logger
}

func New(uow *repository.UnitOfWork, blobs Blobs, log *slog.Logger) *Server {
	return &Server{uow: uow, blobs: blobs, log: log}
}

func (s *Server) Handler() http.Handler {
	opts := []connect.HandlerOption{
		connect.WithInterceptors(logging(s.log)),
		connect.WithRecover(func(ctx context.Context, spec connect.Spec, _ http.Header, p any) error {
			s.log.ErrorContext(ctx, "panic", "procedure", spec.Procedure, "panic", p)
			return connect.NewError(connect.CodeInternal, nil)
		}),
	}
	rpc := http.NewServeMux()
	rpc.Handle(archeicv1connect.NewMediaServiceHandler(&mediaService{uow: s.uow, blobs: s.blobs}, opts...))
	rpc.Handle(archeicv1connect.NewCategoryServiceHandler(&categoryService{uow: s.uow}, opts...))
	rpc.Handle(archeicv1connect.NewCollectionServiceHandler(&collectionService{uow: s.uow}, opts...))

	mux := http.NewServeMux()
	mux.Handle("/api/", http.StripPrefix("/api", rpc))
	mux.HandleFunc("GET /api/health", func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusOK) })
	mux.HandleFunc("POST /api/media", s.upload)
	mux.HandleFunc("GET /api/media/{id}/content", s.content)
	return mux
}

func logging(log *slog.Logger) connect.UnaryInterceptorFunc {
	return func(next connect.UnaryFunc) connect.UnaryFunc {
		return func(ctx context.Context, req connect.AnyRequest) (connect.AnyResponse, error) {
			res, err := next(ctx, req)
			if err != nil {
				log.WarnContext(ctx, "rpc failed", "procedure", req.Spec().Procedure, "code", connect.CodeOf(err).String(), "err", err)
			}
			return res, err
		}
	}
}
