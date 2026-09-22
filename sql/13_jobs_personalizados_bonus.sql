-- 13_jobs_personalizados_bonus.sql
-- Bonus: JOBS PERSONALIZADOS de TimescaleDB.
--
-- Hasta ahora los jobs los creaban las políticas (compresión, retención,
-- refresh de cagg). PERO Timescale te deja programar CUALQUIER funcion o
-- procedimiento PostgreSQL en su planificador: un "cron" gestionado por el
-- motor (persistencia en pg + worker en segundo plano: add_job/run_job).
-- CASO DE USO: calculamos un KPI (velocidad y rpm máximas por hora y coche)
-- y lo volcamos en una tabla aparte, cada hora, sin tocar la tabla cruda.
--
-- Ruta de la demo (probado en 2.30.1 / PG 18.6):
--   add_job -> 1003 | run_job(1003) -> rellena kpi_velocidad | delete_job(1003)
--   al recrearlo -> 1004 (hasta llegar a 1005 cuando se borre el primero).

-- 1) La TABLA destino del KPI (se rellena SOLO por el job).
CREATE TABLE IF NOT EXISTS kpi_velocidad (
    ventana   TIMESTAMPTZ  NOT NULL,
    auto_id   INT          NOT NULL,
    lecturas  INT          NOT NULL,
    vel_max   NUMERIC(6,1) NOT NULL,
    rpm_max   INT          NOT NULL,
    PRIMARY KEY (ventana, auto_id)
);

-- 2) El PROCEDIMIENTO que ejecutará el job.
--    - Firma PL/pgSQL: (job_id int, config jsonb) -> Timescale se los inyecta.
--    - Calcula el KPI de la ÚLTIMA HORA COMPLETA (date_trunc('hour', now-1h))
--      y lo upserta (si el job repite la hora no duplica filas).
--    - Truco: la sentencia referencia "v" (no "ventana")
--      para no chocar con la columna homónima en ON CONFLICT (GOTCHA probado).
CREATE OR REPLACE PROCEDURE calc_kpi_ultima_hora(job_id int, config jsonb)
LANGUAGE plpgsql AS $fn$
DECLARE
  v timestamptz := date_trunc('hour', now() - interval '1 hour');
BEGIN
  INSERT INTO kpi_velocidad (ventana, auto_id, lecturas, vel_max, rpm_max)
  SELECT v, auto_id,
         count(*)::int,
         max(velocidad),
         max(revoluciones)
  FROM vehiculos_ts
  WHERE ts >= v AND ts < v + interval '1 hour'
  GROUP BY auto_id
  ON CONFLICT (ventana, auto_id) DO UPDATE SET
        lecturas = EXCLUDED.lecturas,
        vel_max  = EXCLUDED.vel_max,
        rpm_max  = EXCLUDED.rpm_max;
END
$fn$;

-- 3) PROGRAMAR el job en Timescale (devuelve el job_id, aquí 1003/1004).
--    schedule_interval = cada cuánto se dispara. Este job NO necesita
--    TSL ni licencia extra: los custom jobs están incluidos.
SELECT add_job('calc_kpi_ultima_hora(int,jsonb)'::regprocedure,
               schedule_interval => INTERVAL '1 hour');
--    -> job_id (depende de cuántos jobs hayas creado/borrado; en la demo
--       probada salió 1003 y, al recrearlo, 1004)

-- 4) Ejecutarlo a mano para probar (los jobs son PROCEDIMIENTOS -> CALL):
CALL run_job(1003);    -- <- usa el job_id devuelto en el paso 3

SELECT ventana, auto_id, lecturas, vel_max, rpm_max
FROM kpi_velocidad ORDER BY ventana, auto_id;

-- 5) Estado en el panel de jobs (junto a las políticas):
SELECT job_id, proc_name, schedule_interval, next_start
FROM timescaledb_information.jobs
WHERE job_id IN (1000, 1001, 1002, 1003)
ORDER BY job_id;

-- 6) PAUSAR (sin borrar el job): scheduled => false
SELECT alter_job(1003, scheduled => false);

-- 7) BORRAR el job por id (2.30: delete_job; NO remove_job, que desapareció):
SELECT delete_job(1003);   -- -> ya no aparece en jobs

-- 8) Verificar que se borró:
SELECT count(*) FROM timescaledb_information.jobs WHERE job_id = 1003;

-- 9) Si quieres dejarlo "vivo" en la demo, crea uno nuevo:
SELECT add_job('calc_kpi_ultima_hora(int,jsonb)'::regprocedure,
               schedule_interval => INTERVAL '1 hour');   -- -> 1004