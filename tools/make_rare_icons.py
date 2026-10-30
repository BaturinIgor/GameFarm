"""Иконки редких материалов диких земель 16x16 в стиле пака: медь (самородок), янтарь (капля),
аметист и изумруд (кристаллы). Запуск: python3 tools/make_rare_icons.py godot/assets/art"""
import sys, os
from PIL import Image

OUT = sys.argv[1] if len(sys.argv) > 1 else "godot/assets/art"
os.makedirs(OUT, exist_ok=True)
N = 16


def hexc(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


def outline(im):
    out = im.copy()
    for y in range(N):
        for x in range(N):
            if im.getpixel((x, y))[3] > 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                xx, yy = x + dx, y + dy
                if 0 <= xx < N and 0 <= yy < N and im.getpixel((xx, yy))[3] > 0:
                    out.putpixel((x, y), (0, 0, 0, 255))
                    break
    return out


def from_rows(rows, pal):
    """Рисунок из строк: символ - индекс тона в палитре, точка - пусто."""
    im = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    top = (N - len(rows)) // 2
    for y, row in enumerate(rows):
        left = (N - len(row)) // 2
        for x, ch in enumerate(row):
            if ch != ".":
                im.putpixel((left + x, top + y), pal[int(ch)])
    return outline(im)


NUGGET = [
    "....1111....",
    "..11001111..",
    ".1100111122.",
    "1100111112223",
    "1101111122223",
    "111111122223.",
    ".11111222233.",
    "..112222333..",
    "...2223333...",
    ".....333.....",
]
DROP = [
    "....11....",
    "...1001...",
    "..110011..",
    "..111111..",
    ".11101112.",
    "1110111122",
    "1111111222",
    "1111112223",
    ".11112223.",
    "..122233..",
    "...3333...",
]
CRYSTAL = [
    "......1.......",
    ".....101......",
    "..1..1012.....",
    ".101.10122.1..",
    ".1011101222012",
    ".1011101222012",
    ".1111111222212",
    ".1111111222222",
    "..11111122223.",
    "...111122233..",
    "....3333333...",
]

ICONS = {
    "copper": (NUGGET, ["#ffd2a0", "#e08a4a", "#b05a2a", "#6e3418"]),
    "amber": (DROP, ["#fff0a0", "#ffb52a", "#d9771a", "#8e4210"]),
    "amethyst": (CRYSTAL, ["#f0d0ff", "#b878f0", "#7e3fc0", "#4a1f78"]),
    "emerald": (CRYSTAL, ["#c8ffd8", "#3fd27a", "#1f9450", "#0e5a2e"]),
}
for name, (rows, pal) in ICONS.items():
    from_rows(rows, [hexc(c) for c in pal]).save(os.path.join(OUT, f"ic_{name}.png"))
print("ok")
