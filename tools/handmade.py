"""Пиксельные спрайты, которых нет в паке: пальмы, кактусы, бамбук, кораллы,
ракушки и иконки ресурсов. Рисуются кодом в той же палитре и с тем же
тёмным контуром, что и Cute Fantasy, чтобы не выбиваться из стиля."""
import math
import random

from PIL import Image

OUTLINE = (14, 7, 27, 255)


def hexc(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


# Материалы: тень, основной, блик.
MAT = {
    "leaf": ("#1e6f50", "#33984b", "#5ac54f"),
    "leafdark": ("#134c4c", "#1e6f50", "#33984b"),
    "cactus": ("#1e6f50", "#33984b", "#5ac54f"),
    "bamboo": ("#5a8a2a", "#8fc040", "#c8e870"),
    "trunk": ("#743f39", "#91533b", "#b86f50"),
    "trunklight": ("#91533b", "#b86f50", "#e4a672"),
    "banana": ("#ed7614", "#ffc825", "#fee761"),
    "pine": ("#ed7614", "#ffc825", "#fee761"),
    "coconut": ("#3f2832", "#743f39", "#91533b"),
    "coral": ("#891e2b", "#f5555d", "#ffb0b8"),
    "shell": ("#e4a672", "#f9e6cf", "#ffffff"),
    "shellpink": ("#e86aa8", "#ffb8dc", "#ffe8f4"),
    "clay": ("#743f39", "#b4553a", "#d8805a"),
    "wool": ("#c0cbdc", "#f4f6fb", "#ffffff"),
    "feather": ("#6c7c9d", "#c0cbdc", "#ffffff"),
    "pearl": ("#a8a0c8", "#eeeaf8", "#ffffff"),
    "cloud": ("#a8b8dc", "#e8eeff", "#ffffff"),
    "star": ("#ed7614", "#ffc825", "#fff3b0"),
    "ticket": ("#ed7614", "#ffc825", "#fee761"),
    "water": ("#006da8", "#0095e9", "#00cdf9"),
    "dark": ("#0e071b", "#262b44", "#3c4258"),
    "ice": ("#8fb2cc", "#d8f0ff", "#ffffff"),
    "red": ("#891e2b", "#c42430", "#f5555d"),
    "gold": ("#9c4a00", "#ffc825", "#fff3b0"),
    "pink": ("#a8407a", "#e86aa8", "#ffb8dc"),
    "sand": ("#be7c60", "#e4a672", "#f6ca9f"),
}


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.m = [[None] * w for _ in range(h)]
        self.fixed = {}

    def put(self, x, y, mat):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < self.w and 0 <= y < self.h:
            self.m[y][x] = mat

    def color(self, x, y, hexcolor):
        """Жёстко заданный цвет пикселя поверх материала."""
        x, y = int(round(x)), int(round(y))
        if 0 <= x < self.w and 0 <= y < self.h:
            if self.m[y][x] is None:
                self.m[y][x] = "fixed"
            self.fixed[(x, y)] = hexc(hexcolor)

    def ellipse(self, cx, cy, rx, ry, mat):
        for y in range(self.h):
            for x in range(self.w):
                if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1:
                    self.m[y][x] = mat

    def rect(self, x0, y0, x1, y1, mat):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.put(x, y, mat)

    def line(self, x0, y0, x1, y1, mat, width=1.0):
        n = int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 1
        for i in range(n + 1):
            t = i / n
            x = x0 + (x1 - x0) * t
            y = y0 + (y1 - y0) * t
            self.disc(x, y, width / 2, mat)

    def disc(self, cx, cy, r, mat):
        for y in range(int(cy - r - 1), int(cy + r + 2)):
            for x in range(int(cx - r - 1), int(cx + r + 2)):
                if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= r * r + 0.25:
                    self.put(x, y, mat)

    def curve(self, pts, mat, w0, w1):
        """Квадратичная кривая Безье с сужением от w0 до w1."""
        (x0, y0), (x1, y1), (x2, y2) = pts
        n = 40
        for i in range(n + 1):
            t = i / n
            x = (1 - t) ** 2 * x0 + 2 * (1 - t) * t * x1 + t * t * x2
            y = (1 - t) ** 2 * y0 + 2 * (1 - t) * t * y1 + t * t * y2
            self.disc(x, y, (w0 + (w1 - w0) * t) / 2, mat)

    def render(self, light=True):
        img = Image.new("RGBA", (self.w, self.h))
        px = img.load()

        def empty(x, y, mat):
            if not (0 <= x < self.w and 0 <= y < self.h):
                return True
            return self.m[y][x] != mat

        for y in range(self.h):
            for x in range(self.w):
                mat = self.m[y][x]
                if mat is None:
                    continue
                if (x, y) in self.fixed:
                    px[x, y] = self.fixed[(x, y)]
                    continue
                dark, base, hi = (hexc(c) for c in MAT[mat])
                c = base
                if light:
                    if empty(x, y + 1, mat) or empty(x + 1, y + 1, mat) and empty(x + 1, y, mat):
                        c = dark
                    elif empty(x, y - 1, mat) or empty(x - 1, y - 1, mat) and empty(x - 1, y, mat):
                        c = hi
                px[x, y] = c
        out = img.copy()
        op = out.load()
        for y in range(self.h):
            for x in range(self.w):
                if px[x, y][3]:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < self.w and 0 <= ny < self.h and px[nx, ny][3]:
                        op[x, y] = OUTLINE
                        break
        return out


def pad(im, l=1, t=1, r=1, b=1):
    out = Image.new("RGBA", (im.width + l + r, im.height + t + b))
    out.alpha_composite(im, (l, t))
    return out


def shadowed(im, rx=None, ry=2):
    """Мягкая тень под предметом, как у деревьев пака."""
    w, h = im.size
    rx = rx or max(3, w // 3)
    out = Image.new("RGBA", (w, h + ry + 1))
    sh = Image.new("RGBA", (w, h + ry + 1))
    sp = sh.load()
    cy = h - 1
    for y in range(h + ry + 1):
        for x in range(w):
            if ((x + 0.5 - w / 2) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1:
                sp[x, y] = (0, 0, 0, 70)
    out.alpha_composite(sh)
    out.alpha_composite(im)
    return out


# ---------------------------------------------------------------- деревья и растения

def palm(bananas=False, seed=1):
    rng = random.Random(seed)
    c = Canvas(40, 52)
    # Ствол: изогнутый, из колец.
    pts = [(19, 50), (22, 34), (20, 17)]
    n = 18
    for i in range(n + 1):
        t = i / n
        x = (1 - t) ** 2 * pts[0][0] + 2 * (1 - t) * t * pts[1][0] + t * t * pts[2][0]
        y = (1 - t) ** 2 * pts[0][1] + 2 * (1 - t) * t * pts[1][1] + t * t * pts[2][1]
        c.disc(x, y, 2.4 - t * 0.6, "trunk" if i % 3 else "trunklight")
    # Листья.
    top = (20, 16)
    fronds = [((-17, 3), (-9, -9)), ((17, 5), (9, -9)), ((-13, 13), (-11, 0)), ((14, 14), (12, 1)),
              ((-3, -11), (-6, -12)), ((6, -10), (4, -13))]
    for (dx, dy), (cx, cy) in fronds:
        c.curve([top, (top[0] + cx, top[1] + cy), (top[0] + dx, top[1] + dy)], "leaf", 4.2, 1.2)
    for (dx, dy), (cx, cy) in fronds[:2]:
        c.curve([top, (top[0] + cx, top[1] + cy + 2), (top[0] + dx * 0.8, top[1] + dy + 3)], "leafdark", 2, 1)
    # Кокосы или бананы под кроной.
    if bananas:
        for x, y in ((17, 19), (19, 21), (21, 19), (23, 21), (19, 23), (21, 23)):
            c.disc(x, y, 1.3, "banana")
    else:
        for x, y in ((17, 19), (21, 20), (19, 22)):
            c.disc(x, y, 1.6, "coconut")
    return shadowed(c.render(), rx=9)


def cactus(seed=1):
    c = Canvas(18, 28)
    c.rect(7, 4, 10, 26, "cactus")
    c.disc(8.5, 4.5, 2, "cactus")
    # Левая рука
    c.rect(2, 11, 4, 16, "cactus")
    c.disc(3, 10.6, 1.5, "cactus")
    c.rect(3, 16, 7, 18, "cactus")
    # Правая рука
    c.rect(13, 8, 15, 13, "cactus")
    c.disc(14, 7.6, 1.5, "cactus")
    c.rect(10, 13, 14, 15, "cactus")
    img = c.render()
    px = img.load()
    # Колючки и цветок.
    for x, y in ((8, 8), (9, 12), (8, 16), (9, 20), (8, 23), (3, 13), (14, 10)):
        px[x, y] = hexc("#f9e6cf")
    for x, y, col in ((8, 2, "#f5555d"), (9, 2, "#f5555d"), (8, 1, "#ffb8dc"), (9, 3, "#c42430")):
        px[x, y] = hexc(col)
    return shadowed(img, rx=6)


def bamboo():
    c = Canvas(20, 40)
    for x0, top in ((4, 6), (9, 2), (14, 9)):
        c.rect(x0, top, x0 + 2, 38, "bamboo")
    img = c.render()
    px = img.load()
    for x0, top in ((4, 6), (9, 2), (14, 9)):
        for y in range(top + 5, 38, 7):
            for x in range(x0, x0 + 3):
                px[x, y] = hexc("#5a8a2a")
    lc = Canvas(20, 40)
    for (x, y), (dx, dy) in (((7, 10), (5, -3)), ((12, 6), (-6, -2)), ((17, 14), (2, -4)), ((6, 20), (-5, -2)), ((12, 18), (6, -1))):
        lc.line(x, y, x + dx, y + dy, "leaf", 1.6)
    leaves = lc.render()
    img.alpha_composite(leaves)
    return shadowed(img, rx=8)


def pineapple():
    c = Canvas(16, 20)
    for (x, y), (dx, dy) in (((8, 9), (-5, -6)), ((8, 9), (5, -6)), ((8, 9), (0, -8)), ((8, 9), (-3, -8)), ((8, 9), (3, -8))):
        c.line(x, y, x + dx, y + dy, "leaf", 1.6)
    c.ellipse(8, 13.5, 4, 5, "pine")
    img = c.render()
    px = img.load()
    for y in range(10, 19):
        for x in range(4, 13):
            if px[x, y][:3] in (hexc("#ffc825")[:3], hexc("#fee761")[:3]) and (x + y) % 3 == 0:
                px[x, y] = hexc("#ed7614")
    # Ещё пара листьев у земли
    lc = Canvas(16, 20)
    lc.line(8, 18, 2, 15, "leafdark", 1.6)
    lc.line(8, 18, 14, 15, "leafdark", 1.6)
    out = lc.render()
    out.alpha_composite(img)
    return shadowed(out, rx=6)


def shells():
    c = Canvas(18, 10)
    c.ellipse(5, 5, 3.5, 3, "shell")
    c.ellipse(12, 6, 3, 2.6, "shellpink")
    img = c.render()
    px = img.load()
    for x, y in ((4, 4), (5, 5), (6, 4), (11, 5), (12, 6), (13, 5)):
        if px[x, y][3]:
            px[x, y] = hexc("#e4a672") if x < 8 else hexc("#e86aa8")
    return img


def oyster():
    c = Canvas(16, 10)
    c.ellipse(8, 5, 6, 3.4, "dark")
    c.ellipse(8, 4.2, 5, 2.2, "pearl")
    img = c.render()
    img.load()[8, 4] = hexc("#ffffff")
    return img


def coral():
    c = Canvas(20, 20)
    for (x0, y0), (x1, y1) in (((10, 19), (10, 8)), ((10, 15), (5, 9)), ((10, 13), (15, 7)), ((5, 11), (3, 5)),
                               ((5, 9), (8, 4)), ((15, 9), (17, 4)), ((10, 9), (11, 3))):
        c.line(x0, y0, x1, y1, "coral", 2.2)
    return shadowed(c.render(), rx=6)


def clay_pit():
    c = Canvas(26, 14)
    c.ellipse(13, 8, 11, 5.5, "clay")
    img = c.render()
    hole = Canvas(26, 14)
    hole.ellipse(13, 8, 6, 2.6, "trunk")
    h = hole.render(light=False)
    px = h.load()
    for y in range(14):
        for x in range(26):
            if px[x, y][:3] == OUTLINE[:3]:
                px[x, y] = (0, 0, 0, 0)
    img.alpha_composite(h)
    return img


def ice_hole():
    c = Canvas(22, 14)
    c.ellipse(11, 7, 10, 6, "ice")
    img = c.render()
    w = Canvas(22, 14)
    w.ellipse(11, 7.5, 6.5, 3.5, "water")
    img.alpha_composite(w.render(light=False))
    return img


def star_dots(im):
    out = im.copy()
    px = out.load()
    rng = random.Random(4)
    for _ in range(6):
        x, y = rng.randrange(3, im.width - 3), rng.randrange(3, im.height - 4)
        if px[x, y][3]:
            px[x, y] = hexc("#ffc825")
            px[x + 1, y] = hexc("#fff3b0")
    return out


def embers(im):
    """Тлеющие угольки на обугленной кроне."""
    out = im.copy()
    px = out.load()
    rng = random.Random(7)
    cells = [(x, y) for y in range(im.height) for x in range(im.width)
             if px[x, y][3] > 200 and px[x, y][:3] in ((51, 44, 44), (77, 67, 67))]
    for x, y in rng.sample(cells, min(len(cells), 14)):
        px[x, y] = hexc(rng.choice(["#ff9a1f", "#ffc825", "#ed7614"]))
    return out


def unicorn_horns(sheet):
    """Рисует золотой рог на каждом кадре лошади: над самым левым верхним пикселем головы."""
    out = sheet.copy()
    px = out.load()
    gold, light = hexc("#ffc825"), hexc("#fff3b0")
    for cy in range(0, sheet.height, 32):
        for cx in range(0, sheet.width, 32):
            top = None
            for y in range(cy, cy + 32):
                xs = [x for x in range(cx, cx + 32) if px[x, y][3] > 200]
                if xs:
                    top = (y, min(xs), max(xs))
                    break
            if top is None:
                continue
            y, x0, x1 = top
            # Лошадь смотрит влево: голова у левого края силуэта; на видах спереди и сзади - по центру.
            width = x1 - x0
            hx = x0 + 2 if width < 12 and (x0 - cx) < 12 else (x0 + x1) // 2
            for i, (dx, dy, col) in enumerate(((0, -1, gold), (0, -2, light), (1, -2, OUTLINE), (-1, -2, OUTLINE),
                                               (0, -3, gold), (-1, -1, OUTLINE), (1, -1, OUTLINE), (0, -4, OUTLINE))):
                x, yy = hx + dx, y + dy
                if cx <= x < cx + 32 and cy <= yy < cy + 32 and (px[x, yy][3] == 0 or col != OUTLINE):
                    px[x, yy] = col
    return out


def fish_variant(sheet, ramp_from, ramp_to):
    mapping = {hexc(a)[:3]: hexc(b) for a, b in zip(ramp_from, ramp_to)}
    out = sheet.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            p = px[x, y]
            if p[3] and p[:3] in mapping:
                px[x, y] = mapping[p[:3]][:3] + (p[3],)
    return out


def sprites():
    return {
        "palm": palm(False, 1),
        "palm_banana": palm(True, 2),
        "cactus": cactus(),
        "bamboo": bamboo(),
        "pineapple": pineapple(),
        "shells": shells(),
        "oyster": oyster(),
        "coral": coral(),
        "clay_pit": clay_pit(),
        "ice_hole": ice_hole(),
    }


# ---------------------------------------------------------------- иконки 16x16

def icon_canvas():
    return Canvas(16, 16)


def icons():
    out = {}

    c = icon_canvas()
    for x0, top in ((4, 2), (8, 4)):
        c.rect(x0, top, x0 + 2, 14, "bamboo")
    im = c.render()
    p = im.load()
    for x0, top in ((4, 2), (8, 4)):
        for y in (top + 4, top + 8):
            for x in range(x0, x0 + 3):
                if y < 15:
                    p[x, y] = hexc("#5a8a2a")
    lc = icon_canvas()
    lc.line(11, 6, 14, 3, "leaf", 1.6)
    im.alpha_composite(lc.render())
    out["bamboo"] = im

    c = icon_canvas()
    c.rect(6, 3, 9, 14, "cactus")
    c.disc(7.5, 3.5, 2, "cactus")
    c.rect(2, 6, 3, 9, "cactus")
    c.rect(2, 9, 6, 10, "cactus")
    c.rect(12, 5, 13, 8, "cactus")
    c.rect(9, 8, 13, 9, "cactus")
    im = c.render()
    p = im.load()
    for x, y in ((7, 6), (8, 10), (7, 12)):
        p[x, y] = hexc("#f9e6cf")
    out["cactus"] = im

    c = icon_canvas()
    c.ellipse(8, 8.5, 5.6, 5.4, "coconut")
    im = c.render()
    p = im.load()
    for x, y in ((6, 6), (8, 5), (7, 8)):
        p[x, y] = hexc("#3f2832")
    out["coconut"] = im

    c = icon_canvas()
    c.curve([(3, 5), (5, 13), (13, 12)], "banana", 3.4, 2.2)
    c.curve([(5, 4), (8, 11), (14, 9)], "banana", 3, 2)
    im = c.render()
    im.load()[3, 4] = hexc("#743f39")
    out["banana"] = im

    c = icon_canvas()
    for dx in (-3, 0, 3):
        c.line(8, 6, 8 + dx, 1, "leaf", 1.6)
    c.ellipse(8, 10, 4, 4.6, "pine")
    im = c.render()
    p = im.load()
    for y in range(7, 15):
        for x in range(4, 13):
            if p[x, y][3] and p[x, y][:3] != OUTLINE[:3] and (x + y) % 3 == 0:
                p[x, y] = hexc("#ed7614")
    out["pineapple"] = im

    c = icon_canvas()
    for x, y, r in ((6, 7, 3.4), (10, 7, 3.4), (8, 10, 3.6), (5, 10, 2.6), (11, 10, 2.6)):
        c.disc(x, y, r, "wool")
    out["wool"] = c.render()

    c = icon_canvas()
    c.curve([(3, 14), (6, 6), (13, 2)], "feather", 4.5, 1.5)
    im = c.render()
    p = im.load()
    for i in range(10):
        x, y = 4 + i, 13 - i
        if 0 <= x < 16 and 0 <= y < 16 and p[x, y][3]:
            p[x, y] = hexc("#6c7c9d")
    out["feather"] = im

    c = icon_canvas()
    c.ellipse(8, 8.5, 6, 5.2, "shellpink")
    c.rect(6, 13, 9, 14, "shellpink")
    im = c.render()
    p = im.load()
    for x in (5, 8, 11):
        for y in range(5, 13):
            if p[x, y][3] and p[x, y][:3] != OUTLINE[:3]:
                p[x, y] = hexc("#e86aa8")
    out["shell"] = im

    c = icon_canvas()
    for (x0, y0), (x1, y1) in (((8, 15), (8, 6)), ((8, 11), (4, 5)), ((8, 10), (12, 4)), ((4, 8), (2, 3)), ((12, 7), (14, 3))):
        c.line(x0, y0, x1, y1, "coral", 2)
    out["coral"] = c.render()

    c = icon_canvas()
    c.disc(8, 8.5, 4.8, "pearl")
    im = c.render()
    p = im.load()
    p[6, 6] = hexc("#ffffff")
    p[7, 6] = hexc("#ffffff")
    out["pearl"] = im

    c = icon_canvas()
    for x, y, r in ((5, 10, 3.2), (9, 8, 4.2), (12, 10, 3), (8, 11, 3.2)):
        c.disc(x, y, r, "cloud")
    out["cloud"] = c.render()

    c = icon_canvas()
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        r = 6.5 if i % 2 == 0 else 2.8
        pts.append((8 + r * math.cos(a), 8.5 + r * math.sin(a)))
    for y in range(16):
        for x in range(16):
            if _inside(x + 0.5, y + 0.5, pts):
                c.put(x, y, "star")
    out["stardust"] = c.render()

    c = icon_canvas()
    c.rect(1, 4, 14, 11, "ticket")
    for y in (6, 7, 8, 9):
        c.m[y][1] = None
        c.m[y][14] = None
    im = c.render()
    p = im.load()
    for y in range(4, 12, 2):
        p[10, y] = hexc("#ed7614")
    for x, y in ((5, 7), (6, 7), (5, 8), (6, 8)):
        p[x, y] = hexc("#c42430")
    out["ticket"] = im

    # Свиток (задания)
    c = icon_canvas()
    c.rect(4, 3, 11, 12, "sand")
    c.rect(3, 2, 12, 3, "trunklight")
    c.rect(3, 12, 12, 13, "trunklight")
    im = c.render()
    p = im.load()
    for y in (5, 7, 9):
        for x in range(5, 11):
            p[x, y] = hexc("#be7c60")
    p[10, 10] = hexc("#c42430")
    p[9, 10] = hexc("#c42430")
    out["scroll"] = im

    # Карта
    c = icon_canvas()
    c.rect(2, 3, 13, 12, "sand")
    im = c.render()
    p = im.load()
    for x in (6, 10):
        for y in range(3, 13):
            p[x, y] = hexc("#be7c60")
    for x, y in ((3, 10), (4, 9), (5, 9), (7, 8), (8, 7), (9, 6)):
        p[x, y] = hexc("#c42430")
    for x, y in ((10, 4), (12, 4), (11, 5), (10, 6), (12, 6)):
        p[x, y] = hexc("#891e2b")
    out["map"] = im

    # Лапка (звери)
    c = icon_canvas()
    c.ellipse(8, 10.5, 3.6, 3, "trunklight")
    for x, y in ((3.5, 6.5), (6.5, 4), (9.5, 4), (12.5, 6.5)):
        c.disc(x, y, 1.6, "trunklight")
    out["paw"] = c.render()

    # Рюкзак
    c = icon_canvas()
    c.rect(4, 4, 11, 13, "trunk")
    c.rect(4, 4, 11, 7, "trunklight")
    c.rect(6, 1, 9, 3, "trunk")
    im = c.render()
    p = im.load()
    for x, y in ((7, 8), (8, 8), (7, 9), (8, 9)):
        p[x, y] = hexc("#ffc825")
    out["bag"] = im

    c = icon_canvas()
    c.disc(8, 8, 6, "gold")
    im = c.render()
    p = im.load()
    for x, y in ((8, 5), (8, 6), (8, 7), (8, 8), (8, 9), (8, 10), (8, 11)):
        p[x, y] = hexc("#ed7614")
    out["coin"] = im
    return out


def _inside(x, y, poly):
    inside = False
    n = len(poly)
    for i in range(n):
        x1, y1 = poly[i]
        x2, y2 = poly[(i + 1) % n]
        if (y1 > y) != (y2 > y) and x < (x2 - x1) * (y - y1) / (y2 - y1) + x1:
            inside = not inside
    return inside
