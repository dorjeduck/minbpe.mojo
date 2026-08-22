"""Render the benchmark comparison chart from the three results JSON files.

Writes benchmarks/results/comparison.svg -- one small linear panel per phase,
three bars each. Phases span four orders of magnitude, so each panel carries
its own y-axis; bar heights are comparable within a panel, not across panels.

Greys are chosen to stay legible on both light and dark GitHub themes.

    pixi run chart
"""

import json
import math
import os

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RESULTS = os.path.join(REPO_ROOT, "benchmarks", "results")

IMPLS = [
    ("Python", "python", "#3776AB"),
    ("Rust", "rust", "#A62B1F"),
    ("Mojo", "mojo", "#FF9E0B"),
]
PHASES = [
    ("Basic — training", "basic", "training_time"),
    ("Basic — encoding", "basic", "encoding_time"),
    ("Basic — decoding", "basic", "decoding_time"),
    ("Regex — training", "regex", "training_time"),
    ("Regex — encoding", "regex", "encoding_time"),
    ("Regex — decoding", "regex", "decoding_time"),
]

COLS, ROWS = 3, 2
PANEL_W, PANEL_H = 300, 210
MARGIN_X, MARGIN_TOP = 14, 54
W = COLS * PANEL_W + 2 * MARGIN_X
H = ROWS * PANEL_H + MARGIN_TOP + 10

PAD_L, PAD_R, PAD_T, PAD_B = 58, 16, 34, 40  # within a panel
FG = "#8b949e"


def nice_top(value):
    """Round up to a clean axis maximum (1, 2, 2.5 or 5 x 10^n)."""
    exp = math.floor(math.log10(value))
    for mult in (1, 2, 2.5, 5, 10):
        top = mult * 10**exp
        if top >= value * 1.12:
            return top
    return 10 ** (exp + 1)


def fmt(value):
    if value < 0.01:
        return f"{value * 1000:.1f}ms"
    if value < 1:
        return f"{value * 1000:.0f}ms"
    return f"{value:.2f}s"


def tick_label(value):
    if value == 0:
        return "0"
    return f"{value * 1000:.0f}ms" if value < 1 else f"{value:g}s"


def panel(out, ox, oy, title, values):
    plot_w = PANEL_W - PAD_L - PAD_R
    plot_h = PANEL_H - PAD_T - PAD_B
    baseline = oy + PAD_T + plot_h
    top = nice_top(max(v for _, v, _ in values))

    out.append(
        f'<text x="{ox + PAD_L}" y="{oy + 20}" font-size="12.5" '
        f'font-weight="600" fill="{FG}">{title}</text>'
    )

    for i in range(5):
        v = top * i / 4
        y = baseline - plot_h * i / 4
        out.append(
            f'<line x1="{ox + PAD_L}" y1="{y:.1f}" x2="{ox + PAD_L + plot_w}" '
            f'y2="{y:.1f}" stroke="{FG}" stroke-width="1" stroke-opacity="0.22"/>'
        )
        out.append(
            f'<text x="{ox + PAD_L - 8}" y="{y + 4:.1f}" font-size="10" '
            f'fill="{FG}" text-anchor="end">{tick_label(v)}</text>'
        )

    slot = plot_w / len(values)
    bar_w = slot * 0.5
    for i, (label, value, colour) in enumerate(values):
        cx = ox + PAD_L + slot * (i + 0.5)
        bh = plot_h * value / top
        out.append(
            f'<rect x="{cx - bar_w / 2:.1f}" y="{baseline - bh:.1f}" '
            f'width="{bar_w:.1f}" height="{bh:.1f}" fill="{colour}"/>'
        )
        out.append(
            f'<text x="{cx:.1f}" y="{baseline - bh - 6:.1f}" font-size="10" '
            f'fill="{FG}" text-anchor="middle">{fmt(value)}</text>'
        )
        out.append(
            f'<text x="{cx:.1f}" y="{baseline + 16:.1f}" font-size="11" '
            f'fill="{FG}" text-anchor="middle">{label}</text>'
        )

    out.append(
        f'<line x1="{ox + PAD_L}" y1="{baseline}" x2="{ox + PAD_L + plot_w}" '
        f'y2="{baseline}" stroke="{FG}" stroke-width="1.4"/>'
    )


def main():
    data = {
        key: json.load(open(os.path.join(RESULTS, f"{key}.json")))
        for _, key, _ in IMPLS
    }

    out = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" '
        f'viewBox="0 0 {W} {H}" font-family="-apple-system,BlinkMacSystemFont,'
        f'Segoe UI,Helvetica,Arial,sans-serif">',
        f'<text x="{MARGIN_X + 8}" y="24" font-size="14" font-weight="600" '
        f'fill="{FG}">minbpe: time per phase, seconds (lower is better)</text>',
        f'<text x="{MARGIN_X + 8}" y="42" font-size="11" fill="{FG}">'
        f"Each panel has its own scale.</text>",
    ]

    for i, (title, tok, phase) in enumerate(PHASES):
        ox = MARGIN_X + PANEL_W * (i % COLS)
        oy = MARGIN_TOP + PANEL_H * (i // COLS)
        values = [(name, data[key][tok][phase], colour) for name, key, colour in IMPLS]
        panel(out, ox, oy, title, values)

    out.append("</svg>")

    path = os.path.join(RESULTS, "comparison.svg")
    with open(path, "w") as f:
        f.write("\n".join(out))
    print(f"wrote {path}")


if __name__ == "__main__":
    main()
