"""Пиксельные иконки 16x16 для интерфейса: дом, огород, таланты, профиль.

Рисуются кодом в палитре пака (тёмный контур, тень снизу, блик сверху),
чтобы в окнах не было эмодзи.
"""
from PIL import Image

from handmade import MAT, Canvas, hexc, _inside
import interior  # noqa: F401  (материалы мебели)

MAT.update({
    "steel": ("#3c4258", "#8b9bb4", "#dfe6f0"),
    "wood2": ("#5a3418", "#8a5a30", "#c08850"),
    "green2": ("#1e6f20", "#4fc83a", "#a8f070"),
    "blue2": ("#1c3a6e", "#2f63b0", "#6ca8f0"),
    "purple2": ("#4a2a7a", "#8a4ac8", "#c890ff"),
    "soil": ("#3f2832", "#743f39", "#a0603c"),
    "fire2": ("#a8201e", "#ff7a1f", "#ffe070"),
    "bone2": ("#a89a88", "#efe8da", "#ffffff"),
})


def poly(c, pts, mat):
    for y in range(c.h):
        for x in range(c.w):
            if _inside(x + 0.5, y + 0.5, pts):
                c.put(x, y, mat)


def px(im, pts, color):
    p = im.load()
    for x, y in pts:
        p[x, y] = hexc(color)
    return im


def door():
    c = Canvas(16, 16)
    c.rect(3, 1, 12, 15, "wood2")
    im = c.render()
    p = im.load()
    for y in range(3, 15):
        p[7, y] = hexc("#5a3418")
    return px(im, [(10, 8), (10, 9)], "#ffc825")


def stairs():
    c = Canvas(16, 16)
    for i in range(4):
        c.rect(1 + i * 3, 12 - i * 3, 14, 14 - i * 3 + 1, "wood2")
    return c.render()


def trophy():
    c = Canvas(16, 16)
    c.ellipse(8, 5, 5.5, 4.5, "gold")
    c.rect(7, 8, 8, 11, "gold")
    c.rect(4, 12, 11, 14, "wood2")
    c.disc(2.2, 5, 1.6, "gold")
    c.disc(13.8, 5, 1.6, "gold")
    return c.render()


