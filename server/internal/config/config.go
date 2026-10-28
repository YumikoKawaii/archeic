package config

import "os"

type Config struct {
	Server Server
	MySQL  MySQL
	S3     S3
}

type Server struct {
	Addr string
}

type MySQL struct {
	DSN           string
	MigrationsDir string
}

type S3 struct {
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
			DSN:           env("MYSQL_DSN", ""),
			MigrationsDir: env("MIGRATIONS_DIR", "migrations"),
		},
		S3: S3{
			Endpoint:  env("S3_ENDPOINT", "localhost:9000"),
			AccessKey: env("S3_ACCESS_KEY", ""),
			SecretKey: env("S3_SECRET_KEY", ""),
			Bucket:    env("S3_BUCKET", "archeic"),
			UseSSL:    env("S3_USE_SSL", "false") == "true",
		},
	}
}

func env(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}
