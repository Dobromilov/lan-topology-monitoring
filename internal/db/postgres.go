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

func ListSwitches(ctx context.Context, database *sql.DB) ([]models.Switch, error) {
	rows, err := database.QueryContext(ctx, `
		SELECT switch_id, name, model, ports_count, location, created_at
		FROM switches
		ORDER BY switch_id
	`)
	if err != nil {
		return nil, fmt.Errorf("select switches: %w", err)
	}
	defer rows.Close()

	switches := make([]models.Switch, 0)
	for rows.Next() {
		var networkSwitch models.Switch
		if err := rows.Scan(
			&networkSwitch.SwitchID,
			&networkSwitch.Name,
			&networkSwitch.Model,
			&networkSwitch.PortsCount,
			&networkSwitch.Location,
			&networkSwitch.CreatedAt,
		); err != nil {
			return nil, fmt.Errorf("scan switch: %w", err)
		}

		switches = append(switches, networkSwitch)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate switches: %w", err)
	}

	return switches, nil
}

func ListSwitchPorts(ctx context.Context, database *sql.DB) ([]models.SwitchPort, error) {
	rows, err := database.QueryContext(ctx, `
		SELECT port_id, switch_id, port_number, status, speed_mbps
		FROM switch_ports
		ORDER BY switch_id, port_number
	`)
	if err != nil {
		return nil, fmt.Errorf("select switch ports: %w", err)
	}
	defer rows.Close()

	ports := make([]models.SwitchPort, 0)
	for rows.Next() {
		var port models.SwitchPort
		if err := rows.Scan(
			&port.PortID,
			&port.SwitchID,
			&port.PortNumber,
			&port.Status,
			&port.SpeedMbps,
		); err != nil {
			return nil, fmt.Errorf("scan switch port: %w", err)
		}

		ports = append(ports, port)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate switch ports: %w", err)
	}

	return ports, nil
}

func ListActiveConnections(ctx context.Context, database *sql.DB) ([]models.ActiveConnection, error) {
	rows, err := database.QueryContext(ctx, `
		SELECT
			h.hostname,
			h.ip_address,
			s.name,
			p.port_number,
			p.status,
			p.speed_mbps,
			hc.connected_at
		FROM host_connections hc
		JOIN hosts h ON h.host_id = hc.host_id
		JOIN switch_ports p ON p.port_id = hc.port_id
		JOIN switches s ON s.switch_id = p.switch_id
		WHERE hc.disconnected_at IS NULL
		ORDER BY s.switch_id, p.port_number
	`)
	if err != nil {
		return nil, fmt.Errorf("select active connections: %w", err)
	}
	defer rows.Close()

	connections := make([]models.ActiveConnection, 0)
	for rows.Next() {
		var connection models.ActiveConnection
		if err := rows.Scan(
			&connection.Hostname,
			&connection.IPAddress,
			&connection.SwitchName,
			&connection.PortNumber,
			&connection.PortStatus,
			&connection.SpeedMbps,
			&connection.ConnectedAt,
		); err != nil {
			return nil, fmt.Errorf("scan active connection: %w", err)
		}

		connections = append(connections, connection)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate active connections: %w", err)
	}

	return connections, nil
}
