-- 10_time_bucket.sql
-- time_bucket: qué es, para qué se usa y ejemplos medidos.
--
-- ¿Qué es?  time_bucket(ancho, ts) "trunca" una marca de tiempo a la franja
-- (bucket) temporal de ancho fijo que le corresponde. Sirve para AGRUPAR
-- series temporales por ventanas regulares: medias por hora, resúmenes por
-- día, picos por semana, etc.
--
-- Diferencia con date_trunc de PostgreSQL:
--   - date_trunc alinea con el CALENDARIO (dia -> medianoche, mes -> dia 1).
--   - time_bucket alinea con una PARRILLA FIJA de buckets de ancho constante
--     desde un origen (por defecto 2000-01-01). Admite anchos tipo '2 hours',
--     '90 minutes', '6 hours', '1 week', '1 month' y origen propio.
--   - El bucket SIEMPRE contiene el mismo nº de segundos (fijo), lo que hace
--     que las series queden perfectamente regulares.
--
-- ¿Para qué se usa?
--   1. Downsampling: bajar la resolución de los datos (240 lecturas -> 24
--      medias horarias, o 24 -> 7 resúmenes diarios).
--   2. Series temporales uniformes: alinear lecturas irregulares a una malla
--      fija (toda la telemetría, webs, logs, IoT...).
--   3. Base de los CONTINUOUS AGGREGATES: materializar esos buckets para que
--      la media/hora no se recalcule nunca (ver "Resultados" en pruebas.md).
--   4. Con time_bucket_gapfill: rellenar huecos donde no hubo lecturas.
--
-- Sintaxis: poner ts dentro de time_bucket() en el SELECT y repetirlo en el
-- GROUP BY (u ordenar con GROUP BY 1 = primera columna del SELECT).

-- ============================================================================
-- 1) EL EJEMPLO: lecturas de 1 día -> medias por hora
--    Datos: 10 coches x 24 horas = 240 lecturas en '2026-05-15'.
--    time_bucket('1 hour', ts) -> 24 buckets, 10 lecturas cada uno.
SELECT time_bucket('1 hour', ts) AS hora,
       count(*)                        AS lecturas,
       round(avg(velocidad)::numeric, 1) AS vel_media
FROM vehiculos_ts
WHERE ts >= '2026-05-15'::timestamptz AND ts < '2026-05-16'::timestamptz
GROUP BY 1
ORDER BY 1;
--    Resultado (primeras filas; 24 filas en total):
--      2026-05-15 00:00:00+00 | 10 | 89.0
--      2026-05-15 01:00:00+00 | 10 | 61.6
--      2026-05-15 02:00:00+00 | 10 | 56.7
--      ...
--    Lectura: 24 buckets de 10 lecturas (1 por coche + hora), cada uno con su
--    velocidad media. Lectura suelta de 240 filas -> resumen de 24 filas.

-- ============================================================================
-- 2) Anchos irregulares: buckets de 2 horas -> 24h / 2h = 12 buckets de 20
--    lecturas (10 coches x 2 horas).
SELECT time_bucket('2 hours', ts) AS ventana,
       count(*)                        AS lecturas,
       round(avg(velocidad)::numeric, 1) AS vel_media
FROM vehiculos_ts
WHERE ts >= '2026-05-15'::timestamptz AND ts < '2026-05-16'::timestamptz
GROUP BY time_bucket('2 hours', ts)
ORDER BY 1;
--    Nota: '2 hours' no existe para date_trunc; aqui es natural y produce
--    12 buckets (24h / 2h) con 20 lecturas cada uno (10 coches x 2 horas).

-- ============================================================================
-- 3) ORIGEN PROPIO: anclar la malla donde quieras.
--    Buckets de 90 minutos anclados en 00:30 (no a las 00:00).
--    Con origen 00:30, la lectura de las 01:00 cae en el bucket '00:30'
--    (10 filas); la de las 00:00 cae en el bucket ANTERIOR.
SELECT count(*) AS filas_en_bucket_0030
FROM vehiculos_ts
WHERE time_bucket(interval '90 minutes', ts, timestamptz '2026-05-15 00:30')
      = timestamptz '2026-05-15 00:30'
  AND ts >= '2026-05-15'::timestamptz AND ts < '2026-05-16'::timestamptz;
