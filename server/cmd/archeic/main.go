package main

import (
	"log/slog"
	"net/http"
	"os"

	"github.com/urfave/cli/v2"
	"github.com/yumikokawaii/archeic/internal/api"
	"github.com/yumikokawaii/archeic/internal/config"
	"github.com/yumikokawaii/archeic/internal/repository"
	"github.com/yumikokawaii/archeic/internal/storage"
)

var (
	cfg = config.Load()
	log = slog.New(slog.NewJSONHandler(os.Stdout, nil))
)

func main() {
	app := &cli.App{
		Name: "archeic",
		Commands: []*cli.Command{
			{
				Name:   "server",
				Usage:  "start the http server",
				Action: serverAction,
			},
			{
				Name:  "migrate",
				Usage: "run database migrations",
				Subcommands: []*cli.Command{
					{
						Name:   "up",
						Usage:  "apply all pending migrations",
						Action: migrateAction("up"),
					},
					{
						Name:   "down",
						Usage:  "roll back all migrations",
						Action: migrateAction("down"),
					},
				},
			},
		},
	}
	if err := app.Run(os.Args); err != nil {
		log.Error("archeic stopped", "err", err)
		os.Exit(1)
	}
}

func serverAction(c *cli.Context) error {
	ctx := c.Context
	db, err := repository.Open(cfg.MySQL.DSN)
	if err != nil {
		return err
	}
	defer db.Close()

	blobs, err := storage.New(ctx, cfg.Minio)
	if err != nil {
		return err
	}

	protocols := new(http.Protocols)
	protocols.SetHTTP1(true)
	protocols.SetUnencryptedHTTP2(true)

	srv := &http.Server{
		Addr:      cfg.Server.Addr,
		Handler:   api.New(repository.NewUnitOfWork(db), blobs, log).Handler(),
		Protocols: protocols,
	}
	log.Info("archeic listening", "addr", cfg.Server.Addr)
	return srv.ListenAndServe()
}

func migrateAction(direction string) cli.ActionFunc {
	return func(*cli.Context) error {
		db, err := repository.Open(cfg.MySQL.DSN)
		if err != nil {
			return err
		}
		defer db.Close()

		log.Info("running migrations", "direction", direction, "dir", cfg.MySQL.MigrationsDir)
		if err := repository.Migrate(db, cfg.MySQL.MigrationsDir, direction); err != nil {
			return err
		}
		log.Info("migrations completed", "direction", direction)
		return nil
	}
}
