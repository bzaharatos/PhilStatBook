#!/usr/bin/env bash
set -euo pipefail

CH="${1:-ch1}"                 # ch1 by default
CH_TEX="chapters/${CH}.tex"
PRE_TEX="build/tex/${CH}.tex"
OUT_QMD="${CH}.qmd"

echo "OUT_QMD=$OUT_QMD"

mkdir -p build/tex


python3 scripts/preprocess_tex.py "$CH_TEX" "$PRE_TEX"

pandoc "$PRE_TEX" \
  -f latex \
  -t markdown+definition_lists+tex_math_dollars \
  --wrap=none \
  --lua-filter="filters/latex_to_quarto.lua" \
  -o "$OUT_QMD"

perl -pi -e 's!\(figures/([^)]+?)\)(\{#plot:[^}]+\})!\(figures/$1.png\)$2!g' "$OUT_QMD"

# Ensure HTML can load extensionless figure URLs like figures/scatter
# (Quarto/Pandoc sometimes emits <img src="figures/<stem>"> with no extension.)
for f in figures/*.png; do
  [ -e "$f" ] || continue
  base="${f%.png}"
  cp -f "$f" "$base"
done


# --- Canonicalize equation labels + eqrefs for Quarto ---
OUT_QMD_ENV="$OUT_QMD" python3 - <<'PY'
import os, re
from pathlib import Path

p = Path(os.environ["OUT_QMD_ENV"])
s = p.read_text(encoding="utf-8")

def norm_id(x: str) -> str:
    # chapter:intro -> intro, chapter-intro -> intro, etc.
    x = x.strip()
    x = re.sub(r"^chapter[:\-]", "", x)
    x = x.replace(":", "-")
    return x

# 1) Heading ids: {#chapter:intro} or {#chapter-intro} -> {#sec-intro}
s = re.sub(r"\{#chapter[:\-]([A-Za-z0-9_.:-]+)\}",
           lambda m: "{#sec-" + norm_id(m.group(1)) + "}",
           s)

# 2) Pandoc-generated chapter refs:
#    [\[chapter:intro\]](#chapter:intro){reference-type="ref"...} -> @sec-intro
s = re.sub(r'\[(?:\\.|[^\]])*\]\(#chapter[:\-]([^)]+)\)\{reference-type="ref[^"]*"[^}]*\}',
           lambda m: "@sec-" + norm_id(m.group(1)),
           s)

# 3) Plain tokens in text: [chapter:intro] -> @sec-intro
s = re.sub(r"\[chapter:([A-Za-z0-9_.:-]+)\]",
           lambda m: "@sec-" + norm_id(m.group(1)),
           s)


# 1) Pandoc eqref links -> Quarto refs: @eq-...
#    e.g. [\[eq:bboost\]](#eq:bboost){reference-type="eqref"...} -> @eq-bboost
s = re.sub(
    r"\[(?:\\.|[^\]])*\]\(#eq:([^)]+)\)\{reference-type=\"eqref\"[^}]*\}",
    r"@eq-\1",
    s
)

# 2) Rewrite every $$ ... $$ block that contains an equation label into:
#    $$\nBODY\n$$ {#eq-ID}
pat = re.compile(r"\$\$(.*?)\$\$(\[\]\{[^}]*\}|\{[^}]*\})?", re.DOTALL)

def repl(m):
    body = m.group(1)
    attr = m.group(2) or ""

    # label can appear inside the math body: \label{eq:foo}
    lab = re.search(r"\\label\{eq:([^}]+)\}", body)
    eqid = lab.group(1) if lab else None
    body = re.sub(r"\\label\{eq:[^}]+\}", "", body).strip()

    # or label can appear in pandoc attrs: []{#eq:foo label="eq:foo"} / {#eq-foo}
    a = re.search(r"#eq[:\-]([A-Za-z0-9_.:-]+)", attr)
    if a:
        eqid = a.group(1)

    # If unlabeled, leave block alone (but normalize whitespace a bit)
    if not eqid:
        return f"$$\n{body}\n$$" if body else "$$\n$$"

    eqid = eqid.replace(":", "-")
    return f"$$\n{body}\n$$ {{#eq-{eqid}}}"

s = pat.sub(repl, s)

# 3) Cleanup: remove any empty orphaned label-only lines like "{#eq-foo}{#eq-bar}"
s = re.sub(r"^\s*(\{#eq-[^}]+\})+\s*$\n?", "", s, flags=re.MULTILINE)

# Remove leading "equation " / "Equation " immediately before an equation crossref
s = re.sub(r"\b[Ee]quation\s+(@eq-[A-Za-z0-9_.:-]+)\b", r"\1", s)

s = re.sub(r"\b[Ii]n\s+[Ee]quation\s+(@eq-[A-Za-z0-9_.:-]+)\b", r"In \1", s)



p.write_text(s, encoding="utf-8")
PY
