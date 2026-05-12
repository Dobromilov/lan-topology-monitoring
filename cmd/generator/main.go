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
}
