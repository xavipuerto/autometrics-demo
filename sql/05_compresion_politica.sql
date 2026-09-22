-- 05_compresion_politica.sql
-- Política automática de compresión sobre vehiculos_gorda.
--
-- Qué hace: un job de fondo (policy_compression, job_id 1000) corre cada 24h
-- y comprime/recomprime TODO CHUNK cuyo rango temporal termina hace más de 24h:
--   - comprime de nuevo los chunks con overflow (mezcla filas rowstore -> columnstore)
--   - comprime por primera vez chunks descomprimidos que ya han "envejecido"
--   - NO toca el chunk activo (el que recibe escrituras recientes)
--
-- Comportamiento observado (2026-09-22):
--   - El job se ejecutó solo al crearse (bgw): Success, total_runs=1.
--   - Chunk 6004: 111 MB (overflow de 1.000.000 + 140.916 filas) -> 24 kB,
--     absorbiendo todo el overflow al columnstore SIN intervención manual.
--   - Chunk 6005 (56 MB, ventana hasta hoy): NO se comprimió aún, porque la
--     política solo actúa sobre lo "más viejo que 24 horas". Se comprimirá
--     cuando su ventana quede atrás (approx. 24h después).
--   - next_start queda fijado a +24h; ver job_stats para el próximo run.

-- 1) Crear la política (si no existe ya)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM timescaledb_information.jobs
                 WHERE proc_name = 'policy_compression'
                   AND hypertable_name = 'vehiculos_gorda') THEN
    PERFORM add_compression_policy('vehiculos_gorda',
                                   compress_after     => INTERVAL '24 hours',
                                   schedule_interval  => INTERVAL '24 hours');
  END IF;
END $$;

-- 2) Ver el job creado
SELECT job_id, proc_name, schedule_interval, hypertable_name
FROM timescaledb_information.jobs
WHERE proc_name LIKE 'policy_compression%';

-- 3) Estado: ejecución, siguiente lanzamiento y resultados
SELECT job_id, last_run_started_at, last_run_status, next_start,
       total_runs, total_successes, total_failures
FROM timescaledb_information.job_stats
WHERE job_id = 1000;

-- 4) Ejecutarlo a mano si no quieres esperar al schedule (run_job es procedimiento)
CALL run_job(1000);

-- 5) Comprobar el estado físico de los chunks tras la política
SELECT chunk_name, is_compressed,
       pg_size_pretty(pg_total_relation_size(to_regclass('particiones_gordas.'||chunk_name))) AS size
FROM timescaledb_information.chunks
WHERE hypertable_name = 'vehiculos_gorda'
ORDER BY range_start;