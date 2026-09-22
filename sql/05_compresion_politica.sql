-- 05_compresion_politica.sql
-- Política automática de compresión sobre vehiculos_grande.
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

-- 1) Crear la política (devuelve el job_id creado, p.ej. 1000)
SELECT add_compression_policy('vehiculos_grande',
       compress_after     => INTERVAL '24 hours',
       schedule_interval  => INTERVAL '24 hours');
--    Ojo: si ya existe salta error "policy already exists".
--    Para ver un job existente:
--    SELECT job_id, proc_name, schedule_interval FROM timescaledb_information.jobs
--    WHERE proc_name LIKE 'policy_compression%';

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
       pg_size_pretty(pg_total_relation_size(to_regclass('particiones_grandes.'||chunk_name))) AS size
FROM timescaledb_information.chunks
WHERE hypertable_name = 'vehiculos_grande'
ORDER BY range_start;

-- ---------------------------------------------------------------
-- 6) BORRAR EL JOB DE COMPRESIÓN (por si no te ha convencido)
--    Elimina la política y su job de fondo de golpe:
SELECT remove_compression_policy('vehiculos_grande');
--    Verificar que ya no existe:
--    SELECT job_id, proc_name FROM timescaledb_information.jobs
--    WHERE proc_name LIKE 'policy_compression%';   -- -> 0 filas

-- 7) Alternativas a borrar del todo:
--    a) Pausar el job (lo dejas creado pero sin ejecutarse):
SELECT alter_job(1000, scheduled => false);
--    Reanudarlo cuando quieras:
SELECT alter_job(1000, scheduled => true);
--    b) Cambiar la ventana de compresión sin recrear (más agresivo/menos agresivo):
--    SELECT alter_job(1000, config => '{"compress_after": 259200000000}');  -- 3 días en microsegundos
--    c) Seguir comprimiendo a mano sin política: compress_chunk (ver 03_compresion.sql)