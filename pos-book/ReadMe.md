# pos-book: TeX → Quarto (HTML/PDF) pipeline

This repo converts LaTeX chapter source files (canonical) into Quarto `.qmd` files for a web book / PDF book.

## Design principles (what we optimize for)
1. **Canonical source stays LaTeX** in `chapters/`.
2. **Generated files are disposable** (can be rebuilt).
3. **Figures live in one canonical place** and are referenced consistently.
4. Keep the pipeline minimal: preprocessing should only normalize paths and a few Pandoc/Quarto incompatibilities.

---

## Repo structure (minimal)

pos-book/
_quarto.yml
index.qmd
ch1.qmd # GENERATED (overwriteable)
chapters/
    ch1.tex # CANONICAL
    ...
figures/ # CANONICAL
    scatter.pdf
    scatter.png
    ... 
scripts/
    preprocess_tex.py
    convert_chapter.sh
filters/
    latex_to_quarto.lua # optional; keep only if you actually use it
    styles.css
build/ # GENERATED (disposable)
tex/
    ch1.tex # preprocessed copy for Pandoc


## Figures (the stable rule)
### Canonical rule
Put figures in figures/ as both:
    name.pdf (for TeX/PDF)
    name.png (for HTML)

#### In LaTeX source
Use a path that points to the canonical folder:
    \includegraphics[width=.7\linewidth]{figures/scatter.pdf}
Why explicit extensions?
    Pandoc conversion needs to fetch a real file during TeX→QMD conversion. Extensionless references frequently break at conversion or preview time. We therefore make the conversion copy explicitly use .png.

### Equations + references (stable rule)
In LaTeX source
Put labels inside environments:
    \begin{equation}\label{eq:bboost}
        P(T \mid x) > P(T).
    \end{equation}

In equation \eqref{eq:bboost} ...

### Conversion workflow
    1) Convert chapter
        ./scripts/convert_chapter.sh
This generates:
    build/tex/ch1.tex (preprocessed TeX)
    ch1.qmd (generated; overwriteable)
    2) Preview
        rm -rf _book .quarto
        quarto preview

Copy to public repo, PhilStatBook
    rsync -av --delete \
        --exclude '_site' \
        --exclude '_book' \
        --exclude '.quarto' \
        --exclude '.DS_Store' \
        --exclude '.git' \
    ../Patterns-from-static/pos-book/ \
    ./pos-book/

