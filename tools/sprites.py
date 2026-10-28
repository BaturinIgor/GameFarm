#!/usr/bin/env python3
"""Сборка пиксельных спрайтов игры из исходных паков.

Исходники в репозиторий не кладутся (лицензии запрещают их распространять).
Скрипт режет и перекрашивает нужные куски и пишет готовые PNG и manifest.json
в выходную папку. Потом эта папка шифруется (см. tools/pack_sprites.sh).

Использование:
    python3 tools/sprites.py <папка с паками> <выходная папка>

В папке с паками ожидаются:
    Cute_Fantasy_Free/
    Pixel Crawler - Free Pack 2/Pixel Crawler - Free Pack/
"""
import colorsys
import json
import os
import sys

from PIL import Image

SRC = sys.argv[1]
OUT = sys.argv[2]
CF = os.path.join(SRC, "Cute_Fantasy_Free")
PC = os.path.join(SRC, "Pixel Crawler - Free Pack 2", "Pixel Crawler - Free Pack")
PC_STATIC = os.path.join(PC, "Environment", "Props", "Static")

os.makedirs(OUT, exist_ok=True)
manifest = {}


def load(*parts):
    return Image.open(os.path.join(*parts)).convert("RGBA")


def hexc(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


def crop_opaque(im):
    box = im.getchannel("A").getbbox()
    return im.crop(box) if box else im


def foot_anchor(im):
    """Точка опоры: низ непрозрачной части (тень с малой альфой не считается)."""
    px = im.load()
    w, h = im.size
    bottom = None
    for y in range(h - 1, -1, -1):
        if any(px[x, y][3] > 200 for x in range(w)):
            bottom = y
            break
    if bottom is None:
        return [0.5, 0.0]
    xs = [x for yy in range(max(0, bottom - 2), bottom + 1) for x in range(w) if px[x, yy][3] > 200]
    cx = (min(xs) + max(xs) + 1) / 2
    return [round(cx / w, 4), round((h - bottom - 1) / h, 4)]


def save(name, im, anchor=None):
    im.save(os.path.join(OUT, f"sp_{name}.png"))
    manifest[name] = {"w": im.width, "h": im.height, "anchor": anchor if anchor else foot_anchor(im)}


def remap(im, mapping):
    """Точная замена цветов: {(r,g,b): (r,g,b)}."""
    out = im.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            p = px[x, y]
            if p[3] and p[:3] in mapping:
                px[x, y] = mapping[p[:3]] + (p[3],)
    return out


def ramp_map(im, order, ramp):
    """order: исходные цвета от тёмного к светлому (каждый элемент - список hex),
    ramp: новые цвета той же длины."""
    mapping = {}
    for group, new in zip(order, ramp):
        for c in group:
            mapping[hexc(c)] = hexc(new)
    return remap(im, mapping)


def lum(p):
    return 0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2]


def lum_map(im, ramp, mask=lambda p: True, min_alpha=200):
    """Перекраска по яркости: все подходящие цвета сортируются по яркости
    и раскладываются по градиенту ramp."""
    px = im.load()
    colors = sorted({px[x, y][:3] for y in range(im.height) for x in range(im.width)
                     if px[x, y][3] >= min_alpha and mask(px[x, y])}, key=lum)
    if not colors:
        return im.copy()
    lo, hi = lum(colors[0]), lum(colors[-1])
    stops = [hexc(c) for c in ramp]
    mapping = {}
    for c in colors:
        t = 0 if hi == lo else (lum(c) - lo) / (hi - lo)
        f = t * (len(stops) - 1)
        i = min(int(f), len(stops) - 2)
        k = f - i
        a, b = stops[i], stops[i + 1]
        mapping[c] = tuple(round(a[j] + (b[j] - a[j]) * k) for j in range(3))
    return remap(im, mapping)


def is_green(p):
    h, s, v = colorsys.rgb_to_hsv(p[0] / 255, p[1] / 255, p[2] / 255)
    return 0.17 < h < 0.55 and s > 0.25 and v > 0.12


def is_wood(p):
    h, s, v = colorsys.rgb_to_hsv(p[0] / 255, p[1] / 255, p[2] / 255)
    return (h < 0.12 or h > 0.92) and s > 0.15


def dots(im, points, colors):
    """Рисует круглые плоды 3x3: colors = (основной, тень, блик)."""
    out = im.copy()
    px = out.load()
    main, dark, light = (hexc(c) + (255,) for c in colors)
    for x, y in points:
        for dx, dy in [(0, -1), (-1, 0), (0, 0), (1, 0), (0, 1), (1, 1), (-1, 1), (1, -1)]:
            if 0 <= x + dx < out.width and 0 <= y + dy < out.height:
                px[x + dx, y + dy] = main
        for dx, dy in [(1, 1), (0, 1), (1, 0)]:
            if 0 <= x + dx < out.width and 0 <= y + dy < out.height:
                px[x + dx, y + dy] = dark
        px[x - 1 if x > 0 else x, y - 1 if y > 0 else y] = light
    return out