--    Resultado: 10 (los 10 coches de la lectura de las 01:00).

-- ============================================================================
-- 4) Todo junto: resumen diario de varios dias (downsampling de 24h a 6h)
SELECT time_bucket('6 hours', ts) AS mes_ventana, count(*) AS lecturas
FROM vehiculos_ts
WHERE ts >= '2026-05-15'::timestamptz AND ts < '2026-05-21'::timestamptz
GROUP BY 1 ORDER BY 1;
--    6 dias x 4 ventanas = 24 buckets de 60 lecturas (10 coches x 6 horas).

-- ============================================================================
-- 5) ANTES / DESPUÉS DE LA CONSULTA (para entender qué transforma time_bucket)
--
-- LA TABLA (vehiculos_ts), cómo es:
--   Hypertable Timescale, particionada por ts con chunks de 1 día.
--   Una fila POR COCHE Y HORA: 10 coches x 24h = 240 filas por dia.
--   Columnas (mismas en vehiculos_plana y vehiculos_part):
--     auto_id INT, ts TIMESTAMPTZ (particionado),
--     presion_ruedas NUMERIC(6,3), nivel_combustible SMALLINT,
--     carga_bateria SMALLINT, temperatura_motor NUMERIC(5,2),
--     temperatura_bateria NUMERIC(5,2), presion_aceite NUMERIC(6,2),
--     velocidad NUMERIC(6,1), revoluciones SMALLINT,
--     consumo_potencia NUMERIC(6,1), autonomia SMALLINT
--   Ver estructura real: \d+ vehiculos_ts
--   (Configuracion de compresion en vehiculos_grande y como se ve un chunk
--    comprimido por dentro estan en 03_compresion.sql y pruebas.md.)

-- 5a) ANTES: los datos "en crudo" (muestras reales del 2026-05-15 00:00)
SELECT auto_id, ts, presion_ruedas, velocidad, revoluciones,
       temperatura_motor, autonomia
FROM vehiculos_ts
WHERE ts = '2026-05-15 00:00:00+00'
ORDER BY auto_id
LIMIT 3;
--    Resultado real (3 de las 10 filas de esa hora):
--      auto_id | ts                          | presion_ruedas | velocidad | revoluciones | temperatura_motor | autonomia
--      --------+-----------------------------+----------------+-----------+--------------+-------------------+-----------
--            1 | 2026-05-15 00:00:00+00      |          2.343 |     112.2 |         5833 |             86.63 |       194
--            2 | 2026-05-15 00:00:00+00      |          2.562 |      26.0 |         4538 |             85.34 |       229
--            3 | 2026-05-15 00:00:00+00      |          2.358 |     110.2 |         2483 |             94.29 |       284
--    240 filas en total ese dia (24 horas x 10 coches).

-- 5b) DESPUÉS: ese mismo dia resumido por time_bucket (24 filas, 1 por hora)
SELECT time_bucket('1 hour', ts) AS hora,
       count(*)                        AS lecturas,
       round(avg(velocidad)::numeric, 1) AS vel_media
FROM vehiculos_ts
WHERE ts >= '2026-05-15'::timestamptz AND ts < '2026-05-16'::timestamptz
GROUP BY 1
ORDER BY 1
LIMIT 4;
--    Resultado real (4 de las 24 filas):
--      hora                        | lecturas | vel_media
--      ----------------------------+----------+-----------
--      2026-05-15 00:00:00+00      |       10 |      89.0
--      2026-05-15 01:00:00+00      |       10 |      61.6
--      2026-05-15 02:00:00+00      |       10 |      56.7
--      2026-05-15 03:00:00+00      |       10 |      61.0
--    Lectura clave: 240 filas crudas -> 24 filas de resumen; cada "hora"
--    agrupa las 10 lecturas de esa hora (10 coches) en una sola fila.