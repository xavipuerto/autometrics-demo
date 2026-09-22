-- 01_ddl.sql
-- Prueba 1: 3 tablas de telemetría de vehículos (10 sensores por fila)
--   1. vehiculos_plana: tabla core PostgreSQL (sin Timescale)
--   2. vehiculos_ts:    hypertable Timescale, chunks en ruta por defecto (_timescaledb_internal, prefijo _hyper)
--   3. vehiculos_part:   hypertable Timescale, chunks en esquema 'particiones' con prefijo derivado de la tabla
--
-- Datos: 10 coches x 24 lecturas al dia (una por hora) x dias_datos dias.
--Para cambiar el volumen ajusta el parametro dias_datos (por defecto 1500 -> ~360.000 filas ~ 30MB por tabla).
\set dias_datos 1500
\set fecha_inicio 2026-01-01

CREATE EXTENSION IF NOT EXISTS timescaledb;

CREATE SCHEMA IF NOT EXISTS particiones;
COMMENT ON SCHEMA particiones IS 'Esquema destino de los chunks de la hypertable vehiculos_part (particionado en esquema propio).';

-- 1) Tabla plana (sin Timescale)
CREATE TABLE IF NOT EXISTS vehiculos_plana (
    auto_id              INT           NOT NULL,
    ts                   TIMESTAMPTZ   NOT NULL,
    presion_ruedas       NUMERIC(6,3),
    nivel_combustible    SMALLINT,
    carga_bateria        SMALLINT,
    temperatura_motor    NUMERIC(5,2),
    temperatura_bateria  NUMERIC(5,2),
    presion_aceite       NUMERIC(6,2),
    velocidad            NUMERIC(6,1),
    revoluciones         SMALLINT,
    consumo_potencia     NUMERIC(6,1),
    autonomia            SMALLINT
);
COMMENT ON TABLE vehiculos_plana IS 'Tabla core PostgreSQL (sin Timescale) de telemetría de vehículos. Se usa como referencia de 30MB sin particionado.';
COMMENT ON COLUMN vehiculos_plana.auto_id IS 'Identificador del vehículo que genera la telemetría.';
COMMENT ON COLUMN vehiculos_plana.ts IS 'Marca de tiempo (UTC) en la que se registró la telemetría.';
COMMENT ON COLUMN vehiculos_plana.presion_ruedas IS 'Presión de los neumáticos, en bar.';
COMMENT ON COLUMN vehiculos_plana.nivel_combustible IS 'Nivel de llenado del depósito de gasolina, en %.';
COMMENT ON COLUMN vehiculos_plana.carga_bateria IS 'Estado de carga de la batería de tracción, en %.';
COMMENT ON COLUMN vehiculos_plana.temperatura_motor IS 'Temperatura del motor / refrigerante, en grados centígrados.';
COMMENT ON COLUMN vehiculos_plana.temperatura_bateria IS 'Temperatura del pack de baterías, en grados centígrados.';
COMMENT ON COLUMN vehiculos_plana.presion_aceite IS 'Presión del circuito de aceite, en bar.';
COMMENT ON COLUMN vehiculos_plana.velocidad IS 'Velocidad del vehículo, en km/h.';
COMMENT ON COLUMN vehiculos_plana.revoluciones IS 'Revoluciones del motor por minuto (rpm).';
COMMENT ON COLUMN vehiculos_plana.consumo_potencia IS 'Consumo/generación instantánea de potencia, en kW (negativo = regeneración).';
COMMENT ON COLUMN vehiculos_plana.autonomia IS 'Autonomía restante estimada, en km.';

