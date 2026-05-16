package db

import (
	"context"
	"database/sql"
	"fmt"
	"time"

	"lan-topology-monitoring/internal/config"
	"lan-topology-monitoring/internal/models"

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

func ListHosts(ctx context.Context, database *sql.DB) ([]models.Host, error) {
	rows, err := database.QueryContext(ctx, `
		SELECT host_id, hostname, ip_address, mac_address, status, created_at
		FROM hosts
		ORDER BY host_id
	`)
	if err != nil {
		return nil, fmt.Errorf("select hosts: %w", err)
	}
	defer rows.Close()

	hosts := make([]models.Host, 0)
	for rows.Next() {
		var host models.Host
		if err := rows.Scan(
			&host.HostID,
			&host.Hostname,
			&host.IPAddress,
			&host.MACAddress,
			&host.Status,
			&host.CreatedAt,
		); err != nil {
			return nil, fmt.Errorf("scan host: %w", err)
		}

		hosts = append(hosts, host)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate hosts: %w", err)
	}

	return hosts, nil
}
