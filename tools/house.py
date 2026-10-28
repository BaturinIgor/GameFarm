#!/usr/bin/env python3
"""Дом изнутри: этажи с комнатами, по которым ходит герой.

Каждый этаж - отдельная маленькая локация: стены и пол рисуются сюда же
(sp_ground_home*.png), мебель - спрайтами (их сохраняет sprites.py через props()),
а раскладка (layout_home*.json) говорит сцене, где стены, где мебель,
где станции (плита, кровать, лестницы) и места для украшений.

    python3 tools/house.py <папка с паками> <папка спрайтов> <папка раскладок>
"""
import json
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from handmade import MAT, Canvas, hexc  # noqa: E402
import interior  # noqa: E402  (дополняет MAT и даёт календарь)
from warm import warm  # noqa: E402

T = 16      # пикселей в клетке
PT = 32     # точек в клетке
W, H = 12, 14   # одна комната на этаж: ширина ровно в экран телефона
WALL_ROWS = 4   # задняя стена: на неё помещается высокая мебель
DOOR = (5, 6)   # проём входной двери внизу первого этажа
OUTLINE = (14, 7, 27, 255)

PC = ("Pixel Crawler - Free Pack 2", "Pixel Crawler - Free Pack")


def pc(src, *parts):
    return Image.open(os.path.join(src, *PC, *parts)).convert("RGBA")


def cf(src, *parts):
    return Image.open(os.path.join(src, "Cute_Fantasy", *parts)).convert("RGBA")


def opaque(im):
    box = im.getchannel("A").getbbox()
    return im.crop(box) if box else im


# ================================================================ мебель

MAT.update({
    "beam": ("#2e1a10", "#4a2c1a", "#6e4426"),
    "brass": ("#7a4a10", "#c8902a", "#ffd870"),
    "glasstube": ("#24304a", "#3c5a8a", "#8ab4e8"),
    "board": ("#5a3418", "#8a5a30", "#b07a44"),
    "flame": ("#b8320e", "#ff9a1f", "#ffe070"),
})


