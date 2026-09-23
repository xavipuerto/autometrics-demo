# -*- coding: utf-8 -*-
"""Genera la PPT tecnica de TimescaleDB (cada apartado tecnologico probado en pruebas.md)."""

import re
import os
from pptx import Presentation
from pptx.util import Inches, Pt
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN, MSO_ANCHOR
from pptx.enum.shapes import MSO_SHAPE
from pptx.oxml.ns import qn

IMG_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "img")

# ----------------------------- tema ------------------------------
BG       = RGBColor(0xFF, 0xFF, 0xFF)   # blanco
BG_PANEL = RGBColor(0xF2, 0xF4, 0xF8)   # gris panel
BG_PANEL2= RGBColor(0xE6, 0xEA, 0xF2)
BG_CODE  = RGBColor(0x0A, 0x12, 0x20)   # bloques de código (se mantienen oscuros)
AMBER    = RGBColor(0xB4, 0x53, 0x09)   # ámbar oscuro para texto sobre blanco
AMBER_LINE = RGBColor(0xFB, 0xBF, 0x24) # ámbar para líneas/rellenos decorativos
CYAN     = RGBColor(0x0E, 0x74, 0x90)   # azul-cyan de texto sobre blanco
CODE     = RGBColor(0x7D, 0xD3, 0xFC)   # cyan claro para código sobre fondo oscuro
GREEN    = RGBColor(0x15, 0x80, 0x3D)
RED      = RGBColor(0xB9, 0x1C, 0x1C)
TEXT     = RGBColor(0x1F, 0x29, 0x37)
MUTED    = RGBColor(0x6B, 0x72, 0x80)
LINE     = RGBColor(0xD1, 0xD5, 0xDB)
DARK     = RGBColor(0x1F, 0x29, 0x37)

F_TITLE = "Helvetica Neue"
F_BODY  = "Helvetica Neue"
F_MONO  = "Menlo"

prs = Presentation()
prs.slide_width  = Inches(13.333)
prs.slide_height = Inches(7.5)
BLANK = prs.slide_layouts[6]

TOTAL_SLIDES = 18

# --------------------------- helpers -----------------------------
def new_slide():
    s = prs.slides.add_slide(BLANK)
    r = s.shapes.add_shape(MSO_SHAPE.RECTANGLE, 0, 0, Inches(13.333), Inches(7.5))
    r.fill.solid(); r.fill.fore_color.rgb = BG
    r.line.fill.background()
    r.shadow.inherit = False
    s.shapes.add_picture(os.path.join(IMG_DIR, "pg_elephant.png"),
                         Inches(11.6), Inches(0.22), width=Inches(1.5))
    return s

def rect(slide, x, y, w, h, fill=None, line=None, line_w=1.0, round_=False):
    shp = slide.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE if round_ else MSO_SHAPE.RECTANGLE,
                                 Inches(x), Inches(y), Inches(w), Inches(h))
    if round_:
        try: shp.adjustments[0] = 0.06
        except Exception: pass
    if fill is None:
        shp.fill.background()
    else:
        shp.fill.solid(); shp.fill.fore_color.rgb = fill
    if line is None:
        shp.line.fill.background()
    else:
        shp.line.color.rgb = line; shp.line.width = Pt(line_w)
    shp.shadow.inherit = False
    return shp

def _apply_runs(p, text, base_color, mono=False):
    # markup: `code` y **bold**
    tokens = re.split(r"(`[^`]+`|\*\*[^*]+\*\*)", text)
    for t in tokens:
        if not t:
            continue
        r = p.add_run()
        if t.startswith("`") and t.endswith("`"):
            r.text = t[1:-1]
            r.font.name = F_MONO
            r.font.size = p.font.size if p.font.size else Pt(13)
            r.font.bold = True
            r.font.color.rgb = CODE if base_color == CODE else CYAN
        elif t.startswith("**") and t.endswith("**"):
            r.text = t[2:-2]
            r.font.bold = True
            r.font.color.rgb = AMBER if base_color == TEXT else base_color
        else:
            r.text = t
            r.font.color.rgb = base_color
        r.font.name = F_BODY

def textbox(slide, x, y, w, h, paras, align=PP_ALIGN.LEFT, anchor=MSO_ANCHOR.TOP):
    tb = slide.shapes.add_textbox(Inches(x), Inches(y), Inches(w), Inches(h))
    tf = tb.text_frame
    tf.word_wrap = True
    tf.vertical_anchor = anchor
    tf.margin_left = tf.margin_right = tf.margin_top = tf.margin_bottom = 0
    first = True
    for para in paras:
        p = tf.paragraphs[0] if first else tf.add_paragraph()
        first = False
        p.alignment = para.get("align", align)
        p.space_after = Pt(para.get("space_after", 0))
        p.space_before = Pt(para.get("space_before", 0))
        p.level = para.get("level", 0)
        sz = para.get("size", 15)
        p.font.size = Pt(sz)
        p.font.name = para.get("font", F_BODY)
        p.font.bold = para.get("bold", False)
        p.font.color.rgb = para.get("color", TEXT)
        if para.get("italic"):
            p.font.italic = True
        txt = para.get("text", "")
        _apply_runs(p, txt, p.font.color.rgb, mono=para.get("mono", False))
    return tb

