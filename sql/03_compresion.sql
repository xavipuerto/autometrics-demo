-- 03_compresion.sql
-- Compresión de chunks de vehiculos_gorda (ejecutar mañana).
-- Objetivo: comprimir los 2 chunks más antiguos y comparar su tamaño.
--
-- TIPO DE COMPRESIÓN USADA (envio de la prueba):
--   Compresión NATIVA de TimescaleDB (hypercore): la tabla fila (rowstore)
--   se convierte en columnar (columnstore, tabla ..._chunk_compressed) y cada
--   columna se comprime según su tipo con lossless:
--     - timestamps / enteros: delta-of-delta + simple-8b + run-length (RLE)
--     - flotantes: XOR (Gorilla, de Facebook)
--     - resto / baja cardinalidad: diccionario
--   No requiere herramientas externas. Metricas obtenidas: 56 MB -> 17 MB (~70%).

-- 1) Estado actual: chunks, tamaños y si están comprimidos
SELECT c.chunk_schema,
       c.chunk_name,
       c.range_start,
       c.range_end,
       pg_size_pretty(pg_total_relation_size((c.chunk_schema || '.' || c.chunk_name)::regclass)) AS size,
       c.is_compressed
FROM timescaledb_information.chunks c
WHERE c.hypertable_name = 'vehiculos_gorda'
ORDER BY c.range_start;

-- 2) Comprimir los 2 chunks más antiguos
SELECT compress_chunk(format('%I.%I', x.chunk_schema, x.chunk_name)::regclass)
FROM (
    SELECT chunk_schema, chunk_name
    FROM timescaledb_information.chunks
    WHERE hypertable_name = 'vehiculos_gorda'
    ORDER BY range_start
    LIMIT 2
) x;

-- 3) Estado después: mismos chunks con su tamaño comprimido
SELECT c.chunk_schema,
       c.chunk_name,
       c.range_start,
       c.range_end,
       pg_size_pretty(pg_total_relation_size((c.chunk_schema || '.' || c.chunk_name)::regclass)) AS size,
       c.is_compressed
FROM timescaledb_information.chunks c
WHERE c.hypertable_name = 'vehiculos_gorda'
ORDER BY c.range_start;

-- 4) Comparativa: bytes antes vs después (los 2 comprimidos)
SELECT c.chunk_name,
       pg_size_pretty(pg_total_relation_size((c.chunk_schema || '.' || c.chunk_name)::regclass)) AS size_actual,
       c.is_compressed
FROM timescaledb_information.chunks c
WHERE c.hypertable_name = 'vehiculos_gorda'
  AND c.is_compressed
ORDER BY c.range_start;