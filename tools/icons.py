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
    "skin2": ("#d29f70", "#f6ca9f", "#ffe4c8"),
    "rope": ("#7a5630", "#c8a060", "#ecd0a0"),
    "night": ("#1c1a4a", "#3a3a8a", "#6a6ac8"),
    "moon": ("#c89a30", "#fee761", "#fffbe0"),
    "potion": ("#891e2b", "#e83b5a", "#ff9ab0"),
    "flask": ("#8fb2cc", "#d8f0ff", "#ffffff"),
    "teal2": ("#0e5a5a", "#1fa8a0", "#7ae8d8"),
    "orange2": ("#9c4a00", "#ed7614", "#ffb060"),
    "stone2": ("#4a5470", "#8e9ab4", "#c8d0e0"),
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


# ---------------------------------------------------------------- таланты и бой

def fist():
    c = Canvas(16, 16)
    c.rect(3, 4, 12, 11, "skin2")
    c.rect(4, 11, 11, 14, "skin2")
    c.rect(2, 6, 3, 10, "skin2")
    im = c.render()
    p = im.load()
    for x in (6, 9):
        for y in range(5, 9):
            p[x, y] = hexc("#b47a50")
    for x in range(4, 12):
        p[x, 9] = hexc("#b47a50")
    return im


def target():
    c = Canvas(16, 16)
    c.disc(8, 8, 6.6, "red")
    c.disc(8, 8, 4.6, "pillow")
    c.disc(8, 8, 2.6, "red")
    im = c.render(light=False)
    return px(im, [(8, 8), (7, 8), (8, 7), (7, 7)], "#ffffff")


def shards():
    c = Canvas(16, 16)
    poly(c, [(2, 9), (4, 5), (8, 4), (12, 6), (14, 10), (12, 14), (4, 14)], "stone2")
    c.disc(3, 2.5, 1.4, "stone2")
    c.disc(13, 2.5, 1.2, "stone2")
    im = c.render()
    return px(im, [(8, 5), (8, 6), (7, 7), (7, 8), (8, 9), (9, 10), (9, 11), (8, 12), (8, 13)], "#0e071b")


def flame():
    c = Canvas(16, 16)
    poly(c, [(8, 1), (11, 5), (13, 8), (13, 11), (10, 14), (6, 14), (3, 11), (3, 8), (5, 6), (6, 8), (7, 5)], "fire2")
    poly(c, [(8, 7), (10, 10), (10, 12), (8, 13), (6, 12), (6, 10)], "banana")
    return c.render()


def quake():
    c = Canvas(16, 16)
    c.rect(1, 9, 14, 14, "soil")
    im = c.render()
    pts = [(4, 9), (5, 10), (5, 11), (6, 12), (10, 9), (9, 10), (10, 11), (11, 12), (11, 13)]
    im = px(im, pts, "#0e071b")
    p = im.load()
    for x, y in ((3, 4), (7, 2), (12, 4), (2, 7), (13, 7), (8, 5)):
        p[x, y] = hexc("#a0603c")
        p[x, y + 1] = hexc("#743f39")
    return im


def swords():
    c = Canvas(16, 16)
    c.line(3, 3, 12, 12, "steel", 2)
    c.line(12, 3, 3, 12, "steel", 2)
    c.line(9, 13, 13, 9, "wood2", 1.6)
    c.line(2, 9, 6, 13, "wood2", 1.6)
    return c.render()


def wave():
    c = Canvas(16, 16)
    c.curve([(1, 13), (4, 3), (12, 4)], "water", 3, 2)
    c.curve([(12, 4), (14, 7), (11, 9)], "water", 2, 2)
    c.rect(1, 12, 14, 14, "water")
    im = c.render()
    return px(im, [(5, 6), (6, 5), (8, 4), (9, 4)], "#ffffff")


def basket():
    c = Canvas(16, 16)
    c.disc(5, 6, 2.3, "red")
    c.disc(9, 5, 2.3, "leaf")
    c.disc(11, 7, 2, "banana")
    poly(c, [(1, 8), (15, 8), (13, 15), (3, 15)], "wood2")
    im = c.render()
    p = im.load()
    for x in range(3, 13, 2):
        for y in range(10, 14):
            p[x, y] = hexc("#5a3418")
    return im


def sprout():
    c = Canvas(16, 16)
    c.rect(2, 12, 13, 14, "soil")
    c.line(8, 12, 8, 6, "leafdark", 1.3)
    c.ellipse(5, 6, 3.4, 2.2, "green2")
    c.ellipse(11, 5, 3.4, 2.2, "green2")
    return c.render()


def dice():
    c = Canvas(16, 16)
    c.rect(2, 2, 13, 13, "pillow")
    im = c.render()
    pts = []
    for x0, y0 in ((4, 4), (10, 4), (7, 7), (4, 10), (10, 10)):
        pts += [(x0, y0), (x0 + 1, y0), (x0, y0 + 1), (x0 + 1, y0 + 1)]
    return px(im, pts, "#c42430")


