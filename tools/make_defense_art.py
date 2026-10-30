"""Сторожевая башня и частокол в стиле пака: 3-4 тона на материал, светлый край, чёрный контур снаружи.
Запуск: python3 tools/make_defense_art.py godot/assets/art"""
import sys, os
from PIL import Image

OUT = sys.argv[1] if len(sys.argv) > 1 else "godot/assets/art"
os.makedirs(OUT, exist_ok=True)


def hexc(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


def rect(im, x0, y0, x1, y1, c):
    w, h = im.size
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if 0 <= x < w and 0 <= y < h:
                im.putpixel((x, y), c)


def outline(im):
    """Чёрный контур вокруг непрозрачных пикселей (4 соседа)."""
    w, h = im.size
    out = im.copy()
    for y in range(h):
        for x in range(w):
            if im.getpixel((x, y))[3] > 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                xx, yy = x + dx, y + dy
                if 0 <= xx < w and 0 <= yy < h and im.getpixel((xx, yy))[3] > 0:
                    out.putpixel((x, y), (0, 0, 0, 255))
                    break
    return out


STONE = [hexc("#e4ddd0"), hexc("#bdb5a6"), hexc("#958c7d"), hexc("#6a6257")]
ROOF = [hexc("#e07a52"), hexc("#c0502f"), hexc("#8e3420"), hexc("#5f1f14")]
WOOD = [hexc("#c8925a"), hexc("#a06a3a"), hexc("#764724"), hexc("#4e2c15")]
DARK = hexc("#2a1d14")


def tower():
    W, H = 26, 42
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    # Каменное тело, книзу шире
    rect(im, 6, 15, 19, 41, STONE[1])
    rect(im, 5, 35, 20, 41, STONE[1])
    # Кладка: ряды по 3 пикселя со сдвигом, тёмные швы
    for row, y in enumerate(range(16, 42, 3)):
        rect(im, 5 if y >= 35 else 6, y, 20 if y >= 35 else 19, y, STONE[2])
        off = 0 if row % 2 == 0 else 3
        for x in range(6 + off, 20, 6):
            rect(im, x, y + 1, x, y + 2, STONE[2])
    # Свет слева, тень справа
    rect(im, 6, 15, 6, 41, STONE[0])
    rect(im, 5, 35, 5, 41, STONE[0])
    rect(im, 19, 15, 19, 41, STONE[3])
    rect(im, 20, 35, 20, 41, STONE[3])
    # Площадка под крышей
    rect(im, 3, 12, 22, 15, WOOD[1])
    rect(im, 3, 12, 22, 12, WOOD[0])
    rect(im, 3, 15, 22, 15, WOOD[3])
    for x in range(5, 22, 4):
        rect(im, x, 13, x, 14, WOOD[2])
    # Крыша-шатёр
    for i, y in enumerate(range(1, 12)):
        half = 1 + i
        x0, x1 = 12 - half, 13 + half
        rect(im, x0, y, x1, y, ROOF[1])
        rect(im, x0, y, x0 + 1, y, ROOF[0])
        rect(im, x1 - 1, y, x1, y, ROOF[3])
        if i % 3 == 2:
            rect(im, x0 + 2, y, x1 - 2, y, ROOF[2])
    rect(im, 12, 0, 13, 0, ROOF[2])
    # Флажок
    rect(im, 12, 0, 12, 0, WOOD[3])
    # Бойница и дверь
    rect(im, 12, 20, 13, 25, DARK)
    rect(im, 12, 20, 13, 20, STONE[3])
    rect(im, 10, 33, 15, 41, WOOD[2])
    rect(im, 10, 33, 15, 33, WOOD[3])
    rect(im, 11, 34, 11, 41, WOOD[1])
    rect(im, 14, 37, 14, 37, hexc("#e8c24a"))
    return outline(im)


def palisade():
    W, H = 18, 22
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    # Четыре заострённых бревна
    for i, x0 in enumerate((1, 5, 9, 13)):
        top = 1 if i % 2 == 0 else 3
        rect(im, x0, top + 2, x0 + 3, 21, WOOD[1])
        rect(im, x0 + 1, top, x0 + 2, top + 1, WOOD[1])
        rect(im, x0, top + 2, x0, 21, WOOD[0])
        rect(im, x0 + 3, top + 2, x0 + 3, 21, WOOD[3])
        rect(im, x0 + 1, top + 6, x0 + 2, top + 6, WOOD[2])
    # Связка поперёк
    rect(im, 1, 12, 16, 13, WOOD[2])
    rect(im, 1, 12, 16, 12, WOOD[3])
    return outline(im)


tower().save(os.path.join(OUT, "tower.png"))
palisade().save(os.path.join(OUT, "palisade.png"))
print("ok")
