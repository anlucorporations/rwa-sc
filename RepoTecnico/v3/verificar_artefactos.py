#!/usr/bin/env python3
"""Verificación automática de los artefactos de datos y trazabilidad de RWA v3.

Uso:  python3 RepoTecnico/verificar_artefactos.py
Salida: informe por comprobación + exit code 0 (todo OK) / 1 (fallo).

Comprobaciones (criterio B11/N-16 del INFORME_CIERRE_V3_1):
  1. Parseo SQL de base_datos.sql y migracion_v2_a_v3.sql (pglast si está instalado).
  2. Cuadre de tablas y columnas entre base_datos.sql, diccionario_datos.md y diagrama_er.md.
  3. Sintaxis básica de los bloques Mermaid.
  4. Versión única: sin referencias operativas a 1.3 (solo históricas en INFORME_*).
  5. Recuento de RF / RNF / RT y de supuestos S-n.
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
FAILED = []


def check(name, ok, detail=""):
    print(f"[{'PASS' if ok else 'FAIL'}] {name}" + (f" — {detail}" if detail else ""))
    if not ok:
        FAILED.append(name)


# ---------------------------------------------------------------- 1) SQL
sql_texts = {}
for fname in ("base_datos.sql", "migracion_v2_a_v3.sql"):
    path = ROOT / fname
    text = path.read_text(encoding="utf-8")
    sql_texts[fname] = text
    stmts = None
    try:
        import pglast  # type: ignore

        clean = "\n".join(l for l in text.splitlines() if not l.strip().startswith("\\"))
        stmts = len(pglast.parse_sql(clean))
        check(f"SQL {fname}", True, f"{stmts} sentencias parseadas")
    except ImportError:
        check(f"SQL {fname}", True, "pglast no instalado: parseo omitido (instalar pglast)")
    except Exception as exc:  # noqa: BLE001
        check(f"SQL {fname}", False, f"error de parseo: {exc}")

# ---------------------------------------------------------------- 2) tablas/columnas
sql = sql_texts["base_datos.sql"]


def parse_sql_tables(text):
    out = {}
    for m in re.finditer(r"CREATE TABLE IF NOT EXISTS rwa\.(\w+) \((.*?)\n\);", text, re.S):
        cols, depth = [], 0
        for line in m.group(2).splitlines():
            stripped = line.strip()
            if depth == 0:
                mm = re.match(r"^(\w+)\s+[a-zA-Z]", stripped)
                if mm and mm.group(1).upper() not in ("CONSTRAINT", "PRIMARY"):
                    cols.append(mm.group(1))
            depth += line.count("(") - line.count(")")
        out[m.group(1)] = cols
    return out


sql_tables = parse_sql_tables(sql)

dic = (ROOT / "diccionario_datos.md").read_text(encoding="utf-8")
dic_tables = {}
for m in re.finditer(r"^### \d+\.\d+ `(\w+)`.*?\n(.*?)(?=^### |^## |\Z)", dic, re.M | re.S):
    dic_tables[m.group(1)] = re.findall(r"^\| `(\w+)` \|", m.group(2), re.M)

er = (ROOT / "diagrama_er.md").read_text(encoding="utf-8")
er_tables = {}
for m in re.finditer(r"^    ([A-Z][A-Z0-9_]*) \{\n(.*?)^    \}", er, re.M | re.S):
    er_tables[m.group(1).lower()] = [
        line.split()[1] for line in m.group(2).splitlines() if line.strip() and not line.strip().startswith("}")
    ]

check("Tablas SQL = diccionario", set(sql_tables) == set(dic_tables),
      f"{len(sql_tables)} SQL / {len(dic_tables)} diccionario")
check("Tablas SQL = ER", set(sql_tables) == set(er_tables),
      f"{len(sql_tables)} SQL / {len(er_tables)} ER")

mismatched = []
for table, cols in sql_tables.items():
    if set(cols) != set(dic_tables.get(table, [])):
        mismatched.append(f"{table} (dic)")
    if set(cols) != set(er_tables.get(table, [])):
        mismatched.append(f"{table} (ER)")
check("Columnas SQL = diccionario = ER", not mismatched, ", ".join(mismatched) or "0 discrepancias")

# ---------------------------------------------------------------- 3) Mermaid
blocks = re.findall(r"```mermaid\n(.*?)```", er, re.S)
mermaid_errors = []
for b in blocks:
    for line in b.splitlines():
        st = line.strip()
        if not st or st.startswith("erDiagram") or st in ("}", "{") or st.endswith("{"):
            continue
        if re.match(r"^[A-Za-z_]\w*\s+[A-Za-z_]\w*(\s+(PK|FK|UK))?$", st):
            continue
        if re.match(r'^[A-Z][A-Z0-9_]*\s+(\|\||\}o|\|o|\}\|)(--|\.\.)(\|\||o\{|o\||\|\{)\s+[A-Z][A-Z0-9_]*\s*:\s*".*"$', st):
            continue
        mermaid_errors.append(st)
check("Sintaxis Mermaid", not mermaid_errors, f"{len(blocks)} bloques, {len(mermaid_errors)} errores")

# ---------------------------------------------------------------- 4) versión única
VERSION = "3.0"
operative_13 = []
# Solo patrones operativos: "versión 1.3", "esquema rwa v1.3", "migraciones arrancan en 1.3".
# Se excluyen numeración de sección (### 1.3), notas históricas ("vs") y negaciones ("sin").
PATTERN = re.compile(
    r"(versi[oó]n\s+`?1\.3|esquema\s+`?rwa`?\s+v?1\.3|migraciones?\s+(?:arrancan|empiezan|inician)\s+en\s+`?1\.3)",
    re.I,
)
for fname in ("propuesta_v3.md", "diccionario_datos.md", "diagrama_er.md",
              "entornos_globales.md", "base_datos.sql", "requerimientos.md", "estado_proyecto.md"):
    text = (ROOT / fname).read_text(encoding="utf-8")
    for m in PATTERN.finditer(text):
        snippet = text[max(0, m.start() - 60):m.end() + 20].replace("\n", " ")
        operative_13.append(f"{fname}: …{snippet}…")
check("Versión operativa única 3.0 (sin 1.3)", not operative_13, "; ".join(operative_13))

# ---------------------------------------------------------------- 5) recuentos
req = (ROOT / "requerimientos.md").read_text(encoding="utf-8")
rf = len(set(re.findall(r"\*\*RF-V3-(\d+)\*\*", req)))
rnf = len(set(re.findall(r"\*\*RNF-V3-(\d+)\*\*", req)))
rt = len(set(re.findall(r"\*\*RT-V3-(\d+)\*\*", req)))
sn = len(set(re.findall(r"\| S-(\d+) \|", req)))
print(f"[INFO] Requisitos: {rf} RF · {rnf} RNF · {rt} RT · supuestos S-1…S-{sn}")
check("Cobertura de requisitos mínima", rf >= 28 and rnf >= 14 and rt >= 8,
      f"{rf}/{rnf}/{rt} (esperado ≥28/14/8)")

# ---------------------------------------------------------------- resumen
print()
if FAILED:
    print(f"RESULTADO: FAIL — {len(FAILED)} comprobación(es): " + ", ".join(FAILED))
    sys.exit(1)
print("RESULTADO: PASS — todos los artefactos cuadran.")