def kicker(slide, x, y, w, text):
    textbox(slide, x, y + 0.03, w, 0.35, [dict(text=text.upper(), size=13, bold=True, color=AMBER)])

def h_title(slide, x, y, w, text, size=30):
    tb = slide.shapes.add_textbox(Inches(x), Inches(y), Inches(w), Inches(0.7))
    tf = tb.text_frame
    tf.word_wrap = True
    p = tf.paragraphs[0]
    p.font.size = Pt(size)
    p.font.bold = True
    p.font.color.rgb = TEXT
    _apply_runs(p, text, TEXT)

def rule(slide, x, y, w, color=AMBER_LINE, h=0.045):
    rect(slide, x, y, w, h, fill=color)

def footer(slide, idx):
    rect(slide, 0.6, 7.12, 12.13, 0.012, fill=LINE)
    textbox(slide, 0.6, 7.16, 9.0, 0.3,
            [dict(text="Javier Aragón  ·  TimescaleDB — de la telemetría a la decisión",
                  size=9, color=MUTED)])
    textbox(slide, 11.0, 7.16, 1.73, 0.3,
            [dict(text=f"{idx:02d} / {TOTAL_SLIDES}", size=9, color=MUTED, align=PP_ALIGN.RIGHT)])

def header(slide, idx, kick, title, sub=None):
    ty = 0.42
    h_title(slide, 0.6, ty, 12.1, title)
    if sub:
        textbox(slide, 0.6, ty + 0.60, 12.1, 0.4, [dict(text=sub, size=13, color=MUTED)])
    rule(slide, 0.6, ty + 0.53, 1.05)
    footer(slide, idx)

def bullets(slide, items, x=0.6, y=2.1, w=8.2, gap=8):
    paras = []
    for it in items:
        d = dict(
            text=it.get("text", ""),
            size=it.get("size", 15),
            color=it.get("color", TEXT),
            bold=it.get("bold", False),
            level=it.get("level", 0),
            space_after=it.get("space_after", gap),
            italic=it.get("italic", False),
        )
        if it.get("num"):
            d["text"] = f"{it['num']}.  " + d["text"]
            d["bold"] = True
            d["color"] = AMBER
        if it.get("bullet") and not it.get("num"):
            d["text"] = "·  " + d["text"]
        paras.append(d)
    textbox(slide, x, y, w, 5.0, paras)

def code(slide, lines, x=0.6, y=2.1, w=8.4, size=13, h=None):
    h = h if h else 0.42 + 0.30 * len(lines)
    rect(slide, x, y, w, h, fill=BG_CODE, round_=True)
    textbox(slide, x + 0.25, y + 0.15, w - 0.5, h - 0.3,
            [dict(text=ln, size=size, color=CODE, font=F_MONO, space_after=3) for ln in lines],
            anchor=MSO_ANCHOR.TOP)

def big_stat(slide, x, y, w, number, caption, number_color=AMBER, size=40):
    textbox(slide, x, y, w, 0.9, [dict(text=number, size=size, bold=True, color=number_color)])
    textbox(slide, x, y + 0.75, w, 1.2, [dict(text=caption, size=12, color=MUTED)])

def panel_table(slide, x, y, w, headers, rows, col_w, row_h=0.36, header_h=0.36,
                size=12, highlight_col=None, align=None):
    n = len(headers)
    widths = [w * cw for cw in col_w]
    xs = []
    cx = x
    for ww in widths:
        xs.append(cx); cx += ww
    # header
    hr = rect(slide, x, y, w, header_h, fill=AMBER_LINE)
    for i, htxt in enumerate(headers):
        textbox(slide, xs[i] + 0.12, y + 0.055, widths[i] - 0.24, header_h - 0.11,
                [dict(text=htxt, size=size, bold=True, color=DARK)])
    y += header_h
    for ri, row in enumerate(rows):
        bg = BG_PANEL if ri % 2 == 0 else BG_PANEL2
        rect(slide, x, y, w, row_h, fill=bg)
        for i, cell in enumerate(row):
            col = TEXT
            bold = False
            if highlight_col is not None and (highlight_col == i or (isinstance(highlight_col, (list, tuple)) and i in highlight_col)):
                col = AMBER; bold = True
            al = PP_ALIGN.LEFT
            if align and align[i]:
                al = align[i]
            textbox(slide, xs[i] + 0.12, y + (row_h - 0.19) / 2, widths[i] - 0.24, 0.25,
                    [dict(text=str(cell), size=size, color=col, bold=bold)], anchor=MSO_ANCHOR.MIDDLE)
        y += row_h
    return y

