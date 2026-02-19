#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path


def normalize_environment_typos(tex: str) -> str:
    tex = tex.replace(r"\end{chap quote}", r"\end{chapquote}")
    tex = tex.replace(r"\begin{chap quote}", r"\begin{chapquote}")
    return tex


def convert_chapquote_to_quote_flushright(tex: str) -> str:
    start_tag = r"\begin{chapquote}{"
    end_tag = r"\end{chapquote}"

    def find_matching_brace(s: str, open_pos: int) -> int:
        depth = 1
        i = open_pos
        while i < len(s):
            c = s[i]
            if c == "{":
                depth += 1
            elif c == "}":
                depth -= 1
                if depth == 0:
                    return i
            i += 1
        raise ValueError("Unbalanced braces in chapquote attribution argument")

    out = []
    i = 0
    while True:
        j = tex.find(start_tag, i)
        if j == -1:
            out.append(tex[i:])
            break

        out.append(tex[i:j])

        attr_start = j + len(start_tag)
        attr_end = find_matching_brace(tex, attr_start)
        attr = tex[attr_start:attr_end].strip()

        body_start = attr_end + 1
        k = tex.find(end_tag, body_start)
        if k == -1:
            raise ValueError("Missing \\end{chapquote}")

        body = tex[body_start:k].strip()

        out.append(
            "\\begin{quote}\n"
            f"{body}\n"
            "\\end{quote}\n"
            "\\begin{flushright}\n"
            f"— {attr}\n"
            "\\end{flushright}\n"
        )

        i = k + len(end_tag)

    return "".join(out)


def normalize_graphics_paths(tex: str) -> str:
    # Chapters/foo(.ext)? -> figures/foo  (extensionless)
    pat = re.compile(
        r"(\\includegraphics(?:\[[^\]]*\])?\{)\s*(?:Chapters|chapters)/([^}\s]+?)(?:\.(pdf|png|jpg|jpeg|svg))?\s*(\})"
    )
    return pat.sub(r"\1figures/\2\4", tex)


def force_png_for_conversion(tex: str) -> str:
    # figures/foo(.ext)? -> figures/foo.png  (explicit so Pandoc + HTML preview can fetch)
    return re.sub(
        r"(\\includegraphics(?:\[[^\]]*\])?\{)\s*figures/([^}\s]+?)(?:\.(pdf|png|jpg|jpeg|svg))?\s*(\})",
        r"\1figures/\2.png\4",
        tex,
    )

def normalize_natbib_cites(tex: str) -> str:
    """
    Enforce: \\cite{...} behaves like narrative (no parentheses) in Quarto output.
    Strategy: rewrite \\cite{...} -> \\citet{...}
    Leave \\citep{...} alone.
    """
    import re
    # \cite{...} -> \citet{...} (but don't touch \citep, \citet, etc.)
    tex = re.sub(r"\\cite\{", r"\\citet{", tex)
    return tex


def main() -> None:
    if len(sys.argv) != 3:
        print("Usage: preprocess_tex.py input.tex output.tex", file=sys.stderr)
        sys.exit(2)

    src = Path(sys.argv[1])
    dst = Path(sys.argv[2])

    tex = src.read_text(encoding="utf-8")
    tex = normalize_environment_typos(tex)
    tex = convert_chapquote_to_quote_flushright(tex)
    tex = normalize_natbib_cites(tex)

    tex = normalize_graphics_paths(tex)
    tex = force_png_for_conversion(tex)

    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_text(tex, encoding="utf-8")


if __name__ == "__main__":
    main()
