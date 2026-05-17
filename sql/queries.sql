-- 1. Список всех подключенных хостов с информацией о коммутаторе и порте
SELECT 
    h.hostname, 
    h.ip_address, 
    s.name AS switch_name, 
    p.port_number, 
    hc.connected_at
FROM hosts h
JOIN host_connections hc ON h.host_id = hc.host_id
JOIN switch_ports p ON hc.port_id = p.port_id
JOIN switches s ON p.switch_id = s.switch_id
WHERE hc.disconnected_at IS NULL;

-- 2. Просмотр MAC-таблицы конкретного коммутатора
SELECT 
    s.name AS switch_name, 
    p.port_number, 
    m.mac_address, 
    m.last_seen_at, 
    m.is_static
FROM mac_table m
JOIN switch_ports p ON m.port_id = p.port_id
JOIN switches s ON p.switch_id = s.switch_id
WHERE s.name = 'Core-Switch-01';

-- 3. Трассировка пути конкретного кадра
SELECT 
    f.frame_id, 
    fp.step_number, 
    s.name AS switch_name, 
    p_in.port_number AS ingress_port, 
    p_out.port_number AS egress_port,
    fp.processed_at
FROM frames f
JOIN frame_path fp ON f.frame_id = fp.frame_id
JOIN switches s ON fp.switch_id = s.switch_id
JOIN switch_ports p_in ON fp.in_port_id = p_in.port_id
JOIN switch_ports p_out ON fp.out_port_id = p_out.port_id
ORDER BY f.frame_id, fp.step_number;

-- 4. Статистика переданных кадров по хостам-отправителям
SELECT 
    h.hostname, 
    COUNT(f.frame_id) AS frames_sent, 
    SUM(f.payload_size) AS total_bytes
FROM hosts h
LEFT JOIN frames f ON h.host_id = f.src_host_id
GROUP BY h.hostname
ORDER BY frames_sent DESC;

-- 5. Активные подключения через представление
SELECT *
FROM v_active_connections
ORDER BY switch_id, port_number;

-- 6. MAC-таблица коммутатора через функцию
SELECT *
FROM get_switch_mac_table('Core-Switch-01');

-- 7. Трассировка конкретного кадра через функцию
SELECT *
FROM get_frame_trace(1);

-- 8. Общая статистика трафика по хостам через функцию
SELECT *
FROM get_host_traffic_stats();

-- 9. Регистрация нового кадра средствами БД
-- Функция сама найдет активные подключения хостов, создаст запись в frames,
-- создаст запись в frame_path и вернет frame_id.
-- Пример обернут в транзакцию с ROLLBACK, чтобы не менять базу при демонстрации.
BEGIN;
SELECT register_frame(1, 2, 'IPv4', 128, 'delivered') AS new_frame_id;
ROLLBACK;
