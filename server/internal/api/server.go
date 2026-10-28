package api

import (
	"context"
	"io"
	"log/slog"
	"net/http"

	"connectrpc.com/connect"
	"github.com/yumikokawaii/archeic/gen/archeic/v1/archeicv1connect"
	"github.com/yumikokawaii/archeic/internal/store"
)

type Repository interface {
	Create(ctx context.Context, m *store.Media) error
	List(ctx context.Context, kind string) ([]store.Media, error)
	Get(ctx context.Context, id string) (*store.Media, error)
	Delete(ctx context.Context, id string) error
}

type Blobs interface {
	Put(ctx context.Context, key string, r io.Reader, size int64, contentType string) error
	Open(ctx context.Context, key string) (io.ReadSeekCloser, error)
	Remove(ctx context.Context, key string) error
}

type Server struct {
	repo  Repository
	blobs Blobs
	log   *slog.Logger
}

func New(repo Repository, blobs Blobs, log *slog.Logger) *Server {
	return &Server{repo: repo, blobs: blobs, log: log}
}

func (s *Server) Handler() http.Handler {
	rpc := http.NewServeMux()
	rpc.Handle(archeicv1connect.NewMediaServiceHandler(
		&mediaService{repo: s.repo, blobs: s.blobs},
		connect.WithInterceptors(logging(s.log)),
		connect.WithRecover(func(ctx context.Context, spec connect.Spec, _ http.Header, p any) error {
			s.log.ErrorContext(ctx, "panic", "procedure", spec.Procedure, "panic", p)
			return connect.NewError(connect.CodeInternal, nil)
		}),
	))

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
