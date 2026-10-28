#!/usr/bin/env python3
"""Генератор локаций: форма карты, вода, тропинки, точки ресурсов, декор и проходы.

Для каждой локации пишет:
  - layout_<id>.json (сетка клеток, точки ресурсов, декор, проходы) - в репозиторий, открыто;
  - sp_ground_<id>.png - земля, собранная из тайлов пака (в зашифрованный архив спрайтов).

Использование:
    python3 tools/world.py <папка с паками> <папка спрайтов> <папка layout>

Клетка = 16 пикселей тайла = 32 точки на экране (пиксель = 2 точки). Координаты в JSON - в точках,
ось Y направлена вверх (как в SpriteKit).
"""
import colorsys
import heapq
import json
import math
import os
import random
import sys

from PIL import Image

SRC = sys.argv[1]
SPRITES = sys.argv[2]
LAYOUTS = sys.argv[3]
CF = os.path.join(SRC, "Cute_Fantasy")
T = 16          # пикселей в клетке
PT = 32         # точек в клетке
os.makedirs(SPRITES, exist_ok=True)
os.makedirs(LAYOUTS, exist_ok=True)

LAND, WATER, VOID = "L", "W", "V"


def load(*parts):
    return Image.open(os.path.join(CF, *parts)).convert("RGBA")


def hexc(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


def hsv(p):
    return colorsys.rgb_to_hsv(p[0] / 255, p[1] / 255, p[2] / 255)


def lum(p):
    return 0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2]


def recolor(im, rules):
    """rules: список (условие(pixel) -> bool, рампа цветов). Цвета, попавшие под условие,
    раскладываются по рампе по яркости."""
    out = im.copy()
    px = out.load()
    colors = {px[x, y][:3] for y in range(im.height) for x in range(im.width) if px[x, y][3] > 0}
    mapping = {}
    for cond, ramp in rules:
        group = sorted([c for c in colors if c not in mapping and cond(c)], key=lum)
        if not group:
            continue
        lo, hi = lum(group[0]), lum(group[-1])
        stops = [hexc(c) for c in ramp]
        for c in group:
            t = 0.5 if hi == lo else (lum(c) - lo) / (hi - lo)
            f = t * (len(stops) - 1)
            i = min(int(f), len(stops) - 2)
            k = f - i
            a, b = stops[i], stops[i + 1]
            mapping[c] = tuple(round(a[j] + (b[j] - a[j]) * k) for j in range(3))
    for y in range(out.height):
        for x in range(out.width):
            p = px[x, y]
            if p[3] and p[:3] in mapping:
                px[x, y] = mapping[p[:3]] + (p[3],)
    return out


def is_green(c):
    h, s, v = hsv(c)
    return 0.15 < h < 0.55 and s > 0.2


def is_water(c):
    h, s, v = hsv(c)
    return 0.53 < h < 0.62 and s > 0.6


def is_dirt(c):
    h, s, v = hsv(c)
    return (h < 0.1 or h > 0.9) and s > 0.2 and v < 0.75


def is_sand(c):
    h, s, v = hsv(c)
    return h < 0.12 and s > 0.2 and v >= 0.7


def is_sand_any(c):
    h, s, v = hsv(c)
    return h < 0.12 and s > 0.2


def is_stone(c):
    h, s, v = hsv(c)
    return 0.55 < h < 0.7 and s < 0.5


# ================================================================ тайлсеты

class Tileset:
    """Набор переходов двух материалов (A и B) в схеме "двойной сетки":
    тайл выбирается по четырём углам. Берём блок 3x3 и блок 2x2 из листа
    и определяем, какие четверти тайла заняты материалом A."""

    def __init__(self, img, blocks, is_a, fills_a=None, fills_b=None, key_img=None):
        self.img = img
        self.tiles = {}
        key_img = key_img or img
        for (c0, r0, cols, rows) in blocks:
            for r in range(r0, r0 + rows):
                for c in range(c0, c0 + cols):
                    box = (c * T, r * T, (c + 1) * T, (r + 1) * T)
                    key = self.quadrants(key_img.crop(box), is_a)
                    self.tiles.setdefault(key, img.crop(box))
        self.fills_a = fills_a or ([self.tiles[(1, 1, 1, 1)]] if (1, 1, 1, 1) in self.tiles else [])
        self.fills_b = fills_b or ([self.tiles[(0, 0, 0, 0)]] if (0, 0, 0, 0) in self.tiles else [])
        # Диагональные случаи собираем из четвертей соседних тайлов.
        for key in [(1, 0, 0, 1), (0, 1, 1, 0)]:
            if key not in self.tiles:
                self.tiles[key] = self.compose(key)
        missing = [k for k in self.all_keys() if k not in self.tiles]
        if missing:
            raise SystemExit(f"tileset misses {missing}")

    @staticmethod
    def all_keys():
        return [(a, b, c, d) for a in (0, 1) for b in (0, 1) for c in (0, 1) for d in (0, 1)
                if (a, b, c, d) not in ((0, 0, 0, 0), (1, 1, 1, 1))]

    @staticmethod
    def quadrants(tile, is_a):
        px = tile.load()
        out = []
        for qy in (0, 1):
            for qx in (0, 1):
                n = 0
                for y in range(qy * 8 + 2, qy * 8 + 6):
                    for x in range(qx * 8 + 2, qx * 8 + 6):
                        if is_a(px[x, y]):
                            n += 1
                out.append(1 if n >= 8 else 0)
        return tuple(out)  # TL, TR, BL, BR

    def compose(self, key):
        tile = Image.new("RGBA", (T, T))
        for i, (qx, qy) in enumerate(((0, 0), (1, 0), (0, 1), (1, 1))):
            # Ищем тайл, где эта четверть и её соседи по сторонам такие же.
            want = key[i]
            best = None
            for k, t in self.tiles.items():
                if k[i] != want:
                    continue
                horiz = i ^ 1
                vert = i ^ 2
                score = (k[horiz] == key[horiz]) + (k[vert] == key[vert])
                if best is None or score > best[0]:
                    best = (score, t)
            tile.alpha_composite(best[1].crop((qx * 8, qy * 8, qx * 8 + 8, qy * 8 + 8)), (qx * 8, qy * 8))
        return tile


def alpha_a(p):
    return p[3] > 128


def tile_at(img, c, r):
    return img.crop((c * T, r * T, (c + 1) * T, (r + 1) * T))


# ---------------------------------------------------------------- биомы

GRASS2 = ["#134c4c", "#1e6f50", "#2a8953", "#33984b"]


def biome_rules(b):
    """Правила перекраски тайлов для биома."""
    return b.get("recolor", [])