# --------------------------- slides ------------------------------
# S1 - Portada
s = new_slide()
rect(s, 0, 0, 13.333, 0.14, fill=AMBER_LINE)
textbox(s, 0.8, 1.5, 11.7, 0.4, [dict(text="PRUEBA TÉCNICA · SERIES TEMPORALES SOBRE POSTGRESQL", size=15, bold=True, color=AMBER)])
textbox(s, 0.8, 1.95, 11.7, 1.2, [dict(text="TimescaleDB", size=72, bold=True, color=TEXT)])
rule(s, 0.85, 3.25, 2.2, h=0.055)
textbox(s, 0.8, 3.55, 11.7, 1.0, [
    dict(text="De la telemetría de una flota de coches a la decisión", size=24, bold=True, color=CYAN),
])
textbox(s, 0.8, 5.7, 11.7, 1.0, [
    dict(text="Javier Aragón", size=18, bold=True, color=TEXT),
    dict(text="Arquitecto IT  ·  Idrica · Xylem  ·  javier.aragon.diaz@gmail.com", size=12, color=MUTED, space_after=2),
    dict(text="septiembre 2026", size=12, color=MUTED),
])

# S2 - Quien soy
s = new_slide()
header(s, 2, "ASÍ ABRIMOS", "¿Quién os habla?")
bullets(s, [
    dict(text="**Javier Aragón** — arquitecto IT.", size=16, bullet=False, space_after=6),
    dict(text="javier.aragon.diaz@gmail.com", size=16, bullet=False, color=CYAN, space_after=6),
    dict(text="Actualmente en **Idrica · Xylem**, en proyectos internacionales.", size=16, bullet=False, space_after=6),
    dict(text="Y cada vez me siento más junior.", size=16, bullet=False, italic=True, color=AMBER, space_after=0),
], y=2.9, w=8.0)

# S3 - Agenda
s = new_slide()
header(s, 3, "25 MINUTOS", "El viaje: 12 apartados técnicos")
items = [
    "Hypertables y chunks — la tabla lógica y el trozo físico",
    "Dimensionado de chunks — 1 día (mal) vs 3 días (bien)",
    "Compresión nativa — rowstore → columnstore",
    "Insertar en un chunk comprimido — el overflow",
    "Política de compresión — el trabajo en segundo plano",
    "Pruning — el filtro entra en 1 de 1.500 chunks",
    "Retención / autopurga — el historial se borra solo",
    "time_bucket — downsampling 240 → 24",
    "Continuous aggregates — el resumen precalculado",
    "Jobs personalizados — Timescale como cron",
    "Tuning de parámetros — Timescale + PostgreSQL",
    "El círculo de la telemetría — resumen",
]
col1 = items[:6]; col2 = items[6:]
for ci, (col, xx) in enumerate(((col1, 0.6), (col2, 6.9))):
    paras = [dict(text=f"{ci*6 + n:02d}   " + t, size=14, space_after=10) for n, t in enumerate(col, start=1)]
    textbox(s, xx, 2.35, 5.9, 4.5, paras)
textbox(s, 0.6, 6.75, 12.0, 0.3, [dict(text="Todas las cifras salen de la recreación del entorno desde cero (sept 2026).", size=11, italic=True, color=MUTED)])

# S4 - El problema
s = new_slide()
header(s, 4, "", "TimescaleDB: el dato de serie temporal nativo de PostgreSQL")
bullets(s, [
    dict(text="Es una **extensión de PostgreSQL** (`CREATE EXTENSION timescaledb;`), no un motor aparte: SQL, `EXPLAIN` y catálogo son los de siempre.", size=15, space_after=8),
    dict(text="Cubre la necesidad que nos trae aquí: **lecturas que llegan sin parar** — IoT, telemetría de flota, métricas, datos financieros — que hay que guardar, consultar por ventanas de tiempo y ordenar su ciclo de vida.", size=15, space_after=8),
    dict(text="Y lo hace **sin cambiar de base de datos**: si ya usas PostgreSQL, lo añades y ya.", size=15, space_after=8),
    dict(text="¿Y probarlo en la nube sin instalar nada? **Tiger Cloud** — la plataforma gestionada de la compañía (hoy *TigerData*) — provisiona un PostgreSQL + TimescaleDB en minutos, con **30 días de prueba gratis sin tarjeta**. Esta misma demo corre ahí igual.", size=15, space_after=0),
], y=2.05)
rect(s, 8.8, 2.05, 3.95, 3.7, fill=BG_PANEL, round_=True)
textbox(s, 9.05, 2.3, 3.45, 3.3, [
    dict(text="Lo que aporta", size=14, bold=True, color=AMBER, space_after=8),
    dict(text="· Hipertables: una tabla lógica, particiones por tiempo por dentro", size=12, color=TEXT, space_after=4),
    dict(text="· Compresión nativa de los bloques viejos", size=12, color=TEXT, space_after=4),
    dict(text="· Agregados continuos precalculados", size=12, color=TEXT, space_after=4),
    dict(text="· Retención y autopurga del histórico", size=12, color=TEXT, space_after=4),
    dict(text="· Jobs de fondo con cualquier SQL", size=12, color=TEXT, space_after=8),
    dict(text="Y por debajo, el PostgreSQL que ya conoces.", size=12, italic=True, color=MUTED),
])
textbox(s, 0.6, 6.32, 12.1, 0.5, [dict(text="Mismo SQL, mismo EXPLAIN, mismo catálogo: la diferencia es lo que el motor hace con las tablas por dentro — local o en la nube.", size=13, italic=True, color=MUTED)])

