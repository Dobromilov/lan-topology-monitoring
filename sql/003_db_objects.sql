-- Additional database objects for LAN topology monitoring.
-- This file adds constraints, indexes, views, functions and triggers.

-- =========================
-- Constraints
-- =========================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'hosts'::regclass AND conname = 'chk_hosts_status'
    ) THEN
        ALTER TABLE hosts
            ADD CONSTRAINT chk_hosts_status
            CHECK (status IN ('online', 'offline', 'maintenance'));
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'switches'::regclass AND conname = 'chk_switches_ports_count'
    ) THEN
        ALTER TABLE switches
            ADD CONSTRAINT chk_switches_ports_count
            CHECK (ports_count > 0);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'switch_ports'::regclass AND conname = 'chk_switch_ports_status'
    ) THEN
        ALTER TABLE switch_ports
            ADD CONSTRAINT chk_switch_ports_status
            CHECK (status IN ('up', 'down', 'disabled'));
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'switch_ports'::regclass AND conname = 'chk_switch_ports_speed'
    ) THEN
        ALTER TABLE switch_ports
            ADD CONSTRAINT chk_switch_ports_speed
            CHECK (speed_mbps > 0);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'host_connections'::regclass AND conname = 'chk_host_connections_period'
    ) THEN
        ALTER TABLE host_connections
            ADD CONSTRAINT chk_host_connections_period
            CHECK (disconnected_at IS NULL OR disconnected_at >= connected_at);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'mac_table'::regclass AND conname = 'chk_mac_table_seen_period'
    ) THEN
        ALTER TABLE mac_table
            ADD CONSTRAINT chk_mac_table_seen_period
            CHECK (last_seen_at >= learned_at);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'frames'::regclass AND conname = 'chk_frames_hosts_are_different'
    ) THEN
        ALTER TABLE frames
            ADD CONSTRAINT chk_frames_hosts_are_different
            CHECK (src_host_id <> dst_host_id);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'frames'::regclass AND conname = 'chk_frames_payload_size'
    ) THEN
        ALTER TABLE frames
            ADD CONSTRAINT chk_frames_payload_size
            CHECK (payload_size > 0);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'frames'::regclass AND conname = 'chk_frames_delivery_status'
    ) THEN
        ALTER TABLE frames
            ADD CONSTRAINT chk_frames_delivery_status
            CHECK (delivery_status IN ('delivered', 'dropped', 'flooded'));
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'frame_path'::regclass AND conname = 'chk_frame_path_step_number'
    ) THEN
        ALTER TABLE frame_path
            ADD CONSTRAINT chk_frame_path_step_number
            CHECK (step_number > 0);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'frame_path'::regclass AND conname = 'chk_frame_path_ports_are_different'
    ) THEN
        ALTER TABLE frame_path
            ADD CONSTRAINT chk_frame_path_ports_are_different
            CHECK (in_port_id <> out_port_id);
    END IF;
END
$$;

-- =========================
-- Indexes
-- =========================

CREATE INDEX IF NOT EXISTS idx_hosts_status ON hosts(status);

CREATE INDEX IF NOT EXISTS idx_switch_ports_switch_id ON switch_ports(switch_id);

