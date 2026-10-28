package config

import "os"

type Config struct {
	Addr           string
	MySQLDSN       string
	MigrationsDir  string
	MinioEndpoint  string
	MinioAccessKey string
	MinioSecretKey string
	MinioBucket    string
	MinioUseSSL    bool
}

func Load() Config {
	return Config{
		Addr:           env("ARCHEIC_ADDR", ":8080"),
		MySQLDSN:       env("MYSQL_DSN", "archeic:archeic@tcp(localhost:3306)/archeic?parseTime=true"),
		MigrationsDir:  env("MIGRATIONS_DIR", "migrations"),
		MinioEndpoint:  env("MINIO_ENDPOINT", "localhost:9000"),
		MinioAccessKey: env("MINIO_ACCESS_KEY", "minioadmin"),
		MinioSecretKey: env("MINIO_SECRET_KEY", "minioadmin"),
		MinioBucket:    env("MINIO_BUCKET", "archeic"),
		MinioUseSSL:    env("MINIO_USE_SSL", "false") == "true",
	}
}

func env(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}