-- 2) Hypertable con chunks por defecto
CREATE TABLE IF NOT EXISTS vehiculos_ts (
    auto_id              INT           NOT NULL,
    ts                   TIMESTAMPTZ   NOT NULL,
    presion_ruedas       NUMERIC(6,3),
    nivel_combustible    SMALLINT,
    carga_bateria        SMALLINT,
    temperatura_motor    NUMERIC(5,2),
    temperatura_bateria  NUMERIC(5,2),
    presion_aceite       NUMERIC(6,2),
    velocidad            NUMERIC(6,1),
    revoluciones         SMALLINT,
    consumo_potencia     NUMERIC(6,1),
    autonomia            SMALLINT
);
COMMENT ON TABLE vehiculos_ts IS 'Hypertable Timescale de telemetría de vehículos con configuración por defecto: chunks en _timescaledb_internal con prefijo _hyper.';
COMMENT ON COLUMN vehiculos_ts.auto_id IS 'Identificador del vehículo que genera la telemetría.';
COMMENT ON COLUMN vehiculos_ts.ts IS 'Marca de tiempo (UTC) en la que se registró la telemetría. Columna de particionado.';
COMMENT ON COLUMN vehiculos_ts.presion_ruedas IS 'Presión de los neumáticos, en bar.';
COMMENT ON COLUMN vehiculos_ts.nivel_combustible IS 'Nivel de llenado del depósito de gasolina, en %.';
COMMENT ON COLUMN vehiculos_ts.carga_bateria IS 'Estado de carga de la batería de tracción, en %.';
COMMENT ON COLUMN vehiculos_ts.temperatura_motor IS 'Temperatura del motor / refrigerante, en grados centígrados.';
COMMENT ON COLUMN vehiculos_ts.temperatura_bateria IS 'Temperatura del pack de baterías, en grados centígrados.';
COMMENT ON COLUMN vehiculos_ts.presion_aceite IS 'Presión del circuito de aceite, en bar.';
COMMENT ON COLUMN vehiculos_ts.velocidad IS 'Velocidad del vehículo, en km/h.';
COMMENT ON COLUMN vehiculos_ts.revoluciones IS 'Revoluciones del motor por minuto (rpm).';
COMMENT ON COLUMN vehiculos_ts.consumo_potencia IS 'Consumo/generación instantánea de potencia, en kW (negativo = regeneración).';
COMMENT ON COLUMN vehiculos_ts.autonomia IS 'Autonomía restante estimada, en km.';
SELECT create_hypertable('vehiculos_ts', 'ts', chunk_time_interval => INTERVAL '1 day');

-- 3) Hypertable con chunks en esquema 'particiones' y prefijo de tabla
CREATE TABLE IF NOT EXISTS vehiculos_part (
    auto_id              INT           NOT NULL,
    ts                   TIMESTAMPTZ   NOT NULL,
    presion_ruedas       NUMERIC(6,3),
    nivel_combustible    SMALLINT,
    carga_bateria        SMALLINT,
    temperatura_motor    NUMERIC(5,2),
    temperatura_bateria  NUMERIC(5,2),
    presion_aceite       NUMERIC(6,2),
    velocidad            NUMERIC(6,1),
    revoluciones         SMALLINT,
    consumo_potencia     NUMERIC(6,1),
    autonomia            SMALLINT
);
COMMENT ON TABLE vehiculos_part IS 'Hypertable Timescale de telemetría de vehículos cuyos chunks se crean en el esquema particiones con prefijo derivado del nombre de la tabla.';
COMMENT ON COLUMN vehiculos_part.auto_id IS 'Identificador del vehículo que genera la telemetría.';
COMMENT ON COLUMN vehiculos_part.ts IS 'Marca de tiempo (UTC) en la que se registró la telemetría. Columna de particionado.';
COMMENT ON COLUMN vehiculos_part.presion_ruedas IS 'Presión de los neumáticos, en bar.';
COMMENT ON COLUMN vehiculos_part.nivel_combustible IS 'Nivel de llenado del depósito de gasolina, en %.';
COMMENT ON COLUMN vehiculos_part.carga_bateria IS 'Estado de carga de la batería de tracción, en %.';
COMMENT ON COLUMN vehiculos_part.temperatura_motor IS 'Temperatura del motor / refrigerante, en grados centígrados.';
COMMENT ON COLUMN vehiculos_part.temperatura_bateria IS 'Temperatura del pack de baterías, en grados centígrados.';
COMMENT ON COLUMN vehiculos_part.presion_aceite IS 'Presión del circuito de aceite, en bar.';
COMMENT ON COLUMN vehiculos_part.velocidad IS 'Velocidad del vehículo, en km/h.';
COMMENT ON COLUMN vehiculos_part.revoluciones IS 'Revoluciones del motor por minuto (rpm).';
COMMENT ON COLUMN vehiculos_part.consumo_potencia IS 'Consumo/generación instantánea de potencia, en kW (negativo = regeneración).';
COMMENT ON COLUMN vehiculos_part.autonomia IS 'Autonomía restante estimada, en km.';
SELECT create_hypertable(
    'vehiculos_part',
    'ts',
    chunk_time_interval => INTERVAL '1 day',
    associated_schema_name => 'particiones',
    associated_table_prefix => 'vehiculos_part'
);

