-- 11_continuous_aggregates.sql
-- Continuous aggregates (agregados materializados) sobre vehiculos_ts.
--
-- Qué es: una vista MATERIALIZADA que Timescale refresca por ventanas.
-- Precalcula el GROUP BY de time_bucket para que las consultas de
-- reporting/dashboards NO vuelvan a barrer la hypertable cruda: consultas
-- instantáneas + menos I/O + ahorro de CPU. Es la evolución natural de
-- sql/10_time_bucket.sql (downsampling).
--
-- CLAVE EN TIMESCALE 2.30: materialized_only = t  (ya NO hay "realtime".
-- aggregates"): los datos NUEVOS insertados no aparecen en el cagg hasta que
-- se refresca (a mano o con la política). En versiones antiguas el cagg
-- mezclaba lo materializado con lo crudo en la misma consulta.

-- 1) Crear el cagg: media/mín/máx de velocidad + lecturas, por hora y coche.
--    Al crearlo se materializa TODO el histórico automáticamente.
CREATE MATERIALIZED VIEW cag_vel_hora
WITH (timescaledb.continuous) AS
SELECT time_bucket('1 hour', ts)        AS hora,
       auto_id,
       count(*)                            AS lecturas,
       round(avg(velocidad)::numeric, 1)   AS vel_media,
       round(max(velocidad)::numeric, 1)   AS vel_max,
       round(min(velocidad)::numeric, 1)   AS vel_min
FROM vehiculos_ts
GROUP BY 1, 2;

-- 2) Dónde vive y modo: vista ligada a su propia hypertable materializada
SELECT view_name, materialized_only, materialization_hypertable_name
FROM timescaledb_information.continuous_aggregates;
--    materialized_only = t  -> no hay real-time: refrescar para ver lo nuevo.

-- 3) Tamaños reales (suma de chunks, no de la vista):
--    vehiculos_ts (cruda) = 94 MB | cagg = 57 MB (aún SIN comprimir).
SELECT pg_size_pretty(sum(pg_total_relation_size(c))) AS cruda_size
FROM show_chunks('vehiculos_ts') c;
SELECT pg_size_pretty(sum(pg_total_relation_size(c))) AS cagg_size
FROM show_chunks('_timescaledb_internal._materialized_hypertable_8') c;

-- 4) Rendimiento medido (1 año = 87.600 lecturas):
--    cruda: ~50 ms · 4500 buffers | cagg: ~15 ms · 3450 buffers (~3x).
--    Con más histórico y chunks comprimidos la diferencia se dispara.
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF)
SELECT round(avg(velocidad)::numeric,1) FROM vehiculos_ts
WHERE ts >= '2027-01-01'::timestamptz AND ts < '2028-01-01'::timestamptz;
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF)
SELECT round(avg(vel_media)::numeric,1) FROM cag_vel_hora
WHERE hora >= '2027-01-01'::timestamptz AND hora < '2028-01-01'::timestamptz;

-- 5) GOTCHA 2.30 (probado en la demo): insertar una fila futura y consultar
--    el cagg -> NO aparece (materialized_only = t).
--    INSERT INTO vehiculos_ts ... VALUES (1, '2030-02-09 23:00:00+00', ...);
--    SELECT * FROM cag_vel_hora WHERE hora = '2030-02-09 23:00:00+00';  -- 0 filas

-- 6) Refresco A MANO (procedimiento, no SELECT):
CALL refresh_continuous_aggregate('cag_vel_hora',
                                  timestamptz '2030-02-08',
                                  timestamptz '2030-02-10');
--    Tras el refresh, el bucket 23:00 de 2030-02-09 ya sale (1 lectura: la insertada).

-- 7) Refresco AUTOMÁTICO: política de refresh (devuelve job_id, aquí 1002)
--    Corre cada 1h y sólo toca [ahora - 1 mes, ahora - 1 hora]:
--    end_offset 1h = el bucket en curso NO se recalcula (probablemente aún
--    recibe escrituras).
SELECT add_continuous_aggregate_policy('cag_vel_hora',
       start_offset      => INTERVAL '1 month',
       end_offset        => INTERVAL '1 hour',
       schedule_interval => INTERVAL '1 hour');

-- 8) Estado de los jobs de política (el "panel" de la demo):
SELECT job_id, proc_name, schedule_interval
FROM timescaledb_information.jobs
WHERE job_id IN (1000, 1001, 1002)
ORDER BY job_id;
--    1000 policy_compression                   cada 24 h
--    1001 policy_retention                     cada 24 h
--    1002 policy_refresh_continuous_aggregate  cada 1 h

-- 9) Opcional: comprimir el cagg (como cualquier hypertable) para que el
--    histórico materializado pese aún menos:
--    ALTER MATERIALIZED VIEW cag_vel_hora SET (timescaledb.compress);
--    SELECT add_compression_policy('cag_vel_hora', compress_after => INTERVAL '7 days');