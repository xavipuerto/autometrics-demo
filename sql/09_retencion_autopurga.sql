-- 09_retencion_autopurga.sql
-- Autopurgado: política de retención que borra chunks viejos automáticamente.
-- Demo: vehiculos_grande con 3 chunks -> con drop_after 5 dias se purga el
-- chunk más antiguo (6003, 2026-09-13..09-16) y quedan 2.
--
-- Cómo decide qué borrar: la retención elimina el chunk COMPLETO cuando su
-- range_end queda ANTES de now() - drop_after. Con 3 chunks de 3 días
-- contiguos, borrar es "el más viejo" = exactamente 1.

-- 0) Estado inicial: 3 chunks (6003 comprimido, 6004 comprimido, 6005 sin comprimir)
SELECT chunk_name, is_compressed, range_start, range_end,
       pg_size_pretty(pg_total_relation_size(to_regclass('particiones_grandes.'||chunk_name))) AS size
FROM timescaledb_information.chunks
WHERE hypertable_name = 'vehiculos_grande'
ORDER BY range_start;

SELECT count(*) AS total_filas FROM vehiculos_grande;  -- 2.706.126 (518.405 + 518.405 + 1.669.321... ajustado al estado)

-- ---------------------------------------------------------------
-- 1) MANUAL - ver qué se borraría y borrarlo a mano (una vez, sin job)
SELECT show_chunks('vehiculos_grande', older_than => now() - interval '5 days');
--    -> devuelve solo 'particiones_grandes.vehiculos_grande_6003_chunk'

SELECT drop_chunks('vehiculos_grande', older_than => now() - interval '5 days');
--    -> "SELECT 1" (1 chunk borrado). 6003 desaparece, 6004/6005 se quedan.

-- ---------------------------------------------------------------
-- 2) AUTOMÁTICO - crear el job de retención (devuelve el job_id, aquí 1001)
--    Corre cada 24h por defecto y purga lo más viejo que 5 días.
SELECT add_retention_policy('vehiculos_grande', drop_after => INTERVAL '5 days');

-- 3) Ver el job creado y su estado
SELECT job_id, proc_name, schedule_interval, hypertable_name
FROM timescaledb_information.jobs
WHERE proc_name LIKE 'policy_retention%';

SELECT job_id, last_run_started_at, last_run_status, next_start,
       total_runs, total_successes, total_failures
FROM timescaledb_information.job_stats
WHERE job_id = 1001;

-- 4) Forzarlo a mano si no quieres esperar al horario (run_job es PROCEDIMIENTO)
CALL run_job(1001);

-- 5) Estado final: de 3 chunks -> 2; el más antiguo (6003) purgado
SELECT chunk_name, is_compressed, range_start, range_end
FROM timescaledb_information.chunks
WHERE hypertable_name = 'vehiculos_grande'
ORDER BY range_start;

SELECT count(*) AS total_filas FROM vehiculos_grande;  -- menos las filas del chunk purgado (518.405)

-- 6) Si cambias de opinión: eliminar la política de retención
SELECT remove_retention_policy('vehiculos_grande');