BIOMES = {
    "meadow": dict(grass=2),
    "hills": dict(grass=3),
    "lake": dict(grass=1),
    "swamp": dict(grass=4, water=["#1d3a2c", "#2f5a40", "#4a7a52"], path=["#3a2a1e", "#5a4230", "#7a5a40"]),
    "desert": dict(grass=2, ground="sand",
                   recolor_grass=["#8a5a2e", "#b4783e", "#d09a56", "#e8bc78"],
                   path=["#a8703e", "#c88c50", "#dca66a"]),
    "snow": dict(grass=1, recolor_grass=["#4a5f7a", "#8aa2be", "#c4d6ea", "#eef4fc"],
                 water=["#7aa8cc", "#a8d0ec", "#d8f0ff"], bank=["#2e3e52", "#52687f", "#7a92ac"],
                 path=["#9fb4cc", "#bccde0", "#d4e2f0"]),
    "caves": dict(grass=4, recolor_grass=["#16101f", "#241c33", "#2f2643", "#3a3052"],
                  water=["#0a1430", "#16305e", "#2a4c8a"], bank=["#0b0812", "#17121f", "#231b2e"],
                  path=["#3c3354", "#4c4268", "#5c527a"], void="#05030a"),
    "island": dict(grass=2, ground="beach", water=["#0a88b0", "#16b4d4", "#6ff0ff"]),
    "volcano": dict(grass=4, recolor_grass=["#1a1212", "#2a1f1e", "#3a2c28", "#4c3a34"],
                    water=["#b8320e", "#ff7a1f", "#ffd060"], bank=["#0e0808", "#24140f", "#3c2016"],
                    path=["#4a3a36", "#5c4a44", "#6e5c54"]),
    "sky": dict(grass=1, recolor_grass=["#5a5aa8", "#8a8ad8", "#b0b4f4", "#d8dcff"],
                water=["#3a2a8a", "#5f50c8", "#9a8af0"], bank=["#6a4a8a", "#9a72b8", "#c8a2e0"],
                path=["#e8d8f0", "#f4e8f8", "#fff8ff"], void="#a8d4ff"),
    "garden": dict(grass=2, path=["#a89a8a", "#c8bcae", "#e0d6ca"]),
    "mine": dict(grass=3, recolor_grass=["#1e1610", "#2e2218", "#3e3020", "#4e3e2a"],
                 water=["#1a2e4a", "#2a4a70", "#4a70a0"], bank=["#0e0a06", "#1e160e", "#2e2216"],
                 path=["#5a4630", "#6e583e", "#82684a"], void="#0a0704"),
}


GRASS_PAL = {
    1: ["#193c3e", "#265c42", "#2a8953", "#3e8948"],
    2: ["#134c4c", "#1e6f50", "#2a8953", "#33984b"],
    3: ["#353e1e", "#637731", "#678128", "#7c963c"],
    4: ["#193c3e", "#37625b", "#37765d", "#3f886c"],
}
WATER_PAL = ["#006da8", "#0095e9", "#00cdf9"]
BANK_PAL = ["#3f2832", "#6d483b", "#9c6754"]
SAND_PAL = [["#b86f50", "#be7c60"], ["#e4a672"]]


def pal_map(b, grass=True, water=True, bank=True, path=False):
    """Точная таблица замены цветов для биома (одинаковая для всех листов)."""
    m = {}
    n = b["grass"]
    if grass and b.get("recolor_grass"):
        olds = sorted(GRASS_PAL[n], key=lambda h: lum(hexc(h)))
        for old, new in zip(olds, b["recolor_grass"]):
            m[hexc(old)] = hexc(new)
    if water and b.get("water"):
        for old, new in zip(WATER_PAL, b["water"]):
            m[hexc(old)] = hexc(new)
    if bank and b.get("bank"):
        for old, new in zip(BANK_PAL, b["bank"]):
            m[hexc(old)] = hexc(new)
    if path and b.get("path"):
        for olds, new in zip(SAND_PAL, b["path"]):
            for old in olds:
                m[hexc(old)] = hexc(new)
    return m


def apply_map(im, m):
    if not m:
        return im
    out = im.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            p = px[x, y]
            if p[3] and p[:3] in m:
                px[x, y] = m[p[:3]] + (p[3],)
    return out


def make_biome_tiles(name):
    b = BIOMES[name]
    n = b["grass"]
    grass_tiles = load("Tiles", "Grass", f"Grass_Tiles_{n}.png")
    water_tiles = load("Tiles", "Water", f"Water_Tile_{n}.png")
    middle = load("Tiles", "Grass", f"Grass_{n}_Middle.png")
    path_mid = load("Tiles", "Grass", "Path_Middle.png")
    path_dec = load("Tiles", "Grass", "Path_Decoration.png")
    water_dec = load("Tiles", "Water", "Water_Decoration.png")

    m = pal_map(b)
    pmap = pal_map(b, grass=False, water=False, bank=False, path=True)
    gt = apply_map(grass_tiles, m)
    wt = apply_map(water_tiles, m)
    mid = apply_map(middle, m)
    pm = apply_map(path_mid, pmap)
    pd = apply_map(path_dec, pmap)
    wd = apply_map(water_dec, m)
    grass_fills = [mid] * 12 + [tile_at(gt, 5, 9), tile_at(gt, 6, 9), tile_at(gt, 7, 9)]
    water_fills = [tile_at(wt, 1, 1)] * 24 + [tile_at(wd, i, 0) for i in range(3)]
    path_fills = [pm] * 10 + [tile_at(pd, i, 0) for i in range(3)]

    # Земля и вода: в Water_Tile блок 3x3 - трава с озером внутри, 2x2 - остров травы в воде.
    shore = Tileset(wt, [(0, 0, 3, 3), (0, 3, 2, 2)], lambda p: p[3] > 0 and is_green(p[:3]), key_img=water_tiles,
                    fills_a=grass_fills, fills_b=water_fills)
    # Трава поверх голой земли: в Grass_Tiles блок 3x3 с прозрачной серединой.
    over = Tileset(gt, [(0, 0, 3, 3), (0, 3, 2, 2)], alpha_a, key_img=grass_tiles,
                   fills_a=grass_fills, fills_b=path_fills)
    out = dict(shore=shore, over=over, void=b.get("void"), grass_fills=grass_fills)

    if b.get("ground") in ("sand", "beach"):
        beach_key = load("Tiles", "Beach", "Beach_Tiles.png").crop((0, 0, 80, 48))
        smap = pal_map(b, grass=False, bank=False)
        if name == "desert":
            smap.update({hexc("#be7c60"): hexc("#c88c50"), hexc("#e4a672"): hexc("#e8b47e")})
        beach = apply_map(beach_key, smap)
        sand_mid = apply_map(path_mid, {hexc("#e4a672"): hexc("#e8b47e")} if name == "desert" else {})
        sand_dec = apply_map(path_dec, {hexc("#e4a672"): hexc("#e8b47e"), hexc("#b86f50"): hexc("#c88c50")} if name == "desert" else {})
        sand_fills = [sand_mid] * 12 + [tile_at(sand_dec, i, 0) for i in range(3)]
        sea = Image.new("RGBA", (T, T), hexc(b["water"][1] if b.get("water") else "#0095e9") + (255,))
        # Песок и вода: блок 3x3 - песчаный остров (песок = A).
        out["shore"] = Tileset(beach, [(0, 0, 3, 3), (3, 0, 2, 2)], lambda p: p[3] > 0 and is_sand_any(p[:3]),
                               fills_a=sand_fills, fills_b=[sea] * 30 + [tile_at(wd, i, 0) for i in range(3)], key_img=beach_key)
        if name == "desert":
            # В пустыне "трава" - тёмный слежавшийся песок поверх светлого.
            dmap = {hexc(o): hexc(nw) for o, nw in zip(sorted(GRASS_PAL[n], key=lambda h: lum(hexc(h))), b["recolor_grass"])}
            dune = apply_map(grass_tiles, dmap)
            out["over"] = Tileset(dune, [(0, 0, 3, 3), (0, 3, 2, 2)], alpha_a, key_img=grass_tiles,
                                  fills_a=[apply_map(middle, dmap)] * 12, fills_b=sand_fills)
        else:
            out["over"] = Tileset(gt, [(0, 0, 3, 3), (0, 3, 2, 2)], alpha_a, key_img=grass_tiles,
                                  fills_a=grass_fills, fills_b=sand_fills)
    return out


def _waterish(p, b):
    c = p[:3]
    if is_water(c):
        return True
    if b.get("water"):
        ws = [hexc(x) for x in b["water"]]
        return any(abs(c[0] - w[0]) + abs(c[1] - w[1]) + abs(c[2] - w[2]) < 40 for w in ws)
    return False


# ================================================================ шум и формы

