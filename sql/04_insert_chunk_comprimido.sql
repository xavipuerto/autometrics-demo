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
-- NOTA (lección de la recreación): los nombres de chunk SON ELEGIDOS POR
-- TIMESCALE y cambian si recreas el entorno (aquí vehiculos_gorda_3001_chunk,
-- 3002, 3003; en la demo anterior fueron 6003/6004/6005). Este script ya NO
-- usa nombres fijos: resuelve los chunks por su rango temporal.

-- 0) Estado previo: chunks comprimidos (3001 y 3002 ya lo están)
SELECT chunk_name, is_compressed, range_start, range_end
FROM timescaledb_information.chunks
WHERE hypertable_name = 'vehiculos_gorda'
ORDER BY range_start;

-- 1) INSERT por lotes (5 filas en un solo statement) sobre el chunk MÁS
--    antiguo (comprimido): aquí cae en el intervalo [09-13, 09-16).
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

-- 2) INSERT "registro a registro" (5 statements de 1 fila) sobre el chunk
--    del medio [09-16, 09-19) (también comprimido)
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

-- 3) Estado tras insertar: los chunks siguen "comprimidos" pero CRECEN
--    (overflow rowstore). Los resuelvo por rango, no por nombre.
SELECT c.chunk_name,
       c.is_compressed,
       pg_size_pretty(pg_total_relation_size(format('%I.%I', c.chunk_schema, c.chunk_name)::regclass)) AS size,
       c.range_start
FROM timescaledb_information.chunks c
WHERE c.hypertable_name = 'vehiculos_gorda'
ORDER BY c.range_start;

-- 4) Mezclar el overflow de vuelta al columnstore (recompresion) sobre el
--    chunk del medio. En 2.18+ recompress_chunk está deprecada: usar
--    compress_chunk(). Resolución dinámica del chunk [09-16, 09-19).
SELECT compress_chunk(format('%I.%I', c.chunk_schema, c.chunk_name)::regclass)
FROM timescaledb_information.chunks c
WHERE c.hypertable_name = 'vehiculos_gorda'
  AND c.range_start = '2026-09-16 00:00:00+00';

-- 5) Integridad: la tabla no ha perdido filas (1.555.200 + 10 insertadas).
SELECT count(*) AS filas_total_gorda FROM vehiculos_gorda;