def stairs_up():
    """Лестница наверх у стены: ступени уходят в проём."""
    c = Canvas(32, 52)
    c.rect(0, 0, 31, 51, "beam")
    im = c.render()
    p = im.load()
    dark = hexc("#1a0e08")
    for y in range(2, 20):
        for x in range(3, 29):
            p[x, y] = dark
    step_hi, step, step_lo = hexc("#c08850"), hexc("#a06a3a"), hexc("#6e4426")
    for i in range(6):
        y0 = 20 + i * 5
        inset = max(0, 3 - i // 2)
        for x in range(3 + inset, 29 - inset):
            p[x, y0] = step_hi
            p[x, y0 + 1] = step
            p[x, y0 + 2] = step
            p[x, y0 + 3] = step_lo
            p[x, y0 + 4] = dark if i < 5 else step_lo
    for y in range(2, 51):
        p[2, y] = hexc("#8a5a30")
        p[29, y] = hexc("#8a5a30")
    return im


def stairs_down():
    """Проём в полу со ступенями вниз."""
    c = Canvas(34, 34)
    c.rect(0, 0, 33, 33, "beam")
    im = c.render()
    p = im.load()
    for y in range(3, 31):
        for x in range(3, 31):
            p[x, y] = hexc("#140a06")
    for i in range(5):
        y0 = 3 + i * 5
        shade = 140 - i * 22
        col = (shade + 40, shade, shade - 30, 255)
        for x in range(4, 30):
            for dy in range(3):
                p[x, y0 + dy] = col
        for x in range(4, 30):
            p[x, y0 + 3] = (shade // 2, shade // 3, shade // 4, 255)
    return im


def telescope():
    c = Canvas(30, 34)
    c.line(15, 20, 5, 33, "beam", 2)
    c.line(15, 20, 25, 33, "beam", 2)
    c.line(15, 20, 15, 33, "beam", 2)
    c.line(4, 18, 26, 6, "glasstube", 5)
    c.disc(15, 14, 3, "brass")
    im = c.render()
    p = im.load()
    for x, y in ((25, 5), (26, 6), (24, 4)):
        p[x, y] = hexc("#ffd870")
    return im


def easel():
    """Подставка с планом дома."""
    c = Canvas(24, 30)
    c.line(4, 29, 12, 2, "board", 2)
    c.line(20, 29, 12, 2, "board", 2)
    c.rect(2, 6, 21, 20, "paper")
    im = c.render()
    p = im.load()
    blue = hexc("#2f63b0")
    for x in range(6, 18):
        p[x, 16] = blue
    for y in range(10, 17):
        p[6, y] = blue
        p[17, y] = blue
    for i in range(6):
        p[6 + i, 10 - i // 2] = blue
        p[17 - i, 10 - i // 2] = blue
    for y in range(13, 17):
        p[11, y] = blue
        p[12, y] = blue
    return im


def lectern():
    """Пюпитр с книгой наследия: книга светится."""
    c = Canvas(22, 28)
    c.rect(8, 10, 13, 26, "board")
    c.rect(4, 25, 17, 27, "board")
    c.rect(1, 4, 20, 11, "beam")
    c.rect(3, 2, 18, 8, "paper")
    im = c.render()
    p = im.load()
    for y in range(2, 9):
        p[10, y] = hexc("#8a5a30")
    for x, y in ((6, 4), (7, 4), (13, 4), (14, 5), (6, 6), (14, 6)):
        p[x, y] = hexc("#a64dd6")
    return im


def trophy_board():
    """Полка для трофеев на стене гостиной: рамка, зелёное сукно и две полочки."""
    w, h = 56, 42
    im = Image.new("RGBA", (w, h))
    p = im.load()
    frame = [hexc(c) for c in ("#5a2f2a", "#743f39", "#91533b")]
    felt, felt_d = hexc("#3f7a52"), hexc("#336646")
    for y in range(h):
        for x in range(w):
            edge = x in (0, w - 1) or y in (0, h - 1)
            border = x < 3 or x > w - 4 or y < 3 or y > h - 4
            if edge:
                p[x, y] = OUTLINE
            elif border:
                p[x, y] = frame[2] if (y == 1 or x == 1) else (frame[0] if (y == h - 2 or x == w - 2) else frame[1])
            else:
                p[x, y] = felt_d if (x + y * 3) % 7 == 0 else felt
    # полочки: середина и низ
    for sy in (22, 38):
        for x in range(3, w - 3):
            p[x, sy - 1] = hexc("#e4a672")
            p[x, sy] = hexc("#b86f50")
            p[x, sy + 1] = hexc("#743f39")
    # латунная табличка сверху
    for x in range(22, 34):
        for y in range(4, 7):
            p[x, y] = hexc("#ffc825") if y == 4 else hexc("#c8902a")
    return im


def sconce():
    """Настенный светильник: латунный держатель и тёплый огонёк."""
    c = Canvas(10, 16)
    c.rect(4, 8, 5, 14, "brass")
    c.rect(2, 13, 7, 14, "brass")
    c.ellipse(4.5, 5.5, 3, 4.5, "flame")
    return c.render()


def cup():
    c = Canvas(14, 16)
    c.ellipse(7, 5, 6, 5, "gold")
    c.rect(6, 9, 7, 12, "gold")
    c.rect(3, 13, 10, 15, "gold")
    c.disc(1.5, 5, 1.5, "gold")
    c.disc(12.5, 5, 1.5, "gold")
    return c.render()


def star_plaque():
    c = Canvas(16, 16)
    c.disc(8, 8, 7.5, "beam")
    im = c.render()
    p = im.load()
    pts = [(8, 3), (9, 6), (12, 6), (10, 8), (11, 11), (8, 9), (5, 11), (6, 8), (4, 6), (7, 6)]
    from handmade import _inside
    for y in range(16):
        for x in range(16):
            if _inside(x + 0.5, y + 0.5, pts):
                p[x, y] = hexc("#ffc825")
    return im


def doormat():
    c = Canvas(28, 12)
    c.rect(0, 0, 27, 11, "red")
    im = c.render()
    p = im.load()
    for x in range(3, 25, 3):
        for y in range(2, 10):
            p[x, y] = hexc("#891e2b")
    return im


def seed_tray():
    """Ящик с рассадой для оранжереи."""
    c = Canvas(30, 18)
    c.rect(0, 6, 29, 17, "board")
    im = c.render()
    p = im.load()
    for x in range(3, 27, 5):
        for dy, col in ((0, "#33984b"), (1, "#5ac54f"), (2, "#33984b")):
            p[x, 4 + dy] = hexc(col)
            p[x + 1, 3 + dy] = hexc(col)
        p[x - 1, 5] = hexc("#1e6f50")
    return im


def props(src):
    """Спрайты мебели для sprites.py: имя -> картинка."""
    # Мебель Pixel Crawler перекрашена в тёплую палитру мира (tools/warm.py)
    ip = warm(pc(src, "Environment", "Structures", "Buildings", "Interior", "Interior_Props_01.png"))
    fu = warm(pc(src, "Environment", "Props", "Static", "Furniture.png"))
    wb = warm(pc(src, "Environment", "Structures", "Stations", "Workbench", "Workbench.png"))
    al = warm(pc(src, "Environment", "Structures", "Stations", "Alchemy", "Alchemy_Table_01-Sheet.png"))
    out = {
        "hm_range": opaque(ip.crop((176, 0, 224, 64))),
        "hm_stove": opaque(ip.crop((116, 0, 140, 48))),
        "hm_fireplace": opaque(ip.crop((382, 44, 434, 144))),
        "hm_hearth": opaque(ip.crop((272, 44, 322, 144))),
        "hm_counter": opaque(ip.crop((160, 224, 208, 258))),
        "hm_cupboard": opaque(ip.crop((176, 142, 224, 178))),
        "hm_table_long": opaque(ip.crop((0, 0, 64, 27))),
        "hm_table_round": opaque(ip.crop((80, 7, 112, 43))),
        "hm_table_cloth": opaque(ip.crop((7, 163, 41, 192))),
        "hm_chair": opaque(ip.crop((66, 3, 78, 27))),
        "hm_chair_back": opaque(ip.crop((67, 34, 78, 58))),
        "hm_stool_red": opaque(ip.crop((97, 61, 111, 80))),
        "hm_bench": opaque(ip.crop((7, 99, 41, 128))),
        "hm_bed": opaque(ip.crop((33, 293, 79, 347))),
        "hm_bed_single": opaque(ip.crop((1, 293, 31, 347))),
        "hm_sofa": opaque(ip.crop((80, 301, 125, 322))),
        "hm_window": opaque(ip.crop((64, 176, 92, 207))),
        "hm_window_stone": opaque(ip.crop((98, 176, 126, 208))),
        "hm_door": opaque(ip.crop((134, 178, 170, 224))),
        "hm_trapdoor": opaque(ip.crop((64, 256, 96, 288))),
        "hm_wolf": opaque(ip.crop((552, 8, 568, 25))),
        "hm_bear": opaque(ip.crop((584, 7, 600, 24))),
        "hm_sword": opaque(ip.crop((98, 261, 126, 270))),
        "hm_shield": opaque(ip.crop((129, 272, 143, 288))),
        "hm_menu": opaque(ip.crop((226, 260, 254, 283))),
        "hm_frame": opaque(ip.crop((194, 260, 222, 283))),
        "hm_shelf": opaque(ip.crop((0, 204, 48, 224))),
        "hm_plant_pink": opaque(ip.crop((17, 352, 31, 384))),
        "hm_plant": opaque(ip.crop((32, 360, 47, 384))),
        "hm_plant_big": opaque(ip.crop((48, 354, 64, 384))),
        "hm_plant_fern": opaque(ip.crop((64, 354, 80, 384))),
        "hm_rug_green": opaque(ip.crop((336, 336, 384, 384))),
        "hm_rug_moss": opaque(ip.crop((384, 336, 432, 384))),
        "hm_bath": opaque(ip.crop((128, 144, 178, 178))),
        "hm_bucket": opaque(ip.crop((146, 130, 158, 144))),
        "hm_broom": opaque(ip.crop((592, 336, 608, 366))),
        "hm_pot": opaque(ip.crop((455, 273, 473, 288))),
        "hm_crate": opaque(ip.crop((433, 273, 447, 288))),
        "hm_wardrobe": opaque(fu.crop((0, 46, 32, 96))),
        "hm_display": opaque(fu.crop((32, 48, 80, 82))),
        "hm_display_long": opaque(fu.crop((32, 84, 98, 114))),
        "hm_planter": opaque(fu.crop((32, 118, 80, 146))),
        "hm_table_big": opaque(fu.crop((0, 16, 48, 46))),
        "hm_cabinet": opaque(fu.crop((48, 24, 80, 46))),
        "hm_workbench": opaque(wb.crop((48, 66, 96, 112))),
        "hm_alchemy": opaque(al.crop((0, 32, 32, 64))),
        "hm_stairs_up": stairs_up(),
        "hm_stairs_down": stairs_down(),
        "hm_telescope": telescope(),
        "hm_easel": easel(),
        "hm_lectern": lectern(),
        "hm_trophy_board": trophy_board(),
        "hm_cup": cup(),
        "hm_star": star_plaque(),
        "hm_doormat": doormat(),
        "hm_seed_tray": seed_tray(),
        "hm_calendar_wall": interior.calendar(),
        "hm_sconce": sconce(),
    }
    # Стол с картой мира на чердаке
    table = out["hm_table_big"].copy()
    paper = Canvas(22, 14)
    paper.rect(1, 1, 20, 12, "paper")
    sheet = paper.render()
    sp = sheet.load()
    for x, y in ((6, 5), (7, 6), (8, 6), (12, 4), (13, 5), (14, 8), (15, 8), (9, 9), (10, 9)):
        sp[x, y] = hexc("#5aa06a")
    for x, y in ((15, 4), (16, 5)):
        sp[x, y] = hexc("#c42430")
    table.alpha_composite(sheet, ((table.width - 22) // 2, 3))
    out["hm_map_table"] = table
    # Коврики-пледы из Cute Fantasy: красный, розовый, синий, жёлтый
    blankets = cf(src, "Tiles", "Picnic_Blankets.png")
    for name, (qx, qy) in (("red", (0, 0)), ("pink", (48, 0)), ("blue", (0, 48)), ("yellow", (48, 48))):
        out[f"hm_rug_{name}"] = opaque(blankets.crop((qx, qy, qx + 48, qy + 48)))
    return out


# ================================================================ стены и пол

# Пол рисуется кодом в палитре мира: доски, паркет или плитка из Cute Fantasy.
FLOOR_STYLES = {
    # доски: основной, второй, шов, блик
    "honey": ("#c98d5a", "#bb7e4d", "#8a5434", "#dfa56c"),
    "oak": ("#a8704a", "#9a643f", "#6e4426", "#bf8558"),
}

WALLS = {
    # обои: основной цвет и узор; панель снизу (тёмный, средний, светлый) или None
    "living": dict(paper=("#f3dcae", "#e6c88e"), pattern="stripes", panel=("#743f39", "#a0603c", "#c88458")),
    "bedroom": dict(paper=("#bcd8ee", "#9fc2e2"), pattern="dots", panel=("#9a8a76", "#d8c8ae", "#f2e6d0")),
    "cellar": dict(paper=("#b4705a", "#8e5444"), pattern="bricks", panel=None),
    "attic": dict(paper=("#b07a4a", "#8e5e36"), pattern="planks", panel=None),
    "greenhouse": dict(paper=("#c4ecf8", "#e8f8fc"), pattern="glass", panel=("#3f7a52", "#5aa06a", "#8ccc8c")),
}


def plank_floor(img, x0, y0, x1, y1, style):
    """Половицы поперёк комнаты, швы вразбежку."""
    base, alt, seam, hi = (hexc(c) for c in FLOOR_STYLES[style])
    px = img.load()
    for y in range(y0, y1):
        row = (y - y0) // 5
        ly = (y - y0) % 5
        shift = (row * 23) % 40
        for x in range(x0, x1):
            lx = (x - x0 + shift) % 40
            c = base if row % 2 == 0 else alt
            if ly == 4 or lx == 0:
                c = seam
            elif ly == 0:
                c = hi
            elif (x * 7 + y * 13) % 53 == 0:
                c = seam
            px[x, y] = c


def parquet_floor(img, x0, y0, x1, y1):
    """Паркет ёлочкой: блоки 8x4 и 4x8 по очереди."""
    a, b, seam = hexc("#c99560"), hexc("#b5824f"), hexc("#8a5a34")
    px = img.load()
    for y in range(y0, y1):
        for x in range(x0, x1):
            lx, ly = (x - x0) % 16, (y - y0) % 16
            horiz = (lx < 8) == (ly < 8)
            if horiz:
                c = a if (ly % 8) < 4 else b
                if ly % 4 == 3 or lx % 8 == 0:
                    c = seam
            else:
                c = b if (lx % 8) < 4 else a
                if lx % 4 == 3 or ly % 8 == 0:
                    c = seam
            px[x, y] = c


def tile_floor(img, src, x0, y0, x1, y1, dark=1.0, tint=None):
    """Плитка из Cute Fantasy (песчаник), для кухни, подвала и оранжереи."""
    tile = cf(src, "Tiles", "Pavement_Tiles.png").crop((0, 0, 32, 32))
    if dark != 1.0 or tint:
        tp = tile.load()
        for y in range(32):
            for x in range(32):
                r, g, b, a = tp[x, y]
                if tint:
                    r, g, b = (r + tint[0]) // 2, (g + tint[1]) // 2, (b + tint[2]) // 2
                tp[x, y] = (int(r * dark), int(g * dark), int(b * dark), a)
    for y in range(y0, y1, 32):
        for x in range(x0, x1, 32):
            img.alpha_composite(tile.crop((0, 0, min(32, x1 - x), min(32, y1 - y))), (x, y))


def wall_face(img, theme, x0, x1):
    """Задняя стена: потолочная балка, обои, деревянная панель и плинтус."""
    spec = WALLS[theme]
    px = img.load()
    h = WALL_ROWS * T
    base, alt = hexc(spec["paper"][0]), hexc(spec["paper"][1])
    pattern = spec["pattern"]
    panel = spec["panel"]
    panel_top = h - 16 if panel else h - 3
    for y in range(h):
        for x in range(x0, x1):
            lx, ly = x - x0, y
            c = base
            if pattern == "stripes" and (lx // 4) % 2 == 0:
                c = alt
            elif pattern == "dots" and lx % 8 == 3 and ly % 8 == 3:
                c = alt
            elif pattern == "bricks":
                row = ly // 6
                off = 0 if row % 2 else 6
                if ly % 6 == 5 or (lx + off) % 12 == 0:
                    c = alt
            elif pattern == "planks" and (lx % 9 == 0 or (ly * 7 + lx // 9 * 13) % 31 == 0):
                c = alt
            elif pattern == "glass" and (lx % 16 in (0, 1) or ly % 16 in (0, 1)):
                c = hexc("#6e9a7a")
            elif pattern == "glass" and (lx + ly) % 16 < 3:
                c = alt
            if panel and panel_top <= y < h - 3:
                d, m, hi = (hexc(v) for v in panel)
                c = hi if y == panel_top else (d if lx % 12 == 0 else m)
            if y >= h - 3:
                c = hexc("#5a2f2a") if y < h - 1 else OUTLINE
            if y < 4:
                c = OUTLINE if y == 0 else (hexc("#5a2f2a") if y < 3 else hexc("#743f39"))
            px[x, y] = c
    # тень под балкой
    for x in range(x0, x1):
        for y, k in ((4, 0.72), (5, 0.86)):
            r, g, b, a = px[x, y]
            px[x, y] = (int(r * k), int(g * k), int(b * k), a)


def wall_side(img, x, y0, y1, inner_right):
    """Боковая стена сверху: тёмное дерево с кромкой к комнате."""
    px = img.load()
    for y in range(y0, y1):
        for dx in range(T):
            c = hexc("#5a2f2a")
            if dx == 0 or dx == T - 1:
                c = OUTLINE
            elif (dx == T - 2 and inner_right) or (dx == 1 and not inner_right):
                c = hexc("#91533b")
            elif (dx == T - 3 and inner_right) or (dx == 2 and not inner_right):
                c = hexc("#743f39")
            px[x + dx, y] = c


def wall_bottom(img, x0, x1, y):
    px = img.load()
    for x in range(x0, x1):
        for dy in range(T):
            c = hexc("#5a2f2a")
            if dy in (0, T - 1):
                c = OUTLINE
            elif dy == 1:
                c = hexc("#91533b")
            elif dy == 2:
                c = hexc("#743f39")
            px[x, y + dy] = c


def shade_floor(img):
    """Мягкие тени у стен и тёплый свет в середине комнаты."""
    px = img.load()
    fx0, fx1 = T, (W - 1) * T
    fy0, fy1 = WALL_ROWS * T, (H - 1) * T
    cx, cy = (fx0 + fx1) / 2, (fy0 + fy1) / 2
    for y in range(fy0, fy1):
        for x in range(fx0, fx1):
            r, g, b, a = px[x, y]
            k = 1.0
            d = y - fy0
            if d < 6:
                k *= (0.62, 0.7, 0.78, 0.86, 0.92, 0.97)[d]
            for dd in (x - fx0, fx1 - 1 - x):
                if dd < 3:
                    k *= (0.8, 0.88, 0.95)[dd]
            dist = ((x - cx) / (fx1 - fx0)) ** 2 + ((y - cy) / (fy1 - fy0)) ** 2
            k *= 1.06 - min(0.14, dist * 0.5)
            px[x, y] = (min(255, int(r * k)), min(255, int(g * k)), min(255, int(b * k)), a)


# ================================================================ комнаты

# Мебель: (спрайт, клетки (c0, r0, c1, r1)) - стоит на этих клетках, низ картинки по нижнему краю.
# Можно добавить сдвиг (dx, dy) в клетках третьим элементом.
# На стене: (спрайт, x, y) - центр по x и низ по y в клетках, без препятствий.
# Плоское на полу (ковры): (спрайт, x, y).
# Станции: (вид, x, y) - точка, к которой подходит герой; она должна быть на свободной клетке.
# Места для украшений: (x, y) - центр клетки у стены; украшение не пропускает героя.

FLOORS = {
    "homeGround": dict(
        floor="ground", theme="living", floor_style=("plank", "honey"),
        furniture=[
            ("hm_range", (1, 4, 3, 4)),
            ("hm_counter", (4, 4, 6, 4)),
            ("hm_plant_big", (10, 4, 10, 4)),
            ("hm_table_round", (2, 9, 3, 9)),
            ("hm_stool_red", (1, 9, 1, 9)),
            ("hm_stool_red", (4, 9, 4, 9)),
            ("hm_sofa", (8, 10, 10, 10)),
            ("hm_easel", (10, 6, 10, 6)),
        ],
        wall=[("hm_calendar_wall", 5.5, 2.9), ("hm_trophy_board", 8.5, 3.7), ("hm_sconce", 10.4, 2.6)],
        flat=[("hm_rug_red", 6.0, 9.0), ("hm_doormat", 6.0, 13.0)],
        stations=[("stove", 2.5, 5.6), ("calendar", 5.5, 5.6), ("trophies", 8.5, 4.6), ("plan", 9.3, 6.6),
                  ("exit", 6.0, 13.5)],
        slots=[(1.5, 6.5), (1.5, 11.5), (3.5, 12.5), (8.5, 12.5), (10.5, 12.5), (10.5, 8.5)],
        door=True,
    ),
    "homeUpper": dict(
        floor="upper", theme="bedroom", floor_style=("parquet",),
        furniture=[
            ("hm_bed", (1, 4, 3, 6)),
            ("hm_wardrobe", (4, 4, 5, 4)),
            ("bookshelf", (8, 4, 8, 4)),
            ("bookshelf", (9, 4, 9, 4)),
            ("hm_plant", (10, 4, 10, 4)),
            ("hm_chair_back", (9, 7, 9, 7)),
            ("hm_table_big", (8, 8, 10, 8)),
            ("hm_lectern", (1, 10, 1, 10)),
            ("hm_plant_pink", (10, 12, 10, 12)),
        ],
        wall=[("hm_window", 6.9, 3.4), ("painting", 2.4, 2.6), ("hm_sconce", 8.5, 2.7)],
        flat=[("hm_rug_blue", 5.0, 10.0)],
        stations=[("bed", 2.5, 7.6), ("wardrobe", 5.0, 5.6), ("desk", 9.5, 9.6), ("lectern", 2.4, 10.6)],
        slots=[(6.5, 4.6), (1.5, 8.5), (1.5, 12.5), (4.5, 12.5), (7.5, 12.5), (10.5, 6.0)],
    ),
    "homeBasement": dict(
        floor="basement", theme="cellar", floor_style=("tile", 0.82),
        furniture=[
            ("barrel_berries", (1, 4, 1, 4)),
            ("barrel_water", (2, 4, 2, 4)),
            ("barrel_berries", (3, 4, 3, 4)),
            ("hm_crate", (1, 6, 1, 6)),
            ("hm_workbench", (6, 4, 8, 4)),
            ("hm_stove", (10, 4, 10, 4)),
            ("anvil", (8, 8, 8, 8)),
            ("hm_pot", (1, 12, 1, 12)),
            ("hm_bucket", (10, 12, 10, 12)),
        ],
        wall=[("hm_shelf", 2.5, 2.8), ("hm_sconce", 4.9, 2.6), ("hm_sconce", 9.2, 2.6)],
        flat=[],
        stations=[("pantry", 2.5, 5.6), ("workbench", 7.5, 5.6), ("anvil", 8.5, 9.6)],
        slots=[(4.5, 4.6), (1.5, 9.0), (4.5, 12.5), (6.5, 12.5), (10.5, 7.0), (10.5, 10.0)],
    ),
    "homeAttic": dict(
        floor="attic", theme="attic", floor_style=("plank", "oak"),
        furniture=[
            ("hm_telescope", (2, 5, 3, 5)),
            ("hm_display", (5, 4, 7, 4)),
            ("chest_anim", (9, 4, 9, 4)),
            ("hm_crate", (10, 4, 10, 4)),
            ("hm_map_table", (5, 9, 7, 9)),
            ("hm_crate", (10, 8, 10, 8)),
            ("hm_broom", (1, 12, 1, 12)),
        ],
        wall=[("hm_window_stone", 2.5, 3.5), ("hm_sconce", 8.0, 2.6)],
        flat=[("hm_rug_yellow", 2.6, 9.6)],
        stations=[("telescope", 2.5, 6.6), ("chest", 9.5, 5.6), ("map", 6.0, 10.6)],
        slots=[(8.0, 4.6), (1.5, 8.5), (10.5, 10.5), (3.5, 12.5), (8.5, 12.5), (10.5, 12.5)],
    ),
    "homeGreenhouse": dict(
        floor="greenhouse", theme="greenhouse", floor_style=("tile", 1.0, (190, 230, 190)),
        furniture=[
            ("hm_planter", (1, 4, 3, 4)),
            ("hm_alchemy", (5, 4, 6, 4)),
            ("hm_planter", (8, 4, 10, 4)),
            ("hm_plant_big", (1, 7, 1, 7)),
            ("hm_plant_fern", (10, 7, 10, 7)),
            ("hm_seed_tray", (4, 9, 5, 9)),
            ("hm_seed_tray", (7, 9, 8, 9)),
            ("hm_bucket", (10, 12, 10, 12)),
        ],
        wall=[("hm_sconce", 4.0, 2.6), ("hm_sconce", 7.9, 2.6)],
        flat=[],
        stations=[("compost", 5.5, 5.6), ("seedlings", 6.0, 10.6)],
        slots=[(1.5, 10.0), (10.5, 10.0), (1.5, 12.5), (3.5, 12.5), (8.5, 12.5), (10.5, 5.6)],
    ),
}


def build_floor(src, fid, spec):
    img = Image.new("RGBA", (W * T, H * T))
    fx0, fx1, fy0, fy1 = T, (W - 1) * T, WALL_ROWS * T, (H - 1) * T
    style = spec["floor_style"]
    door = spec.get("door", False)
    floor_rect = (fx0, fy0, fx1, fy1 + (T if door else 0))
    if style[0] == "plank":
        plank_floor(img, *floor_rect, style[1])
    elif style[0] == "parquet":
        parquet_floor(img, *floor_rect)
    else:
        tile_floor(img, src, *floor_rect, dark=style[1], tint=style[2] if len(style) > 2 else None)
    shade_floor(img)
    wall_face(img, spec["theme"], fx0, fx1)
    wall_side(img, 0, 0, H * T, inner_right=True)
    wall_side(img, (W - 1) * T, 0, H * T, inner_right=False)
    wall_bottom(img, 0, W * T, (H - 1) * T)
    if door:
        # проём входной двери: пол и косяки
        if style[0] == "plank":
            plank_floor(img, DOOR[0] * T, fy1, (DOOR[-1] + 1) * T, H * T, style[1])
        else:
            tile_floor(img, src, DOOR[0] * T, fy1, (DOOR[-1] + 1) * T, H * T)
        px = img.load()
        for y in range(fy1, H * T):
            for dx in (0, 1):
                px[DOOR[0] * T + dx, y] = OUTLINE if dx == 0 else hexc("#91533b")
                px[(DOOR[-1] + 1) * T - 1 - dx, y] = OUTLINE if dx == 0 else hexc("#91533b")

    grid = [["L"] * W for _ in range(H)]
    for r in range(H):
        for c in range(W):
            if r < WALL_ROWS or r == H - 1 or c in (0, W - 1):
                grid[r][c] = "B"
    if door:
        for c in DOOR:
            grid[H - 1][c] = "L"

    props = []

    def at(x, y):
        return [round(x * PT), round((H - y) * PT)]

    for item in spec["furniture"]:
        name, (c0, r0, c1, r1) = item[0], item[1]
        dx, dy = item[2] if len(item) > 2 else (0, 0)
        for r in range(r0, r1 + 1):
            for c in range(c0, c1 + 1):
                assert grid[r][c] == "L", f"{fid}: {name} перекрывает ({c},{r})"
                grid[r][c] = "B"
        props.append([name, *at((c0 + c1 + 1) / 2 + dx, r1 + 1 + dy), 0])
    for name, x, y in spec["wall"] + spec["flat"]:
        props.append([name, *at(x, y), 0])

    def free(x, y):
        c, r = int(x), int(min(y, H - 0.01))
        return 0 <= c < W and 0 <= r < H and grid[r][c] == "L"

    stations = []
    for kind, x, y in spec["stations"]:
        assert free(x, y), f"{fid}: станция {kind} на занятой клетке ({x},{y})"
        stations.append([kind, *at(x, y)])
    slots = []
    for i, (x, y) in enumerate(spec["slots"]):
        assert free(x, y), f"{fid}: место {i} на занятой клетке ({x},{y})"
        for kind, sx, sy in spec["stations"]:
            assert abs(sx - x) + abs(sy - y) > 1.2, f"{fid}: место {i} вплотную к станции {kind}"
        slots.append([f"{spec['floor']}_{i}", *at(x, y)])

    # Все станции достижимы от точки появления, даже если на все места поставить украшения
    base = (6.0, 11.5)
    blocked = {(int(x), int(y)) for x, y in spec["slots"]}
    seen, todo = set(), [(int(base[0]), int(base[1]))]
    while todo:
        c, r = todo.pop()
        if (c, r) in seen or not (0 <= c < W and 0 <= r < H) or grid[r][c] != "L" or (c, r) in blocked:
            continue
        seen.add((c, r))
        todo += [(c + 1, r), (c - 1, r), (c, r + 1), (c, r - 1)]
    for kind, x, y in spec["stations"]:
        assert (int(x), int(min(y, H - 0.01))) in seen, f"{fid}: к станции {kind} не пройти"

    data = dict(
        id=fid, w=W, h=H, cell=PT, edge="void",
        rows=["".join(row) for row in grid],
        base=at(*base),
        gates=[], spots=[], props=props, border=[], farm=[],
        stations=stations, slots=slots,
    )
    return img, data


def main():
    src, sprites_dir, layouts_dir = sys.argv[1], sys.argv[2], sys.argv[3]
    for fid, spec in FLOORS.items():
        img, data = build_floor(src, fid, spec)
        img.save(os.path.join(sprites_dir, f"sp_ground_{fid}.png"))
        with open(os.path.join(layouts_dir, f"layout_{fid}.json"), "w") as f:
            json.dump(data, f, separators=(",", ":"))
        print(f"{fid}: {len(data['props'])} props, {len(data['stations'])} stations")


if __name__ == "__main__":
    main()
