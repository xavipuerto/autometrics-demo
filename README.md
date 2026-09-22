# TimescaleDB — de la telemetría a la decisión

> *"Un coche emite 240 lecturas al día. Una flota de 10, miles cada hora.
> La mayoría de las empresas guarda ese ruido. Pocas lo convierten en
> decisión. Esta demo es exactamente eso: hacer que los datos hablen."*

Repo de la prueba técnica (PTT) y charla **TimescaleDB: series temporales
sobre PostgreSQL**. Incluye el guión de 25 minutos, todos los scripts
reproducibles y el entorno Docker lista para levantar.

---

## Quién soy

Soy **Javier Aragón Díaz**, ingeniero informático y, sobre todo, una persona
que lleva más de dos décadas enamorada de los datos.

Mi trayectoria es la de alguien que empezó donde todo empieza: en 2004,
administrando los sistemas de una distribuidora de combustibles en
Puertollano — dominios, redes, VPNs, y sobre todo **bases de datos y
reporting**. Recuerdo perfectamente la primera vez que una consulta SQL
"organizó" el caos de cientos de miles de registros.

Desde entonces todo ha sido subir de nivel, sin soltar el hilo de los datos:

- **Becario de sistemas** en una planta fotovoltaica (ISFOC) y luego
  **emprendedor IT** creando proyectos web propios.
- **Consultor IT / ingeniero de sistemas** en Tecnocoom (BBVA), Indra
  (Educación y Sanidad Madrileña, Banco Santander, Orange) y Capgemini —
  tomando requisitos, modelando datos y construyendo **cuadros de mando**.
- Desde 2018, **Jefe de Proyectos IT Financiero en Mercadona**, liderando
  proyectos con una obsesión: que los KPI sean ciertos, medibles y usables.
- Formación continua: **Ingeniería Técnica en Informática de Sistemas**
  (UCLM), **Máster en Business Intelligence** (UOC), certificación
  **Oracle Database SQL Expert**, y un **MBA** en curso.

Toda mi carrera es la misma pregunta repetida con herramientas nuevas:
*¿qué están diciendo estos datos?* SQL, Oracle, Business Objects, Netezza…
y ahora, para telemetría e IoT en tiempo real, **TimescaleDB**.

## Por qué esta demo me hace vibrar

Esta no es una charla sobre "otra base de datos". Es la historia de siempre
con la herramienta que la hace posible:

- 360.000 lecturas de sensores por tabla que se **comprimen al 30 % su
  tamaño** sin perder ni una fila.
- Consultas que iban a barrer millones de registros y pasan a tocar **1 de
  cada 1.500 chunks**.
- 240 lecturas sueltas por hora que se convierten en **24 medias horarias**
  precalculadas, para que el dashboard vaya instantáneo mientras el motor
  las refresca solo.
- Y al final del ciclo de vida, **Timescale borra los datos viejos él solo**.

La telemetría que antes era un vertedero de números se convierte en un
pipeline que decide por ti: *comprimo lo viejo, agrego a mitad de camino y
borro lo caducado — sin que nadie tenga que acordarse.*

---

## De qué va el proyecto

Un laboratorio completo montado con Docker Compose para demostrar el valor
de TimescaleDB sobre una casuística de **telemetría de una flota de
vehículos** (presión, temperatura, velocidad, rpm, autonomía…) con dos
hipertables bien diferenciadas:

- `vehiculos_ts` — 1500 chunks de 1 día, el "caso mal dimensionado".
- `vehiculos_gorda` — 3 chunks de 3 días, el "caso bien dimensionado",
  convertidos a columnar con compresión nativa.

| Componente | Valor |
|---|---|
| Imagen | `timescale/timescaledb:latest-pg18` |
| PostgreSQL / TimescaleDB | 18.6 / 2.30.1 |
| Host / puerto | `localhost:5432` |
| BD | `timeseries` (`postgres`/`postgres`) |
| Persistencia | volumen `timescaledb_data` |

## Estructura del repo

| Ruta | Qué es |
|---|---|
| `presentacion/` | Guión de 25 minutos (`guion-25-minutos.md`) y la PPT final (`.pptx`) |
| `pruebas.md` | Documento de trabajo completo: runbook, evidencias medidas y speech (fuente de la presentaación) |
| `sql/01_ddl.sql` … `sql/13_jobs_personalizados_bonus.sql` | Scripts reproducibles, en orden de ejecución |
| `docker-compose.yml` | Entorno TimescaleDB listo para levantar |