# S5 - Hypertables y chunks
s = new_slide()
header(s, 5, "", "`01_ddl.sql`", "Hypertables y chunks: la tabla lógica y el trozo físico por franja de tiempo")
bullets(s, [
    dict(text="**Hypertable**: la tabla que tu SQL ve (la misma `CREATE TABLE`).", size=15, space_after=4),
    dict(text="**Chunk**: cada partición temporal es una tabla física escondida en `_timescaledb_internal` (o en tu esquema).", size=15, space_after=4),
    dict(text="El particionado lo decide `chunk_time_interval`: nosotros usamos **1 día** en `vehiculos_ts`.", size=15, space_after=10),
])
code(s, [
    "SELECT create_hypertable('vehiculos_ts', 'ts',",
    "       chunk_time_interval => INTERVAL '1 day');",
    "",
    "-- Con associated_schema_name => 'particiones' los chunks",
    "-- viven en tu esquema con nombre derivado: vehiculos_part_*_chunk",
], y=4.15, h=1.63)
rect(s, 8.8, 2.2, 4.0, 3.0, fill=BG_PANEL, round_=True)
textbox(s, 9.05, 2.45, 3.5, 2.5, [
    dict(text="Resultado", size=14, bold=True, color=AMBER, space_after=6),
    dict(text="Para tu SQL es la misma tabla de siempre; por dentro, cada franja de tiempo es un trozo físico.", size=12, color=TEXT, space_after=6),
    dict(text="A dónde viven y cómo se llaman los chunks lo decide Timescale: `vehiculos_part_*_chunk` en tu esquema, `_hyper_*` por defecto.", size=12, color=MUTED, space_after=4),
    dict(text="Ver los chunks: `timescaledb_information.chunks`", size=11, color=MUTED),
])

# S6 - Dimensionado de chunks
s = new_slide()
header(s, 6, "", "`02_grande.sql`", "Dimensionar el chunk: la decisión que marca la diferencia")
bullets(s, [
    dict(text="Trocear muy fino dispara el **overhead por chunk**: cada trozo físico es una tabla, con sus metadatos, índices y páginas propias — más trozos, más gasto fijo.", size=14, bullet=True, space_after=8),
    dict(text="**Regla práctica**: un chunk debe cubrir ~**10-20 min de tu buffer target** de ingesta constante; menos chunks y más grandes reducen ese gasto.", size=14, bullet=True, space_after=8),
    dict(text='La demo juega con ambos a propósito: el "mal dimensionado" (un chunk por día) y el "correcto" (tres días por chunk) nos sirven para ver el efecto en el EXPLAIN.', size=14, bullet=True),
], y=2.25)
rect(s, 8.8, 2.25, 3.95, 2.75, fill=BG_PANEL, round_=True)
textbox(s, 9.05, 2.55, 3.45, 2.4, [
    dict(text="Para la telemetría", size=14, bold=True, color=AMBER, space_after=6),
    dict(text="Un chunk debe cubrir ~10-20 min de la ingesta constante que quepa en tus buffers.", size=12, color=TEXT, space_after=4),
    dict(text="En flota: una franja de 3 días por chunk da chunks con oficio.", size=12, color=TEXT),
])

# S7 - Compresion nativa
s = new_slide()
header(s, 7, "", "`03_compresion.sql`", "Compresión nativa: la tabla fila se convierte en columnas")
bullets(s, [
    dict(text="Cada chunk comprimido pasa a ser un **columnstore** (`..._chunk_compressed`) y es **lossless** (pérdida cero): `count(*)` se mantiene.", size=15, space_after=4),
    dict(text="Algoritmo por defecto: Timescale lo elige solo al comprimir, **según el tipo de cada columna** (catálogo 2.30):", size=15, space_after=2),
    dict(text="`DELTADELTA` + simple-8b + RLE → enteros y timestamps (el `ts` pasa de 64 bits a ~1)", size=13, level=1, space_after=2),
    dict(text="`GORILLA` (XOR) → flotantes: velocidad, presiones, temperaturas", size=13, level=1, space_after=2),
    dict(text="`DICTIONARY` → baja cardinalidad: `auto_id`", size=13, level=1, space_after=2),
    dict(text="`BOOL` / `UUID` → bools e ids; `ARRAY` solo para filtros/índices", size=13, level=1, space_after=8),
    dict(text="Tú no pides el algoritmo (solo `segmentby`/`orderby`): `timescaledb_information.compression_settings` muestra lo aplicado.", size=15, space_after=4),
    dict(text="Contrapartida: escribir sobre columna comprimida es más caro → por eso solo se comprime lo **viejo**.", size=15, space_after=0),
], y=2.15, w=8.0)
rect(s, 8.8, 2.15, 3.9, 2.7, fill=BG_PANEL, round_=True)
textbox(s, 9.05, 2.45, 3.4, 2.2, [
    dict(text="Resultado medido", size=14, bold=True, color=AMBER, space_after=6),
    dict(text="56 MB → 17 MB", size=30, bold=True, color=GREEN, space_after=2),
    dict(text="por chunk · −70 % · ×3,3", size=13, color=TEXT, space_after=6),
    dict(text="Doc Timescale: hasta 90-95 % en casos típicos", size=11, color=MUTED),
])
textbox(s, 0.6, 6.3, 8.0, 0.7, [
    dict(text="SQL habitado: `ALTER TABLE vehiculos_grande SET (timescaledb.compress, segmentby='auto_id', orderby='ts DESC');`", size=13, color=TEXT),
])

