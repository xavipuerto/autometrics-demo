-- 03_compresion.sql
-- Compresión de chunks de vehiculos_grande (ejecutar mañana).
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
WHERE c.hypertable_name = 'vehiculos_grande'
ORDER BY c.range_start;

-- 2) Comprimir los 2 chunks más antiguos
SELECT compress_chunk(format('%I.%I', x.chunk_schema, x.chunk_name)::regclass)
FROM (
    SELECT chunk_schema, chunk_name
    FROM timescaledb_information.chunks
    WHERE hypertable_name = 'vehiculos_grande'
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
WHERE c.hypertable_name = 'vehiculos_grande'
ORDER BY c.range_start;

-- 4) Comparativa: bytes antes vs después (los 2 comprimidos)
SELECT c.chunk_name,
       pg_size_pretty(pg_total_relation_size((c.chunk_schema || '.' || c.chunk_name)::regclass)) AS size_actual,
       c.is_compressed
FROM timescaledb_information.chunks c
WHERE c.hypertable_name = 'vehiculos_grande'
  AND c.is_compressed
ORDER BY c.range_start;

-- ---------------------------------------------------------------
-- 5) OPCIONAL - CREAR EL JOB DE COMPRESIÓN AUTOMÁTICA (política)
--    Si en vez de comprimir a mano quieres que Timescale lo haga solo:
--    crea un job (policy_compression) que corre cada 24h y comprime todo
--    chunk cuyo rango temporal termina hace más de 24h.
SELECT add_compression_policy('vehiculos_grande',
       compress_after     => INTERVAL '24 hours',   -- comprimir lo más viejo que 24h
       schedule_interval  => INTERVAL '24 hours');  -- el job corre cada 24h
--    Devuelve el job_id (normalmente 1000).

-- 6) Ver el job creado y su siguiente ejecución
SELECT job_id, proc_name, schedule_interval, hypertable_name
FROM timescaledb_information.jobs
WHERE proc_name LIKE 'policy_compression%';

SELECT job_id, last_run_started_at, last_run_status, next_start,
       total_runs, total_successes, total_failures
FROM timescaledb_information.job_stats
WHERE job_id = 1000;

-- 7) Si no quieres esperar al horario, ejecútalo a mano
--    (run_job es un PROCEDIMIENTO: usa CALL, no SELECT)
CALL run_job(1000);

-- Nota: los comandos completos (con creación idempotente) están
-- en sql/05_compresion_politica.sql.