# ---------------------------------------------------------------- персонаж

PLAYER = load(CF, "Player", "Player.png")
ACTIONS = load(CF, "Player", "Player_Actions.png")

BASE = {
    "hair": ["#704643", "#5d2c28"],
    "skin": ["#f6ca9f", "#d29f70"],
    "shirt": ["#33984b", "#1e6f50", "#134c4c"],
    "pants": ["#0098dc", "#0069aa"],
}

SKINS = {
    "farmer": {},
    "farmerWoman": {"hair": ["#c0612b", "#8a3b1e"], "shirt": ["#e86a92", "#b7416e", "#7a2a52"], "pants": ["#7b8cf0", "#5160c4"]},
    "farmerMan": {"hair": ["#3b2a20", "#24170f"], "shirt": ["#d14a3a", "#9c2e2e", "#5e1d24"], "pants": ["#3d6fb0", "#284d80"]},
    "builder": {"hair": ["#ffd23f", "#d9a521"], "shirt": ["#ffa630", "#e0731f", "#9c4a14"], "pants": ["#4a4a5a", "#2e2e3a"]},
    "cowboy": {"hair": ["#8a5a2b", "#5e3a1a"], "shirt": ["#d9a066", "#b07a45", "#7a4f2a"], "pants": ["#2d5f9a", "#1d3f6a"]},
    "detective": {"hair": ["#4a3426", "#2e1f16"], "shirt": ["#c8b58a", "#a08c62", "#6e5f40"], "pants": ["#5a5a66", "#3a3a44"]},
    "elf": {"hair": ["#f2d16b", "#c9a43c"], "shirt": ["#3e8948", "#265c42", "#193c3e"], "pants": ["#8f563b", "#663931"]},
    "rockstar": {"hair": ["#2a2a35", "#16161e"], "shirt": ["#b4202a", "#73172d", "#3b1725"], "pants": ["#3a3a4a", "#232330"]},
    "robot": {"hair": ["#8b9bb4", "#5a6988"], "skin": ["#c0cbdc", "#8b9bb4"], "shirt": ["#5a6988", "#3a4466", "#262b44"], "pants": ["#8b9bb4", "#5a6988"]},
    "genie": {"hair": ["#202030", "#101018"], "skin": ["#5fcde4", "#2f8fb8"], "shirt": ["#9b5fd6", "#6b3fa0", "#43266b"], "pants": ["#e8c170", "#b8913e"]},
    "wizard": {"hair": ["#d8d8e0", "#a8a8b8"], "shirt": ["#5b3fa0", "#3d2a70", "#271a4a"], "pants": ["#3d2a70", "#271a4a"]},
    "ninja": {"hair": ["#1c1c24", "#0f0f14"], "shirt": ["#3a3a48", "#25252e", "#16161c"], "pants": ["#2a2a34", "#1a1a20"]},
    "vampire": {"hair": ["#1e1a2a", "#120f1a"], "skin": ["#e6e2f0", "#b8b0c8"], "shirt": ["#a3203a", "#6b1530", "#3a0f22"], "pants": ["#2a2232", "#18121e"]},
    "astronaut": {"hair": ["#f0f4ff", "#c0c8dc"], "shirt": ["#f4f6fb", "#c8d0e0", "#8b9bb4"], "pants": ["#dfe5f0", "#a8b2c8"]},
    "princess": {"hair": ["#ffe27a", "#e0b33c"], "shirt": ["#ff8fb8", "#e0608e", "#9e3b62"], "pants": ["#ffb3cf", "#e07aa2"]},
    "prince": {"hair": ["#c99a4a", "#9a6d2c"], "shirt": ["#3a5fd0", "#2a3f9a", "#1c2a66"], "pants": ["#e8ecf4", "#b8c0d0"]},
    "superhero": {"hair": ["#202028", "#121218"], "shirt": ["#e03a3a", "#a82424", "#6b1616"], "pants": ["#2f5fd6", "#1f3f9a"]},
    "merperson": {"hair": ["#36c5b0", "#1f8a7a"], "shirt": ["#5fe0c8", "#2fa898", "#1f6a66"], "pants": ["#2fa070", "#1f6a50"]},
    "fairy": {"hair": ["#ff9ad5", "#d665a8"], "shirt": ["#d8b0ff", "#a77ce0", "#6e4fa0"], "pants": ["#a8f0d0", "#6cc0a0"]},
    "zombie": {"hair": ["#3a3a2a", "#22221a"], "skin": ["#9cc27a", "#6f9450"], "shirt": ["#7a6a4a", "#544830", "#3a301f"], "pants": ["#4a4a6a", "#30304a"]},
}