class Noise:
    def __init__(self, seed, scale):
        self.rng = random.Random(seed)
        self.scale = scale
        self.cache = {}

    def v(self, ix, iy):
        k = (ix, iy)
        if k not in self.cache:
            self.cache[k] = self.rng.random() * 2 - 1
        return self.cache[k]

    def at(self, x, y):
        x /= self.scale
        y /= self.scale
        ix, iy = math.floor(x), math.floor(y)
        fx, fy = x - ix, y - iy
        sx, sy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
        a = self.v(ix, iy) + (self.v(ix + 1, iy) - self.v(ix, iy)) * sx
        b = self.v(ix, iy + 1) + (self.v(ix + 1, iy + 1) - self.v(ix, iy + 1)) * sx
        return a + (b - a) * sy


def sdf(shape, x, y):
    """Положительное внутри. x, y в долях карты (y вверх)."""
    kind = shape[0]
    if kind == "ellipse":
        _, cx, cy, rx, ry = shape
        return 1 - math.hypot((x - cx) / rx, (y - cy) / ry)
    if kind == "rect":
        _, x0, y0, x1, y1 = shape
        return min(x - x0, x1 - x, y - y0, y1 - y) * 6
    raise ValueError(kind)


# ================================================================ узлы (как в Tools.swift)

NODE_RADIUS = {
    "tree": 18, "pine": 16, "palm": 16, "snowPine": 18, "glowTree": 20, "bush": 14, "appleTree": 18, "mushroom": 10,
    "carrot": 11, "cactus": 14, "bamboo": 14, "glowShroom": 12, "rock": 16, "boulder": 24, "coalOre": 20, "ironOre": 20,
    "goldOre": 20, "iceBlock": 18, "diamondOre": 20, "crystalOre": 22, "fishSpot": 14, "oasisFish": 14, "iceHole": 16,
    "willow": 18, "herbPatch": 12, "clayPit": 18, "swampFish": 14, "bananaPalm": 18, "pineapple": 14, "shells": 12,
    "oyster": 14, "coral": 18, "ashTree": 20, "fireFlower": 12, "sulfurVent": 20, "obsidianOre": 20, "rubyOre": 20,
    "lavaFish": 14, "cloudBush": 16, "goldenTree": 20, "skyTree": 20, "starRock": 20, "starPond": 14,
    "beehive": 14, "grapeVine": 20, "treasureChest": 16,
}
WATER_NODES = {"fishSpot", "oasisFish", "iceHole", "swampFish", "oyster", "lavaFish", "starPond"}
TALL = {"tree", "pine", "palm", "snowPine", "glowTree", "appleTree", "willow", "bananaPalm", "ashTree", "goldenTree",
        "skyTree", "bamboo", "grapeVine"}

# ================================================================ локации

# Стороны проходов: N (верх), S (низ), W (лево), E (право); pos - доля вдоль стороны
# (для N/S слева направо, для W/E снизу вверх).
GATES = {
    "meadow_hills": (("meadow", "W", 0.55), ("hills", "E", 0.42)),
    "meadow_lake": (("meadow", "E", 0.5), ("lake", "W", 0.38)),
    "meadow_desert": (("meadow", "N", 0.5), ("desert", "S", 0.5)),
    "lake_swamp": (("lake", "N", 0.62), ("swamp", "S", 0.5)),
    "swamp_desert": (("swamp", "W", 0.5), ("desert", "E", 0.46)),
    "hills_snow": (("hills", "N", 0.5), ("snow", "S", 0.45)),
    "desert_snow": (("desert", "W", 0.55), ("snow", "E", 0.5)),
    "snow_caves": (("snow", "N", 0.5), ("caves", "S", 0.5)),
    "swamp_island": (("swamp", "N", 0.45), ("island", "S", 0.5)),
    "caves_volcano": (("caves", "E", 0.55), ("volcano", "W", 0.5)),
    "island_volcano": (("island", "W", 0.55), ("volcano", "E", 0.5)),
    "volcano_sky": (("volcano", "N", 0.5), ("sky", "S", 0.5)),
    "meadow_garden": (("meadow", "S", 0.22), ("garden", "N", 0.5)),
}


def C(node, count, x, y, r):
    return (node, count, x, y, r)