# S8 - Gorda: tabla antes/despues
s = new_slide()
header(s, 8, "", "`03_compresion.sql`", "vehiculos_grande: 3 chunks de 3 días, 2 comprimidos y 1 de control")
panel_table(s, 0.6, 2.25, 12.1, ["Chunk", "Ventana", "Antes", "Después", "Comprimido"],
            [["3001 (en otra recreación: 6003)", "2026-09-13 → 09-16", "56 MB", "17 MB", "sí"],
             ["3002 (… 6004)", "2026-09-16 → 09-19", "56 MB", "17 MB", "sí"],
             ["3003 (… 6005) · control", "2026-09-19 → 09-22", "56 MB", "56 MB", "no"]],
            [0.40, 0.24, 0.13, 0.13, 0.10], highlight_col=[3])
bullets(s, [
    dict(text="Los datos se **leen igual pero desde el columnstore**; la tabla fila del chunk queda a ~0 bytes.", size=14, bullet=True, space_after=4),
    dict(text="Tamaños calculados con `pg_total_relation_size(chunk)` — incluye índices y el almacenamiento comprimido.", size=14, bullet=True, space_after=4),
    dict(text="Los nombres de chunk **cambian en cada recreación**: `3001` aquí, `6003` en otra pasada. Se resuelven por rango, no por nombre.", size=14, bullet=True, space_after=4),
    dict(text="El tercer chunk queda **sin comprimir a propósito** para comparar en directo.", size=14, bullet=True),
], y=4.45)
stat_d = big_stat(s, 0.6, 6.05, 3.0, "1.555.200", "filas siguen ahí tras comprimir (count intacto)", size=28)

# S9 - Insert en comprimido
s = new_slide()
header(s, 9, "", "`04_insert_chunk_comprimido.sql`", "¿Insertar en un chunk ya comprimido? Sí, y sin descomprimir todo")
bullets(s, [
    dict(text='**Mito a corregir**: "Timescale descomprime y recompresa en cada INSERT" → **falso**.', size=15, bold=True, space_after=4),
    dict(text="Las filas nuevas van a un **overflow rowstore** del chunk: `is_compressed` sigue a `t` pero el chunk **crece** (8192 B → 24 kB con 10 filas).", size=15, space_after=4),
    dict(text="El merge con el columnstore llega al **recomprimir**: `compress_chunk()` o la política de compresión en segundo plano.", size=15, space_after=8),
    dict(text="Medidas (2026-09):", size=15, space_after=2),
    dict(text="lote de 5 filas → 5,6 ms  ·  5 individuales → ~0,5 ms c/u", size=14, level=1, space_after=2),
    dict(text="1M en un INSERT → 3,5 s (~285 000 filas/s)  ·  pgbench fila-a-fila → 4.697 tps", size=14, level=1, space_after=8),
    dict(text="Recomendación: **lotes de ≥1000 filas o `COPY`**; deja que la política reabsorba el overflow.", size=15, bold=True, color=AMBER, space_after=0),
], y=2.15, w=8.2)
rect(s, 9.0, 2.15, 3.75, 2.6, fill=BG_CODE, round_=True)
textbox(s, 9.25, 2.4, 3.3, 2.2, [
    dict(text="SELECT * FROM chunk…", size=11, color=MUTED, space_after=6),
    dict(text="overflow + columnstore", size=13, bold=True, color=GREEN, space_after=2),
    dict(text="= lo que lee toda consulta de ese chunk", size=11, color=MUTED),
])
textbox(s, 0.6, 6.3, 12.0, 0.5, [dict(text="Backfill puntual en chunk viejo: fuerza luego `compress_chunk` sobre ese chunk y duerme tranquilo con la política.", size=13, italic=True, color=MUTED)])

# S10 - Politica compresion
s = new_slide()
header(s, 10, "", "`05_compresion_politica.sql`", "La política de compresión: se ocupa de todo sola")
code(s, [
    "SELECT add_compression_policy('vehiculos_grande',",
    "       compress_after    => INTERVAL '24 hours',",
    "       schedule_interval => INTERVAL '24 hours');  -- el id lo asigna Timescale",
    "",
    "CALL run_job(<job_id>);       -- forzarlo a mano (procedimiento)",
    "SELECT alter_job(<job_id>, scheduled => false);     -- pausar",
    "SELECT remove_compression_policy('vehiculos_grande'); -- borrar",
], y=2.2, h=1.95, size=13)
bullets(s, [
    dict(text="Cada **24 h** comprime/recomprime todo chunk cuyo rango terminó hace **>24 h**.", size=15, bullet=True, space_after=4),
    dict(text="**Reabsorbe el overflow** del rowstore al columnstore sin intervención manual.", size=15, bullet=True, space_after=4),
    dict(text="**Respeta el chunk activo**: nunca toca la ventana reciente (por eso el chunk de control sigue sin comprimir).", size=15, bullet=True, space_after=4),
    dict(text="`job_stats` / `job_history` muestran la ejecución en vivo: éxito, tiempos, siguiente arranque.", size=15, bullet=True, space_after=0),
], y=4.15)
rect(s, 9.0, 2.2, 3.75, 2.35, fill=BG_PANEL, round_=True)
textbox(s, 9.25, 2.5, 3.3, 1.9, [
    dict(text="Estado probado", size=13, bold=True, color=AMBER, space_after=6),
    dict(text="Éxito (Success)", size=16, bold=True, color=GREEN, space_after=2),
    dict(text="arrancó al crearse y vuelve cada 24 h", size=11, color=MUTED, space_after=4),
    dict(text='Speech: "si no te convence, lo quitas en una línea"', size=11, italic=True, color=MUTED),
])

