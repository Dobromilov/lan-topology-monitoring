package main

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"time"

	"lan-topology-monitoring/internal/config"
	"lan-topology-monitoring/internal/db"
)

func main() {
	cfg := config.Load()

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	database, err := db.Connect(ctx, cfg)
	if err != nil {
		log.Fatalf("database connection failed: %v", err)
	}
	defer database.Close()

	fmt.Println("PostgreSQL connection is OK")

	hosts, err := db.ListHosts(ctx, database)
	if err != nil {
		log.Fatalf("failed to load hosts: %v", err)
	}

	fmt.Println("Hosts:")
	for _, host := range hosts {
		fmt.Printf(
			"- #%d %s | IP: %s | MAC: %s | status: %s\n",
			host.HostID,
			host.Hostname,
			host.IPAddress,
			host.MACAddress,
			host.Status,
		)
	}

	switches, err := db.ListSwitches(ctx, database)
	if err != nil {
		log.Fatalf("failed to load switches: %v", err)
	}

	fmt.Println("Switches:")
	for _, networkSwitch := range switches {
		fmt.Printf(
			"- #%d %s | model: %s | ports: %d | location: %s\n",
			networkSwitch.SwitchID,
			networkSwitch.Name,
			nullableString(networkSwitch.Model),
			networkSwitch.PortsCount,
			nullableString(networkSwitch.Location),
		)
	}

	ports, err := db.ListSwitchPorts(ctx, database)
	if err != nil {
		log.Fatalf("failed to load switch ports: %v", err)
	}

	fmt.Println("Switch ports:")
	for _, port := range ports {
		fmt.Printf(
			"- switch #%d port %d | status: %s | speed: %d Mbps\n",
			port.SwitchID,
			port.PortNumber,
			port.Status,
			port.SpeedMbps,
		)
	}

	connections, err := db.ListActiveConnections(ctx, database)
	if err != nil {
		log.Fatalf("failed to load active connections: %v", err)
	}

	fmt.Println("Active connections:")
	for _, connection := range connections {
		fmt.Printf(
			"- %s (%s) -> %s port %d | %s | %d Mbps\n",
			connection.Hostname,
			connection.IPAddress,
			connection.SwitchName,
			connection.PortNumber,
			connection.PortStatus,
			connection.SpeedMbps,
		)
	}
}

func nullableString(value sql.NullString) string {
	if !value.Valid {
		return "n/a"
	}

	return value.String
}
