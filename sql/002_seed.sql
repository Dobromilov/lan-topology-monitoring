-- Заполнение таблицы хостов
INSERT INTO hosts (hostname, ip_address, mac_address, status) VALUES
('Workstation-01', '192.168.1.10', '00:50:56:c0:00:01', 'online'),
('Workstation-02', '192.168.1.11', '00:50:56:c0:00:02', 'online'),
('Server-Main', '192.168.1.200', '00:50:56:c0:00:ff', 'online');

-- Заполнение таблицы коммутаторов
INSERT INTO switches (name, model, ports_count, location) VALUES
('Core-Switch-01', 'Cisco Catalyst 9300', 24, 'DataCenter-Rack-A1');

-- Заполнение портов коммутатора
INSERT INTO switch_ports (switch_id, port_number, status, speed_mbps) VALUES
(1, 1, 'up', 1000),
(1, 2, 'up', 1000),
(1, 24, 'up', 10000);

-- Подключение хостов к портам
INSERT INTO host_connections (host_id, port_id) VALUES
(1, 1),
(2, 2);

-- Наполнение MAC-таблицы
INSERT INTO mac_table (port_id, mac_address, is_static) VALUES
(1, '00:50:56:c0:00:01', FALSE),
(2, '00:50:56:c0:00:02', FALSE);

-- Пример передачи кадра
INSERT INTO frames (src_host_id, dst_host_id, src_mac, dst_mac, ether_type, payload_size, delivery_status) VALUES
(1, 2, '00:50:56:c0:00:01', '00:50:56:c0:00:02', 'IPv4', 64, 'delivered');

-- Путь кадра через коммутатор
INSERT INTO frame_path (frame_id, switch_id, in_port_id, out_port_id, step_number) VALUES
(1, 1, 1, 2, 1);
