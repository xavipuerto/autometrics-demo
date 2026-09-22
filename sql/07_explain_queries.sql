-- 07_explain_queries.sql
-- Consultas filtradas con EXPLAIN: ver el "chunk pruning" en acción.
--
-- El punto clave para la PPT: filtrar por la columna de particionado (ts)
-- hace que Timescale SOLO toque los trozos que le corresponden.
-- Comparativa (mismo filtro de 1 dia, 2026-05-15):

-- 1) COMPACTO: 1 dia en una hypertable con 1500 chunks diarios -> 1 chunk
EXPLAIN (COSTS OFF)
SELECT count(*) FROM vehiculos_ts
WHERE ts >= '2026-05-15'::timestamptz AND ts < '2026-05-16'::timestamptz;
--      Aggregate
--        ->  Seq Scan on _hyper_5_3137_chunk   <-- solo 1 chunk de los 1500

-- 2) ANALYZE: 1 dia en vehiculos_ts -> tocado 1 chunk, 3 buffers, ~0,1 ms
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF)
SELECT count(*) FROM vehiculos_ts
WHERE ts >= '2026-05-15'::timestamptz AND ts < '2026-05-16'::timestamptz;

-- 3) 30 dias -> Append con ~30 chunks parciales (no escanea los 1500)
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF)
SELECT count(*) FROM vehiculos_ts
WHERE ts >= '2026-05-15'::timestamptz AND ts < '2026-06-14'::timestamptz;

-- 4) TABLA PLANA (sin Timescale): mismo filtro de 1 dia ->
--    escaneo COMPLETO de la tabla (4440 buffers, ~20 ms, descarta 119.920 filas)
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF)
SELECT count(*) FROM vehiculos_plana
WHERE ts >= '2026-05-15'::timestamptz AND ts < '2026-05-16'::timestamptz;
--    Parallel Seq Scan on vehiculos_plana  <-- toda la tabla, sin particiones

-- 5) Chunk COMPRIMIDO: la consulta lee directo del columnstore
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF)
SELECT count(*) FROM vehiculos_grande
WHERE ts >= '2026-09-16'::timestamptz AND ts < '2026-09-20'::timestamptz;
--    Custom Scan (ColumnarIndexScan) on vehiculos_grande_6004_chunk  <-- sobre la tabla de columnas

-- 6) Agregado por franja temporal: time_bucket sobre la hypertable grande
SELECT time_bucket('1 hour', ts) AS hora,
       count(*)                      AS lecturas,
       round(avg(velocidad)::numeric,1) AS vel_media
FROM vehiculos_ts
WHERE ts >= '2026-05-15'::timestamptz AND ts < '2026-05-16'::timestamptz
GROUP BY 1
ORDER BY 1;