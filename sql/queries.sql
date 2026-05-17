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

-- 10. Хосты, отправившие больше одного кадра (GROUP BY + HAVING)
SELECT
    h.hostname,
    COUNT(f.frame_id) AS frames_sent,
    SUM(f.payload_size) AS bytes_sent
FROM hosts h
JOIN frames f ON f.src_host_id = h.host_id
GROUP BY h.hostname
HAVING COUNT(f.frame_id) > 1
ORDER BY frames_sent DESC;

-- 11. Топ-3 самых активных направлений передачи кадров (WITH/CTE + ORDER BY LIMIT)
WITH traffic_pairs AS (
    SELECT
        src.hostname AS src_hostname,
        dst.hostname AS dst_hostname,
        COUNT(*) AS frames_count,
        SUM(f.payload_size) AS total_bytes
    FROM frames f
    JOIN hosts src ON src.host_id = f.src_host_id
    JOIN hosts dst ON dst.host_id = f.dst_host_id
    GROUP BY src.hostname, dst.hostname
)
SELECT *
FROM traffic_pairs
ORDER BY frames_count DESC, total_bytes DESC
LIMIT 3;

-- 12. Нагрузка на порты коммутаторов по исходящему трафику
SELECT
    s.name AS switch_name,
    p.port_number,
    COUNT(fp.path_id) AS outgoing_frames
FROM switches s
JOIN switch_ports p ON p.switch_id = s.switch_id
LEFT JOIN frame_path fp ON fp.out_port_id = p.port_id
GROUP BY s.name, p.port_number
ORDER BY outgoing_frames DESC, p.port_number;

-- 13. Хосты без активного подключения к коммутатору
SELECT
    h.host_id,
    h.hostname,
    h.ip_address,
    h.status
FROM hosts h
LEFT JOIN host_connections hc
    ON hc.host_id = h.host_id
   AND hc.disconnected_at IS NULL
WHERE hc.connection_id IS NULL
ORDER BY h.hostname;

-- 14. Свободные порты коммутаторов
SELECT
    s.name AS switch_name,
    p.port_id,
    p.port_number,
    p.status,
    p.speed_mbps
FROM switch_ports p
JOIN switches s ON s.switch_id = p.switch_id
LEFT JOIN host_connections hc
    ON hc.port_id = p.port_id
   AND hc.disconnected_at IS NULL
WHERE hc.connection_id IS NULL
ORDER BY s.name, p.port_number;

-- 15. Количество кадров по статусам доставки
SELECT
    delivery_status,
    COUNT(*) AS frames_count,
    SUM(payload_size) AS total_bytes
FROM frames
GROUP BY delivery_status
ORDER BY frames_count DESC;

-- 16. Динамика трафика по дням
SELECT
    DATE(sent_at) AS traffic_date,
    COUNT(*) AS frames_count,
    SUM(payload_size) AS total_bytes,
    ROUND(AVG(payload_size), 2) AS avg_payload_size
FROM frames
GROUP BY DATE(sent_at)
ORDER BY traffic_date;

-- 17. Последние 5 переданных кадров с именами хостов
SELECT
    f.frame_id,
    src.hostname AS src_hostname,
    dst.hostname AS dst_hostname,
    f.ether_type,
    f.payload_size,
    f.delivery_status,
    f.sent_at
FROM frames f
JOIN hosts src ON src.host_id = f.src_host_id
JOIN hosts dst ON dst.host_id = f.dst_host_id
ORDER BY f.sent_at DESC
LIMIT 5;

-- 18. Утилизация портов коммутаторов
SELECT
    s.name AS switch_name,
    COUNT(p.port_id) AS total_ports_in_db,
    COUNT(hc.connection_id) AS used_ports,
    COUNT(p.port_id) - COUNT(hc.connection_id) AS free_ports
FROM switches s
JOIN switch_ports p ON p.switch_id = s.switch_id
LEFT JOIN host_connections hc
    ON hc.port_id = p.port_id
   AND hc.disconnected_at IS NULL
GROUP BY s.name
ORDER BY s.name;

-- 19. MAC-адреса, изученные на портах без активного подключения
SELECT
    s.name AS switch_name,
    p.port_number,
    m.mac_address,
    m.last_seen_at
FROM mac_table m
JOIN switch_ports p ON p.port_id = m.port_id
JOIN switches s ON s.switch_id = p.switch_id
LEFT JOIN host_connections hc
    ON hc.port_id = p.port_id
   AND hc.disconnected_at IS NULL
WHERE hc.connection_id IS NULL
ORDER BY m.last_seen_at DESC;

-- 20. Нумерация кадров по каждому отправителю (оконная функция)
SELECT
    f.frame_id,
    h.hostname AS src_hostname,
    f.dst_host_id,
    f.payload_size,
    f.sent_at,
    ROW_NUMBER() OVER (
        PARTITION BY f.src_host_id
        ORDER BY f.sent_at
    ) AS frame_number_for_sender
FROM frames f
JOIN hosts h ON h.host_id = f.src_host_id
ORDER BY h.hostname, frame_number_for_sender;
