-- 01_ddl.sql
-- Prueba 1: 3 tablas de telemetría de vehículos (10 sensores por fila)
--   1. lecturas_plana: tabla core PostgreSQL (sin Timescale)
--   2. lecturas_ts:    hypertable Timescale, chunks en ruta por defecto (_timescaledb_internal, prefijo _hyper)
--   3. lecturas_sch:   hypertable Timescale, chunks en esquema 'particiones' con prefijo derivado de la tabla
--
-- Datos: 10 coches x 24 lecturas al dia (una por hora) x dias_datos dias.
--Para cambiar el volumen ajusta el parametro dias_datos (por defecto 1500 -> ~360.000 filas ~ 30MB por tabla).
\set dias_datos 1500
\set fecha_inicio 2026-01-01

CREATE EXTENSION IF NOT EXISTS timescaledb;

CREATE SCHEMA IF NOT EXISTS particiones;
COMMENT ON SCHEMA particiones IS 'Esquema destino de los chunks de la hypertable lecturas_sch (particionado en esquema propio).';

-- 1) Tabla plana (sin Timescale)
CREATE TABLE IF NOT EXISTS lecturas_plana (
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
COMMENT ON TABLE lecturas_plana IS 'Tabla core PostgreSQL (sin Timescale) de telemetría de vehículos. Se usa como referencia de 30MB sin particionado.';
COMMENT ON COLUMN lecturas_plana.auto_id IS 'Identificador del vehículo que genera la telemetría.';
COMMENT ON COLUMN lecturas_plana.ts IS 'Marca de tiempo (UTC) en la que se registró la telemetría.';
COMMENT ON COLUMN lecturas_plana.presion_ruedas IS 'Presión de los neumáticos, en bar.';
COMMENT ON COLUMN lecturas_plana.nivel_combustible IS 'Nivel de llenado del depósito de gasolina, en %.';
COMMENT ON COLUMN lecturas_plana.carga_bateria IS 'Estado de carga de la batería de tracción, en %.';
COMMENT ON COLUMN lecturas_plana.temperatura_motor IS 'Temperatura del motor / refrigerante, en grados centígrados.';
COMMENT ON COLUMN lecturas_plana.temperatura_bateria IS 'Temperatura del pack de baterías, en grados centígrados.';
COMMENT ON COLUMN lecturas_plana.presion_aceite IS 'Presión del circuito de aceite, en bar.';
COMMENT ON COLUMN lecturas_plana.velocidad IS 'Velocidad del vehículo, en km/h.';
COMMENT ON COLUMN lecturas_plana.revoluciones IS 'Revoluciones del motor por minuto (rpm).';
COMMENT ON COLUMN lecturas_plana.consumo_potencia IS 'Consumo/generación instantánea de potencia, en kW (negativo = regeneración).';
COMMENT ON COLUMN lecturas_plana.autonomia IS 'Autonomía restante estimada, en km.';

-- 2) Hypertable con chunks por defecto
CREATE TABLE IF NOT EXISTS lecturas_ts (
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
COMMENT ON TABLE lecturas_ts IS 'Hypertable Timescale de telemetría de vehículos con configuración por defecto: chunks en _timescaledb_internal con prefijo _hyper.';
COMMENT ON COLUMN lecturas_ts.auto_id IS 'Identificador del vehículo que genera la telemetría.';
COMMENT ON COLUMN lecturas_ts.ts IS 'Marca de tiempo (UTC) en la que se registró la telemetría. Columna de particionado.';
COMMENT ON COLUMN lecturas_ts.presion_ruedas IS 'Presión de los neumáticos, en bar.';
COMMENT ON COLUMN lecturas_ts.nivel_combustible IS 'Nivel de llenado del depósito de gasolina, en %.';
COMMENT ON COLUMN lecturas_ts.carga_bateria IS 'Estado de carga de la batería de tracción, en %.';
COMMENT ON COLUMN lecturas_ts.temperatura_motor IS 'Temperatura del motor / refrigerante, en grados centígrados.';
COMMENT ON COLUMN lecturas_ts.temperatura_bateria IS 'Temperatura del pack de baterías, en grados centígrados.';
COMMENT ON COLUMN lecturas_ts.presion_aceite IS 'Presión del circuito de aceite, en bar.';
COMMENT ON COLUMN lecturas_ts.velocidad IS 'Velocidad del vehículo, en km/h.';
COMMENT ON COLUMN lecturas_ts.revoluciones IS 'Revoluciones del motor por minuto (rpm).';
COMMENT ON COLUMN lecturas_ts.consumo_potencia IS 'Consumo/generación instantánea de potencia, en kW (negativo = regeneración).';
COMMENT ON COLUMN lecturas_ts.autonomia IS 'Autonomía restante estimada, en km.';
SELECT create_hypertable('lecturas_ts', 'ts', chunk_time_interval => INTERVAL '1 day');

-- 3) Hypertable con chunks en esquema 'particiones' y prefijo de tabla
CREATE TABLE IF NOT EXISTS lecturas_sch (
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
COMMENT ON TABLE lecturas_sch IS 'Hypertable Timescale de telemetría de vehículos cuyos chunks se crean en el esquema particiones con prefijo derivado del nombre de la tabla.';
COMMENT ON COLUMN lecturas_sch.auto_id IS 'Identificador del vehículo que genera la telemetría.';
COMMENT ON COLUMN lecturas_sch.ts IS 'Marca de tiempo (UTC) en la que se registró la telemetría. Columna de particionado.';
COMMENT ON COLUMN lecturas_sch.presion_ruedas IS 'Presión de los neumáticos, en bar.';
COMMENT ON COLUMN lecturas_sch.nivel_combustible IS 'Nivel de llenado del depósito de gasolina, en %.';
COMMENT ON COLUMN lecturas_sch.carga_bateria IS 'Estado de carga de la batería de tracción, en %.';
COMMENT ON COLUMN lecturas_sch.temperatura_motor IS 'Temperatura del motor / refrigerante, en grados centígrados.';
COMMENT ON COLUMN lecturas_sch.temperatura_bateria IS 'Temperatura del pack de baterías, en grados centígrados.';
COMMENT ON COLUMN lecturas_sch.presion_aceite IS 'Presión del circuito de aceite, en bar.';
COMMENT ON COLUMN lecturas_sch.velocidad IS 'Velocidad del vehículo, en km/h.';
COMMENT ON COLUMN lecturas_sch.revoluciones IS 'Revoluciones del motor por minuto (rpm).';
COMMENT ON COLUMN lecturas_sch.consumo_potencia IS 'Consumo/generación instantánea de potencia, en kW (negativo = regeneración).';
COMMENT ON COLUMN lecturas_sch.autonomia IS 'Autonomía restante estimada, en km.';
SELECT create_hypertable(
    'lecturas_sch',
    'ts',
    chunk_time_interval => INTERVAL '1 day',
    associated_schema_name => 'particiones',
    associated_table_prefix => 'lecturas_sch'
);

-- ============================================================================
-- Carga de datos aleatorios (24 lecturas/dia x 10 coches, una por hora)
-- ============================================================================

-- 1) lecturas_plana
INSERT INTO lecturas_plana (auto_id, ts, presion_ruedas, nivel_combustible, carga_bateria,
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

-- 2) lecturas_ts
INSERT INTO lecturas_ts (auto_id, ts, presion_ruedas, nivel_combustible, carga_bateria,
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

-- 3) lecturas_sch
INSERT INTO lecturas_sch (auto_id, ts, presion_ruedas, nivel_combustible, carga_bateria,
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