def plan():
    c = Canvas(16, 16)
    c.rect(1, 2, 14, 13, "blue2")
    im = c.render()
    white = "#dff4ff"
    pts = [(x, 10) for x in range(4, 12)] + [(4, y) for y in range(6, 11)] + [(11, y) for y in range(6, 11)]
    pts += [(4 + i, 6 - i // 2) for i in range(4)] + [(11 - i, 6 - i // 2) for i in range(4)]
    return px(im, pts, white)


def bed():
    c = Canvas(16, 16)
    c.rect(1, 3, 3, 14, "wood2")
    c.rect(3, 8, 14, 12, "red")
    c.rect(3, 6, 6, 8, "pillow")
    c.rect(13, 9, 14, 14, "wood2")
    return c.render()


def wardrobe():
    c = Canvas(16, 16)
    c.rect(2, 1, 13, 15, "wood2")
    im = c.render()
    p = im.load()
    for y in range(3, 14):
        p[7, y] = hexc("#5a3418")
    return px(im, [(6, 8), (9, 8)], "#ffc825")


def book():
    c = Canvas(16, 16)
    c.rect(2, 2, 13, 13, "purple2")
    c.rect(3, 12, 13, 14, "paper")
    im = c.render()
    return px(im, [(7, 6), (8, 6), (6, 7), (9, 7), (7, 8), (8, 8)], "#ffc825")


def hammer():
    c = Canvas(16, 16)
    c.line(4, 13, 10, 7, "wood2", 2)
    c.rect(7, 2, 14, 6, "steel")
    return c.render()


def telescope():
    c = Canvas(16, 16)
    c.line(2, 11, 13, 4, "blue2", 3.2)
    c.line(8, 9, 5, 15, "wood2", 1.5)
    c.line(8, 9, 11, 15, "wood2", 1.5)
    return c.render()


def bag(fill, mark):
    c = Canvas(16, 16)
    c.ellipse(8, 10, 6, 5, fill)
    c.rect(5, 2, 10, 5, fill)
    im = c.render()
    p = im.load()
    for x in range(5, 11):
        p[x, 5] = hexc("#5a3418")
    return px(im, mark, "#ffffff")


def compost():
    c = Canvas(16, 16)
    c.ellipse(8, 11, 6.5, 4, "soil")
    c.line(8, 9, 8, 3, "green2", 1.4)
    c.ellipse(5.5, 4.5, 2.5, 1.6, "green2")
    c.ellipse(10.5, 4, 2.5, 1.6, "green2")
    return c.render()


def watering_can():
    c = Canvas(16, 16)
    c.rect(3, 6, 10, 13, "steel")
    c.line(10, 9, 15, 4, "steel", 1.6)
    c.ellipse(6.5, 4, 3.5, 2, "steel")
    im = c.render()
    return px(im, [(14, 2), (15, 3), (13, 1)], "#6ca8f0")


def shield():
    c = Canvas(16, 16)
    poly(c, [(2, 2), (14, 2), (14, 8), (8, 15), (2, 8)], "blue2")
    im = c.render()
    return px(im, [(8, y) for y in range(4, 12)] + [(x, 6) for x in range(5, 12)], "#ffc825")


def sword():
    c = Canvas(16, 16)
    c.line(3, 13, 12, 4, "steel", 2)
    c.line(4, 9, 7, 12, "wood2", 1.6)
    c.disc(2.5, 13.5, 1.2, "gold")
    return c.render()


def boots():
    c = Canvas(16, 16)
    c.rect(4, 1, 9, 11, "wood2")
    c.rect(4, 9, 13, 13, "wood2")
    im = c.render()
    p = im.load()
    for x in range(4, 14):
        p[x, 14] = hexc("#3f2832")
    for x in range(4, 10):
        p[x, 3] = hexc("#c08850")
    return im


def helmet():
    c = Canvas(16, 16)
    c.ellipse(8, 9, 6.5, 6, "steel")
    c.rect(1, 9, 14, 15, "steel")
    im = c.render()
    p = im.load()
    for x in range(3, 13):
        p[x, 11] = hexc("#262b44")
    return px(im, [(8, y) for y in range(3, 10)], "#c42430")


def bolt():
    c = Canvas(16, 16)
    poly(c, [(9, 1), (3, 9), (8, 9), (6, 15), (13, 6), (8, 6)], "gold")
    return c.render()


def clover():
    c = Canvas(16, 16)
    c.line(8, 8, 11, 15, "leafdark", 1.3)
    for (cx, cy), mat in (((5, 5), "green2"), ((11, 5), "leaf"), ((5, 11), "leaf"), ((11, 11), "green2")):
        c.disc(cx, cy, 2.9, mat)
    return c.render()


def eye():
    c = Canvas(16, 16)
    c.ellipse(8, 8, 7, 4.5, "pillow")
    c.disc(8, 8, 3, "blue2")
    im = c.render()
    return px(im, [(8, 8), (7, 7)], "#0e071b")


def skull():
    c = Canvas(16, 16)
    c.ellipse(8, 7, 6, 5.5, "bone2")
    c.rect(5, 11, 10, 14, "bone2")
    im = c.render()
    return px(im, [(5, 7), (6, 7), (10, 7), (11, 7), (6, 8), (10, 8), (7, 13), (9, 13)], "#0e071b")


def paw():
    c = Canvas(16, 16)
    c.ellipse(8, 12.2, 3.3, 2.6, "wood2")
    for cx, cy in ((2.5, 7.5), (6, 3), (10, 3), (13.5, 7.5)):
        c.disc(cx, cy, 1.5, "wood2")
    return c.render()


def magnet():
    c = Canvas(16, 16)
    poly(c, [(2, 2), (6, 2), (6, 9), (8, 11), (10, 9), (10, 2), (14, 2), (14, 10), (8, 15), (2, 10)], "red")
    im = c.render()
    return px(im, [(3, 2), (4, 2), (5, 2), (11, 2), (12, 2), (13, 2), (3, 3), (4, 3), (5, 3), (11, 3), (12, 3), (13, 3)], "#dfe6f0")


def hourglass():
    c = Canvas(16, 16)
    c.rect(3, 1, 12, 2, "wood2")
    c.rect(3, 13, 12, 14, "wood2")
    poly(c, [(4, 3), (12, 3), (8, 8)], "glass")
    poly(c, [(8, 8), (4, 13), (12, 13)], "glass")
    im = c.render()
    return px(im, [(7, 11), (8, 11), (6, 12), (7, 12), (8, 12), (9, 12), (7, 4), (8, 4), (9, 4)], "#ffc825")


def heart_plus():
    c = Canvas(16, 16)
    c.disc(5.5, 6, 3.4, "red")
    c.disc(10.5, 6, 3.4, "red")
    poly(c, [(2.2, 7), (13.8, 7), (8, 14)], "red")
    im = c.render()
    return px(im, [(8, y) for y in range(5, 10)] + [(x, 7) for x in range(6, 11)], "#ffffff")


def crown():
    c = Canvas(16, 16)
    poly(c, [(2, 12), (2, 4), (5, 8), (8, 3), (11, 8), (14, 4), (14, 12)], "gold")
    im = c.render()
    return px(im, [(8, 9), (5, 10), (11, 10)], "#c42430")


def coin_stack():
    c = Canvas(16, 16)
    for i, mat in enumerate(("gold", "banana", "gold")):
        c.ellipse(8 + (i % 2) * 1.5 - 0.7, 12.5 - i * 3.5, 6, 2.4, mat)
    im = c.render()
    p = im.load()
    for i in range(3):
        y = int(12.5 - i * 3.5) + 2
        for x in range(3, 14):
            if p[x, y][3] and p[x, y][:3] != (14, 7, 27):
                p[x, y] = hexc("#9c4a00")
    return im


def scroll():
    c = Canvas(16, 16)
    c.rect(3, 3, 12, 12, "paper")
    c.disc(3, 3.5, 2, "wood2")
    c.disc(12, 12.5, 2, "wood2")
    im = c.render()
    return px(im, [(x, y) for y in (6, 8, 10) for x in range(5, 11)], "#a89a88")


def star():
    c = Canvas(16, 16)
    poly(c, [(8, 1), (10, 6), (15, 6), (11, 9), (13, 15), (8, 11), (3, 15), (5, 9), (1, 6), (6, 6)], "gold")
    return c.render()


def gem():
    c = Canvas(16, 16)
    poly(c, [(4, 3), (12, 3), (15, 7), (8, 15), (1, 7)], "purple2")
    im = c.render()
    return px(im, [(6, 5), (7, 5), (5, 6)], "#ffffff")


def stopwatch():
    c = Canvas(16, 16)
    c.disc(8, 9, 6, "steel")
    c.disc(8, 9, 4.3, "pillow")
    c.rect(7, 1, 8, 3, "steel")
    im = c.render()
    return px(im, [(8, 9), (8, 8), (8, 7), (9, 9), (10, 9)], "#0e071b")


def sun():
    c = Canvas(16, 16)
    c.disc(8, 8, 4, "gold")
    for x, y in ((8, 1), (8, 14), (1, 8), (14, 8), (3, 3), (12, 3), (3, 12), (12, 12)):
        c.disc(x, y, 1.1, "gold")
    return c.render()


def icons():
    return {
        "door": door(), "stairs": stairs(), "trophy": trophy(), "plan": plan(), "bed": bed(),
        "wardrobe": wardrobe(), "book": book(), "hammer": hammer(), "telescope": telescope(),
        "compost": compost(), "watering_can": watering_can(),
        "fert_compost": bag("soil", [(7, 9), (8, 9), (8, 10)]),
        "fert_super": bag("green2", [(8, 8), (8, 9), (8, 10), (7, 9), (9, 9)]),
        "fert_magic": bag("purple2", [(8, 7), (7, 9), (9, 9), (8, 11), (6, 8), (10, 10)]),
        "shield": shield(), "sword": sword(), "boots": boots(), "helmet": helmet(), "bolt": bolt(),
        "clover": clover(), "eye": eye(), "skull": skull(), "paw": paw(), "magnet": magnet(),
        "hourglass": hourglass(), "heart_plus": heart_plus(), "crown": crown(), "coins": coin_stack(),
        "scroll2": scroll(), "star": star(), "gem": gem(), "stopwatch": stopwatch(), "sun": sun(),
    }
