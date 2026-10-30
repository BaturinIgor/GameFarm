"""Иконки товаров ткацкой и ювелирной 16x16 в стиле пака: ткань, облачный шёлк, огранённый алмаз, украшение.
Запуск: python3 tools/make_craft_icons.py godot/assets/art"""
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
    im = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    top = (N - len(rows)) // 2
    for y, row in enumerate(rows):
        left = (N - len(row)) // 2
        for x, ch in enumerate(row):
            if ch != ".":
                im.putpixel((left + x, top + y), pal[int(ch)])
    return outline(im)


# Рулон ткани: торец справа, складка снизу
ROLL = [
    "..11111111111.",
    ".1000000000144",
    "11111111111433",
    "12222222224434",
    "12222222224343",
    "12222222224434",
    "12222222224343",
    "22222222224434",
    "23333333334343",
    ".333333333344.",
    "..3333333333..",
]
# Огранённый камень
GEM = [
    "...11111111...",
    "..1001110011..",
    ".100111111022.",
    "11111111112222",
    ".1112222223333",
    "..11222223333.",
    "...122223333..",
    "....1223333...",
    ".....12333....",
    "......133.....",
]
# Кольцо с камнем: 0-3 золото, 4-5 янтарь
RING = [
    ".....44.....",
    "....4554....",
    "....4554....",
    "...001100...",
    "..01....12..",
    ".01......12.",
    ".1........2.",
    ".1........2.",
    ".12......23.",
    "..12....23..",
    "...223323...",
    ".....33.....",
]

ICONS = {
    "cloth": (ROLL, ["#d8e8ff", "#7aa6e8", "#4a76c0", "#2c4a86", "#f0e6d0"]),
    "silk": (ROLL, ["#ffffff", "#f0e4ff", "#cdb6f0", "#9a7ed0", "#fff6d8"]),
    "cut_gem": (GEM, ["#ffffff", "#bff4ff", "#6fd4f0", "#2f9ac0"]),
    "jewel": (RING, ["#fff2a8", "#ffd23a", "#d9971a", "#8e5a10", "#ffb52a", "#ffe9a0"]),
}
for name, (rows, pal) in ICONS.items():
    from_rows(rows, [hexc(c) for c in pal]).save(os.path.join(OUT, f"ic_{name}.png"))
print("ok")
