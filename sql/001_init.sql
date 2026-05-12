CREATE TABLE hosts (
    host_id SERIAL PRIMARY KEY,
    hostname VARCHAR(100) NOT NULL,
    ip_address INET UNIQUE NOT NULL,
    mac_address MACADDR UNIQUE NOT NULL,
    status VARCHAR(20) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE switches (
    switch_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    model VARCHAR(100),
    ports_count INT NOT NULL,
    location VARCHAR(100),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE switch_ports (
    port_id SERIAL PRIMARY KEY,
    switch_id INT NOT NULL REFERENCES switches(switch_id),
    port_number INT NOT NULL,
    status VARCHAR(20) NOT NULL,
    speed_mbps INT NOT NULL,
    UNIQUE (switch_id, port_number)
);

CREATE TABLE host_connections (
    connection_id SERIAL PRIMARY KEY,
    host_id INT NOT NULL REFERENCES hosts(host_id),
    port_id INT NOT NULL REFERENCES switch_ports(port_id),
    connected_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    disconnected_at TIMESTAMP NULL
);

CREATE TABLE mac_table (
    entry_id SERIAL PRIMARY KEY,
    port_id INT NOT NULL REFERENCES switch_ports(port_id),
    mac_address MACADDR NOT NULL,
    learned_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_seen_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    is_static BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE frames (
    frame_id SERIAL PRIMARY KEY,
    src_host_id INT NOT NULL REFERENCES hosts(host_id),
    dst_host_id INT NOT NULL REFERENCES hosts(host_id),
    src_mac MACADDR NOT NULL,
    dst_mac MACADDR NOT NULL,
    ether_type VARCHAR(20) NOT NULL,
    payload_size INT NOT NULL,
    sent_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    delivery_status VARCHAR(20) NOT NULL
);

CREATE TABLE frame_path (
    path_id SERIAL PRIMARY KEY,
    frame_id INT NOT NULL REFERENCES frames(frame_id),
    switch_id INT NOT NULL REFERENCES switches(switch_id),
    in_port_id INT NOT NULL REFERENCES switch_ports(port_id),
    out_port_id INT NOT NULL REFERENCES switch_ports(port_id),
    step_number INT NOT NULL,
    processed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
