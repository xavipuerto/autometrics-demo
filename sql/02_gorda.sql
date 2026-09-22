-- 02_gorda.sql
-- vehiculos_gorda: hypertable con chunks "gordos" de 3 días, en esquema particiones_gordas.
-- Objetivo: 3 chunks de ~40MB que mañana podremos comprimir (ver 03_compresion.sql).
--
-- Datos: 10 coches, 1 lectura cada 5 segundos durante 9 días -> 3 chunks de 3 días.
--   filas por chunk = (3 dias * 17280 lecturas/dia) * 10 autos = 518.400 filas (~40MB).

CREATE SCHEMA IF NOT EXISTS particiones_gordas;
COMMENT ON SCHEMA particiones_gordas IS 'Esquema destino de los chunks de la hypertable vehiculos_gorda (chunks gordos de 3 días para pruebas de compresión).';

CREATE TABLE IF NOT EXISTS vehiculos_gorda (
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
COMMENT ON TABLE vehiculos_gorda IS 'Hypertable Timescale con chunks gordos de 3 días en el esquema particiones_gordas, preparada para pruebas de compresión.';
COMMENT ON COLUMN vehiculos_gorda.auto_id IS 'Identificador del vehículo que genera la telemetría.';
COMMENT ON COLUMN vehiculos_gorda.ts IS 'Marca de tiempo (UTC) en la que se registró la telemetría. Columna de particionado.';
COMMENT ON COLUMN vehiculos_gorda.presion_ruedas IS 'Presión de los neumáticos, en bar.';
COMMENT ON COLUMN vehiculos_gorda.nivel_combustible IS 'Nivel de llenado del depósito de gasolina, en %.';
COMMENT ON COLUMN vehiculos_gorda.carga_bateria IS 'Estado de carga de la batería de tracción, en %.';
COMMENT ON COLUMN vehiculos_gorda.temperatura_motor IS 'Temperatura del motor / refrigerante, en grados centígrados.';
COMMENT ON COLUMN vehiculos_gorda.temperatura_bateria IS 'Temperatura del pack de baterías, en grados centígrados.';
COMMENT ON COLUMN vehiculos_gorda.presion_aceite IS 'Presión del circuito de aceite, en bar.';
COMMENT ON COLUMN vehiculos_gorda.velocidad IS 'Velocidad del vehículo, en km/h.';
COMMENT ON COLUMN vehiculos_gorda.revoluciones IS 'Revoluciones del motor por minuto (rpm).';
COMMENT ON COLUMN vehiculos_gorda.consumo_potencia IS 'Consumo/generación instantánea de potencia, en kW (negativo = regeneración).';
COMMENT ON COLUMN vehiculos_gorda.autonomia IS 'Autonomía restante estimada, en km.';

SELECT create_hypertable(
    'vehiculos_gorda',
    'ts',
    chunk_time_interval => INTERVAL '3 days',
    associated_schema_name => 'particiones_gordas',
    associated_table_prefix => 'vehiculos_gorda'
);

-- Configuración de compresión (los chunks se comprimirán mañana, ver 03_compresion.sql)
ALTER TABLE vehiculos_gorda SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'auto_id',
    timescaledb.compress_orderby = 'ts DESC'
);

-- ============================================================================
-- Carga de datos aleatorios: 1 lectura cada 5 segundos x 10 coches x 9 dias
--   -> 3 chunks de 3 dias, ~518.400 filas / chunk (~40MB)
-- ============================================================================
INSERT INTO vehiculos_gorda (auto_id, ts, presion_ruedas, nivel_combustible, carga_bateria,
                             temperatura_motor, temperatura_bateria, presion_aceite, velocidad,
                             revoluciones, consumo_potencia, autonomia)
SELECT a,
       '2026-09-13 00:00:00+00'::timestamptz + s * interval '5 seconds',
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
     generate_series(0, 9 * 17280 - 1) s;