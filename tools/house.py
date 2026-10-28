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

T = 16      # пикселей в клетке
PT = 32     # точек в клетке
W, H = 19, 14
WALL_ROWS = 3
PART = 10   # столбец перегородки между комнатами
DOOR_ROWS = (7, 8, 9)
OUTLINE = (14, 7, 27, 255)

PC = ("Pixel Crawler - Free Pack 2", "Pixel Crawler - Free Pack")


def pc(src, *parts):
    return Image.open(os.path.join(src, *PC, *parts)).convert("RGBA")


def opaque(im):
    box = im.getchannel("A").getbbox()
    return im.crop(box) if box else im


# ================================================================ мебель

MAT.update({
    "beam": ("#2e1a10", "#4a2c1a", "#6e4426"),
    "brass": ("#7a4a10", "#c8902a", "#ffd870"),
    "glasstube": ("#24304a", "#3c5a8a", "#8ab4e8"),
    "board": ("#5a3418", "#8a5a30", "#b07a44"),
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
    """Доска для трофеев на стене гостиной: два ряда по три крючка."""
    c = Canvas(56, 42)
    c.rect(0, 0, 55, 41, "board")
    im = c.render()
    p = im.load()
    for x in range(2, 54):
        p[x, 2] = hexc("#c08850")
        p[x, 39] = hexc("#5a3418")
        p[x, 20] = hexc("#6e4426")
    for row in (5, 23):
        for i in range(3):
            x = 10 + i * 18
            p[x, row] = hexc("#c8902a")
            p[x, row + 1] = hexc("#7a4a10")
    return im


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
    ip = pc(src, "Environment", "Structures", "Buildings", "Interior", "Interior_Props_01.png")
    fu = pc(src, "Environment", "Props", "Static", "Furniture.png")
    wb = pc(src, "Environment", "Structures", "Stations", "Workbench", "Workbench.png")
    al = pc(src, "Environment", "Structures", "Stations", "Alchemy", "Alchemy_Table_01-Sheet.png")
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
    }
    return out


# ================================================================ стены и пол

FLOOR_TILES = {
    "wood": (16, 332, 64, 380),
    "stone": (96, 332, 144, 380),
    "parquet": (176, 332, 224, 380),
    "herring": (256, 332, 304, 380),
}

WALLS = {
    # обои: цвет, полоска; панель снизу
    "living": dict(paper=("#f0d8a8", "#e2c48e"), panel="board", pattern="stripes"),
    "kitchen": dict(paper=("#e8f0f4", "#b8d0dc"), panel="board", pattern="tiles"),
    "bedroom": dict(paper=("#b8d4ec", "#9cc0e0"), panel="board", pattern="dots"),
    "library": dict(paper=("#3e6a4a", "#335a3e"), panel="beam", pattern="stripes"),
    "cellar": dict(paper=("#7a7686", "#5e5a6a"), panel=None, pattern="bricks"),
    "workshop": dict(paper=("#8a5a30", "#6e4426"), panel=None, pattern="planks"),
    "observatory": dict(paper=("#2a2a5a", "#20204a"), panel="beam", pattern="stars"),
    "attic": dict(paper=("#a06a3a", "#86562e"), panel=None, pattern="planks"),
    "greenhouse": dict(paper=("#bfe6f4", "#9fd0e6"), panel="board", pattern="glass"),
    "potting": dict(paper=("#c8e8c0", "#a8d4a0"), panel="board", pattern="glass"),
}


def tile_floor(img, src, kind, x0, y0, x1, y1):
    walls = pc(src, "Environment", "Structures", "Buildings", "Interior", "Interior_Walls_01.png")
    tile = walls.crop(FLOOR_TILES[kind])
    tw, th = tile.size
    for y in range(y0, y1, th):
        for x in range(x0, x1, tw):
            part = tile.crop((0, 0, min(tw, x1 - x), min(th, y1 - y)))
            img.alpha_composite(part, (x, y))


def wall_face(img, theme, x0, x1):
    """Стена комнаты сверху: обои и панель, высотой WALL_ROWS клеток."""
    spec = WALLS[theme]
    px = img.load()
    h = WALL_ROWS * T
    base, alt = hexc(spec["paper"][0]), hexc(spec["paper"][1])
    pattern = spec["pattern"]
    panel_top = h - 12 if spec["panel"] else h
    for y in range(h):
        for x in range(x0, x1):
            c = base
            lx, ly = x - x0, y
            if pattern == "stripes" and (lx // 4) % 2 == 0:
                c = alt
            elif pattern == "tiles" and (lx % 8 == 0 or ly % 8 == 0):
                c = alt
            elif pattern == "dots" and lx % 8 == 3 and ly % 8 == 3:
                c = alt
            elif pattern == "bricks":
                row = ly // 6
                off = 0 if row % 2 else 6
                if ly % 6 == 5 or (lx + off) % 12 == 0:
                    c = alt
            elif pattern == "planks" and (lx % 10 == 0 or (ly * 7 + lx // 10 * 13) % 29 == 0):
                c = alt
            elif pattern == "stars" and (lx * 7 + ly * 13) % 47 == 0:
                c = hexc("#ffe27a")
            elif pattern == "glass" and (lx % 16 == 0 or ly % 16 == 0):
                c = hexc("#e8f6fc")
            if y >= panel_top:
                d, m, hi = (hexc(v) for v in MAT[spec["panel"]])
                c = hi if y == panel_top else (d if (lx % 12 == 0 or y == h - 1) else m)
            if y < 3:
                c = hexc("#4a2c1a") if y < 2 else hexc("#6e4426")
            px[x, y] = c
    # тень под потолком
    for x in range(x0, x1):
        r, g, b, a = px[x, 3]
        px[x, 3] = (r * 3 // 4, g * 3 // 4, b * 3 // 4, a)


def beam_v(img, x, y0, y1):
    """Вертикальная балка: боковая стена или перегородка (вид сверху)."""
    px = img.load()
    for y in range(y0, y1):
        for dx in range(T):
            c = hexc("#4a2c1a")
            if dx in (0, T - 1):
                c = OUTLINE
            elif dx in (1, 2):
                c = hexc("#6e4426")
            elif dx == T - 2:
                c = hexc("#2e1a10")
            px[x + dx, y] = c


def beam_h(img, x0, x1, y):
    px = img.load()
    for x in range(x0, x1):
        for dy in range(T):
            c = hexc("#4a2c1a")
            if dy in (0, T - 1):
                c = OUTLINE
            elif dy in (1, 2):
                c = hexc("#6e4426")
            px[x, y + dy] = c


# ================================================================ этажи

# Предметы: (спрайт, x, y, клетки-препятствия). x, y - точка опоры в клетках:
# x - центр по горизонтали, y - нижний край (0 - верх карты).
# Станции: (вид, x, y) - куда подойти. Места для украшений: (номер, x, y).

def cells(c0, r0, c1=None, r1=None):
    c1 = c0 if c1 is None else c1
    r1 = r0 if r1 is None else r1
    return [(c, r) for c in range(c0, c1 + 1) for r in range(r0, r1 + 1)]


FLOORS = {
    "homeGround": dict(
        floor="ground",
        rooms=(("living", "wood"), ("kitchen", "stone")),
        door=5,
        props=[
            ("hm_stairs_up", 2.0, 4.0, cells(1, 3, 2, 3)),
            ("hm_trophy_board", 4.8, 2.9, []),
            ("hm_fireplace", 8.3, 4.0, cells(7, 3, 9, 3)),
            ("hm_rug_green", 5.0, 9.6, []),
            ("hm_sofa", 5.0, 7.6, cells(4, 6, 5, 6)),
            ("hm_table_round", 5.0, 10.0, cells(4, 9, 5, 9)),
            ("hm_plant_big", 9.3, 6.0, cells(9, 5)),
            ("hm_stairs_down", 1.8, 13.0, cells(1, 12, 2, 12)),
            ("hm_doormat", 5.5, 13.0, []),
            ("hm_easel", 8.2, 12.8, cells(8, 12)),
            # кухня
            ("hm_range", 12.6, 4.0, cells(11, 3, 13, 3)),
            ("hm_counter", 16.0, 4.2, cells(15, 3, 17, 3)),
            ("hm_calendar_wall", 16.0, 1.9, []),
            ("hm_table_long", 14.5, 8.8, cells(13, 8, 15, 8)),
            ("hm_chair_back", 13.4, 8.0, []),
            ("hm_chair_back", 15.6, 8.0, []),
            ("hm_chair", 14.5, 10.4, []),
            ("hm_cupboard", 16.8, 12.9, cells(16, 12, 17, 12)),
            ("hm_plant", 11.6, 12.8, cells(11, 12)),
        ],
        stations=[("exit", 5.5, 13.5), ("up", 2.0, 4.7), ("down", 1.8, 11.6), ("trophies", 4.8, 3.7),
                  ("plan", 8.2, 11.9), ("stove", 12.6, 4.7), ("calendar", 16.0, 4.8)],
        decor_slots=[(0, 2.2, 8.0), (1, 8.5, 9.0), (2, 3.0, 11.6), (3, 11.8, 7.0), (4, 17.2, 8.2), (5, 12.4, 10.6)],
    ),
    "homeUpper": dict(
        floor="upper",
        rooms=(("bedroom", "parquet"), ("library", "herring")),
        props=[
            ("hm_stairs_down", 1.8, 13.0, cells(1, 12, 2, 12)),
            ("hm_window", 3.0, 2.3, []),
            ("hm_bed", 3.0, 6.4, cells(2, 3, 3, 5)),
            ("hm_wardrobe", 6.0, 4.0, cells(5, 3, 6, 3)),
            ("painting", 8.4, 2.0, []),
            ("rug", 5.2, 10.0, []),
            ("hm_plant_pink", 9.3, 12.8, cells(9, 12)),
            # библиотека
            ("bookshelf", 12.0, 4.0, cells(11, 3, 12, 3)),
            ("bookshelf", 13.4, 4.0, cells(13, 3)),
            ("bookshelf", 14.8, 4.0, cells(14, 3)),
            ("hm_stairs_up", 17.0, 4.0, cells(16, 3, 17, 3)),
            ("hm_table_big", 14.0, 8.6, cells(13, 8, 14, 8)),
            ("hm_chair_back", 14.0, 7.6, []),
            ("hm_lectern", 17.0, 9.4, cells(17, 8)),
            ("hm_plant", 11.6, 12.8, cells(11, 12)),
        ],
        stations=[("down", 1.8, 11.6), ("bed", 3.0, 6.9), ("wardrobe", 6.0, 4.7), ("desk", 14.0, 9.6),
                  ("lectern", 17.0, 10.1), ("up", 17.0, 4.7)],
        decor_slots=[(0, 2.0, 9.0), (1, 8.0, 7.0), (2, 7.8, 11.2), (3, 11.8, 6.0), (4, 17.2, 12.2), (5, 12.2, 10.6)],
    ),
    "homeBasement": dict(
        floor="basement",
        rooms=(("cellar", "stone"), ("workshop", "stone")),
        props=[
            ("hm_stairs_up", 2.0, 4.0, cells(1, 3, 2, 3)),
            ("hm_shelf", 5.0, 2.4, []),
            ("barrel_berries", 4.0, 4.0, cells(4, 3)),
            ("barrel_water", 5.0, 4.0, cells(5, 3)),
            ("barrel_berries", 6.0, 4.0, cells(6, 3)),
            ("hm_crate", 8.8, 6.0, cells(8, 5)),
            ("hm_crate", 8.8, 7.0, cells(8, 6)),
            ("hm_pot", 2.0, 12.8, cells(2, 12)),
            ("barrel_water", 7.5, 12.8, cells(7, 12)),
            # мастерская
            ("hm_workbench", 13.0, 4.2, cells(12, 3, 13, 3)),
            ("hm_hearth", 16.4, 4.0, cells(15, 3, 17, 3)),
            ("anvil", 14.0, 8.0, cells(14, 7)),
            ("hm_bucket", 11.6, 12.8, []),
        ],
        stations=[("up", 2.0, 4.7), ("pantry", 5.0, 4.7), ("workbench", 13.0, 4.9), ("anvil", 14.0, 8.6)],
        decor_slots=[(0, 2.0, 8.0), (1, 5.5, 9.5), (2, 7.8, 10.8), (3, 11.8, 7.0), (4, 17.2, 10.0), (5, 13.4, 11.6)],
    ),
    "homeAttic": dict(
        floor="attic",
        rooms=(("observatory", "wood"), ("attic", "wood")),
        props=[
            ("hm_stairs_down", 1.8, 13.0, cells(1, 12, 2, 12)),
            ("hm_window_stone", 5.0, 2.2, []),
            ("hm_telescope", 5.0, 7.6, cells(4, 6, 5, 6)),
            ("hm_display", 8.4, 4.0, cells(7, 3, 9, 3)),
            ("hm_rug_green", 5.0, 10.2, []),
            # чердак
            ("chest_anim", 12.0, 4.2, cells(12, 3)),
            ("hm_crate", 13.2, 4.0, cells(13, 3)),
            ("hm_cabinet", 15.0, 4.2, cells(14, 3, 15, 3)),
            ("hm_stairs_up", 17.0, 4.0, cells(16, 3, 17, 3)),
            ("hm_table_cloth", 14.5, 8.6, cells(14, 8)),
            ("hm_broom", 11.5, 12.8, []),
        ],
        stations=[("down", 1.8, 11.6), ("telescope", 5.0, 8.2), ("chest", 12.0, 4.9), ("map", 14.5, 9.6), ("up", 17.0, 4.7)],
        decor_slots=[(0, 2.0, 9.0), (1, 8.5, 7.5), (2, 8.5, 11.2), (3, 11.8, 7.5), (4, 17.2, 9.2), (5, 13.4, 12.0)],
    ),
    "homeGreenhouse": dict(
        floor="greenhouse",
        rooms=(("greenhouse", "parquet"), ("potting", "stone")),
        props=[
            ("hm_stairs_down", 1.8, 13.0, cells(1, 12, 2, 12)),
            ("hm_planter", 4.5, 4.2, cells(4, 3, 5, 3)),
            ("hm_planter", 4.5, 8.2, cells(4, 7, 5, 7)),
            ("hm_planter", 7.6, 8.2, cells(7, 7, 8, 7)),
            ("hm_plant_big", 8.5, 4.0, cells(8, 3)),
            ("hm_plant_fern", 4.2, 12.8, cells(4, 12)),
            ("hm_plant_pink", 9.3, 12.8, cells(9, 12)),
            # рассадная
            ("hm_alchemy", 13.0, 4.2, cells(12, 3, 13, 3)),
            ("hm_seed_tray", 16.0, 4.2, cells(15, 3, 16, 3)),
            ("hm_seed_tray", 14.5, 9.0, cells(14, 8, 15, 8)),
            ("hm_bucket", 17.2, 12.8, []),
            ("hm_plant", 11.6, 12.8, cells(11, 12)),
        ],
        stations=[("down", 1.8, 11.6), ("compost", 13.0, 4.9), ("seedlings", 16.0, 4.9)],
        decor_slots=[(0, 2.4, 8.0), (1, 6.0, 10.6), (2, 8.6, 11.0), (3, 11.8, 7.0), (4, 17.2, 8.2), (5, 13.0, 11.6)],
    ),
}

# Предметы на стене, которые рисуются кодом (календарь берётся из иконки).
EXTRA_WALL = {}


def build_floor(src, fid, spec):
    img = Image.new("RGBA", (W * T, H * T))
    (left, lfloor), (right, rfloor) = spec["rooms"]
    # пол
    tile_floor(img, src, lfloor, T, WALL_ROWS * T, PART * T, (H - 1) * T)
    tile_floor(img, src, rfloor, (PART + 1) * T, WALL_ROWS * T, (W - 1) * T, (H - 1) * T)
    # проём в перегородке - пол левой комнаты
    tile_floor(img, src, lfloor, PART * T, DOOR_ROWS[0] * T, (PART + 1) * T, (DOOR_ROWS[-1] + 1) * T)
    # стены
    wall_face(img, left, T, PART * T)
    wall_face(img, right, (PART + 1) * T, (W - 1) * T)
    beam_v(img, 0, 0, H * T)
    beam_v(img, (W - 1) * T, 0, H * T)
    beam_v(img, PART * T, 0, DOOR_ROWS[0] * T)
    beam_v(img, PART * T, (DOOR_ROWS[-1] + 1) * T, (H - 1) * T)
    beam_h(img, 0, W * T, (H - 1) * T)
    door = spec.get("door")
    if door is not None:
        # проём двери внизу: пол
        tile_floor(img, src, lfloor, door * T, (H - 1) * T, (door + 1) * T, H * T)
    # тень от стены на полу
    px = img.load()
    for x in range(T, (W - 1) * T):
        for dy, k in ((0, 0.62), (1, 0.75), (2, 0.88)):
            y = WALL_ROWS * T + dy
            r, g, b, a = px[x, y]
            px[x, y] = (int(r * k), int(g * k), int(b * k), a)

    # клетки
    grid = [["L"] * W for _ in range(H)]
    for r in range(H):
        for c in range(W):
            if r < WALL_ROWS or r == H - 1 or c in (0, W - 1):
                grid[r][c] = "B"
            if c == PART and r not in DOOR_ROWS:
                grid[r][c] = "B"
    if door is not None:
        grid[H - 1][door] = "L"
    props = []
    for name, x, y, block in spec["props"]:
        props.append([name, round(x * PT), round((H - y) * PT), 0])
        for c, r in block:
            grid[r][c] = "B"
    for name, x, y in spec.get("props_wall", []):
        props.append([name, round(x * PT), round((H - y) * PT), 0])
    stations = [[k, round(x * PT), round((H - y) * PT)] for k, x, y in spec["stations"]]
    slots = [[f"{spec['floor']}_{i}", round(x * PT), round((H - y) * PT)] for i, x, y in spec["decor_slots"]]
    data = dict(
        id=fid, w=W, h=H, cell=PT, edge="void",
        rows=["".join(row) for row in grid],
        base=[round((door + 0.5) * PT) if door is not None else 2 * PT, round(2.2 * PT)],
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
