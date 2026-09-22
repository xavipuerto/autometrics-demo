-- 12_tuning_gucs.sql
-- Tuning de parámetros de configuración (TimescaleDB + PostgreSQL).
-- La imagen timescale/timescaledb auto-ajusta los principales al arrancar
-- según la RAM/CPU del contenedor; aquí se muestra cómo consultarlos y
-- cómo cambiarlos para producción.
--
-- CALCULADORA RÁPIDA (misma regla que usa PgTune/Timescale):
--   shared_buffers                 = 25% de la RAM
--   effective_cache_size           = ~75% de la RAM (lo que USA el SO de caché)
--   maintenance_work_mem           = ~5-6% de la RAM (p.ej. 1 GB en 16 GB)
--   work_mem                      = 8-16 MB por conteo de conexiones simultáneas
--   max_parallel_workers_per_gather= nº de núcleos
--   max_parallel_workers           = nº de núcleos
--   max_worker_processes           = parallel + timescaledb.max_background_workers + margen aplicacion
--   max_connections               = nº de clientes pico esperados (no 1000)
--
-- Ejemplo servidor 4 CPU / 16 GB:
--   shared_buffers = 4 GB
--   effective_cache_size = 12 GB
--   maintenance_work_mem = 1 GB
--   work_mem = 16 MB
--   max_parallel_workers_per_gather = 4
--   max_parallel_workers = 4
--   max_worker_processes = 28   (8 parallel*sin usar todos + 16 bgw TS + 4 margen)
--   timescaledb.max_background_workers = 8
--   max_wal_size = 4 GB
--   checkpoint_completion_target = 0.9

-- 1) Ver los valores ACTUALES de los parámetros clave
SELECT name, setting, unit
FROM pg_settings
WHERE name IN ('shared_buffers','max_connections','work_mem','maintenance_work_mem',
               'effective_cache_size','max_parallel_workers_per_gather','max_parallel_workers',
               'max_worker_processes','timescaledb.max_background_workers',
               'timescaledb.max_open_chunks_per_insert','timescaledb.telemetry_level',
               'checkpoint_completion_target','wal_buffers','max_wal_size')
ORDER BY name;

-- 2) Parámetros propios de TIMESCALE (prefijo timescaledb.*)
SELECT name, setting, unit
FROM pg_settings
WHERE name LIKE 'timescaledb.%'
ORDER BY name;
--   timescaledb.max_background_workers     -> threads de los jobs (compresion, retencion, cagg...).
--                                            Debe caber en max_worker_processes.
--   timescaledb.max_open_chunks_per_insert -> chunks que mantiene abiertos un INSERT masivo.
--                                            Relacionado con el tamaño del chunk_time_interval:
--                                            si tus chunks son de 3 dias, baja esto (ej. 16)
--                                            en vez de 1024.
--   timescaledb.telemetry_level            -> 'basic' por defecto; en producción se apaga ('off').

-- 3) Cómo CAMBIARLOS (produce postgresql.auto.conf; requiere reload/restart)
-- ALTER SYSTEM SET shared_buffers = '4GB';                    -- restart
-- ALTER SYSTEM SET effective_cache_size = '12GB';             -- reload
-- ALTER SYSTEM SET max_parallel_workers_per_gather = 4;       -- restart
-- ALTER SYSTEM SET max_parallel_workers = 4;                  -- restart
-- ALTER SYSTEM SET max_worker_processes = 28;                 -- restart
-- ALTER SYSTEM SET timescaledb.max_background_workers = 8;    -- restart
-- ALTER SYSTEM SET timescaledb.max_open_chunks_per_insert = 16;
-- ALTER SYSTEM SET timescaledb.telemetry_level = 'off';
-- Docker: añádelos como --cpus / -m al contenedor y Timescale AUTO-tunea al arrancar.

-- 4) Ver en qué fichero están y si son reloadable (context)
SELECT name, context, source
FROM pg_settings
WHERE name IN ('shared_buffers','max_parallel_workers','timescaledb.max_background_workers');