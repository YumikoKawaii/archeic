package config

import "os"

type Config struct {
	Server Server
	MySQL  MySQL
	Minio  Minio
}

type Server struct {
	Addr string
}

type MySQL struct {
	DSN           string
	MigrationsDir string
}

type Minio struct {
	Endpoint  string
	AccessKey string
	SecretKey string
	Bucket    string
	UseSSL    bool
}

func Load() Config {
	return Config{
		Server: Server{
			Addr: env("ARCHEIC_ADDR", ":8080"),
		},
		MySQL: MySQL{
			DSN:           env("MYSQL_DSN", "archeic:archeic@tcp(localhost:3306)/archeic?parseTime=true"),
			MigrationsDir: env("MIGRATIONS_DIR", "migrations"),
		},
		Minio: Minio{
			Endpoint:  env("MINIO_ENDPOINT", "localhost:9000"),
			AccessKey: env("MINIO_ACCESS_KEY", "minioadmin"),
			SecretKey: env("MINIO_SECRET_KEY", "minioadmin"),
			Bucket:    env("MINIO_BUCKET", "archeic"),
			UseSSL:    env("MINIO_USE_SSL", "false") == "true",
		},
	}
}

func env(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}