# S11 - Pruning
s = new_slide()
header(s, 11, "", "`07_explain_queries.sql`", "Pruning: el filtro temporal entra directo en el chunk que toca")
panel_table(s, 0.6, 2.25, 12.1, ["Consulta (mismo filtro 1 día)", "Plan", "Coste"],
            [["vehiculos_ts + ts (hypertable 1d)", "Seq Scan → 1 solo chunk", "0,09 ms · 3 buffers"],
             ["vehiculos_ts + ts 30 días", "Append con ~30 partner aggregates", "1,5 ms · 90 buffers"],
             ["vehiculos_plana (sin Timescale)", "Parallel Seq Scan toda la tabla", "20,5 ms · 4.440 buffers"],
             ["vehiculos_grande (comprimida)", "ColumnarIndexScan en columnstore", "filtra y agrega en compresión"]],
            [0.40, 0.34, 0.26], highlight_col=[1])
bullets(s, [
    dict(text="**“El peor caso de la tabla plana es el caso normal de Timescale”**: la misma consulta mueve 4.440 buffers en plana y 3 en la hypertable.", size=15, space_after=0),
], y=4.45)
textbox(s, 0.6, 5.2, 12.1, 0.6, [
    dict(text="EXPLAIN (COSTS OFF) SELECT … FROM vehiculos_ts WHERE ts >= '2026-05-15' AND ts < '2026-05-16';", size=12, color=CYAN, font=F_MONO),
])
textbox(s, 0.6, 6.15, 12.0, 0.5, [dict(text="Nota rigurosa: tamaños y tiempos medidos tal cual en el laboratorio. No afirmamos “228× más lento” sin un benchmark controlado.", size=11, italic=True, color=MUTED)])

# S12 - Retencion
s = new_slide()
header(s, 12, "", "`09_retencion_autopurga.sql`", "Retención / autopurga: que lo viejo desaparezca solo")
code(s, [
    "-- Manual, una vez:",
    "SELECT drop_chunks('vehiculos_grande', older_than => now() - INTERVAL '5 days');",
    "",
    "-- Automático: política de retención (se repite cada 24 h)",
    "SELECT add_retention_policy('vehiculos_grande', drop_after => INTERVAL '5 days');",
    "CALL run_job(<job_id>);   SELECT remove_retention_policy('vehiculos_grande');",
], y=2.15, h=1.6, size=12)
bullets(s, [
    dict(text="Borra **chunks completos**, no filas: elimina el chunk cuando su `range_end` queda antes de `now() - drop_after`.", size=15, bullet=True, space_after=4),
    dict(text="En la demo: **3 → 2 chunks**; la autopurga se llevó exactamente el más antiguo.", size=15, bullet=True, space_after=4),
    dict(text="Compresión y retención son **dos políticas que se complementan**: comprimo lo viejo y, cuando pasa aún más tiempo, lo **borro**.", size=15, bullet=True, space_after=0),
], y=4.15)
rect(s, 9.0, 4.15, 3.75, 1.6, fill=BG_PANEL, round_=True)
textbox(s, 9.25, 4.4, 3.3, 1.3, [
    dict(text="En la charla", size=13, bold=True, color=AMBER, space_after=4),
    dict(text="“los datos se comprimen y al final de su vida útil, Timescale los borra sin que yo me acuerde”", size=12, italic=True, color=TEXT),
])

# S13 - time_bucket
s = new_slide()
header(s, 13, "", "`10_time_bucket.sql`", "Downsampling: 240 lecturas sueltas → 24 medias horizontales")
code(s, [
    "SELECT time_bucket('1 hour', ts) AS hora,",
    "       count(*)             AS lecturas,",
    "       round(avg(velocidad)::numeric,1) AS vel_media",
    "FROM vehiculos_ts",
    "GROUP BY 1 ORDER BY 1;",
], y=2.15, h=1.49, size=13)
bullets(s, [
    dict(text="A diferencia de `date_trunc`, alinea con una **parrilla fija**: sirve para `2 hours`, `90 minutes`, semanas… y series uniformes.", size=15, bullet=True, space_after=4),
    dict(text="Resultado real (2026-05-15): **24 filas**, cada una con sus 10 lecturas de la hora.", size=15, bullet=True, space_after=4),
    dict(text="Es el **ladrillo** de los continuous aggregates: si esto lo hace el motor de forma continua, tienes un cagg.", size=15, bullet=True, space_after=0),
], y=3.7)
panel_table(s, 0.6, 5.6, 7.4, ["hora", "lecturas", "vel_media"],
            [["00:00", "10", "89,0"], ["01:00", "10", "61,6"], ["02:00", "10", "56,7"], ["03:00", "10", "61,0"]],
            [0.4, 0.3, 0.3], header_h=0.32, row_h=0.30, size=12)