OUTLINE = hexc("#0e071b")
HAIR_DARK = hexc("#5d2c28")


def skin_sheet(sheet, cell, skin):
    """Перекраска листа персонажа. Тёмный цвет волос совпадает с цветом обуви,
    поэтому обувь (низ фигуры в каждой клетке) не трогаем."""
    mapping = {}
    for part, cols in BASE.items():
        new = skin.get(part)
        if not new:
            continue
        for old, nw in zip(cols, new):
            mapping[hexc(old)] = hexc(nw)
    out = sheet.copy()
    px = out.load()
    src = sheet.load()
    for cy in range(0, sheet.height, cell):
        for cx in range(0, sheet.width, cell):
            bottom = None
            for y in range(cy + cell - 1, cy - 1, -1):
                if any(src[x, y][:3] == OUTLINE and src[x, y][3] == 255 for x in range(cx, cx + cell)):
                    bottom = y
                    break
            if bottom is None:
                continue
            for y in range(cy, cy + cell):
                for x in range(cx, cx + cell):
                    p = src[x, y]
                    if p[3] == 0 or p[:3] not in mapping:
                        continue
                    if p[:3] == HAIR_DARK and y >= bottom - 3:
                        continue
                    px[x, y] = mapping[p[:3]] + (p[3],)
    return out


for name, skin in SKINS.items():
    skin_sheet(PLAYER, 32, skin).save(os.path.join(OUT, f"sp_player_{name}.png"))
    skin_sheet(ACTIONS, 48, skin).save(os.path.join(OUT, f"sp_actions_{name}.png"))
manifest["player"] = {"w": 32, "h": 32, "anchor": foot_anchor(PLAYER.crop((0, 0, 32, 32)))}
manifest["actions"] = {"w": 48, "h": 48, "anchor": foot_anchor(ACTIONS.crop((0, 48, 48, 96)))}

# ---------------------------------------------------------------- животные

for animal in ["Chicken", "Cow", "Pig", "Sheep"]:
    sheet = load(CF, "Animals", animal, f"{animal}.png")
    sheet.save(os.path.join(OUT, f"sp_animal_{animal.lower()}.png"))
    manifest[f"animal_{animal.lower()}"] = {"w": 32, "h": 32, "anchor": foot_anchor(sheet.crop((0, 0, 32, 32)))}

# ---------------------------------------------------------------- деревья

OAK = crop_opaque(load(CF, "Outdoor decoration", "Oak_Tree.png"))
OAK_GREENS = [["#091b15"], ["#134c4c"], ["#1e6f50"], ["#33984b"], ["#5ac54f"]]
save("oak", OAK)
apples = [(12, 17), (27, 12), (19, 29), (32, 26), (8, 33), (24, 40)]
save("oak_apple", dots(OAK, apples, ("#d84650", "#7a2934", "#f3b0b6")))
save("oak_glow", ramp_map(OAK, OAK_GREENS, ["#160b24", "#45266e", "#6a3aa8", "#9a5ce0", "#d09bff"]))
save("oak_sky", ramp_map(OAK, OAK_GREENS, ["#1b2a40", "#5f86bb", "#8fb6e6", "#c6defa", "#f2f8ff"]))
save("oak_willow", ramp_map(OAK, OAK_GREENS, ["#0d1a14", "#2a4a3a", "#3f6a42", "#5e8a48", "#8fae5a"]))
golden = ramp_map(OAK, OAK_GREENS, ["#2a1606", "#7a4a14", "#c47f1c", "#f2b632", "#ffe57a"])
save("oak_golden", dots(golden, apples, ("#ff9a1f", "#9c4a00", "#fff3b0")))
save("oak_golden_bare", golden)

small = load(CF, "Outdoor decoration", "Oak_Tree_Small.png")
save("oak_small", crop_opaque(small.crop((32, 0, 64, 48))))

pine_sheet = load(PC_STATIC, "Trees", "Model_02", "Size_04.png")
pine = crop_opaque(pine_sheet.crop((4, 121, 58, 224)))
save("pine", pine)
teal = crop_opaque(pine_sheet.crop((4, 9, 58, 112)))
save("pine_frost", lum_map(teal, ["#16233a", "#3a5878", "#8fb2cc", "#d6ecf8", "#ffffff"], is_green))

