package main

import (
	"context"
	"log/slog"
	"net/http"
	"os"

	"github.com/yumikokawaii/archeic/internal/api"
	"github.com/yumikokawaii/archeic/internal/config"
	"github.com/yumikokawaii/archeic/internal/storage"
	"github.com/yumikokawaii/archeic/internal/store"
)

func main() {
	log := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	if err := run(context.Background(), log); err != nil {
		log.Error("archeic stopped", "err", err)
		os.Exit(1)
	}
}

func run(ctx context.Context, log *slog.Logger) error {
	cfg := config.Load()

	db, err := store.Open(cfg.MySQLDSN)
	if err != nil {
		return err
	}
	defer db.Close()

	if err := db.Migrate(ctx); err != nil {
		return err
	}

	blobs, err := storage.New(ctx, cfg)
	if err != nil {
		return err
	}

	protocols := new(http.Protocols)
	protocols.SetHTTP1(true)
	protocols.SetUnencryptedHTTP2(true)

	srv := &http.Server{
		Addr:      cfg.Addr,
		Handler:   api.New(db, blobs, log).Handler(),
		Protocols: protocols,
	}
	log.Info("archeic listening", "addr", cfg.Addr)
	return srv.ListenAndServe()
}
