package db

import (
	"context"
	"database/sql"
	"fmt"

	"lan-topology-monitoring/internal/models"
)

func CreateFrame(ctx context.Context, tx *sql.Tx, frame models.Frame) (int, error) {
	var frameID int

	err := tx.QueryRowContext(ctx, `
		INSERT INTO frames (
			src_host_id,
			dst_host_id,
			src_mac,
			dst_mac,
			ether_type,
			payload_size,
			delivery_status
		)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
		RETURNING frame_id
	`,
		frame.SrcHostID,
		frame.DstHostID,
		frame.SrcMAC,
		frame.DstMAC,
		frame.EtherType,
		frame.PayloadSize,
		frame.DeliveryStatus,
	).Scan(&frameID)

	if err != nil {
		return 0, fmt.Errorf("create frame: %w", err)
	}

	return frameID, nil
}

func CreateFramePath(ctx context.Context, tx *sql.Tx, path models.FramePath) (int, error) {
	var pathID int

	err := tx.QueryRowContext(ctx, `
		INSERT INTO frame_path (
			frame_id,
			switch_id,
			in_port_id,
			out_port_id,
			step_number
		)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING path_id
	`,
		path.FrameID,
		path.SwitchID,
		path.InPortID,
		path.OutPortID,
		path.StepNumber,
	).Scan(&pathID)

	if err != nil {
		return 0, fmt.Errorf("create frame path: %w", err)
	}

	return pathID, nil
}

func CreateFrameWithPath(ctx context.Context, database *sql.DB, frame models.Frame, path models.FramePath) (int, int, error) {
	tx, err := database.BeginTx(ctx, nil)
	if err != nil {
		return 0, 0, fmt.Errorf("begin create frame transaction: %w", err)
	}

	frameID, err := CreateFrame(ctx, tx, frame)
	if err != nil {
		_ = tx.Rollback()
		return 0, 0, err
	}

	path.FrameID = frameID
	pathID, err := CreateFramePath(ctx, tx, path)
	if err != nil {
		_ = tx.Rollback()
		return 0, 0, err
	}

	if err := tx.Commit(); err != nil {
		return 0, 0, fmt.Errorf("commit create frame transaction: %w", err)
	}

	return frameID, pathID, nil
}
