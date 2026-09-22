-- 01_ddl.sql
-- Prueba 1: 3 tablas de lecturas
--   1. lecturas_plana: tabla core PostgreSQL (sin Timescale)
--   2. lecturas_ts:    hypertable Timescale, chunks en ruta por defecto (_timescaledb_internal, prefijo _hyper)
--   3. lecturas_sch:   hypertable Timescale, chunks en esquema 'particiones' con prefijo derivado de la tabla

CREATE EXTENSION IF NOT EXISTS timescaledb;

CREATE SCHEMA IF NOT EXISTS particiones;
COMMENT ON SCHEMA particiones IS 'Esquema destino de los chunks de la hypertable lecturas_sch (particionado en esquema propio).';

-- 1) Tabla plana (sin Timescale)
CREATE TABLE IF NOT EXISTS lecturas_plana (
    sensor_id INT,
    ts        TIMESTAMPTZ NOT NULL,
    valor     DOUBLE PRECISION,
    payload   TEXT
);
COMMENT ON TABLE lecturas_plana IS 'Tabla core PostgreSQL (sin Timescale) con lecturas de sensores. Se usa como referencia de 30MB sin particionado.';
COMMENT ON COLUMN lecturas_plana.sensor_id IS 'Identificador del sensor que genera la lectura.';
COMMENT ON COLUMN lecturas_plana.ts IS 'Marca de tiempo (UTC) en la que se registró la lectura.';
COMMENT ON COLUMN lecturas_plana.valor IS 'Valor numérico medido por el sensor.';
COMMENT ON COLUMN lecturas_plana.payload IS 'Datos auxiliares de la lectura, usado para inflar el tamaño de la fila.';

-- 2) Hypertable con chunks por defecto
CREATE TABLE IF NOT EXISTS lecturas_ts (
    sensor_id INT,
    ts        TIMESTAMPTZ NOT NULL,
    valor     DOUBLE PRECISION,
    payload   TEXT
);
COMMENT ON TABLE lecturas_ts IS 'Hypertable Timescale con configuración por defecto: chunks en _timescaledb_internal con prefijo _hyper.';
COMMENT ON COLUMN lecturas_ts.sensor_id IS 'Identificador del sensor que genera la lectura.';
COMMENT ON COLUMN lecturas_ts.ts IS 'Marca de tiempo (UTC) en la que se registró la lectura. Columna de particionado.';
COMMENT ON COLUMN lecturas_ts.valor IS 'Valor numérico medido por el sensor.';
COMMENT ON COLUMN lecturas_ts.payload IS 'Datos auxiliares de la lectura, usado para inflar el tamaño de la fila.';
SELECT create_hypertable('lecturas_ts', 'ts');

-- 3) Hypertable con chunks en esquema 'particiones' y prefijo de tabla
CREATE TABLE IF NOT EXISTS lecturas_sch (
    sensor_id INT,
    ts        TIMESTAMPTZ NOT NULL,
    valor     DOUBLE PRECISION,
    payload   TEXT
);
COMMENT ON TABLE lecturas_sch IS 'Hypertable Timescale cuyos chunks se crean en el esquema particiones con prefijo derivado del nombre de la tabla.';
COMMENT ON COLUMN lecturas_sch.sensor_id IS 'Identificador del sensor que genera la lectura.';
COMMENT ON COLUMN lecturas_sch.ts IS 'Marca de tiempo (UTC) en la que se registró la lectura. Columna de particionado.';
COMMENT ON COLUMN lecturas_sch.valor IS 'Valor numérico medido por el sensor.';
COMMENT ON COLUMN lecturas_sch.payload IS 'Datos auxiliares de la lectura, usado para inflar el tamaño de la fila.';
SELECT create_hypertable(
    'lecturas_sch',
    'ts',
    associated_schema_name => 'particiones',
    associated_table_prefix => 'lecturas_sch'
);