LOCATIONS = {
    "meadow": dict(
        size=(40, 50), biome="meadow", seed=11, edge="forest", trees=["tree_oak_big", "tree_oak", "tree_fruit_big", "tree_birch_big"],
        land=[("ellipse", 0.5, 0.5, 0.44, 0.45), ("ellipse", 0.3, 0.3, 0.3, 0.25), ("ellipse", 0.72, 0.7, 0.26, 0.24)],
        water=[("ellipse", 0.76, 0.2, 0.09, 0.06), ("ellipse", 0.2, 0.7, 0.07, 0.06)],
        base=(0.5, 0.3), bare=[("ellipse", 0.3, 0.55, 0.06, 0.05)],
        clusters=[C("tree", 9, 0.22, 0.42, 5), C("tree", 8, 0.78, 0.55, 5), C("tree", 8, 0.32, 0.8, 5),
                  C("appleTree", 4, 0.66, 0.78, 3), C("bush", 6, 0.5, 0.5, 4), C("bush", 5, 0.8, 0.36, 3),
                  C("mushroom", 6, 0.14, 0.6, 3), C("rock", 6, 0.68, 0.24, 4), C("rock", 4, 0.4, 0.66, 3)],
        decor=dict(flowers=0.07, tufts=0.05, props=0.012), props=["bush_leafy", "bush_leafy2", "log", "stump_mossy", "rock1", "flowers_purple"],
    ),
    "hills": dict(
        size=(42, 52), biome="hills", seed=23, edge="forest", trees=["tree_spruce_big", "tree_spruce", "tree_autumn_big", "tree_birch_big"],
        land=[("ellipse", 0.45, 0.38, 0.4, 0.3), ("ellipse", 0.6, 0.7, 0.33, 0.27), ("ellipse", 0.85, 0.42, 0.14, 0.12)],
        holes=[("ellipse", 0.24, 0.72, 0.1, 0.1)],
        water=[("ellipse", 0.62, 0.86, 0.07, 0.05)],
        base=(0.72, 0.42), bare=[("ellipse", 0.38, 0.52, 0.12, 0.08), ("ellipse", 0.55, 0.2, 0.1, 0.06)],
        clusters=[C("pine", 8, 0.22, 0.3, 5), C("pine", 7, 0.72, 0.78, 5), C("tree", 5, 0.48, 0.86, 4),
                  C("rock", 7, 0.4, 0.52, 4), C("boulder", 5, 0.25, 0.5, 4), C("coalOre", 6, 0.58, 0.55, 4),
                  C("ironOre", 6, 0.35, 0.2, 4), C("carrot", 6, 0.55, 0.32, 3), C("carrot", 4, 0.86, 0.6, 2),
                  C("mushroom", 4, 0.82, 0.86, 3)],
        decor=dict(flowers=0.03, tufts=0.07, props=0.016), props=["boulder2", "rock2", "rock_mossy", "stump_small", "logs_pile", "bush_leafy3"],
    ),
    "lake": dict(
        size=(44, 54), biome="lake", seed=37, edge="forest", trees=["tree_oak_big", "tree_willow_big", "tree_fruit_big"],
        land=[("ellipse", 0.5, 0.5, 0.45, 0.46)],
        water=[("ellipse", 0.52, 0.56, 0.24, 0.18), ("ellipse", 0.24, 0.84, 0.08, 0.06), ("ellipse", 0.8, 0.2, 0.09, 0.07)],
        base=(0.3, 0.2), bare=[],
        clusters=[C("fishSpot", 5, 0.52, 0.56, 0), C("fishSpot", 3, 0.24, 0.84, 0), C("fishSpot", 3, 0.8, 0.2, 0),
                  C("bamboo", 7, 0.82, 0.48, 4), C("bamboo", 4, 0.5, 0.86, 3), C("appleTree", 5, 0.18, 0.46, 4),
                  C("tree", 5, 0.75, 0.82, 4), C("pine", 4, 0.12, 0.66, 3), C("mushroom", 5, 0.38, 0.3, 3),
                  C("rock", 4, 0.62, 0.22, 3), C("coalOre", 4, 0.86, 0.68, 3), C("ironOre", 3, 0.5, 0.12, 3)],
        decor=dict(flowers=0.06, tufts=0.05, props=0.01, lilies=0.05, reeds=0.25), props=["bush_leafy", "log_mossy", "rock_mossy", "flowers_purple"],
    ),
    "swamp": dict(
        size=(44, 54), biome="swamp", seed=89, edge="forest", trees=["tree_willow_big", "tree_willow", "tree_spruce_big"],
        land=[("ellipse", 0.5, 0.5, 0.45, 0.46), ("ellipse", 0.15, 0.5, 0.15, 0.12)],
        water=[("ellipse", 0.28, 0.66, 0.12, 0.09), ("ellipse", 0.72, 0.3, 0.12, 0.08), ("ellipse", 0.62, 0.72, 0.07, 0.05),
               ("ellipse", 0.36, 0.26, 0.06, 0.05)],
        base=(0.52, 0.48), bare=[("ellipse", 0.2, 0.2, 0.1, 0.07)],
        clusters=[C("swampFish", 4, 0.28, 0.66, 0), C("swampFish", 4, 0.72, 0.3, 0), C("willow", 7, 0.8, 0.6, 5),
                  C("willow", 5, 0.15, 0.4, 4), C("herbPatch", 7, 0.42, 0.82, 4), C("herbPatch", 5, 0.56, 0.18, 3),
                  C("clayPit", 6, 0.2, 0.2, 4), C("bamboo", 5, 0.86, 0.84, 3), C("mushroom", 6, 0.66, 0.86, 3),
                  C("ironOre", 4, 0.12, 0.78, 3), C("coalOre", 3, 0.86, 0.14, 3)],
        decor=dict(flowers=0.02, tufts=0.09, props=0.016, lilies=0.08, reeds=0.35), props=["log_mossy", "stump_mossy", "rock_mossy", "bush_leafy2", "fern"],
    ),
    "desert": dict(
        size=(46, 56), biome="desert", seed=41, edge="dunes",
        trees=["boulder", "boulder2", "boulder3", "boulder4"],
        land=[("ellipse", 0.5, 0.5, 0.46, 0.45), ("ellipse", 0.5, 0.2, 0.3, 0.2)],
        water=[("ellipse", 0.52, 0.62, 0.1, 0.07)],
        base=(0.5, 0.36), bare=[("ellipse", 0.25, 0.3, 0.14, 0.1), ("ellipse", 0.74, 0.76, 0.14, 0.09), ("ellipse", 0.8, 0.3, 0.08, 0.1)],
        clusters=[C("oasisFish", 5, 0.52, 0.62, 0), C("palm", 7, 0.52, 0.62, 7), C("palm", 4, 0.84, 0.88, 3),
                  C("cactus", 8, 0.2, 0.32, 5), C("cactus", 6, 0.78, 0.76, 5), C("boulder", 5, 0.8, 0.32, 4),
                  C("goldOre", 6, 0.22, 0.78, 4), C("ironOre", 4, 0.86, 0.55, 3), C("rock", 4, 0.5, 0.16, 3),
                  C("coalOre", 3, 0.14, 0.56, 3)],
        decor=dict(flowers=0.0, tufts=0.02, props=0.01), props=["rock1", "rock3", "stone_small1", "boulder4"],
    ),
    "snow": dict(
        size=(46, 56), biome="snow", seed=53, edge="forest", trees=["tree_frost_big", "tree_frost", "tree_frost_big"],
        land=[("ellipse", 0.5, 0.5, 0.45, 0.46)],
        ice=[("ellipse", 0.64, 0.42, 0.15, 0.11)],
        base=(0.4, 0.22), bare=[("ellipse", 0.2, 0.62, 0.08, 0.06)],
        clusters=[C("iceHole", 5, 0.64, 0.42, 4), C("snowPine", 8, 0.2, 0.4, 5), C("snowPine", 7, 0.78, 0.82, 5),
                  C("iceBlock", 7, 0.26, 0.72, 4), C("diamondOre", 5, 0.52, 0.8, 4), C("ironOre", 4, 0.86, 0.18, 3),
                  C("goldOre", 3, 0.12, 0.88, 3), C("boulder", 3, 0.42, 0.6, 3)],
        decor=dict(flowers=0.0, tufts=0.02, props=0.012), props=["rock2", "stone_small2", "stump_small"],
    ),
    "caves": dict(
        size=(44, 54), biome="caves", seed=67, edge="void", trees=["boulder", "boulder2", "boulder3"],
        land=[("ellipse", 0.32, 0.36, 0.28, 0.3), ("ellipse", 0.68, 0.66, 0.3, 0.3), ("ellipse", 0.6, 0.28, 0.24, 0.18),
              ("ellipse", 0.3, 0.74, 0.2, 0.16)],
        holes=[("ellipse", 0.5, 0.5, 0.06, 0.05), ("ellipse", 0.78, 0.42, 0.05, 0.05)],
        water=[("ellipse", 0.24, 0.2, 0.08, 0.06), ("ellipse", 0.74, 0.84, 0.07, 0.05)],
        base=(0.5, 0.2), bare=[("ellipse", 0.4, 0.5, 0.1, 0.08)],
        clusters=[C("crystalOre", 6, 0.25, 0.42, 5), C("crystalOre", 6, 0.75, 0.7, 5), C("diamondOre", 6, 0.66, 0.34, 4),
                  C("goldOre", 5, 0.3, 0.74, 4), C("glowShroom", 7, 0.5, 0.62, 4), C("glowShroom", 4, 0.84, 0.86, 3),
                  C("glowTree", 4, 0.14, 0.26, 3), C("coalOre", 4, 0.86, 0.5, 3), C("boulder", 4, 0.5, 0.86, 3)],
        decor=dict(flowers=0.0, tufts=0.0, props=0.02), props=["crystal_amethyst", "rock3", "stone_small2", "rubble"],
    ),
    "island": dict(
        size=(48, 56), biome="island", seed=97, edge="sea", trees=[],
        land=[("ellipse", 0.5, 0.52, 0.36, 0.36), ("ellipse", 0.32, 0.3, 0.16, 0.14), ("ellipse", 0.7, 0.74, 0.16, 0.12)],
        grass=[("ellipse", 0.52, 0.56, 0.24, 0.24)],
        water=[("ellipse", 0.36, 0.56, 0.07, 0.06)],
        base=(0.5, 0.3), bare=[],
        clusters=[C("oyster", 5, 0.5, 0.52, 0), C("oyster", 3, 0.36, 0.56, 0), C("coral", 6, 0.78, 0.44, 4),
                  C("bananaPalm", 7, 0.55, 0.62, 6), C("palm", 5, 0.26, 0.26, 3), C("pineapple", 6, 0.44, 0.72, 4),
                  C("shells", 7, 0.32, 0.4, 5), C("shells", 4, 0.72, 0.22, 3), C("crystalOre", 3, 0.14, 0.5, 2)],
        decor=dict(flowers=0.03, tufts=0.04, props=0.008), props=["rock1", "stone_small1", "bush_leafy3"],
    ),
    "volcano": dict(
        size=(46, 56), biome="volcano", seed=103, edge="lava", trees=[],
        land=[("ellipse", 0.5, 0.5, 0.42, 0.42), ("ellipse", 0.5, 0.18, 0.2, 0.14)],
        water=[("ellipse", 0.3, 0.62, 0.09, 0.07), ("ellipse", 0.72, 0.32, 0.08, 0.06), ("ellipse", 0.56, 0.8, 0.06, 0.04)],
        base=(0.5, 0.26), bare=[("ellipse", 0.66, 0.6, 0.1, 0.08)],
        clusters=[C("lavaFish", 4, 0.3, 0.62, 0), C("lavaFish", 3, 0.72, 0.32, 0), C("obsidianOre", 7, 0.72, 0.6, 5),
                  C("rubyOre", 5, 0.26, 0.84, 4), C("sulfurVent", 6, 0.24, 0.34, 4), C("ashTree", 6, 0.58, 0.88, 4),
                  C("fireFlower", 7, 0.46, 0.46, 4), C("goldOre", 4, 0.86, 0.82, 3)],
        decor=dict(flowers=0.0, tufts=0.0, props=0.014), props=["rock3", "rubble", "stone_small2", "boulder4"],
    ),
    "sky": dict(
        size=(46, 56), biome="sky", seed=131, edge="void", trees=[],
        land=[("ellipse", 0.5, 0.42, 0.34, 0.3), ("ellipse", 0.3, 0.76, 0.18, 0.14), ("ellipse", 0.72, 0.78, 0.16, 0.13),
              ("rect", 0.47, 0.0, 0.53, 0.2)],
        water=[("ellipse", 0.5, 0.48, 0.1, 0.08)],
        base=(0.5, 0.24), bare=[],
        bridges=[((0.42, 0.62), (0.32, 0.7)), ((0.6, 0.62), (0.7, 0.72))],
        clusters=[C("starPond", 5, 0.5, 0.48, 0), C("skyTree", 6, 0.26, 0.42, 4), C("goldenTree", 5, 0.74, 0.4, 4),
                  C("cloudBush", 6, 0.72, 0.8, 3), C("starRock", 5, 0.3, 0.78, 3), C("crystalOre", 3, 0.5, 0.68, 2),
                  C("cloudBush", 3, 0.5, 0.3, 2)],
        decor=dict(flowers=0.05, tufts=0.02, props=0.006), props=["bush_cloud", "stone_small2"],
    ),
    "garden": dict(
        size=(36, 44), biome="garden", seed=7, edge="hedge", trees=["tree_oak_big", "tree_cherry", "tree_peach"],
        land=[("rect", 0.1, 0.08, 0.9, 0.92), ("rect", 0.45, 0.0, 0.55, 0.2)],
        water=[("ellipse", 0.72, 0.68, 0.12, 0.08)],
        base=(0.5, 0.82), bare=[("rect", 0.47, 0.12, 0.53, 0.86), ("rect", 0.18, 0.47, 0.82, 0.53),
                                ("ellipse", 0.5, 0.5, 0.1, 0.08)],
        clusters=[C("appleTree", 4, 0.25, 0.75, 3), C("appleTree", 4, 0.25, 0.28, 3), C("goldenTree", 2, 0.78, 0.28, 2),
                  C("bush", 6, 0.36, 0.62, 3), C("beehive", 4, 0.82, 0.42, 2), C("fishSpot", 4, 0.72, 0.68, 0),
                  C("herbPatch", 6, 0.62, 0.22, 3), C("grapeVine", 3, 0.36, 0.38, 2)],
        decor=dict(flowers=0.1, tufts=0.03, props=0.01), props=["flowers_purple", "flowers_red", "bush_leafy", "basket"],
        fixed_props=[("fountain_anim", 0.5, 0.5)],
    ),
    "goldMine": dict(
        size=(34, 40), biome="mine", seed=211, edge="void", trees=["boulder", "boulder3"],
        land=[("ellipse", 0.5, 0.5, 0.42, 0.42), ("ellipse", 0.5, 0.12, 0.14, 0.12)],
        holes=[("ellipse", 0.32, 0.6, 0.05, 0.05), ("ellipse", 0.7, 0.42, 0.05, 0.05)],
        water=[("ellipse", 0.72, 0.74, 0.07, 0.05)],
        base=(0.5, 0.18), bare=[],
        clusters=[C("goldOre", 12, 0.5, 0.55, 9), C("diamondOre", 4, 0.3, 0.8, 4), C("rubyOre", 3, 0.75, 0.55, 3),
                  C("crystalOre", 3, 0.25, 0.4, 3), C("coalOre", 5, 0.62, 0.3, 4)],
        decor=dict(flowers=0.0, tufts=0.0, props=0.02), props=["rubble", "rock3", "crystal_gold"],
    ),
    "treasureIsland": dict(
        size=(36, 40), biome="island", seed=223, edge="sea", trees=[],
        land=[("ellipse", 0.5, 0.5, 0.36, 0.34)],
        grass=[("ellipse", 0.5, 0.56, 0.18, 0.16)],
        base=(0.5, 0.28), bare=[],
        clusters=[C("treasureChest", 7, 0.5, 0.55, 8), C("shells", 7, 0.5, 0.45, 9), C("palm", 5, 0.5, 0.6, 5),
                  C("pineapple", 4, 0.4, 0.66, 3), C("coral", 3, 0.75, 0.4, 3), C("oyster", 4, 0.5, 0.15, 8)],
        decor=dict(flowers=0.02, tufts=0.03, props=0.008), props=["rock1", "stone_small1"],
    ),
    "luckyMeadow": dict(
        size=(34, 40), biome="meadow", seed=227, edge="forest", trees=["tree_oak_big", "tree_birch_big", "tree_fruit_big"],
        land=[("ellipse", 0.5, 0.5, 0.42, 0.42)],
        base=(0.5, 0.22), bare=[],
        clusters=[C("goldenTree", 4, 0.5, 0.62, 6), C("appleTree", 4, 0.3, 0.45, 4), C("bush", 6, 0.7, 0.45, 4),
                  C("herbPatch", 6, 0.5, 0.4, 5), C("mushroom", 5, 0.3, 0.72, 3), C("tree", 4, 0.72, 0.75, 3)],
        decor=dict(flowers=0.14, tufts=0.04, props=0.01), props=["flowers_purple", "flowers_red", "bush_leafy"],
    ),
}