### Los scripts, de un vistazo

| # | Script | Demuestra |
|---|---|---|
| 01 | `01_ddl.sql` | 3 tablas idénticas: plana, hypertable y hypertable en esquema propio (360.000 filas c/u) |
| 02 | `02_gorda.sql` | Chunks gordos de 3 días + compresión habilitada |
| 03 | `03_compresion.sql` | `compress_chunk`: 2 chunks de 56→17 MB (~70 %) y política automática (job 1000) |
| 04 | `04_insert_chunk_comprimido.sql` | Insertar sobre un chunk comprimido: overflow rowstore, sin descompresión, recompress |
| 05 | `05_compresion_politica.sql` | Alta/baja/pausa de la política de compresión por SQL |
| 07 | `07_explain_queries.sql` | Pruning de chunks: 1 de 1500 vs tabla plana (4440 buffers) |
| 08 | `08_consultas_tiempo.sql` | Consultas por rangos dinámicos (resisten el paso del tiempo) |
| 09 | `09_retencion_autopurga.sql` | Retención: borrado automático del chunk más antiguo (3→2) |
| 10 | `10_time_bucket.sql` | Downsampling: 240 lecturas → 24 medias horarias |
| 11 | `11_continuous_aggregates.sql` | Continuous aggregate `cag_vel_hora`: 94→57 MB y consultas ~3× más rápidas (job 1002) |
| 12 | `12_tuning_gucs.sql` | Tuning para 4/8/16 CPU y GUCs propios de Timescale |
| 13 | `13_jobs_personalizados_bonus.sql` | Timescale como cron: cualquier procedimiento PostgreSQL con `add_job` (job 1004) |

## Cómo levantar la demo

```bash
docker compose up -d              # arranca el entorno (auto-tunning por RAM/CPU)

# Cargar los scripts en orden (son idempotentes y se pasan por stdin)
docker exec -i timescaledb psql -U postgres -d timeseries -v ON_ERROR_STOP=1 < sql/01_ddl.sql
docker exec -i timescaledb psql -U postgres -d timeseries -v ON_ERROR_STOP=1 < sql/02_gorda.sql
docker exec -i timescaledb psql -U postgres -d timeseries -v ON_ERROR_STOP=1 < sql/03_compresion.sql
# ... y así con el resto (07/08/10 para las consultas, 09 retención, 11 cagg, 13 bonus)
```

Detalles que ahorran tropiezos en directo:

- **Los nombres de chunk no son fijos** (`3001` hoy, `6003` en otra pasada):
  los scripts `04`, `11` y `13` los resuelven por rango/catálogo.
- `run_job`, `refresh_continuous_aggregate` y `compress_chunk` son
  **procedimientos**: se invocan con `CALL`, no con `SELECT`.
- En 2.30 los continuous aggregates son `materialized_only` (sin realtime):
  los datos nuevos no salen hasta refrescar (manual o por política).
- Si quieres dejar vivos los jobs del panel final (1000-1004), no ejecutes
  los pasos destructivos de `05` (paso 6) ni `09` (paso 6).

## Las fichas que se llevan los asistentes

| Motor | Cifra |
|---|---|
| Compresión | 56 MB → **17 MB** por chunk (~70 %, pérdida cero) |
| Continuous aggregate | 94 MB → **57 MB**; consulta de 1 año ~3× más rápida y ~10× menos I/O |
| Pruning | 1 chunk de 1500 en el plan; la tabla plana mueve 4440 buffers |
| Autopurga | `CALL run_job(1001)` borra el chunk más antiguo: 3→2 chunks |
| Insert en comprimido | overflow en rowstore (no descomprime el chunk); el policy lo reabsorbe |
| Jobs finales | 1000 compresión · 1001 retención · 1002 refresh cagg · 1004 KPI custom |

## Para cerrar

> *"Mi carrera es una sola frase repetida: hacer que los datos cuenten algo
> útil. TimescaleDB es otro capítulo de esa frase — y esta demo, su mejor
> resumen."*

---

**Javier Aragón Díaz** · jefe de proyectos IT, obsesionado con los datos ·
[javier.aragon.diaz@gmail.com](mailto:javier.aragon.diaz@gmail.com) ·
[LinkedIn](https://es.linkedin.com/in/javieraragondiaz)