def magnifier():
    c = Canvas(16, 16)
    c.line(9, 9, 14, 14, "wood2", 2.4)
    c.disc(6.5, 6.5, 5, "steel")
    c.disc(6.5, 6.5, 3.2, "glass")
    im = c.render()
    return px(im, [(5, 5), (5, 6), (6, 4)], "#ffffff")


def owl():
    c = Canvas(16, 16)
    c.ellipse(8, 9, 6, 6, "wood2")
    poly(c, [(2, 2), (6, 5), (3, 6)], "wood2")
    poly(c, [(14, 2), (10, 5), (13, 6)], "wood2")
    c.disc(5.5, 7.5, 2.2, "pillow")
    c.disc(10.5, 7.5, 2.2, "pillow")
    im = c.render()
    im = px(im, [(5, 7), (6, 7), (10, 7), (11, 7)], "#0e071b")
    return px(im, [(8, 10), (8, 9)], "#ffc825")


def rainbow():
    c = Canvas(16, 16)
    for r, mat in ((7, "red"), (5.6, "banana"), (4.2, "green2"), (2.8, "blue2")):
        c.disc(8, 13, r, mat)
    im = c.render(light=False)
    p = im.load()
    for y in range(13, 16):
        for x in range(16):
            p[x, y] = (0, 0, 0, 0)
    for x in range(1, 15):
        if p[x, 12][3]:
            p[x, 13] = hexc("#0e071b")
    for y in range(8, 13):
        for x in range(6, 11):
            if (x - 7.5) ** 2 + (y - 12.5) ** 2 < 2.0:
                p[x, y] = (0, 0, 0, 0)
    return im


def lasso():
    c = Canvas(16, 16)
    c.ellipse(9, 6.5, 5.6, 4.6, "rope")
    c.line(6, 10, 2, 14, "rope", 1.8)
    im = c.render()
    p = im.load()
    for y in range(16):
        for x in range(16):
            if ((x + 0.5 - 9) / 3.4) ** 2 + ((y + 0.5 - 6.5) / 2.4) ** 2 <= 1:
                p[x, y] = (0, 0, 0, 0)
            elif ((x + 0.5 - 9) / 4.4) ** 2 + ((y + 0.5 - 6.5) / 3.4) ** 2 <= 1 and p[x, y][3]:
                p[x, y] = hexc("#0e071b")
    return px(im, [(5, 9), (6, 9)], "#7a5630")


def tag():
    c = Canvas(16, 16)
    poly(c, [(2, 6), (7, 1), (14, 8), (8, 14)], "red")
    im = c.render()
    p = im.load()
    for x, y in ((6, 4), (7, 4), (6, 5), (7, 5)):
        p[x, y] = hexc("#0e071b")
    return px(im, [(8, 8), (9, 9), (10, 10)], "#ffffff")