textbox(s, 8.3, 5.6, 4.4, 1.2, [
    dict(text="240 → 24", size=34, bold=True, color=GREEN, space_after=2),
    dict(text="la misma información, al tamaño de una diapositiva", size=12, color=MUTED),
])

# S14 - Cagg
s = new_slide()
header(s, 14, "", "`11_continuous_aggregates.sql`", "Continuous aggregates: el resumen precalculado")
bullets(s, [
    dict(text="Una **vista materializada** que guarda el resultado de `time_bucket + GROUP BY`; se refresca **por ventanas** (solo lo que cambió).", size=15, space_after=4),
    dict(text="Vive en su propia hypertable (`_materialized_hypertable_*` — el nombre cambia por recreación).", size=15, space_after=8),
    dict(text="Evidencias:", size=15, space_after=2),
    dict(text="tamaño: cruda **94 MB** → cagg **57 MB** (aún sin comprimir)", size=14, level=1, space_after=2),
    dict(text="consulta 1 año: cruda ~24 ms · 16.121 buffers → **cagg ~9 ms · 1.640 buffers** (~10× menos I/O)", size=14, level=1, space_after=8),
    dict(text="**Gotcha 2.30**: `materialized_only = t` (sin realtime) → la fila recién insertada no sale hasta refrescar (manual o política).", size=15, bold=True, color=AMBER, space_after=0),
], y=2.1, w=8.2)
code(s, [
    "SELECT add_continuous_aggregate_policy('cag_vel_hora',",
    "  start_offset => INTERVAL '1 month',",
    "  end_offset   => INTERVAL '1 hour',",
    "  schedule_interval => INTERVAL '1 hour');  -- refresco cada hora",
], y=5.5, w=8.2, size=12, h=1.15)
rect(s, 9.0, 2.1, 3.75, 3.1, fill=BG_PANEL, round_=True)
textbox(s, 9.25, 2.35, 3.3, 2.7, [
    dict(text="cagg cag_vel_hora", size=14, bold=True, color=AMBER, space_after=6),
    dict(text="360 001", size=30, bold=True, color=GREEN, space_after=2),
    dict(text="buckets (hora × coche)", size=11, color=MUTED, space_after=8),
    dict(text="Refresco: 1 h, ventana [−1 mes, −1 h] — el bucket en curso no se recalcula.", size=11, italic=True, color=TEXT),
])

# S15 - Tuning (script 12)
s = new_slide()
header(s, 15, "", "`12_tuning_gucs.sql`", "Tuning: Timescale es PostgreSQL + media docena de GUC propias")
panel_table(s, 0.6, 2.2, 12.1, ["Parámetro", "Valor aquí (8 CPU / 8 GB, auto)", "Regla"],
            [["shared_buffers", "~2 GB", "25 % de la RAM"],
             ["effective_cache_size", "~5,7 GB", "~75 % de la RAM"],
             ["work_mem / maintenance_work_mem", "8 MB / ~1 GB", "8-16 MB · 5-6 % RAM"],
             ["max_parallel_workers / _per_gather", "8 / 4", "= nº de núcleos"],
             ["max_worker_processes", "27", "parallel + bgw + margen"],
             ["timescaledb.max_background_workers", "16", "hilos de los jobs"],
             ["timescaledb.max_open_chunks_per_insert", "1024 → 16", "≥chunks abiertos en un INSERT"],
             ["timescaledb.telemetry_level", "basic → off", "off en producción"]],
            [0.36, 0.38, 0.26], size=11.5, row_h=0.33)
textbox(s, 0.6, 5.6, 12.1, 1.1, [
    dict(text="La imagen `timescaledb` **auto-tunea al arrancar** según CPU/RAM del contenedor. En producción, más RAM/corees de job y chunks grandes…", size=13, color=TEXT, space_after=4),
    dict(text="Ejemplo 4 CPU / 16 GB: `ALTER SYSTEM SET max_worker_processes=28; max_background_workers=8; max_open_chunks_per_insert=16;`", size=12, color=CYAN, font=F_MONO),
])

# S16 - Jobs personalizados (script 13)
s = new_slide()
header(s, 16, "", "`13_jobs_personalizados_bonus.sql`", "Jobs personalizados: Timescale como cron de PostgreSQL")
code(s, [
    "SELECT add_job('calc_kpi_ultima_hora(int,jsonb)'::regprocedure,",
    "               schedule_interval => INTERVAL '1 hour');  -- se registra solo",
    "CALL run_job(<job_id>);          -- rellena kpi_velocidad (10 filas)",
    "SELECT alter_job(<job_id>, scheduled => false);  SELECT delete_job(<job_id>);",
    "SELECT add_job(...);             -- recreado → otro id",
], y=2.15, h=1.45, size=12)
bullets(s, [
    dict(text="Programas **cualquier procedimiento/función PostgreSQL** en el planificador de fondo: sin cron aparte.", size=15, bullet=True, space_after=4),
    dict(text="El procedimiento recibe `job_id int, config jsonb` (Timescale los inyecta).", size=15, bullet=True, space_after=4),
    dict(text="Nuestro ejemplo: calcula los **máximos de velocidad/rpm de la última hora completa** y los upserta en `kpi_velocidad`.", size=15, bullet=True, space_after=4),
    dict(text="En 2.30 el borrado es `delete_job` (el viejo `remove_job` ya no existe).", size=15, bullet=True, space_after=0),
], y=3.9)
rect(s, 9.0, 2.15, 3.75, 2.6, fill=BG_PANEL, round_=True)
textbox(s, 9.25, 2.4, 3.3, 2.2, [
    dict(text="kpi_velocidad", size=13, bold=True, color=AMBER, space_after=4),
    dict(text="1 fila por coche y hora", size=11, color=MUTED, space_after=6),
    dict(text="27.7 → 1.934 rpm_max", size=15, bold=True, color=GREEN, space_after=2),
    dict(text="datos de muestra, job ejecutado a mano", size=11, color=MUTED),
])