DECOR_FLOWERS = [f"flowers{i}" for i in range(18)]
DECOR_TUFTS = ["tuft1", "tuft2"]


def gates_of(loc):
    out = []
    for gid, ends in GATES.items():
        for i, (l, side, pos) in enumerate(ends):
            if l == loc:
                other = ends[1 - i][0]
                out.append((gid, other, side, pos))
    return out


# ================================================================ генерация

class Grid:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.t = [[VOID] * w for _ in range(h)]
        self.bare = [[False] * w for _ in range(h)]
        self.grass = [[True] * w for _ in range(h)]   # для острова: трава поверх песка
        self.ice = [[False] * w for _ in range(h)]
        self.blocked = [[False] * w for _ in range(h)]  # проходимо ли (деревья края, ворота)

    def inside(self, c, r):
        return 0 <= c < self.w and 0 <= r < self.h

    def get(self, c, r):
        c = min(max(c, 0), self.w - 1)
        r = min(max(r, 0), self.h - 1)
        return self.t[r][c]

    def walkable(self, c, r):
        return self.inside(c, r) and (self.t[r][c] == LAND or self.ice[r][c]) and not self.blocked[r][c]


def norm_to_cell(g, x, y):
    return int(x * g.w), int((1 - y) * g.h)


def cell_to_pt(g, c, r):
    return ((c + 0.5) * PT, (g.h - r - 0.5) * PT)


def gate_cells(g, side, pos):
    """Клетка у края карты и направление внутрь."""
    if side == "N":
        return int(pos * (g.w - 1)), 0, (0, 1)
    if side == "S":
        return int(pos * (g.w - 1)), g.h - 1, (0, -1)
    if side == "W":
        return 0, int((1 - pos) * (g.h - 1)), (1, 0)
    return g.w - 1, int((1 - pos) * (g.h - 1)), (-1, 0)