def moon():
    c = Canvas(16, 16)
    c.disc(8, 8, 6.4, "moon")
    im = c.render()
    p = im.load()
    for y in range(16):
        for x in range(16):
            if (x + 0.5 - 11.5) ** 2 + (y + 0.5 - 5.5) ** 2 < 25:
                p[x, y] = (0, 0, 0, 0)
    out = im.copy()
    op = out.load()
    for y in range(16):
        for x in range(16):
            if p[x, y][3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < 16 and 0 <= ny < 16 and p[nx, ny][3] and p[nx, ny][:3] != (14, 7, 27):
                    op[x, y] = (14, 7, 27, 255)
                    break
    return out


def portal():
    c = Canvas(16, 16)
    c.ellipse(8, 8, 6.5, 7, "purple2")
    c.ellipse(8, 8, 4, 4.6, "violet")
    c.ellipse(8, 8, 1.8, 2.2, "pearl")
    return c.render(light=False)


def wind():
    c = Canvas(16, 16)
    c.curve([(1, 5), (8, 5), (12, 3)], "cloud", 2, 1.6)
    c.curve([(1, 9), (10, 9), (14, 7)], "cloud", 2, 1.6)
    c.curve([(3, 13), (8, 13), (11, 11)], "cloud", 2, 1.6)
    return c.render()


def compass():
    c = Canvas(16, 16)
    c.disc(8, 8, 6.5, "gold")
    c.disc(8, 8, 4.8, "pillow")
    im = c.render()
    im = px(im, [(8, 4), (8, 5), (8, 6), (7, 6), (9, 6), (8, 7)], "#c42430")
    return px(im, [(8, 9), (8, 10), (8, 11), (7, 9), (9, 9)], "#3c4258")


def moneybag():
    c = Canvas(16, 16)
    c.ellipse(8, 10, 6, 5, "rope")
    c.rect(6, 3, 9, 5, "rope")
    poly(c, [(5, 1), (11, 1), (9, 4), (7, 4)], "rope")
    im = c.render()
    p = im.load()
    for x in range(6, 10):
        p[x, 5] = hexc("#7a5630")
    return px(im, [(8, 8), (7, 9), (8, 10), (9, 11), (8, 12), (8, 7), (8, 13)], "#ffc825")


def wing():
    c = Canvas(16, 16)
    poly(c, [(1, 5), (5, 2), (12, 2), (15, 4), (13, 6), (14, 8), (11, 10), (11, 12), (7, 14), (3, 11)], "feather")
    im = c.render()
    return px(im, [(5, 5), (6, 5), (7, 5), (8, 5), (9, 5), (10, 5), (11, 5), (5, 8), (6, 8), (7, 8), (8, 8), (9, 8), (5, 11), (6, 11), (7, 11)], "#8b9bb4")


def ball():
    c = Canvas(16, 16)
    c.disc(8, 8, 6.2, "pillow")
    im = c.render()
    p = im.load()
    for y in range(16):
        for x in range(16):
            if not p[x, y][3] or p[x, y][:3] == (14, 7, 27):
                continue
            a = (x - 7.5, y - 7.5)
            if a[0] < -0.5 and a[1] < -0.5:
                p[x, y] = hexc("#c42430")
            elif a[0] > 0.5 and a[1] > 0.5:
                p[x, y] = hexc("#2f63b0")
            elif a[0] > 0.5 and a[1] < -0.5:
                p[x, y] = hexc("#ffc825")
    return px(im, [(5, 4), (4, 5)], "#ff9ab0")


def net():
    c = Canvas(16, 16)
    c.line(2, 14, 7, 9, "wood2", 1.6)
    c.disc(10, 6, 5, "rope")
    im = c.render()
    p = im.load()
    for y in range(2, 11):
        for x in range(6, 15):
            if (x + 0.5 - 10) ** 2 + (y + 0.5 - 6) ** 2 < 14 and (x + y) % 2 == 0:
                p[x, y] = (0, 0, 0, 0)
    return im


def fang():
    c = Canvas(16, 16)
    poly(c, [(3, 2), (13, 2), (12, 5), (10, 14), (8, 6), (6, 14), (4, 5)], "bone2")
    im = c.render()
    return px(im, [(10, 12), (10, 13), (6, 12), (6, 13)], "#c42430")


def potion():
    c = Canvas(16, 16)
    c.disc(8, 10, 5, "potion")
    c.rect(6, 2, 9, 6, "flask")
    c.rect(5, 1, 10, 2, "wood2")
    im = c.render()
    return px(im, [(5, 8), (6, 7)], "#ffffff")


def key():
    c = Canvas(16, 16)
    c.disc(5, 5, 3.6, "gold")
    c.line(7, 7, 13, 13, "gold", 2)
    c.rect(10, 12, 11, 14, "gold")
    c.rect(12, 10, 14, 11, "gold")
    im = c.render()
    p = im.load()
    p[5, 5] = (0, 0, 0, 0)
    return im


def heart_shield():
    c = Canvas(16, 16)
    poly(c, [(2, 2), (14, 2), (14, 8), (8, 15), (2, 8)], "red")
    im = c.render()
    return px(im, [(5, 5), (6, 5), (9, 5), (10, 5), (4, 6), (7, 6), (8, 6), (11, 6), (5, 7), (10, 7), (6, 8), (9, 8), (7, 9), (8, 9)], "#ffffff")


def anvil_icon():
    c = Canvas(16, 16)
    c.rect(2, 4, 13, 7, "steel")
    poly(c, [(0, 4), (2, 4), (2, 6)], "steel")
    c.rect(6, 7, 10, 11, "steel")
    c.rect(3, 11, 12, 13, "steel")
    return c.render()


def scroll_quest():
    c = Canvas(16, 16)
    c.rect(3, 2, 12, 13, "paper")
    im = c.render()
    return px(im, [(5, 5), (6, 5), (7, 5), (8, 5), (9, 5), (10, 5), (5, 8), (6, 8), (7, 8), (8, 8), (5, 11), (6, 11), (7, 11), (8, 11), (9, 11)], "#743f39")


def no_ads():
    c = Canvas(16, 16)
    c.rect(1, 3, 14, 12, "blue2")
    im = c.render()
    tri = [(6, y) for y in range(5, 11)] + [(7, y) for y in range(6, 10)] + [(8, y) for y in range(6, 10)] + [(9, 7), (9, 8)]
    im = px(im, tri, "#ffffff")
    p = im.load()
    for i in range(14):
        x, y = 1 + i, 14 - i
        p[x, y] = hexc("#f5555d")
        if y - 1 >= 0:
            p[x, y - 1] = hexc("#c42430")
    return im


def talent_icons():
    return {
        "fist": fist(), "target": target(), "shards": shards(), "flame": flame(), "quake": quake(),
        "swords": swords(), "wave": wave(), "basket": basket(), "sprout": sprout(), "dice": dice(),
        "magnifier": magnifier(), "owl": owl(), "rainbow": rainbow(), "lasso": lasso(), "tag": tag(),
        "moon": moon(), "portal": portal(), "wind": wind(), "compass": compass(), "moneybag": moneybag(),
        "wing": wing(), "ball": ball(), "net": net(), "fang": fang(), "potion": potion(), "key": key(),
        "heart_shield": heart_shield(), "anvil2": anvil_icon(), "quest": scroll_quest(), "no_ads": no_ads(),
    }


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
        **talent_icons(),
    }