CREATE INDEX IF NOT EXISTS idx_host_connections_host_id ON host_connections(host_id);
CREATE INDEX IF NOT EXISTS idx_host_connections_port_id ON host_connections(port_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_host_connections_active_host_unique
    ON host_connections(host_id)
    WHERE disconnected_at IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_host_connections_active_port_unique
    ON host_connections(port_id)
    WHERE disconnected_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mac_table_mac_address_unique ON mac_table(mac_address);
CREATE INDEX IF NOT EXISTS idx_mac_table_port_id ON mac_table(port_id);
CREATE INDEX IF NOT EXISTS idx_mac_table_last_seen_at ON mac_table(last_seen_at);

CREATE INDEX IF NOT EXISTS idx_frames_src_host_id ON frames(src_host_id);
CREATE INDEX IF NOT EXISTS idx_frames_dst_host_id ON frames(dst_host_id);
CREATE INDEX IF NOT EXISTS idx_frames_sent_at ON frames(sent_at);
CREATE INDEX IF NOT EXISTS idx_frames_delivery_status ON frames(delivery_status);

CREATE INDEX IF NOT EXISTS idx_frame_path_frame_id ON frame_path(frame_id);
CREATE INDEX IF NOT EXISTS idx_frame_path_switch_id ON frame_path(switch_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_frame_path_frame_step_unique
    ON frame_path(frame_id, step_number);

-- =========================
-- Views
-- =========================

CREATE OR REPLACE VIEW v_active_connections AS
SELECT
    hc.connection_id,
    h.host_id,
    h.hostname,
    h.ip_address,
    h.mac_address,
    s.switch_id,
    s.name AS switch_name,
    p.port_id,
    p.port_number,
    p.status AS port_status,
    p.speed_mbps,
    hc.connected_at
FROM host_connections hc
JOIN hosts h ON h.host_id = hc.host_id
JOIN switch_ports p ON p.port_id = hc.port_id
JOIN switches s ON s.switch_id = p.switch_id
WHERE hc.disconnected_at IS NULL;

CREATE OR REPLACE VIEW v_switch_mac_table AS
SELECT
    s.switch_id,
    s.name AS switch_name,
    p.port_id,
    p.port_number,
    m.mac_address,
    m.learned_at,
    m.last_seen_at,
    m.is_static
FROM mac_table m
JOIN switch_ports p ON p.port_id = m.port_id
JOIN switches s ON s.switch_id = p.switch_id;

CREATE OR REPLACE VIEW v_frame_trace AS
SELECT
    f.frame_id,
    f.sent_at,
    f.src_host_id,
    src.hostname AS src_hostname,
    f.dst_host_id,
    dst.hostname AS dst_hostname,
    fp.step_number,
    s.switch_id,
    s.name AS switch_name,
    in_port.port_number AS in_port_number,
    out_port.port_number AS out_port_number,
    fp.processed_at
FROM frames f
JOIN hosts src ON src.host_id = f.src_host_id
JOIN hosts dst ON dst.host_id = f.dst_host_id
JOIN frame_path fp ON fp.frame_id = f.frame_id
JOIN switches s ON s.switch_id = fp.switch_id
JOIN switch_ports in_port ON in_port.port_id = fp.in_port_id
JOIN switch_ports out_port ON out_port.port_id = fp.out_port_id;

CREATE OR REPLACE VIEW v_host_traffic_stats AS
SELECT
    h.host_id,
    h.hostname,
    COALESCE(sent.frames_sent, 0) AS frames_sent,
    COALESCE(sent.bytes_sent, 0) AS bytes_sent,
    COALESCE(received.frames_received, 0) AS frames_received,
    COALESCE(received.bytes_received, 0) AS bytes_received
FROM hosts h
LEFT JOIN (
    SELECT
        src_host_id AS host_id,
        COUNT(*) AS frames_sent,
        COALESCE(SUM(payload_size), 0) AS bytes_sent
    FROM frames
    GROUP BY src_host_id
) sent ON sent.host_id = h.host_id
LEFT JOIN (
    SELECT
        dst_host_id AS host_id,
        COUNT(*) AS frames_received,
        COALESCE(SUM(payload_size), 0) AS bytes_received
    FROM frames
    GROUP BY dst_host_id
) received ON received.host_id = h.host_id;

-- =========================
-- Functions
-- =========================

CREATE OR REPLACE FUNCTION learn_mac_address(
    p_port_id INT,
    p_mac_address MACADDR,
    p_is_static BOOLEAN DEFAULT FALSE
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO mac_table (port_id, mac_address, is_static)
    VALUES (p_port_id, p_mac_address, p_is_static)
    ON CONFLICT (mac_address) DO UPDATE
    SET
        port_id = EXCLUDED.port_id,
        last_seen_at = CURRENT_TIMESTAMP,
        is_static = mac_table.is_static OR EXCLUDED.is_static;
END;
$$;

CREATE OR REPLACE FUNCTION register_frame(
    p_src_host_id INT,
    p_dst_host_id INT,
    p_ether_type VARCHAR DEFAULT 'IPv4',
    p_payload_size INT DEFAULT 128,
    p_delivery_status VARCHAR DEFAULT 'delivered'
)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
    v_src RECORD;
    v_dst RECORD;
    v_frame_id INT;
BEGIN
    IF p_src_host_id = p_dst_host_id THEN
        RAISE EXCEPTION 'Source host and destination host must be different';
    END IF;

    SELECT
        h.host_id,
        h.mac_address,
        hc.port_id,
        p.switch_id
    INTO v_src
    FROM hosts h
    JOIN host_connections hc ON hc.host_id = h.host_id
    JOIN switch_ports p ON p.port_id = hc.port_id
    WHERE h.host_id = p_src_host_id
      AND hc.disconnected_at IS NULL
    ORDER BY hc.connected_at DESC
    LIMIT 1;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Source host % does not have an active connection', p_src_host_id;
    END IF;

    SELECT
        h.host_id,
        h.mac_address,
        hc.port_id,
        p.switch_id
    INTO v_dst
    FROM hosts h
    JOIN host_connections hc ON hc.host_id = h.host_id
    JOIN switch_ports p ON p.port_id = hc.port_id
    WHERE h.host_id = p_dst_host_id
      AND hc.disconnected_at IS NULL
    ORDER BY hc.connected_at DESC
    LIMIT 1;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Destination host % does not have an active connection', p_dst_host_id;
    END IF;

    IF v_src.switch_id <> v_dst.switch_id THEN
        RAISE EXCEPTION 'Automatic frame registration supports one switch path only';
    END IF;

    INSERT INTO frames (
        src_host_id,
        dst_host_id,
        src_mac,
        dst_mac,
        ether_type,
        payload_size,
        delivery_status
    )
    VALUES (
        v_src.host_id,
        v_dst.host_id,
        v_src.mac_address,
        v_dst.mac_address,
        p_ether_type,
        p_payload_size,
        p_delivery_status
    )
    RETURNING frame_id INTO v_frame_id;

    INSERT INTO frame_path (
        frame_id,
        switch_id,
        in_port_id,
        out_port_id,
        step_number
    )
    VALUES (
        v_frame_id,
        v_src.switch_id,
        v_src.port_id,
        v_dst.port_id,
        1
    );

    RETURN v_frame_id;
END;
$$;

CREATE OR REPLACE FUNCTION get_frame_trace(p_frame_id INT)
RETURNS TABLE (
    frame_id INT,
    step_number INT,
    switch_name TEXT,
    in_port_number INT,
    out_port_number INT,
    processed_at TIMESTAMP
)
LANGUAGE sql
AS $$
    SELECT
        vt.frame_id,
        vt.step_number,
        vt.switch_name::TEXT,
        vt.in_port_number,
        vt.out_port_number,
        vt.processed_at
    FROM v_frame_trace vt
    WHERE vt.frame_id = p_frame_id
    ORDER BY vt.step_number;
$$;

CREATE OR REPLACE FUNCTION get_host_traffic_stats()
RETURNS TABLE (
    host_id INT,
    hostname TEXT,
    frames_sent BIGINT,
    bytes_sent BIGINT,
    frames_received BIGINT,
    bytes_received BIGINT
)
LANGUAGE sql
AS $$
    SELECT
        v.host_id,
        v.hostname::TEXT,
        v.frames_sent::BIGINT,
        v.bytes_sent::BIGINT,
        v.frames_received::BIGINT,
        v.bytes_received::BIGINT
    FROM v_host_traffic_stats v
    ORDER BY v.frames_sent DESC, v.frames_received DESC, v.hostname;
$$;

CREATE OR REPLACE FUNCTION get_switch_mac_table(p_switch_name TEXT)
RETURNS TABLE (
    switch_name TEXT,
    port_number INT,
    mac_address MACADDR,
    last_seen_at TIMESTAMP,
    is_static BOOLEAN
)
LANGUAGE sql
AS $$
    SELECT
        v.switch_name::TEXT,
        v.port_number,
        v.mac_address,
        v.last_seen_at,
        v.is_static
    FROM v_switch_mac_table v
    WHERE v.switch_name = p_switch_name
    ORDER BY v.port_number, v.mac_address;
$$;

-- =========================
-- Triggers
-- =========================

CREATE OR REPLACE FUNCTION validate_frame_hosts()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_src_mac MACADDR;
    v_dst_mac MACADDR;
BEGIN
    IF NEW.src_host_id = NEW.dst_host_id THEN
        RAISE EXCEPTION 'Source host and destination host must be different';
    END IF;

    SELECT mac_address INTO v_src_mac
    FROM hosts
    WHERE host_id = NEW.src_host_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Source host % does not exist', NEW.src_host_id;
    END IF;

    SELECT mac_address INTO v_dst_mac
    FROM hosts
    WHERE host_id = NEW.dst_host_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Destination host % does not exist', NEW.dst_host_id;
    END IF;

    IF NEW.src_mac <> v_src_mac THEN
        RAISE EXCEPTION 'Source MAC % does not match host % MAC %',
            NEW.src_mac, NEW.src_host_id, v_src_mac;
    END IF;

    IF NEW.dst_mac <> v_dst_mac THEN
        RAISE EXCEPTION 'Destination MAC % does not match host % MAC %',
            NEW.dst_mac, NEW.dst_host_id, v_dst_mac;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_frame_hosts ON frames;
CREATE TRIGGER trg_validate_frame_hosts
BEFORE INSERT OR UPDATE ON frames
FOR EACH ROW
EXECUTE FUNCTION validate_frame_hosts();

CREATE OR REPLACE FUNCTION learn_src_mac_from_frame()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_port_id INT;
BEGIN
    SELECT hc.port_id INTO v_port_id
    FROM host_connections hc
    WHERE hc.host_id = NEW.src_host_id
      AND hc.disconnected_at IS NULL
    ORDER BY hc.connected_at DESC
    LIMIT 1;

    IF v_port_id IS NOT NULL THEN
        PERFORM learn_mac_address(v_port_id, NEW.src_mac, FALSE);
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_learn_src_mac_from_frame ON frames;
CREATE TRIGGER trg_learn_src_mac_from_frame
AFTER INSERT ON frames
FOR EACH ROW
EXECUTE FUNCTION learn_src_mac_from_frame();

CREATE OR REPLACE FUNCTION validate_frame_path_ports()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_in_switch_id INT;
    v_out_switch_id INT;
BEGIN
    IF NEW.in_port_id = NEW.out_port_id THEN
        RAISE EXCEPTION 'Input port and output port must be different';
    END IF;

    SELECT switch_id INTO v_in_switch_id
    FROM switch_ports
    WHERE port_id = NEW.in_port_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Input port % does not exist', NEW.in_port_id;
    END IF;

    SELECT switch_id INTO v_out_switch_id
    FROM switch_ports
    WHERE port_id = NEW.out_port_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Output port % does not exist', NEW.out_port_id;
    END IF;

    IF v_in_switch_id <> NEW.switch_id THEN
        RAISE EXCEPTION 'Input port % does not belong to switch %',
            NEW.in_port_id, NEW.switch_id;
    END IF;

    IF v_out_switch_id <> NEW.switch_id THEN
        RAISE EXCEPTION 'Output port % does not belong to switch %',
            NEW.out_port_id, NEW.switch_id;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_frame_path_ports ON frame_path;
CREATE TRIGGER trg_validate_frame_path_ports
BEFORE INSERT OR UPDATE ON frame_path
FOR EACH ROW
EXECUTE FUNCTION validate_frame_path_ports();

COMMENT ON VIEW v_active_connections IS 'Current host-to-switch-port connections.';
COMMENT ON VIEW v_switch_mac_table IS 'MAC table with switch and port details.';
COMMENT ON VIEW v_frame_trace IS 'Frame path with readable switch and port information.';
COMMENT ON VIEW v_host_traffic_stats IS 'Sent and received traffic statistics by host.';

COMMENT ON FUNCTION register_frame(INT, INT, VARCHAR, INT, VARCHAR)
IS 'Registers a frame and its one-switch path using active host connections.';
