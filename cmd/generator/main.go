package main

import (
	"context"
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
}
