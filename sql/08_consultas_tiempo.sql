-- 08_consultas_tiempo.sql
-- Consultas POR TIEMPO sobre la hypertable vehiculos_ts.
--
-- IMPORTANTE (recreacion del entorno): los rangos se DERIVAN de los datos
-- (min/max ts) para que funcionen igual mañana cuando se rehaga todo desde
-- cero. La fecha fija de carga es 2026-01-01 (sql/01_ddl.sql) -> el último
-- día siempre existe sea cual sea el dia en que se ejecuten.
-- En la DEMO se usan estas consultas dinamicas; si prefieres fechas fijas,
-- sustituye max(ts) por una fecha conocida (p.ej. '2026-05-15').

-- 0) Rango real de datos (para el speech y para acotar consultas)
SELECT min(ts) AS min_ts, max(ts) AS max_ts, count(*) AS total
FROM vehiculos_ts;

-- 1) Ultimas 24h de datos: 10 coches x 24 horas = 240 lecturas (1 chunk)
SELECT count(*) AS ultimas_24h,
       count(DISTINCT date_trunc('hour', ts)) AS horas_distintas
FROM vehiculos_ts
WHERE ts >  (SELECT max(ts) FROM vehiculos_ts) - interval '24 hours'
  AND ts <= (SELECT max(ts) FROM vehiculos_ts);

-- 2) Agregado por hora (time_bucket) del ultimo dia completo
SELECT time_bucket('1 hour', ts) AS hora,
       count(*)                   AS lecturas,
       round(avg(velocidad)::numeric, 1) AS vel_media,
       round(max(velocidad)::numeric, 1) AS vel_max
FROM vehiculos_ts
WHERE ts >= (SELECT max(ts)::date FROM vehiculos_ts) - interval '1 day'
  AND ts <  (SELECT max(ts)::date FROM vehiculos_ts)
GROUP BY 1
ORDER BY 1;

-- 3) Resumen diario de los ultimos 7 dias
SELECT time_bucket('1 day', ts) AS dia,
       count(*)                 AS lecturas,
       round(avg(velocidad)::numeric, 1) AS vel_media,
       round(avg(revoluciones)::numeric, 0) AS rpm_media
FROM vehiculos_ts
WHERE ts >= (SELECT max(ts) FROM vehiculos_ts) - interval '7 days'
GROUP BY 1
ORDER BY 1;

-- 4) EXPLAIN: ultimas 24h -> debe tocar 1 solo chunk (pruning)
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF)
SELECT count(*) FROM vehiculos_ts
WHERE ts >  (SELECT max(ts) FROM vehiculos_ts) - interval '24 hours'
  AND ts <= (SELECT max(ts) FROM vehiculos_ts);
--    Resultado esperado: Aggregate -> Seq Scan on _hyper_5_XXXX_chunk (1 chunk)

-- 5) EXPLAIN: ultimos 30 dias -> Append con ~30 chunks (no escanea los 1500)
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF)
SELECT count(*) FROM vehiculos_ts
WHERE ts > (SELECT max(ts) FROM vehiculos_ts) - interval '30 days';
--    Resultado esperado: Append -> ~30 Partial Aggregate

-- 6) Comparativa de rendimiento: misma ventana 24h en tabla plana (sin TS)
--    -> escanea TODA la tabla (4440 buffers aprox), descarta ~119.000 filas
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF)
SELECT count(*) FROM vehiculos_plana
WHERE ts >= (SELECT max(ts) FROM vehiculos_plana) - interval '24 hours'
  AND ts <= (SELECT max(ts) FROM vehiculos_plana);

-- 7) grande: ultima ventana del chunk grande (3 dias)
SELECT count(*) AS lecturas_chunk_activo
FROM vehiculos_grande
WHERE ts >= (SELECT max(ts) FROM vehiculos_grande) - interval '3 days';