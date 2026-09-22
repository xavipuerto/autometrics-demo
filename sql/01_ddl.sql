-- 01_ddl.sql
-- Prueba 1: 3 tablas de lecturas
--   1. lecturas_plana: tabla core PostgreSQL (sin Timescale)
--   2. lecturas_ts:    hypertable Timescale, chunks en ruta por defecto (_timescaledb_internal, prefijo _hyper)
--   3. lecturas_sch:   hypertable Timescale, chunks en esquema 'particiones' con prefijo derivado de la tabla

CREATE EXTENSION IF NOT EXISTS timescaledb;

CREATE SCHEMA IF NOT EXISTS particiones;

-- 1) Tabla plana (sin Timescale)
CREATE TABLE IF NOT EXISTS lecturas_plana (
    sensor_id INT,
    ts        TIMESTAMPTZ NOT NULL,
    valor     DOUBLE PRECISION,
    payload   TEXT
);

-- 2) Hypertable con chunks por defecto
CREATE TABLE IF NOT EXISTS lecturas_ts (
    sensor_id INT,
    ts        TIMESTAMPTZ NOT NULL,
    valor     DOUBLE PRECISION,
    payload   TEXT
);
SELECT create_hypertable('lecturas_ts', 'ts');

-- 3) Hypertable con chunks en esquema 'particiones' y prefijo de tabla
CREATE TABLE IF NOT EXISTS lecturas_sch (
    sensor_id INT,
    ts        TIMESTAMPTZ NOT NULL,
    valor     DOUBLE PRECISION,
    payload   TEXT
);
SELECT create_hypertable(
    'lecturas_sch',
    'ts',
    associated_schema_name => 'particiones',
    associated_table_prefix => 'lecturas_sch'
);