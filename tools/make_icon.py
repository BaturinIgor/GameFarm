"""Иконка Harvest Hollow: герой с топором у домика на поляне, вечернее небо со звездой.

    python3 tools/make_icon.py <out.png>

Рисуется пикселями 64x64 вручную (без графики паков), потом увеличивается в 16 раз
и получает мягкое свечение звезды и окна.
"""
import math
import random
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

N = 64
SCALE = 16


def hexc(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


OUT = "#0e071b"

PAL = {
    "O": OUT,
    # шляпа
    "L": "#fff3b0", "Y": "#ffc825", "y": "#ed7614", "z": "#b85a0e",
    # волосы, кожа, глаза
    "H": "#91533b", "h": "#5a2f2a", "S": "#f6ca9f", "s": "#d29f70", "p": "#f08a7a", "E": "#262b44", "e": "#ffffff",
    # рубашка, штаны, ботинки
    "G": "#33984b", "g": "#1e6f50", "I": "#5ac54f",
    "B": "#3a6fd0", "b": "#24408a", "W": "#743f39", "w": "#3f2832",
    # топор
    "T": "#c8844e", "t": "#7a4630", "M": "#d8e0ec", "m": "#7a88a8", "X": "#ffffff", "n": "#4a5470",
}

# Голова героя: широкая соломенная шляпа, как в игре.
HEAD = [
    ".......OOOOOOO........",
    ".....OOLLLLYYYOO......",
    "....OLLYYYYYYYYyO.....",
    "....OLYYYYYYYYYyO.....",
    "...OOYYYYYYYYYYyOO....",
    "..OYyzzzzzzzzzzzyYO...",
    ".OLYYYYYYYYYYYYYYYYyO.",
    "OLYYYYYYYYYYYYYYYYYYyO",
    "OyyYYYYYYYYYYYYYYYyyyO",
    ".OOyyyyyyyyyyyyyyyyOO.",
    "...OhHHHHHHHHHHHHhO...",
    "...OHHhSSSSSSSShHHO...",
    "...OHhSSSSSSSSSShHO...",
    "...OhSSEeSSSSEeSShO...",
    "...OSSSEESSSSEESSSO...",
    "...OSpSSSSSSSSSSpSO...",
    "...OsSSSSSssSSSSSsO...",
    "....OssSSSSSSSSssO....",
    ".....OOOOOOOOOOOO.....",
]

# Топор: рукоять (T, t) и лезвие вправо.
AXE = [
    "..OO.........",
    ".OTtO....OO..",
    ".OTtO...OMXO.",
    ".OTtO..OmMXO.",
    ".OTtOOOmMMXO.",
    ".OTtOnmMMMMXO",
    ".OTtOnmMMMMXO",
    ".OTtOOOmMMXO.",
    ".OTtO..OmMXO.",
    ".OTtO...OMXO.",
    ".OTtO....OO..",
]


def paint(img, rows, x0, y0, pal=PAL):
    px = img.load()
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch == ".":
                continue
            x, y = x0 + i, y0 + j
            if 0 <= x < img.width and 0 <= y < img.height:
                px[x, y] = hexc(pal[ch])


def lerp(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (255,)


BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def sky(img):
    """Вечернее небо: полосы с пиксельным размытием (dither) от синего к закатному."""
    stops = [(0, "#140c30"), (10, "#24164e"), (20, "#3c2370"), (28, "#6a2f84"), (34, "#b2477e"), (39, "#ec7a62"), (44, "#ffb15e")]
    px = img.load()
    cols = [(y, hexc(c)) for y, c in stops]
    for y in range(N):
        for x in range(N):
            # ступени по 2 пикселя, между ними шахматка Байера
            for k in range(len(cols) - 1):
                if cols[k][0] <= y < cols[k + 1][0] or k == len(cols) - 2:
                    a, b = cols[k], cols[k + 1]
                    break
            t = min(1, max(0, (y - a[0]) / max(1, b[0] - a[0])))
            levels = 3
            f = t * levels
            lo = int(f)
            frac = f - lo
            if BAYER[y % 4][x % 4] / 16 < frac:
                lo += 1
            px[x, y] = lerp(a[1], b[1], min(1, lo / levels))


def stars(img):
    px = img.load()
    rnd = random.Random(7)
    for _ in range(26):
        x, y = rnd.randrange(N), rnd.randrange(0, 26)
        c = "#c8c0ff" if rnd.random() < 0.6 else "#ffffff"
        if rnd.random() < 0.3:
            c = "#7a6ab8"
        px[x, y] = hexc(c)


BIG_STAR = [
    "......O......",
    ".....OLO.....",
    ".....OLO.....",
    "....OLXLO....",
    "OOOOLXXXLOOOO",
    "OLLXXXXXXXLLO",
    "OOOOLXXXLOOOO",
    "....OLXLO....",
    ".....OLO.....",
    ".....OLO.....",
    "......O......",
]


def hills(img):
    """Дальние холмы и лес силуэтом."""
    px = img.load()
    far = hexc("#4a2f6e")
    far_hi = hexc("#7a3f7e")
    near = hexc("#2a2552")
    for x in range(N):
        h1 = 37 + 2.5 * math.sin(x * 0.15 + 1) + 1.5 * math.sin(x * 0.37)
        for y in range(int(h1), N):
            px[x, y] = far_hi if y == int(h1) else far
    rnd = random.Random(3)
    # ёлки на горизонте
    for cx in list(range(-2, 20, 4)) + list(range(46, 68, 5)):
        hgt = rnd.randint(5, 9)
        base = 42
        for j in range(hgt):
            w = (j * 0.55) + 0.5
            y = base - hgt + j
            for x in range(int(cx - w), int(cx + w) + 1):
                if 0 <= x < N:
                    px[x, y] = near
        for y in range(base, 46):
            for x in range(cx - 4, cx + 5):
                if 0 <= x < N:
                    px[x, y] = near


def meadow(img):
    px = img.load()
    rim = hexc("#9ad25a")
    top = hexc("#5aa84a")
    mid = hexc("#3a8a48")
    low = hexc("#24603e")
    for x in range(N):
        h = 44 + 1.6 * math.sin(x * 0.11 + 0.4)
        for y in range(int(h), N):
            d = y - int(h)
            if d == 0:
                c = rim
            elif d < 6:
                c = top if BAYER[y % 4][x % 4] > d * 2 else mid
            elif d < 14:
                c = mid if BAYER[y % 4][x % 4] > (d - 6) * 2 else low
            else:
                c = low
            px[x, y] = c
    rnd = random.Random(11)
    dark = hexc("#1e4a34")
    light = hexc("#7ac85a")
    for _ in range(70):
        x, y = rnd.randrange(N), rnd.randrange(48, N)
        px[x, y] = dark
        if y - 1 >= 0:
            px[x, y - 1] = light if rnd.random() < 0.5 else dark
    for _ in range(14):
        x, y = rnd.randrange(N), rnd.randrange(50, N - 1)
        c = hexc(rnd.choice(["#ffb8dc", "#fee761", "#ffffff", "#f5555d"]))
        px[x, y] = c


def house(img, x0, y0):
    """Домик: черепичная крыша, бревенчатые стены, светящееся окно, труба."""
    W, Hh = 26, 25
    c = Image.new("RGBA", (W, Hh), (0, 0, 0, 0))
    px = c.load()
    o = hexc(OUT)
    R, r, Q = hexc("#c42430"), hexc("#891e2b"), hexc("#f5555d")
    K, k, J = hexc("#b86f50"), hexc("#743f39"), hexc("#e4a672")
    V, v = hexc("#fee761"), hexc("#ffc825")
    st, sd = hexc("#8e9ab4"), hexc("#4a5470")
    D, d = hexc("#5a2f2a"), hexc("#3f2832")
    # труба
    for y in range(1, 9):
        for x in range(17, 21):
            px[x, y] = o if x in (17, 20) or y == 1 else (st if x == 18 else sd)
    # крыша: трапеция
    roof_top, roof_bot = 4, 12
    for y in range(roof_top, roof_bot + 1):
        t = (y - roof_top) / (roof_bot - roof_top)
        half = 6 + t * 7
        xa, xb = round(12.5 - half), round(12.5 + half)
        for x in range(xa, xb + 1):
            if not (0 <= x < W):
                continue
            edge = x in (xa, xb) or y == roof_top
            if edge:
                px[x, y] = o
            else:
                # черепица рядами
                row = (y - roof_top) % 3
                if row == 0:
                    px[x, y] = r
                elif row == 1:
                    px[x, y] = Q if (x + y) % 5 == 0 else R
                else:
                    px[x, y] = R
    for x in range(0, W):
        px[x, roof_bot + 1] = o
    for x in range(1, W - 1):
        px[x, roof_bot] = r
    # стены
    for y in range(roof_bot + 2, Hh - 1):
        for x in range(2, W - 2):
            if x in (2, W - 3):
                px[x, y] = o
            else:
                plank = (y - roof_bot) % 3
                px[x, y] = k if plank == 0 else (J if (plank == 1 and x % 7 == 3) else K)
    # тень под крышей
    for x in range(3, W - 3):
        px[x, roof_bot + 2] = k
    # фундамент
    for x in range(1, W - 1):
        px[x, Hh - 1] = o
        px[x, Hh - 2] = sd if x % 3 == 0 else st
    px[1, Hh - 2] = o
    px[W - 2, Hh - 2] = o
    # дверь
    for y in range(roof_bot + 4, Hh - 2):
        for x in range(5, 11):
            px[x, y] = o if x in (5, 10) or y == roof_bot + 4 else (D if x < 9 else d)
    px[9, roof_bot + 8] = V
    # окно со светом
    for y in range(roof_bot + 4, roof_bot + 10):
        for x in range(14, 21):
            if x in (14, 20) or y in (roof_bot + 4, roof_bot + 9):
                px[x, y] = o
            elif x == 17 or y == roof_bot + 6:
                px[x, y] = k
            else:
                px[x, y] = V if (x + y) % 4 else v
    # окошко на крыше (чердак)
    for y in range(6, 10):
        for x in range(10, 15):
            px[x, y] = o if x in (10, 14) or y in (6, 9) else v
    img.alpha_composite(c, (x0, y0))
    return (x0 + 17, y0 + roof_bot + 7), (x0 + 12, y0 + 8)


def smoke(img, x, y):
    px = img.load()
    puffs = [(0, 0, 1.2), (-1, -3, 1.6), (-3, -6, 2), (-6, -9, 1.6)]
    for dx, dy, r in puffs:
        for yy in range(int(y + dy - r), int(y + dy + r) + 1):
            for xx in range(int(x + dx - r), int(x + dx + r) + 1):
                if (xx - x - dx) ** 2 + (yy - y - dy) ** 2 <= r * r and 0 <= xx < N and 0 <= yy < N:
                    px[xx, yy] = hexc("#b8a8d8") if yy < y + dy else hexc("#8a7ab0")


def shadow(img, cx, cy, rx, ry, k=0.6):
    px = img.load()
    for y in range(int(cy - ry), int(cy + ry) + 1):
        for x in range(int(cx - rx), int(cx + rx) + 1):
            if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1 and 0 <= x < N and 0 <= y < N:
                r, g, b, a = px[x, y]
                px[x, y] = (int(r * k), int(g * k), int(b * k), a)


def outline(layer):
    """Тёмный контур вокруг всего, что нарисовано на слое (как у спрайтов пака)."""
    px = layer.load()
    w, h = layer.size
    o = hexc(OUT)
    add = []
    for y in range(h):
        for x in range(w):
            if px[x, y][3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                xx, yy = x + dx, y + dy
                if 0 <= xx < w and 0 <= yy < h and px[xx, yy][3] and px[xx, yy] != o:
                    add.append((x, y))
                    break
    for x, y in add:
        px[x, y] = o


def hero():
    """Герой 24x32: голова со шляпой из HEAD, тело рисуется прямоугольниками."""
    layer = Image.new("RGBA", (26, 34), (0, 0, 0, 0))
    px = layer.load()
    c = {k: hexc(v) for k, v in PAL.items()}
    ox, oy = 1, 1

    def fill(x0, y0, x1, y1, k):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                px[ox + x, oy + y] = c[k]

    # рубашка
    fill(6, 19, 15, 24, "G")
    fill(6, 19, 6, 23, "I")
    fill(15, 19, 15, 24, "g")
    fill(6, 24, 15, 24, "g")
    fill(9, 19, 12, 19, "g")
    # левая рука вдоль тела
    fill(4, 19, 5, 21, "G")
    fill(4, 21, 4, 21, "g")
    fill(4, 22, 5, 23, "S")
    fill(4, 23, 4, 23, "s")
    # правая рука держит топор
    fill(16, 19, 17, 21, "G")
    fill(17, 21, 17, 21, "g")
    # штаны и ботинки
    fill(6, 25, 15, 27, "B")
    fill(6, 25, 6, 27, "b")
    fill(14, 25, 15, 27, "b")
    fill(6, 28, 9, 29, "W")
    fill(12, 28, 15, 29, "W")
    fill(6, 29, 9, 29, "w")
    fill(12, 29, 15, 29, "w")
    # шов между ног
    for y in range(26, 28):
        px[ox + 10, oy + y] = (0, 0, 0, 0)
        px[ox + 11, oy + y] = (0, 0, 0, 0)
    # голова поверх тела
    paint(layer, HEAD, ox, oy)
    outline(layer)
    # швы между частями
    for x in range(7, 15):
        px[ox + x, oy + 24] = c["g"]
    return layer


def glow(big, cx, cy, radius, color, strength):
    layer = Image.new("RGBA", big.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for i in range(12, 0, -1):
        r = radius * i / 12
        a = int(strength * (1 - i / 12) ** 1.6 * 255)
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=color + (a,))
    layer = layer.filter(ImageFilter.GaussianBlur(radius / 6))
    return Image.alpha_composite(big, layer) if False else ImageChops.screen(big.convert("RGB"), layer.convert("RGB")).convert("RGBA") if False else _add(big, layer)


def _add(base, layer):
    out = base.copy()
    out.alpha_composite(layer)
    return out


def main(path):
    img = Image.new("RGBA", (N, N))
    sky(img)
    stars(img)
    paint(img, BIG_STAR, 45, 4)
    hills(img)
    meadow(img)
    # домик слева, чуть дальше героя
    shadow(img, 15, 48, 14, 2.5, 0.65)
    window, chimney = house(img, 2, 24)
    smoke(img, 21, 22)
    # тропинка к двери
    px = img.load()
    for y in range(48, N):
        w = 2 + (y - 48) * 0.35
        cx = 10 + (y - 48) * 0.9
        for x in range(int(cx - w), int(cx + w) + 1):
            if 0 <= x < N:
                px[x, y] = hexc("#c8925a") if (x + y) % 6 else hexc("#a8744a")
    # герой с топором
    h = hero()
    hx, hy = 26, 27
    shadow(img, hx + 12, hy + 31, 9, 1.6, 0.55)
    axe = Image.new("RGBA", (16, 34), (0, 0, 0, 0))
    paint(axe, AXE, 2, 0)
    ap = axe.load()
    for y in range(11, 28):
        ap[3, y] = hexc(PAL["T"])
        ap[4, y] = hexc(PAL["t"])
    outline(axe)
    img.alpha_composite(axe, (hx + 16, hy + 2))
    img.alpha_composite(h, (hx, hy))
    # кулак поверх рукояти
    px = img.load()
    for x, y, k in ((hx + 18, hy + 23, "S"), (hx + 19, hy + 23, "S"), (hx + 20, hy + 23, "s"),
                    (hx + 18, hy + 24, "s"), (hx + 19, hy + 24, "S"), (hx + 20, hy + 24, "s")):
        px[x, y] = hexc(PAL[k])
    for x, y in ((hx + 17, hy + 23), (hx + 17, hy + 24), (hx + 21, hy + 23), (hx + 21, hy + 24),
                 (hx + 18, hy + 25), (hx + 19, hy + 25), (hx + 20, hy + 25), (hx + 18, hy + 22), (hx + 20, hy + 22)):
        px[x, y] = hexc(OUT)

    big = img.resize((N * SCALE, N * SCALE), Image.NEAREST)
    s = SCALE
    big = glow(big, 51.5 * s, 9.5 * s, 13 * s, (255, 236, 170), 0.55)
    big = glow(big, window[0] * s, window[1] * s, 9 * s, (255, 200, 90), 0.4)
    big.convert("RGB").save(path)
    print("ok", path)


if __name__ == "__main__":
    main(sys.argv[1])
