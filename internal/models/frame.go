package models

type Frame struct {
	FrameID        int
	SrcHostID      int
	DstHostID      int
	SrcMAC         string
	DstMAC         string
	EtherType      string
	PayloadSize    int
	DeliveryStatus string
}

type FramePath struct {
	PathID     int
	FrameID    int
	SwitchID   int
	InPortID   int
	OutPortID  int
	StepNumber int
}