broad = load(PC_STATIC, "Trees", "Model_01", "Size_04.png")
bare = crop_opaque(broad.crop((166, 2, 235, 128)))
save("ash", lum_map(bare, ["#0a0808", "#1c1717", "#332c2c", "#4d4343", "#6e605a"]))
save("tree_autumn", crop_opaque(broad.crop((3, 130, 76, 256))))

stump = crop_opaque(load(CF, "Outdoor decoration", "Outdoor_Decor_Free.png").crop((0, 32, 16, 48)))
save("stump", stump)

# ---------------------------------------------------------------- кусты и грядки

veg = load(PC_STATIC, "Vegetation.png")
bush = crop_opaque(veg.crop((2, 99, 45, 142)))
save("bush_empty", bush)
save("bush", dots(bush, [(12, 12), (25, 9), (31, 19), (17, 23), (8, 27), (27, 29)], ("#4f67ff", "#2a2f8a", "#c8d2ff")))

DECOR = load(CF, "Outdoor decoration", "Outdoor_Decor_Free.png")


def dc(c, r, w=1, h=1):
    return crop_opaque(DECOR.crop((c * 16, r * 16, (c + w) * 16, (r + h) * 16)))


save("carrot", dc(4, 2))
save("carrot_young", dc(3, 2))
save("sprout", dc(3, 1))
save("herb", dc(6, 1))
save("mushroom", dc(2, 7))
save("wheat", dc(6, 2))
save("grass1", dc(0, 0))
save("grass2", dc(1, 0))
save("grass3", dc(2, 0))
save("flowers_white", dc(0, 1))
save("flowers_yellow", dc(1, 1))
save("flowers_mix", dc(2, 1))
save("tulip_red", dc(0, 9))
save("tulip_yellow", dc(1, 9))
save("log", dc(0, 7, 2, 1))

# ---------------------------------------------------------------- камни и руды

STONE = [["#262b44"], ["#3c4258", "#424c6e"], ["#6c7c9d"], ["#8e9ab4"], ["#c0cbdc"]]
GOLD = [["#3f2832"], ["#dd5a08"], ["#feae34"], ["#fee761"], ["#fff7d2"]]

stone, stone2, stone3, crystal = dc(0, 3), dc(1, 3), dc(2, 3), dc(3, 3)
gold_ore, gold_crystal = dc(0, 5), dc(3, 5)
save("stone", stone)
save("stone2", stone2)
save("stone3", stone3)
save("rock_grass", dc(2, 2))
save("pebbles", ramp_map(dc(0, 4), STONE, ["#262b44", "#3c4258", "#6c7c9d", "#8e9ab4", "#c0cbdc"]))
save("coal", ramp_map(stone, STONE, ["#0b0a0e", "#1b1a20", "#2e2c34", "#45424e", "#6e6a78"]))
save("iron", ramp_map(stone2, STONE, ["#2b1d1d", "#5a3a32", "#9a6a55", "#c4977a", "#ead2bc"]))
save("gold", gold_ore)
save("sulfur", ramp_map(gold_ore, GOLD, ["#3d3a12", "#9a9a1a", "#cfd23a", "#eef070", "#fbffd0"]))
save("obsidian", ramp_map(stone2, STONE, ["#0d0a14", "#1f1630", "#3a2a5a", "#6a4c9c", "#b8a0f0"]))
save("star", ramp_map(gold_crystal, GOLD, ["#4a3a20", "#c9a640", "#f2d872", "#fff2b0", "#ffffff"]))
save("crystal", ramp_map(crystal, STONE, ["#2a1840", "#5b2f9e", "#8a55e0", "#b892ff", "#efe2ff"]))
save("diamond", ramp_map(crystal, STONE, ["#123044", "#1f7a9e", "#3ec8e8", "#8ef0ff", "#ffffff"]))
save("ruby", ramp_map(crystal, STONE, ["#3a0d18", "#8e1830", "#d92f4a", "#ff7a8a", "#ffe0e6"]))
save("ice", ramp_map(crystal, STONE, ["#2a4660", "#5f93b8", "#a8d4f0", "#d8f0ff", "#ffffff"]))

# ---------------------------------------------------------------- постройки

save("chest", load(CF, "Outdoor decoration", "Chest.png"))
save("house", crop_opaque(load(CF, "Outdoor decoration", "House_1_Wood_Base_Blue.png")))

with open(os.path.join(OUT, "sp_manifest.json"), "w") as f:
    json.dump(manifest, f, indent=1, sort_keys=True)
print(f"{len(os.listdir(OUT))} files written to {OUT}")
