package models

import (
	"database/sql"
	"time"
)

type Switch struct {
	SwitchID   int
	Name       string
	Model      sql.NullString
	PortsCount int
	Location   sql.NullString
	CreatedAt  time.Time
}

type SwitchPort struct {
	PortID     int
	SwitchID   int
	PortNumber int
	Status     string
	SpeedMbps  int
}