-- ============================================================================
-- Carga de datos aleatorios (24 lecturas/dia x 10 coches, una por hora)
-- ============================================================================
--
-- Cada INSERT rellena:
--   10 coches (auto_id 1..10)
--   x 24 lecturas al dia (h = 0..23, una por hora)
--   x :dias_datos dias (por defecto 1500)
--   = 360.000 registros por tabla  (~35 MB c/u en vehiculos_plana)
--
-- Los valores de los 10 sensores se generan con random() en rangos realistas
-- (presion_ruedas 2,3-2,6 bar, velocidad 0-140 km/h, etc.).

-- 1) vehiculos_plana --> INSERT 0 360000 (0 dias extra si cambias :dias_datos)
INSERT INTO vehiculos_plana (auto_id, ts, presion_ruedas, nivel_combustible, carga_bateria,
                            temperatura_motor, temperatura_bateria, presion_aceite, velocidad,
                            revoluciones, consumo_potencia, autonomia)
SELECT a,
       :'fecha_inicio'::date + d * interval '1 day' + h * interval '1 hour',
       round((2.3 + random() * 0.3)::numeric, 3),
       floor(5 + random() * 95)::int,
       floor(15 + random() * 85)::int,
       round((85 + random() * 20)::numeric, 2),
       round((25 + random() * 20)::numeric, 2),
       round((2.5 + random() * 2)::numeric, 2),
       round((random() * 140)::numeric, 1),
       floor(800 + random() * 5700)::int,
       round((-5 + random() * 80)::numeric, 1),
       floor(150 + random() * 350)::int
FROM generate_series(1, 10) a,
     generate_series(0, :dias_datos - 1) d,
     generate_series(0, 23) h;

-- 2) vehiculos_ts --> INSERT 0 360000 (otras 360.000 filas, ahora en chunks diarios)
INSERT INTO vehiculos_ts (auto_id, ts, presion_ruedas, nivel_combustible, carga_bateria,
                         temperatura_motor, temperatura_bateria, presion_aceite, velocidad,
                         revoluciones, consumo_potencia, autonomia)
SELECT a,
       :'fecha_inicio'::date + d * interval '1 day' + h * interval '1 hour',
       round((2.3 + random() * 0.3)::numeric, 3),
       floor(5 + random() * 95)::int,
       floor(15 + random() * 85)::int,
       round((85 + random() * 20)::numeric, 2),
       round((25 + random() * 20)::numeric, 2),
       round((2.5 + random() * 2)::numeric, 2),
       round((random() * 140)::numeric, 1),
       floor(800 + random() * 5700)::int,
       round((-5 + random() * 80)::numeric, 1),
       floor(150 + random() * 350)::int
FROM generate_series(1, 10) a,
     generate_series(0, :dias_datos - 1) d,
     generate_series(0, 23) h;

-- 3) vehiculos_part --> INSERT 0 360000 (otras 360.000, chunks en esquema 'particiones')
INSERT INTO vehiculos_part (auto_id, ts, presion_ruedas, nivel_combustible, carga_bateria,
                          temperatura_motor, temperatura_bateria, presion_aceite, velocidad,
                          revoluciones, consumo_potencia, autonomia)
SELECT a,
       :'fecha_inicio'::date + d * interval '1 day' + h * interval '1 hour',
       round((2.3 + random() * 0.3)::numeric, 3),
       floor(5 + random() * 95)::int,
       floor(15 + random() * 85)::int,
       round((85 + random() * 20)::numeric, 2),
       round((25 + random() * 20)::numeric, 2),
       round((2.5 + random() * 2)::numeric, 2),
       round((random() * 140)::numeric, 1),
       floor(800 + random() * 5700)::int,
       round((-5 + random() * 80)::numeric, 1),
       floor(150 + random() * 350)::int
FROM generate_series(1, 10) a,
     generate_series(0, :dias_datos - 1) d,
     generate_series(0, 23) h;

-- Verificación de conteos (para el speech: cuantos registros hay en cada tabla)
SELECT 'vehiculos_plana' AS tabla, count(*) AS registros FROM vehiculos_plana
UNION ALL SELECT 'vehiculos_ts', count(*) FROM vehiculos_ts
UNION ALL SELECT 'vehiculos_part', count(*) FROM vehiculos_part;