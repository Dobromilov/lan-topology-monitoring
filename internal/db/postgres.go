package db

import (
	"context"
	"database/sql"
	"fmt"
	"time"

	"lan-topology-monitoring/internal/config"

	_ "github.com/lib/pq"
)

func Connect(ctx context.Context, cfg config.Config) (*sql.DB, error) {
	database, err := sql.Open("postgres", cfg.DSN())
	if err != nil {
		return nil, fmt.Errorf("open postgres connection: %w", err)
	}

	database.SetMaxOpenConns(5)
	database.SetMaxIdleConns(5)
	database.SetConnMaxLifetime(30 * time.Minute)

	if err := database.PingContext(ctx); err != nil {
		_ = database.Close()
		return nil, fmt.Errorf("ping postgres: %w", err)
	}

	return database, nil
}
