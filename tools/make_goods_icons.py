"""Иконки товаров усадьбы 16x16 в стиле пака: заливка в 3-4 тона, светлый блик, чёрный контур снаружи.
Запуск: python3 tools/make_goods_icons.py godot/assets/art"""
import sys, os
from PIL import Image

OUT = sys.argv[1] if len(sys.argv) > 1 else "godot/assets/art"
os.makedirs(OUT, exist_ok=True)
N = 16


def canvas():
    return Image.new("RGBA", (N, N), (0, 0, 0, 0))


def rect(im, x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if 0 <= x < N and 0 <= y < N:
                im.putpixel((x, y), c)


def px(im, pts, c):
    for x, y in pts:
        if 0 <= x < N and 0 <= y < N:
            im.putpixel((x, y), c)


def outline(im):
    """Чёрный контур вокруг непрозрачных пикселей (4 соседа)."""
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


def hexc(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


def ingots(light, mid, dark, hl):
    im = canvas()
    # Нижний слиток (трапеция) и верхний поверх
    for (ox, oy) in ((1, 8), (5, 3)):
        rect(im, ox + 1, oy, ox + 8, oy, light)          # верхняя грань
        rect(im, ox, oy + 1, ox + 9, oy + 2, mid)        # бок
        rect(im, ox, oy + 3, ox + 9, oy + 4, dark)       # низ
        px(im, [(ox + 2, oy), (ox + 3, oy)], hl)         # блик
        px(im, [(ox + 1, oy + 1)], light)
    return outline(im)


def planks():
    im = canvas()
    light, mid, dark, grain = hexc("e0a96d"), hexc("c0803f"), hexc("8a5228"), hexc("a56a33")
    for i, oy in enumerate((10, 6, 2)):
        ox = 1 + i * 1
        rect(im, ox, oy, ox + 12, oy + 2, mid)
        rect(im, ox, oy, ox + 12, oy, light)
        rect(im, ox, oy + 3, ox + 12, oy + 3, dark)
        px(im, [(ox + 4, oy + 1), (ox + 5, oy + 1), (ox + 9, oy + 2)], grain)
        px(im, [(ox + 12, oy + 1), (ox + 12, oy + 2)], dark)
    return outline(im)


def slats():
    im = canvas()
    g1, g2, g3, band = hexc("c9de62"), hexc("94b83c"), hexc("5f7d26"), hexc("b5492f")
    for i, x in enumerate((3, 5, 7, 9, 11)):
        top = 2 + (i % 2)
        rect(im, x, top, x, 13, g2)
        px(im, [(x, top)], g1)
        px(im, [(x, 6), (x, 10)], g3)
    rect(im, 3, 8, 11, 8, band)
    rect(im, 3, 9, 11, 9, hexc("7d2c1b"))
    return outline(im)


def brick():
    im = canvas()
    light, mid, dark, mortar = hexc("e8826a"), hexc("c8553d"), hexc("8e3426"), hexc("e7cf9f")
    for (ox, oy) in ((1, 8), (5, 3)):
        rect(im, ox, oy, ox + 9, oy + 4, mid)
        rect(im, ox, oy, ox + 9, oy, light)
        rect(im, ox, oy + 4, ox + 9, oy + 4, dark)
        px(im, [(ox + 3, oy + 2), (ox + 6, oy + 1)], dark)
    rect(im, 1, 7, 10, 7, mortar)
    return outline(im)


def sack(fill_light, fill_mid, fill_dark, mark):
    im = canvas()
    sl, sm, sd = hexc("f1dfb8"), hexc("d9bf8c"), hexc("a8895a")
    # Мешок: горловина сверху, круглое тело
    rect(im, 6, 2, 9, 3, sm)
    rect(im, 5, 4, 10, 4, hexc("8a5228"))      # верёвка
    rect(im, 4, 5, 11, 13, sm)
    rect(im, 3, 7, 12, 12, sm)
    rect(im, 4, 13, 11, 13, sd)
    rect(im, 3, 12, 12, 12, sd)
    px(im, [(5, 6), (4, 8), (5, 7)], sl)
    # Содержимое видно сверху и знак на боку
    rect(im, 6, 1, 9, 1, fill_light)
    px(im, [(7, 0), (8, 0)], fill_light)
    px(im, mark, fill_mid)
    return outline(im)


def flour():
    return sack(hexc("ffffff"), hexc("e3a83a"), None, [(7, 8), (8, 9), (7, 10), (8, 11), (6, 9), (9, 9)])


def lime():
    im = canvas()
    w1, w2, w3 = hexc("ffffff"), hexc("dfe4ea"), hexc("aab3c0")
    # Горка белого порошка в деревянной миске
    rect(im, 4, 6, 11, 7, w2)
    rect(im, 3, 8, 12, 9, w2)
    rect(im, 6, 4, 9, 5, w1)
    px(im, [(5, 6), (6, 6), (4, 8)], w1)
    px(im, [(10, 8), (11, 9)], w3)
    b1, b2 = hexc("c0803f"), hexc("8a5228")
    rect(im, 2, 10, 13, 11, b1)
    rect(im, 3, 12, 12, 12, b1)
    rect(im, 4, 13, 11, 13, b2)
    px(im, [(3, 10), (4, 10)], hexc("e0a96d"))
    return outline(im)


def oil():
    im = canvas()
    glass, glass_d, oil_l, oil_m, oil_d = hexc("d8eef5"), hexc("9cc3cf"), hexc("ffe07a"), hexc("f0b22e"), hexc("a8721a")
    cork = hexc("a0673a")
    rect(im, 7, 1, 8, 2, cork)
    rect(im, 6, 3, 9, 4, glass)
    rect(im, 4, 5, 11, 14, glass)
    rect(im, 3, 7, 12, 13, glass)
    rect(im, 4, 8, 11, 13, oil_m)
    rect(im, 3, 9, 12, 12, oil_m)
    rect(im, 4, 8, 11, 8, oil_l)
    rect(im, 4, 13, 11, 13, oil_d)
    px(im, [(5, 6), (4, 7), (5, 9), (5, 10)], (255, 255, 255, 255))
    px(im, [(11, 6), (12, 8)], glass_d)
    return outline(im)


ICONS = {
    "planks": planks(),
    "slats": slats(),
    "brick": brick(),
    "lime": lime(),
    "iron_bar": ingots(hexc("c0cbdc"), hexc("8e9ab4"), hexc("424c6e"), hexc("f9e6cf")),
    "gold_bar": ingots(hexc("ffe07a"), hexc("f0b22e"), hexc("a8721a"), hexc("fff8d8")),
    "flour": flour(),
    "oil": oil(),
}

for name, im in ICONS.items():
    im.save(os.path.join(OUT, "ic_%s.png" % name))
print("ok", len(ICONS))
