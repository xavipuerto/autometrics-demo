-- 04_insert_chunk_comprimido.sql
-- Inserción sobre un chunk YA comprimido (vehiculos_gorda).
-- 
-- Comportamiento observado (TimescaleDB 2.30.1 / PG 18.6):
--   NO descomprime todo el chunk ni lo recompresa en cada INSERT.
--   Las filas nuevas van a un segmento rowstore/"overflow" del chunk
--   (el chunk sigue con is_compressed = t pero crece).
--   El merge con el columnstore ocurre al recomprimir (compress_chunk /
--   recompress_chunk) o con la política de compresión.
--
-- Medidas tomadas en la prueba (2026-09-22):
--   - 5 filas en 1 INSERT (batch):        5,6 ms
--   - 5 INSERT de 1 fila (uno a uno):     3,95 + 0,56 + 0,44 + 0,50 + 0,67 ms
--   - CALL recompress_chunk()             13 ms  (deprecada en 2.18+; ahora es compress_chunk)
--   - Contenedor durante el proceso:      CPU ~1,9 %, MEM ~702 MiB
--   - Integridad: count(*) se mantiene (518.400 + filas insertadas).

-- 0) Estado previo: chunks comprimidos
SELECT chunk_name, is_compressed, range_start, range_end
FROM timescaledb_information.chunks
WHERE hypertable_name = 'vehiculos_gorda'
ORDER BY range_start;

-- 1) INSERT por lotes (5 filas en un solo statement) sobre chunk comprimido 6003
\timing on
INSERT INTO vehiculos_gorda (auto_id, ts, presion_ruedas, nivel_combustible, carga_bateria,
                             temperatura_motor, temperatura_bateria, presion_aceite, velocidad,
                             revoluciones, consumo_potencia, autonomia) VALUES
(5, '2026-09-14 12:00:00+00', 2.45, 42, 68, 95.2, 31.4, 3.1, 83.5, 2200, 12.5, 320),
(5, '2026-09-14 12:01:00+00', 2.44, 41, 68, 95.0, 31.3, 3.1, 84.0, 2250, 13.1, 320),
(5, '2026-09-14 12:02:00+00', 2.46, 41, 67, 95.3, 31.5, 3.2, 83.9, 2300, 13.8, 318),
(5, '2026-09-14 12:03:00+00', 2.45, 40, 67, 95.1, 31.4, 3.1, 84.5, 2350, 14.2, 318),
(5, '2026-09-14 12:04:00+00', 2.43, 40, 66, 95.4, 31.6, 3.1, 84.2, 2400, 14.0, 317);
\timing off

-- 2) INSERT "registro a registro" (5 statements de 1 fila) sobre chunk comprimido 6004
INSERT INTO vehiculos_gorda (auto_id, ts, presion_ruedas, nivel_combustible, carga_bateria,
                             temperatura_motor, temperatura_bateria, presion_aceite, velocidad,
                             revoluciones, consumo_potencia, autonomia)
VALUES (6, '2026-09-17 12:00:00+00', 2.45, 42, 68, 95.2, 31.4, 3.1, 83.5, 2200, 12.5, 320);
INSERT INTO vehiculos_gorda (auto_id, ts, presion_ruedas, nivel_combustible, carga_bateria,
                             temperatura_motor, temperatura_bateria, presion_aceite, velocidad,
                             revoluciones, consumo_potencia, autonomia)
VALUES (7, '2026-09-17 12:00:01+00', 2.44, 41, 68, 95.0, 31.3, 3.1, 84.0, 2250, 13.1, 320);
INSERT INTO vehiculos_gorda (auto_id, ts, presion_ruedas, nivel_combustible, carga_bateria,
                             temperatura_motor, temperatura_bateria, presion_aceite, velocidad,
                             revoluciones, consumo_potencia, autonomia)
VALUES (8, '2026-09-17 12:00:02+00', 2.46, 41, 67, 95.3, 31.5, 3.2, 83.9, 2300, 13.8, 318);
INSERT INTO vehiculos_gorda (auto_id, ts, presion_ruedas, nivel_combustible, carga_bateria,
                             temperatura_motor, temperatura_bateria, presion_aceite, velocidad,
                             revoluciones, consumo_potencia, autonomia)
VALUES (9, '2026-09-17 12:00:03+00', 2.45, 40, 67, 95.1, 31.4, 3.1, 84.5, 2350, 14.2, 318);
INSERT INTO vehiculos_gorda (auto_id, ts, presion_ruedas, nivel_combustible, carga_bateria,
                             temperatura_motor, temperatura_bateria, presion_aceite, velocidad,
                             revoluciones, consumo_potencia, autonomia)
VALUES (10, '2026-09-17 12:00:04+00', 2.43, 40, 66, 95.4, 31.6, 3.1, 84.2, 2400, 14.0, 317);

-- 3) Estado tras insertar: el chunk sigue "comprimido" pero crece (overflow rowstore)
SELECT chunk_name, is_compressed, pg_size_pretty(pg_total_relation_size(to_regclass('particiones_gordas.'||chunk_name))) AS size
FROM timescaledb_information.chunks
WHERE hypertable_name = 'vehiculos_gorda'
ORDER BY range_start;

-- 4) Mezclar el overflow de vuelta al columnstore (recompresion)
CALL recompress_chunk('particiones_gordas.vehiculos_gorda_6004_chunk');
-- En TimescaleDB 2.18+ recompress_chunk esta deprecada: usa compress_chunk()
-- SELECT compress_chunk('particiones_gordas.vehiculos_gorda_6004_chunk');

-- 5) Integridad: conteo de filas del chunk 6004 (era 518.400 + 5 = 518.405)
SELECT count(*) AS filas_chunk_6004
FROM vehiculos_gorda
WHERE ts >= '2026-09-16'::timestamptz AND ts < '2026-09-19'::timestamptz;