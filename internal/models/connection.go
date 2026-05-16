package models

import "time"

type HostConnection struct {
	ConnectionID   int
	HostID         int
	PortID         int
	ConnectedAt    time.Time
	DisconnectedAt *time.Time
}

type ActiveConnection struct {
	Hostname    string
	IPAddress   string
	SwitchName  string
	PortNumber  int
	PortStatus  string
	SpeedMbps   int
	ConnectedAt time.Time
}