def astar(g, start, goal, cost):
    openq = [(0, start)]
    came = {start: None}
    best = {start: 0}
    while openq:
        _, cur = heapq.heappop(openq)
        if cur == goal:
            break
        for dc, dr in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (cur[0] + dc, cur[1] + dr)
            if not g.inside(*n):
                continue
            k = cost(n)
            if k is None:
                continue
            nb = best[cur] + k
            if nb < best.get(n, 1e18):
                best[n] = nb
                came[n] = cur
                heapq.heappush(openq, (nb + abs(n[0] - goal[0]) + abs(n[1] - goal[1]), n))
    if goal not in came:
        return []
    path = []
    cur = goal
    while cur:
        path.append(cur)
        cur = came[cur]
    return path[::-1]


def generate(lid, spec):
    W, H = spec["size"]
    g = Grid(W, H)
    rng = random.Random(spec["seed"])
    noise = Noise(spec["seed"] * 7 + 1, 4.0)
    noise2 = Noise(spec["seed"] * 13 + 5, 1.7)

    def field(shapes, c, r, amp=0.18):
        x = (c + 0.5) / W
        y = 1 - (r + 0.5) / H
        d = max(sdf(s, x, y) for s in shapes)
        return d + amp * (noise.at(c, r) * 0.75 + noise2.at(c, r) * 0.25)

    # Суша
    for r in range(H):
        for c in range(W):
            if field(spec["land"], c, r) > 0:
                g.t[r][c] = LAND
    for r in range(H):
        for c in range(W):
            for hole in spec.get("holes", []):
                x, y = (c + 0.5) / W, 1 - (r + 0.5) / H
                if sdf(hole, x, y) + 0.25 * noise2.at(c + 50, r) > 0:
                    g.t[r][c] = VOID
    # Края карты всегда за пределами
    for r in range(H):
        for c in range(W):
            if c < 2 or r < 2 or c >= W - 2 or r >= H - 2:
                g.t[r][c] = VOID

    gates = gates_of(lid)
    base = norm_to_cell(g, *spec["base"])
    gate_info = []

    # Коридоры к проходам: прямой отрезок от края внутрь, пока не упрёмся в сушу.
    for gid, other, side, pos in gates:
        c0, r0, (dc, dr) = gate_cells(g, side, pos)
        c, r = c0, r0
        steps = 0
        while steps < max(W, H):
            for k in range(-2, 3):
                cc, rr = (c + k, r) if dr else (c, r + k)
                if g.inside(cc, rr):
                    g.t[rr][cc] = LAND
            steps += 1
            if steps > 6 and all(g.get(c + dc * j, r + dr * j) == LAND for j in range(1, 4)):
                break
            c += dc
            r += dr
        inner = (c0 + dc * 5, r0 + dr * 5)
        barrier = (c0 + dc * 2, r0 + dr * 2)
        gate_info.append(dict(id=gid, to=other, side=side, edge=(c0, r0), barrier=barrier, inner=inner, dir=(dc, dr)))

    # Мостики (небесные острова)
    for (a, b) in spec.get("bridges", []):
        ca, ra = norm_to_cell(g, *a)
        cb, rb = norm_to_cell(g, *b)
        n = max(abs(cb - ca), abs(rb - ra)) + 1
        for i in range(n + 1):
            t = i / n
            c = round(ca + (cb - ca) * t)
            r = round(ra + (rb - ra) * t)
            for dc in (-1, 0, 1):
                for dr in (-1, 0, 1):
                    if g.inside(c + dc, r + dr):
                        g.t[r + dr][c + dc] = LAND

    # Вода внутри суши
    for r in range(H):
        for c in range(W):
            if g.t[r][c] != LAND:
                continue
            if spec.get("water") and field(spec["water"], c, r, 0.12) > 0:
                g.t[r][c] = WATER
            if spec.get("ice") and field(spec["ice"], c, r, 0.12) > 0:
                g.t[r][c] = WATER
                g.ice[r][c] = True

    # Площадка склада всегда суша
    for r in range(base[1] - 4, base[1] + 5):
        for c in range(base[0] - 5, base[0] + 6):
            if g.inside(c, r) and (c - base[0]) ** 2 + (r - base[1]) ** 2 <= 22:
                g.t[r][c] = LAND
                g.ice[r][c] = False

    # Убираем одиночные клетки и диагональные стыки, которые плохо рисуются.
    for _ in range(3):
        for r in range(1, H - 1):
            for c in range(1, W - 1):
                t = g.t[r][c]
                same = sum(g.t[r + dr][c + dc] == t for dc, dr in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                if same <= 1:
                    counts = {}
                    for dc, dr in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        k = g.t[r + dr][c + dc]
                        counts[k] = counts.get(k, 0) + 1
                    g.t[r][c] = max(counts, key=counts.get)
                    g.ice[r][c] = any(g.ice[r + dr][c + dc] for dc, dr in ((1, 0), (-1, 0), (0, 1), (0, -1))) and g.t[r][c] == WATER
        for r in range(H - 1):
            for c in range(W - 1):
                a, b, cc, d = g.t[r][c], g.t[r][c + 1], g.t[r + 1][c], g.t[r + 1][c + 1]
                if a == d and b == cc and a != b:
                    # Диагональ: заполняем сушей.
                    if a == LAND:
                        g.t[r][c + 1] = LAND
                        g.t[r + 1][c] = LAND
                    else:
                        g.t[r][c] = LAND
                        g.t[r + 1][c + 1] = LAND

    # Остров: трава только в центре, по краям песок
    if spec.get("grass") is not None:
        for r in range(H):
            for c in range(W):
                g.grass[r][c] = field(spec["grass"], c, r, 0.15) > 0

    # Тропинки: от склада к проходам и к группам ресурсов
    def path_cost(n):
        c, r = n
        if g.t[r][c] != LAND:
            return None
        near_water = any(g.get(c + dc, r + dr) != LAND for dc in (-1, 0, 1) for dr in (-1, 0, 1))
        return 1 + (6 if near_water else 0) + (noise.at(c * 2.3, r * 2.3) + 1) * 2.2

    gate_targets = [gi["inner"] for gi in gate_info]
    trail_targets = []
    seen = []
    for node, count, x, y, rad in spec["clusters"]:
        if node in WATER_NODES:
            continue
        cc = norm_to_cell(g, x, y)
        if any(abs(cc[0] - s[0]) + abs(cc[1] - s[1]) < 10 for s in seen):
            continue
        seen.append(cc)
        trail_targets.append(cc)
    trail_targets.sort(key=lambda t: abs(t[0] - base[0]) + abs(t[1] - base[1]))
    path_cells = set()
    for tgt in gate_targets + trail_targets[: spec.get("trails", 3)]:
        is_gate = tgt in gate_targets
        tgt = nearest_land(g, tgt)
        if tgt is None:
            continue
        path = astar(g, base, tgt, path_cost)
        for c, r in path[: (len(path) if is_gate else max(0, len(path) - 3))]:
            for dc, dr in ((0, 0), (1, 0), (0, 1), (1, 1)) if is_gate else ((0, 0),):
                path_cells.add((c + dc, r + dr))
    for gi in gate_info:
        c0, r0 = gi["edge"]
        dc, dr = gi["dir"]
        for j in range(0, 7):
            for k in (-1, 0, 1):
                cc, rr = (c0 + dc * j + (k if dr else 0), r0 + dr * j + (k if dc else 0))
                path_cells.add((cc, rr))
    for shape in spec.get("bare", []):
        for r in range(H):
            for c in range(W):
                if field([shape], c, r, 0.1) > 0:
                    path_cells.add((c, r))
    for r in range(base[1] - 3, base[1] + 4):
        for c in range(base[0] - 4, base[0] + 5):
            if (c - base[0]) ** 2 * 0.8 + (r - base[1]) ** 2 <= 10:
                path_cells.add((c, r))
    for c, r in path_cells:
        if g.inside(c, r) and g.t[r][c] == LAND:
            g.bare[r][c] = True
    # Голая земля не должна касаться воды (иначе нет подходящих тайлов).
    for r in range(H):
        for c in range(W):
            if g.bare[r][c] and any(g.get(c + dc, r + dr) != LAND for dc in (-1, 0, 1) for dr in (-1, 0, 1)):
                g.bare[r][c] = False

    # Край: деревья или камни (непроходимо), или пустота/вода.
    edge = spec["edge"]

    # Достижимые клетки от склада
    reach = set()
    stack = [base]
    while stack:
        c, r = stack.pop()
        if (c, r) in reach or not g.inside(c, r) or not g.walkable(c, r):
            continue
        reach.add((c, r))
        stack.extend([(c + 1, r), (c - 1, r), (c, r + 1), (c, r - 1)])

    # Точки ресурсов
    spots = []
    gate_zone = [gi["barrier"] for gi in gate_info] + [gi["inner"] for gi in gate_info]
    base_pt = cell_to_pt(g, *base)

    def free_for(node, p):
        rad = NODE_RADIUS[node]
        for (n2, q) in spots:
            gap = max(48, NODE_RADIUS[n2] + rad + 24)
            if math.hypot(p[0] - q[0], p[1] - q[1]) < gap:
                return False
        return True

    sea = spec["edge"] in ("sea", "lava")

    def candidates(node, center, rad):
        cands = []
        for r in range(H):
            for c in range(W):
                if node in WATER_NODES:
                    t = g.t[r][c]
                    if not (t == WATER or (sea and t == VOID)):
                        continue
                    if g.ice[r][c]:
                        # Лунки - на льду, в пределах озера.
                        if math.hypot(c - center[0], r - center[1]) > max(rad, 1) + 3:
                            continue
                    else:
                        # Рыба - у самого берега, чтобы до неё дотянуться с суши.
                        if not any((c + dc, r + dr) in reach for dc, dr in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                            continue
                        if math.hypot(c - center[0], r - center[1]) > max(rad, 12):
                            continue
                    cands.append((c, r))
                else:
                    if (c, r) not in reach or g.bare[r][c]:
                        continue
                    if math.hypot(c - center[0], r - center[1]) > rad:
                        continue
                    if any(abs(c - z[0]) <= 3 and abs(r - z[1]) <= 3 for z in gate_zone):
                        continue
                    if math.hypot(c - base[0], r - base[1]) < 5:
                        continue
                    if node in TALL and any(not g.walkable(c + dc, r) for dc in (-1, 1)):
                        continue
                    cands.append((c, r))
        rng.shuffle(cands)
        # Ближние к центру группы - в первую очередь.
        cands.sort(key=lambda p: math.hypot(p[0] - center[0], p[1] - center[1]) // max(2, rad * 0.6))
        return cands

    for node, count, x, y, rad in spec["clusters"]:
        center = norm_to_cell(g, x, y)
        made = 0
        tried = set()
        for grow in (0, 3, 6, 10):
            if made >= count:
                break
            for c, r in candidates(node, center, rad + grow):
                if made >= count:
                    break
                if (c, r) in tried:
                    continue
                tried.add((c, r))
                px, py = cell_to_pt(g, c, r)
                px += rng.uniform(-7, 7)
                py += rng.uniform(-7, 7)
                if not free_for(node, (px, py)):
                    continue
                spots.append((node, (round(px), round(py))))
                made += 1
        if made < count:
            print(f"  {lid}: {node} {made}/{count}")

    # Крупный декор (спрайты) и деревья по краю
    props = []
    occupied = [(q, NODE_RADIUS[n]) for n, q in spots]

    def clear(p, r=22):
        return all(math.hypot(p[0] - q[0], p[1] - q[1]) > r + rq for q, rq in occupied)

    for name, x, y in spec.get("fixed_props", []):
        c, r = norm_to_cell(g, x, y)
        p = cell_to_pt(g, c, r)
        props.append((name, (round(p[0]), round(p[1])), 1))
        occupied.append((p, 50))

    for r in range(H):
        for c in range(W):
            if (c, r) not in reach or g.bare[r][c]:
                continue
            if rng.random() < spec["decor"].get("props", 0):
                p = cell_to_pt(g, c, r)
                p = (p[0] + rng.uniform(-12, 12), p[1] + rng.uniform(-12, 12))
                if clear(p, 30) and math.hypot(c - base[0], r - base[1]) > 5 and \
                        not any(abs(c - z[0]) <= 3 and abs(r - z[1]) <= 3 for z in gate_zone):
                    props.append((rng.choice(spec["props"]), (round(p[0]), round(p[1])), 0))
                    occupied.append((p, 18))

    border = []
    if edge in ("forest", "dunes", "hedge") and spec.get("trees"):
        for r in range(-1, H + 2):
            for c in range(-1, W + 1):
                if g.inside(c, r) and g.t[r][c] != VOID:
                    continue
                # Расстояние до проходимой суши (в клетках)
                d = min((abs(c - cc) + abs(r - rr) for cc in range(c - 4, c + 5) for rr in range(r - 4, r + 5)
                         if g.inside(cc, rr) and g.t[rr][cc] != VOID), default=99)
                if d > 4:
                    continue
                density = 0.85 if d <= 2 else 0.45
                if rng.random() > density:
                    continue
                p = cell_to_pt(g, c, r)
                p = (p[0] + rng.uniform(-14, 14), p[1] + rng.uniform(-14, 14))
                name = rng.choice(spec["trees"])
                border.append((name, (round(p[0]), round(p[1]))))
        for r in range(H):
            for c in range(W):
                if g.t[r][c] == VOID:
                    g.blocked[r][c] = True

    # Мелкий декор, запекаемый в землю
    flat = []
    for r in range(H):
        for c in range(W):
            p = cell_to_pt(g, c, r)
            if g.t[r][c] == LAND and not g.bare[r][c] and (spec["edge"] != "sea" or g.grass[r][c]):
                if rng.random() < spec["decor"].get("flowers", 0):
                    flat.append((rng.choice(DECOR_FLOWERS), p))
                elif rng.random() < spec["decor"].get("tufts", 0):
                    flat.append((rng.choice(DECOR_TUFTS), p))
            elif g.t[r][c] == WATER and not g.ice[r][c]:
                shore = any(g.get(c + dc, r + dr) == LAND for dc, dr in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                if not shore and rng.random() < spec["decor"].get("lilies", 0):
                    flat.append((rng.choice(["lily", "lily", "lily_pink"]), p))
            if g.t[r][c] == LAND and not g.bare[r][c]:
                shore = any(g.get(c + dc, r + dr) == WATER and not g.ice[min(max(r + dr, 0), H - 1)][min(max(c + dc, 0), W - 1)]
                            for dc, dr in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                if shore and rng.random() < spec["decor"].get("reeds", 0):
                    q = (p[0] + rng.uniform(-8, 8), p[1] + rng.uniform(-6, 6))
                    if clear(q, 14):
                        props.append((rng.choice(["cattail", "cattail2", "reed"]), (round(q[0]), round(q[1])), 0))

    return dict(grid=g, base=base, gates=gate_info, spots=spots, props=props, border=border, flat=flat, reach=reach)


def nearest_land(g, cell):
    c0, r0 = cell
    best = None
    for r in range(g.h):
        for c in range(g.w):
            if g.t[r][c] == LAND:
                d = abs(c - c0) + abs(r - r0)
                if best is None or d < best[0]:
                    best = (d, (c, r))
    return best[1] if best else None


# ================================================================ рисование земли

def render_ground(lid, spec, gen, tiles, sprite_dir):
    g = gen["grid"]
    W, H = g.w, g.h
    img = Image.new("RGBA", (W * T, H * T), (0, 0, 0, 255))
    rng = random.Random(spec["seed"] + 99)
    edge = spec["edge"]
    biome = BIOMES[spec["biome"]]
    void_color = biome.get("void")
    if edge == "lava":
        void_color = None

    def corner_land(c, r):
        t = g.get(c, r)
        if t == LAND:
            return True
        if t == VOID:
            return edge in ("forest", "dunes", "hedge")
        return False

    def corner_ice(c, r):
        cc = min(max(c, 0), W - 1)
        rr = min(max(r, 0), H - 1)
        return g.ice[rr][cc]

    shore = tiles["shore"]
    over = tiles["over"]
    void_tiles = tiles.get("void_set")
    # Двойная сетка: тайл (i, j) накрывает центры клеток (i-1, j-1)...(i, j).
    for j in range(H + 1):
        for i in range(W + 1):
            corners = [(i - 1, j - 1), (i, j - 1), (i - 1, j), (i, j)]
            key = tuple(1 if corner_land(c, r) else 0 for c, r in corners)
            x, y = i * T - T // 2, j * T - T // 2
            ice = any(corner_ice(c, r) for c, r in corners)
            vset = shore
            if any(g.get(c, r) == VOID for c, r in corners) and edge == "void" and void_tiles:
                vset = void_tiles
            if ice and tiles.get("ice_set"):
                vset = tiles["ice_set"]
            if key == (1, 1, 1, 1):
                tile = rng.choice(vset.fills_a)
            elif key == (0, 0, 0, 0):
                tile = rng.choice(vset.fills_b)
            else:
                tile = vset.tiles[key]
            img.alpha_composite(tile, (x, y)) if x >= 0 and y >= 0 else paste_clip(img, tile, x, y)

    # Голая земля и трава поверх неё
    for j in range(H + 1):
        for i in range(W + 1):
            corners = [(i - 1, j - 1), (i, j - 1), (i - 1, j), (i, j)]
            if not all(g.get(c, r) == LAND or (edge in ("forest", "dunes", "hedge") and g.get(c, r) == VOID) for c, r in corners):
                continue

            def is_bare(c, r):
                cc = min(max(c, 0), W - 1)
                rr = min(max(r, 0), H - 1)
                if g.t[rr][cc] != LAND:
                    return False
                if edge == "sea":
                    return g.bare[rr][cc] or not g.grass[rr][cc]
                return g.bare[rr][cc]

            key = tuple(0 if is_bare(c, r) else 1 for c, r in corners)
            if key == (1, 1, 1, 1):
                if edge == "sea" and spec.get("grass"):
                    paste_clip(img, rng.choice(over.fills_a), i * T - T // 2, j * T - T // 2)
                continue
            x, y = i * T - T // 2, j * T - T // 2
            paste_clip(img, rng.choice(over.fills_b), x, y)
            if key != (0, 0, 0, 0):
                paste_clip(img, over.tiles[key], x, y)

    # Мелкий декор
    for name, (x, y) in gen["flat"]:
        path = os.path.join(sprite_dir, f"sp_{name}.png")
        if not os.path.exists(path):
            continue
        im = Image.open(path).convert("RGBA")
        px_x = int(x / PT * T - im.width / 2)
        px_y = int((H * PT - y) / PT * T - im.height / 2)
        paste_clip(img, im, px_x, px_y)
    return img


def paste_clip(dst, src, x, y):
    if x >= 0 and y >= 0 and x + src.width <= dst.width and y + src.height <= dst.height:
        dst.alpha_composite(src, (x, y))
        return
    sx0, sy0 = max(0, -x), max(0, -y)
    sx1, sy1 = min(src.width, dst.width - x), min(src.height, dst.height - y)
    if sx1 <= sx0 or sy1 <= sy0:
        return
    dst.alpha_composite(src.crop((sx0, sy0, sx1, sy1)), (x + sx0, y + sy0))


# ================================================================ главное

def build_tiles(biome_name, edge):
    tiles = make_biome_tiles(biome_name)
    b = BIOMES[biome_name]
    n = b["grass"]
    raw = load("Tiles", "Water", f"Water_Tile_{n}.png")
    if biome_name == "snow":
        # Замёрзшее озеро: тот же переход, но вода - лёд.
        m = pal_map(b, water=False)
        m.update({hexc(o): hexc(nw) for o, nw in zip(WATER_PAL, ["#9ac8e8", "#c8e6f8", "#eaf8ff"])})
        ice = apply_map(raw, m)
        tiles["ice_set"] = Tileset(ice, [(0, 0, 3, 3), (0, 3, 2, 2)], lambda p: p[3] > 0 and is_green(p[:3]),
                                   fills_a=tiles["grass_fills"], fills_b=[tile_at(ice, 1, 1)], key_img=raw)
    if edge == "void" and b.get("void"):
        m = pal_map(b, water=False)
        m.update({hexc(o): hexc(b["void"]) for o in WATER_PAL})
        vimg = apply_map(raw, m)
        tiles["void_set"] = Tileset(vimg, [(0, 0, 3, 3), (0, 3, 2, 2)], lambda p: p[3] > 0 and is_green(p[:3]),
                                    fills_a=tiles["grass_fills"], fills_b=[Image.new("RGBA", (T, T), hexc(b["void"]) + (255,))],
                                    key_img=raw)
    return tiles


def export(lid, spec, gen):
    g = gen["grid"]
    rows = []
    for r in range(g.h):
        row = []
        for c in range(g.w):
            t = g.t[r][c]
            if t == WATER and g.ice[r][c]:
                ch = "I"
            elif t == LAND and g.blocked[r][c]:
                ch = "B"
            elif t == LAND:
                ch = "P" if g.bare[r][c] else "L"
            elif t == WATER:
                ch = "W"
            else:
                ch = "V"
            row.append(ch)
        rows.append("".join(row))
    gates = []
    for gi in gen["gates"]:
        gates.append(dict(id=gi["id"], to=gi["to"], side=gi["side"],
                          barrier=cell_to_pt(g, *gi["barrier"]), inner=cell_to_pt(g, *gi["inner"]),
                          edge=cell_to_pt(g, *gi["edge"])))
    data = dict(
        id=lid, w=g.w, h=g.h, cell=PT, edge=spec["edge"],
        rows=rows,
        base=cell_to_pt(g, *gen["base"]),
        gates=gates,
        spots=[[n, p[0], p[1]] for n, p in gen["spots"]],
        props=[[n, p[0], p[1], fixed] for n, p, fixed in gen["props"]],
        border=[[n, p[0], p[1]] for n, p in gen["border"]],
    )
    with open(os.path.join(LAYOUTS, f"layout_{lid}.json"), "w") as f:
        json.dump(data, f, separators=(",", ":"))


def main():
    only = sys.argv[4:] or list(LOCATIONS)
    cache = {}
    for lid in only:
        spec = LOCATIONS[lid]
        key = (spec["biome"], spec["edge"])
        if key not in cache:
            cache[key] = build_tiles(spec["biome"], spec["edge"])
        gen = generate(lid, spec)
        img = render_ground(lid, spec, gen, cache[key], SPRITES)
        img.save(os.path.join(SPRITES, f"sp_ground_{lid}.png"))
        export(lid, spec, gen)
        print(f"{lid}: {len(gen['spots'])} spots, {len(gen['props'])} props, {len(gen['border'])} border, {len(gen['flat'])} flat")


if __name__ == "__main__":
    main()