# S17 - El circulo
s = new_slide()
header(s, 17, "RESUMEN", "El círculo de la telemetría: 4 políticas que mantienen viva la historia")
row_h = 0.72
steps = [
    ("INGESTA", "lotes ≥1000 o COPY", CYAN),
    ("HIPERTABLE", "chunks por tiempo · comprime lo viejo", TEXT),
    ("COMPRIME", "rowstore → columnstore · −70 %", GREEN),
    ("AGREGA", "cagg cada hora · −10× I/O", GREEN),
    ("BORRA", "autopurga del chunk caducado", RED),
    ("KPI", "cualquier procedimiento, cron propio", AMBER),
]
x0, y0, wstep, gap = 0.6, 2.5, 1.92, 0.07
for i, (t, sub, col) in enumerate(steps):
    x = x0 + (wstep + gap) * i
    box = rect(s, x, y0, wstep, row_h, fill=BG_PANEL, round_=True)
    textbox(s, x + 0.12, y0 + 0.10, wstep - 0.24, 0.35,
            [dict(text=t, size=13, bold=True, color=col)])
    textbox(s, x + 0.12, y0 + 0.42, wstep - 0.24, 0.3,
            [dict(text=sub, size=9, color=MUTED)])
if len(steps) > 1:
    textbox(s, x0, y0 + row_h + 0.12, 12.1, 0.6,
            [dict(text="→", size=32, bold=True, color=AMBER, align=PP_ALIGN.CENTER)])
bullets(s, [
    dict(text="Cuatro procesos de fondo vivos de principio a fin: compresión, retención, refresco del cagg y el KPI custom (cada uno con su id, asignado por Timescale).", size=16, bold=True, color=TEXT, space_after=4),
    dict(text="El pipeline completo: **comprimo lo viejo, agrego a mitad de camino y borro lo caducado — sin que nadie se acuerde**.", size=16, bold=True, color=AMBER, space_after=0),
], y=3.7)
textbox(s, 0.6, 6.4, 12.1, 0.4, [dict(text="La telemetría que era un vertedero de números se convierte en un pipeline que decide por ti.", size=13, italic=True, color=MUTED)])

# S18 - Cierre
s = new_slide()
textbox(s, 0.9, 2.1, 11.5, 0.5, [dict(text="LO QUE NOS LLEVAMOS", size=15, bold=True, color=AMBER)])
textbox(s, 0.9, 2.6, 11.5, 1.2, [dict(text="25 minutos para ver cómo PostgreSQL no tiene miedo al volumen.", size=38, bold=True, color=TEXT)])
bullets(s, [
    dict(text="**Comprimir** casi sin esfuerzo: 56 → 17 MB por chunk, lossless.", size=16, space_after=4),
    dict(text="**Leer 1 de 1.500 chunks** cuando filtras por tiempo (pruning) y agregados precalculados ~10× menos I/O.", size=16, space_after=4),
    dict(text="**Automatizar el ciclo de vida**: compresión, retención, refresco y cualquier procedimiento con 4 líneas.", size=16, space_after=4),
    dict(text="Y aun así: sigue siendo PostgreSQL. `EXPLAIN`, catálogo abierto, tuning estándar.", size=16, space_after=0),
], y=4.0)
rect(s, 0.6, 6.05, 12.1, 0.012, fill=LINE)
textbox(s, 0.6, 6.2, 8.0, 1.1, [
    dict(text="Javier Aragón", size=16, bold=True, color=TEXT, space_after=2),
    dict(text="Arquitecto IT · javier.aragon.diaz@gmail.com · linkedin.com/in/javieraragondiaz", size=12, color=CYAN, space_after=2),
    dict(text="Repo con los scripts de esta demo: github.com/xavipuerto/autometrics-demo", size=12, color=MUTED),
])
textbox(s, 8.6, 6.3, 4.2, 0.7, [
    dict(text='"Con los datos tengo la pregunta clara: ¿qué me están contando?"', size=13, italic=True, color=AMBER, align=PP_ALIGN.RIGHT),
])

# --------------------------- guardar -----------------------------
OUT = "/Users/javiermac/projects/timescale/presentacion/TimescaleDB-PPT-Javier.pptx"
prs.save(OUT)
print("OK ->", OUT)