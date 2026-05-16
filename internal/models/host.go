package models

import "time"

type Host struct {
	HostID     int
	Hostname   string
	IPAddress  string
	MACAddress string
	Status     string
	CreatedAt  time.Time
}
