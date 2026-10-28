#!/usr/bin/env python3
"""Сборка пиксельных спрайтов игры из пака Cute Fantasy (Premium).

Исходники в репозиторий не кладутся (лицензия запрещает их распространять).
Скрипт режет, собирает по слоям и перекрашивает нужные куски и пишет готовые
PNG и sp_manifest.json в выходную папку. Потом эта папка шифруется
(см. tools/pack_sprites.sh).

Использование:
    python3 tools/sprites.py <папка с паками> <выходная папка>

В папке с паками ожидается Cute_Fantasy/ (платная версия пака).
Масштаб везде один: 1 пиксель исходника = 2.5 точки на экране.
"""
import colorsys
import json
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import handmade  # noqa: E402

SRC = sys.argv[1]
OUT = sys.argv[2]
CF = os.path.join(SRC, "Cute_Fantasy")

os.makedirs(OUT, exist_ok=True)
manifest = {}


def load(*parts):
    return Image.open(os.path.join(CF, *parts)).convert("RGBA")


def hexc(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


def crop_opaque(im):
    box = im.getchannel("A").getbbox()
    return im.crop(box) if box else im


def cell(sheet, c, r, w=16, h=16):
    return sheet.crop((c * w, r * h, (c + 1) * w, (r + 1) * h))


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


def save(name, im, anchor=None, extra=None):
    im.save(os.path.join(OUT, f"sp_{name}.png"))
    entry = {"w": im.width, "h": im.height, "anchor": anchor if anchor else foot_anchor(im)}
    if extra:
        entry.update(extra)
    manifest[name] = entry


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


def swap(im, pairs):
    """pairs: [(старый hex, новый hex)]."""
    return remap(im, {hexc(a): hexc(b) for a, b in pairs})


def lum(p):
    return 0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2]


def lum_map(im, ramp, mask=lambda p: True, min_alpha=1):
    """Перекраска по яркости: подходящие цвета сортируются по яркости
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


def hsv(p):
    return colorsys.rgb_to_hsv(p[0] / 255, p[1] / 255, p[2] / 255)


def is_green(p):
    h, s, v = hsv(p)
    return 0.17 < h < 0.55 and s > 0.25 and v > 0.12


def flip(im):
    return im.transpose(Image.FLIP_LEFT_RIGHT)


def stack(frames):
    """Кадры одной строкой."""
    w, h = frames[0].size
    out = Image.new("RGBA", (w * len(frames), h))
    for i, f in enumerate(frames):
        out.alpha_composite(f, (i * w, 0))
    return out


OUTLINE = "#0e071b"
LEAVES = ["#091b15", "#134c4c", "#1e6f50", "#33984b", "#5ac54f"]
TRUNK = ["#3f2832", "#743f39", "#91533b", "#b86f50"]
SPRUCE = ["#091b15", "#193c3e", "#37625b", "#3f886c"]
BIRCH_LEAVES = ["#4f3f22", "#826327", "#ae8129", "#c6942f", "#deae4f"]
APPLE = ["#571c27", "#891e2b", "#c42430", "#f5555d"]


def ramp_pairs(old, new):
    return list(zip(old, new))


# ================================================================ персонаж

PLAYER = "Player"
BASE = load(PLAYER, "Player_Base", "Player_Base_animations.png")
HANDS = load(PLAYER, "Hands", "Hands_1_Bare.png")
TOOLS = load(PLAYER, "Tools", "Iron", "Iron_Tools.png")
ROD = load(PLAYER, "Tools", "Fishing_Rod", "Wooden_Fishing_Rod.png")
HAT = load(PLAYER, "Accessories", "Farmer_Hat_1.png")

# Какие строки исходного листа берём: (строка, кадров). Вниз, вбок, вверх.
ROWS = (
    [(r, 6) for r in (0, 1, 2)]          # стоит
    + [(r, 6) for r in (3, 4, 5)]        # идёт
    + [(r, 6) for r in (32, 33, 34)]     # топор
    + [(r, 6) for r in (35, 36, 37)]     # кирка
    + [(r, 6) for r in (38, 39, 40)]     # мотыга
    + [(r, 9) for r in (44, 45, 46)]     # заброс удочки
    + [(r, 8) for r in (47, 48, 49)]     # вытаскивает
)
SKIN_TONES = {
    "light": None,
    "tan": ["#e4a672", "#b86f50"],
    "dark": ["#9c6754", "#6d483b"],
    "pale": ["#f2eef8", "#c9c0d8"],
    "green": ["#a8ca58", "#6f9450"],
    "blue": ["#7fd0f0", "#3f8fc8"],
    "metal": ["#c7cfdd", "#8e9ab4"],
}
BASE_SKIN = ["#f6ca9f", "#d29f70"]

HAIR_RECOLOR = {
    "Teal": ["#1f6a66", "#36c5b0", "#8ff0dc"],
    "Pink": ["#a8407a", "#ff7ac0", "#ffc0e4"],
    "White": ["#9ea9c0", "#e8ecf4", "#ffffff"],
}

SKINS = {
    "farmer": dict(hair=(1, "Brown"), chest="OG_Shirt/Shirt_1_Green", legs="OG_Pants/Pants_1_Blue", feet="Brown", hat="#ffc825"),
    "farmerWoman": dict(hair=(4, "Ginger"), chest="Farmer_Shirt/Farmer_Shirt_1_Pink", legs="Farmer_Pants/Farmer_Pants_1_Blue",
                        feet="Brown", hat="#ffc825", tone="tan"),
    "farmerMan": dict(hair=(2, "Black"), chest="Farmer_Shirt/Farmer_Shirt_1_White_and_Brown",
                      legs="Farmer_Pants/Farmer_Pants_1_White_and_Brown", feet="Black", tone="dark"),
    "builder": dict(helmet="Plate_Helmet_1/Plate_Helmet_1_Orange", chest="Lumberjack_Shirt/Lumberjack_Shirt_1_Orange",
                    legs="OG_Pants/Pants_1_Blue", feet="Brown"),
    "cowboy": dict(hair=(5, "Brown"), chest="Lumberjack_Shirt/Lumberjack_Shirt_1_Red", legs="OG_Pants/Pants_1_Brown",
                   feet="Brown", hat="#8a5a2b", tone="tan"),
    "detective": dict(hair=(2, "Brown"), chest="Royal_Shirt/Royal_Shirt_1_Black", legs="OG_Pants/Pants_1_Black",
                      feet="Black", hat="#6a6a78"),
    "elf": dict(hair=(5, "Blonde"), chest="Royal_Shirt/Royal_Shirt_1_Green", legs="Royal_Pants/Royal_Pants_1_Green", feet="Green"),
    "rockstar": dict(hair=(3, "Black"), chest="Lumberjack_Shirt/Lumberjack_Shirt_1_Black", legs="OG_Pants/Pants_1_Black",
                     feet="Red", tone="dark"),
    "robot": dict(helmet="Plate_Helmet_2/Heavy_Plate_Helmet_1_Iron", chest="Plate_Chest/Plate_Chest_Iron",
                  legs="Plate_Legs/Plate_Legs_Iron", feet="White", tone="metal"),
    "genie": dict(hair=(6, "Black"), chest="Royal_Shirt/Royal_Shirt_1_Purple", legs="Royal_Pants/Royal_Pants_1_Purple",
                  feet="Purple", tone="blue"),
    "wizard": dict(hair=(5, "Grey"), chest="Royal_Shirt/Royal_Shirt_1_Purple", legs="Royal_Pants/Royal_Pants_1_Purple",
                   feet="Purple", hat="#5b3fa0"),
    "ninja": dict(hair=(6, "Black"), chest="OG_Shirt/Shirt_1_Black", legs="OG_Pants/Pants_1_Black", feet="Black"),
    "vampire": dict(hair=(2, "Black"), chest="Royal_Shirt/Royal_Shirt_1_Red", legs="Royal_Pants/Royal_Pants_1_Black",
                    feet="Black", tone="pale"),
    "astronaut": dict(helmet="Plate_Helmet_2/Heavy_Plate_Helmet_1_Iron", helmet_tint=["#5a6988", "#c0cbdc", "#ffffff"],
                      chest="Royal_Shirt/Royal_Shirt_1_White", legs="Royal_Pants/Royal_Pants_1_White", feet="White"),
    "princess": dict(hair=(5, "Blonde"), chest="Farmer_Shirt/Farmer_Shirt_1_Pink", legs="Farmer_Pants/Farmer_Pants_1_Pink",
                     feet="Pink", crown=True),
    "prince": dict(hair=(1, "Blonde"), chest="Royal_Shirt/Royal_Shirt_1_Blue", legs="Royal_Pants/Royal_Pants_1_White",
                   feet="Blue", crown=True, tone="tan"),
    "superhero": dict(hair=(2, "Black"), chest="OG_Shirt/Shirt_1_Red", legs="OG_Pants/Pants_1_Blue", feet="Red"),
    "merperson": dict(hair=(5, "Teal"), chest="Farmer_Shirt/Farmer_Shirt_1_Blue", legs="OG_Pants/Pants_1_Green", feet="Green",
                      tone="tan"),
    "fairy": dict(hair=(6, "Pink"), chest="Royal_Shirt/Royal_Shirt_1_Green", legs="Farmer_Pants/Farmer_Pants_1_Pink", feet="Pink"),
    "zombie": dict(hair=(1, "Grey"), chest="OG_Shirt/Shirt_1_Brown", legs="OG_Pants/Pants_1_Green", feet="Brown", tone="green"),
    "knight": dict(helmet="Plate_Helmet_1/Plate_Helmet_1_Gold", chest="Plate_Chest/Plate_Chest_Gold",
                   legs="Plate_Legs/Plate_Legs_Gold", feet="Brown"),
}

_layer_cache = {}


def layer(path):
    if path not in _layer_cache:
        _layer_cache[path] = load(PLAYER, path)
    return _layer_cache[path]


def hair_layer(style, color):
    if color in HAIR_RECOLOR:
        base = layer(f"Head/Hair_{style}/Hair_{style}_Grey.png")
        return lum_map(base, HAIR_RECOLOR[color], mask=lambda p: p[:3] in (hexc("#b4b4b4"), hexc("#858585")))
    return layer(f"Head/Hair_{style}/Hair_{style}_{color}.png")


def crown_on(frame, facing):
    """Маленькая корона поверх головы: ищем верх волос и рисуем 5 пикселей золота."""
    px = frame.load()
    top = None
    for y in range(64):
        xs = [x for x in range(16, 48) if px[x, y][3] > 200]
        if xs:
            top = (y, (min(xs) + max(xs)) // 2)
            break
    if top is None:
        return frame
    y, cx = top
    gold, dark, gem = hexc("#ffc825") + (255,), hexc("#ed7614") + (255,), hexc("#e43b44") + (255,)
    outline = hexc(OUTLINE) + (255,)
    shape = [(-3, 0, "o"), (-2, 0, "g"), (-1, 0, "g"), (0, 0, "r"), (1, 0, "g"), (2, 0, "g"), (3, 0, "o"),
             (-3, -1, "o"), (-2, -1, "g"), (0, -1, "g"), (2, -1, "g"), (3, -1, "o"),
             (-2, -2, "o"), (0, -2, "o"), (2, -2, "o"), (-1, -1, "d"), (1, -1, "d")]
    for dx, dy, k in shape:
        x, yy = cx + dx, y + dy
        if 0 <= x < 64 and 0 <= yy < 64:
            px[x, yy] = {"o": outline, "g": gold, "d": dark, "r": gem}[k]
    return frame


def build_skin(spec):
    tone = spec.get("tone")
    base = BASE if not tone or not SKIN_TONES.get(tone) else swap(BASE, ramp_pairs(BASE_SKIN, SKIN_TONES[tone]))
    hands = HANDS if not tone or not SKIN_TONES.get(tone) else swap(HANDS, ramp_pairs(BASE_SKIN, SKIN_TONES[tone]))
    layers = [base, layer(f"Feet/Shoes_1_{spec['feet']}.png"), layer(f"Legs/{spec['legs']}.png"),
              layer(f"Chest/{spec['chest']}.png"), hands]
    if "helmet" in spec:
        helmet = layer(f"Head/{spec['helmet']}.png")
        if spec.get("helmet_tint"):
            helmet = lum_map(helmet, spec["helmet_tint"], mask=lambda p: p[:3] != hexc(OUTLINE))
        layers.append(helmet)
    else:
        layers.append(hair_layer(*spec["hair"]))
    if spec.get("hat"):
        c = spec["hat"]
        hat = HAT if c == "#ffc825" else lum_map(HAT, ["#1a1020", c, "#ffffff"], mask=lambda p: p[:3] != hexc(OUTLINE))
        layers.append(hat)

    cols = 9
    out = Image.new("RGBA", (cols * 64, len(ROWS) * 64))
    for i, (row, count) in enumerate(ROWS):
        for col in range(count):
            box = (col * 64, row * 64, col * 64 + 64, row * 64 + 64)
            frame = Image.new("RGBA", (64, 64))
            for l in layers:
                frame.alpha_composite(l.crop(box))
            if spec.get("crown") and row not in (2, 5, 34, 37, 40, 46, 49):
                frame = crown_on(frame, row)
            if 32 <= row <= 40:
                tool_row = row - 32
                frame.alpha_composite(TOOLS.crop((col * 64, tool_row * 64, col * 64 + 64, tool_row * 64 + 64)))
            if 44 <= row <= 49:
                rod_row = row - 44
                frame.alpha_composite(ROD.crop((col * 64, rod_row * 64, col * 64 + 64, rod_row * 64 + 64)))
            out.alpha_composite(frame, (col * 64, i * 64))
    return out


for name, spec in SKINS.items():
    sheet = build_skin(spec)
    sheet.save(os.path.join(OUT, f"sp_pl_{name}.png"))
    if name == "farmer":
        manifest["pl"] = {"w": 64, "h": 64, "anchor": foot_anchor(sheet.crop((0, 0, 64, 64))),
                          "rows": [count for _, count in ROWS]}

# ================================================================ животные

ANIMALS = {
    "chicken": ("Chicken", "Chicken_01.png"),
    "rooster": ("Chicken", "Rooster.png"),
    "cow": ("Cow", "Cow_01.png"),
    "duck": ("Duck", "Duck_01.png"),
    "duckHat": ("Duck", "Duck_in_a_hat.png"),
    "frog": ("Frog", "Frog_01.png"),
    "goose": ("Goose", "Goose_01.png"),
    "horse": ("Horse", "Horse_01.png"),
    "mouse": ("Mouse", "Mouse_01.png"),
    "pig": ("Pig", "Pig_01.png"),
    "sheep": ("Sheep", "Sheep_01.png"),
    "swan": ("Swan", "Swan_01.png"),
}
for key, (folder, file) in ANIMALS.items():
    sheet = load("Animals", folder, file)
    save(f"an_{key}", sheet, anchor=foot_anchor(sheet.crop((0, 0, 32, 32))))

# Единорог: белая лошадь с золотым рогом и розовой гривой.
horse = load("Animals", "Horse", "Horse_01.png")
HORSE_BODY = ["#8a4836", "#bf6f4a", "#e69c69"]
unicorn = swap(horse, ramp_pairs(HORSE_BODY, ["#c0cbdc", "#f4f4ff", "#ffffff"]))
unicorn = lum_map(unicorn, ["#7a2a6a", "#e86aa8", "#ffb8dc"],
                  mask=lambda p: hsv(p)[0] < 0.1 and hsv(p)[1] > 0.35 and p[:3] not in (hexc(OUTLINE),))
save("an_unicorn", handmade.unicorn_horns(unicorn), anchor=foot_anchor(unicorn.crop((0, 0, 32, 32))))

goose = load("Animals", "Goose", "Goose_01.png")
golden = swap(goose, [("#ffffff", "#fff3b0"), ("#f9e6cf", "#ffd84a"), ("#f6ca9f", "#e8a72a")])
save("an_goldenGoose", golden, anchor=foot_anchor(golden.crop((0, 0, 32, 32))))

bee = load("Animals", "Bee", "Bee_Flying_Animation.png")
save("an_bee", bee.crop((0, 0, 64, 16)), anchor=[0.5, 0.0])
fly = load("Animals", "Butterfly", "Butterfly.png")
save("an_butterfly", fly, anchor=[0.5, 0.0])

for albino in ("", "Albino_"):
    idle = load("Animals", "Kapybara", "Static", f"{albino}Kapybara_Idle.png")
    look = load("Animals", "Kapybara", "Static", f"{albino}Kapybara_LookAround.png")
    sheet = Image.new("RGBA", (look.width, 64))
    sheet.alpha_composite(idle, (0, 0))
    sheet.alpha_composite(look, (0, 32))
    save("an_capybara" + ("Albino" if albino else ""), sheet, anchor=[0.5, 0.2])

# ================================================================ деревья

def tree_frames(file, w, h):
    sheet = load("Trees", file) if not file.startswith("Crops") else load(*file.split("/"))
    return [sheet.crop((i * w, 0, (i + 1) * w, h)) for i in range(sheet.width // w)]


oak_m = tree_frames("Medium_Oak_Tree.png", 32, 48)
oak_b = tree_frames("Big_Oak_Tree.png", 64, 80)
oak_s = tree_frames("Small_Oak_Tree.png", 32, 64)
spr_m = tree_frames("Medium_Spruce_Tree.png", 32, 48)
spr_b = tree_frames("Big_Spruce_tree.png", 64, 80)
spr_s = tree_frames("Small_Spruce_Tree.png", 32, 64)
bir_m = tree_frames("Medium_Birch_Tree.png", 32, 48)
bir_b = tree_frames("Big_Birch_Tree.png", 32, 80)
bir_s = tree_frames("Small_Birch_Tree.png", 32, 64)
fru_m = tree_frames("Medium_Fruit_Tree.png", 32, 64)
fru_b = tree_frames("Big_Fruit_Tree.png", 32, 64)


def save_tree(name, im):
    save(name, crop_opaque(im))


save_tree("tree_oak", oak_m[1])
save_tree("tree_oak_big", oak_b[1])
save_tree("tree_oak_small", oak_s[1])
save_tree("stump_oak", oak_m[0])
save_tree("stump_oak_big", oak_b[0])
save_tree("tree_spruce", spr_m[1])
save_tree("tree_spruce_big", spr_b[1])
save_tree("tree_spruce_small", spr_s[1])
save_tree("stump_spruce", spr_m[0])
save_tree("tree_birch", bir_m[1])
save_tree("tree_birch_big", bir_b[1])
save_tree("tree_birch_small", bir_s[1])
save_tree("stump_birch", bir_m[0])
save_tree("tree_fruit", fru_m[1])
save_tree("tree_fruit_big", fru_b[1])
save_tree("stump_fruit", fru_m[0])

apple_tree = load("Crops", "Apple_Tree.png")
save_tree("tree_apple", apple_tree)
for fruit in ("Cherry", "Peach", "Pear"):
    save_tree(f"tree_{fruit.lower()}", load("Crops", f"{fruit}_Tree.png"))
apple_bare = swap(apple_tree, ramp_pairs(APPLE, ["#134c4c", "#1e6f50", "#33984b", "#5ac54f"]))
save_tree("tree_apple_bare", apple_bare)

FROST = ["#16233a", "#3a5878", "#8fb2cc", "#e8f6ff"]
save_tree("tree_frost", swap(spr_m[1], ramp_pairs(SPRUCE, FROST)))
save_tree("tree_frost_big", swap(spr_b[1], ramp_pairs(SPRUCE, FROST)))
save_tree("tree_frost_small", swap(spr_s[1], ramp_pairs(SPRUCE, FROST)))
save_tree("stump_frost", swap(spr_m[0], [("#b86f50", "#d8e8f4")]))
GLOW = ["#160b24", "#45266e", "#6a3aa8", "#9a5ce0", "#d09bff"]
save_tree("tree_glow", swap(oak_m[1], ramp_pairs(LEAVES, GLOW)))
save_tree("tree_glow_big", swap(oak_b[1], ramp_pairs(LEAVES, GLOW)))
SKY = ["#1b2a40", "#5f86bb", "#8fb6e6", "#c6defa", "#f2f8ff"]
save_tree("tree_sky", swap(bir_m[1], ramp_pairs(BIRCH_LEAVES, SKY)))
save_tree("tree_sky_big", swap(bir_b[1], ramp_pairs(BIRCH_LEAVES, SKY)))
WILLOW = ["#0d1a14", "#21402f", "#3f6a42", "#5e8a48", "#8fae5a"]
save_tree("tree_willow", swap(fru_m[1], ramp_pairs(LEAVES, WILLOW)))
save_tree("tree_willow_big", swap(fru_b[1], ramp_pairs(LEAVES, WILLOW)))
ASH = ["#0a0808", "#1c1717", "#332c2c", "#4d4343", "#6e605a"]
ash = swap(oak_m[1], ramp_pairs(LEAVES, ASH))
save_tree("tree_ash", handmade.embers(ash))
save_tree("tree_ash_big", handmade.embers(swap(oak_b[1], ramp_pairs(LEAVES, ASH))))
save_tree("stump_ash", swap(oak_m[0], [("#b86f50", "#4d4343"), ("#91533b", "#332c2c")]))
GOLDEN = ["#2a1606", "#7a4a14", "#c47f1c", "#f2b632", "#ffe57a"]
golden_tree = swap(apple_tree, ramp_pairs(LEAVES, GOLDEN) + ramp_pairs(APPLE, ["#9c4a00", "#ed7614", "#ff9a1f", "#fff3b0"]))
save_tree("tree_golden", golden_tree)
save_tree("tree_golden_bare", swap(apple_bare, ramp_pairs(LEAVES, GOLDEN)))
AUTUMN = ["#2a1206", "#6a2a10", "#b4471c", "#e0742a", "#f7b04a"]
save_tree("tree_autumn", swap(oak_m[1], ramp_pairs(LEAVES, AUTUMN)))
save_tree("tree_autumn_big", swap(oak_b[1], ramp_pairs(LEAVES, AUTUMN)))
PALE = ["#1d2a3a", "#6a7fa8", "#a8b8dc", "#dce4fa", "#ffffff"]

# ================================================================ кусты, грядки, цветы

DECOR = load("Outdoor decoration", "Outdoor_Decor.png")


def dc(c, r, w=1, h=1):
    return crop_opaque(DECOR.crop((c * 16, r * 16, (c + w) * 16, (r + h) * 16)))


BERRIES = load("Crops", "Berries.png")
save("bush_berry", crop_opaque(cell(BERRIES, 2, 0)))
save("bush_redberry", crop_opaque(cell(BERRIES, 0, 0)))
save("bush", dc(3, 9))
save("bush_leafy", dc(5, 9))
save("bush_leafy2", dc(6, 9))
save("bush_leafy3", dc(7, 9))
save("bush_cloud", lum_map(dc(3, 9), ["#4a5a8a", "#a8b8e8", "#e8eeff", "#ffffff"], mask=is_green))
save("bush_cloud_star", handmade.star_dots(lum_map(crop_opaque(cell(BERRIES, 2, 0)), ["#4a5a8a", "#a8b8e8", "#e8eeff", "#ffffff"], mask=is_green)))

CROPS = load("Crops", "Crops.png")
CROPS2 = load("Crops", "Crops_2.png")
save("carrot_ripe", crop_opaque(cell(CROPS, 5, 5)))
save("carrot_young", crop_opaque(cell(CROPS, 3, 5)))
save("sprout", crop_opaque(cell(CROPS, 2, 5)))
save("leek", crop_opaque(cell(CROPS2, 5, 13)))
save("leek_young", crop_opaque(cell(CROPS2, 3, 13)))
save("wheat", crop_opaque(cell(CROPS, 5, 1)))
save("sunflower", crop_opaque(cell(CROPS2, 5, 1)))
save("pumpkin", crop_opaque(cell(CROPS, 5, 11)))
save("cabbage", crop_opaque(cell(CROPS, 5, 15)))
save("strawberry", crop_opaque(cell(CROPS2, 5, 7)))
grapes = load("Crops", "Grapes_Bower.png")
save("grapes", crop_opaque(grapes.crop((96, 80, 192, 160))))
save("grapes_bare", crop_opaque(grapes.crop((0, 80, 96, 160))))

save("mushroom_red", dc(0, 3))
save("mushroom_purple", dc(1, 3))
save("mushroom_blue", dc(2, 3))
save("mushroom_tiny_red", dc(6, 1))
save("mushroom_tiny_purple", dc(7, 1))
save("mushroom_tiny_blue", dc(8, 1))
save("mushroom_brown", dc(7, 2))
save("mushroom_brown_small", dc(8, 2))
for i, (c, r) in enumerate([(0, 0), (1, 0), (2, 0), (3, 0), (4, 0), (5, 0), (0, 1), (1, 1), (2, 1), (3, 1), (4, 1), (5, 1),
                            (0, 2), (1, 2), (2, 2), (3, 2), (4, 2), (5, 2)]):
    save(f"flowers{i}", dc(c, r))
save("tuft1", dc(6, 2))
save("tuft2", dc(6, 3))
save("tuft3", dc(7, 3))
save("tuft4", dc(8, 3))
save("reed", dc(8, 6))
save("cattail", dc(4, 5))
save("cattail2", dc(8, 8))
save("lily", dc(3, 3))
save("lily_big", crop_opaque(DECOR.crop((65, 48, 79, 64))))
save("lily_pink", dc(5, 3))
save("stone_small1", dc(0, 5))
save("stone_small2", dc(1, 5))
save("pebble", dc(2, 5))
save("rock1", dc(3, 6))
save("rock2", dc(4, 6))
save("rock3", dc(6, 6))
save("rock_big", dc(8, 4))
save("rock_mossy", dc(4, 9))
save("boulder", crop_opaque(DECOR.crop((97, 180, 127, 204))))
save("boulder2", crop_opaque(DECOR.crop((68, 185, 90, 205))))
save("boulder3", crop_opaque(DECOR.crop((97, 213, 127, 236))))
save("boulder4", crop_opaque(DECOR.crop((69, 219, 94, 238))))
save("log", dc(0, 7, 2, 1))
save("log_mossy", dc(2, 7, 2, 1))
save("log_short", dc(4, 7, 2, 1))
save("stump_mossy", dc(0, 9, 2, 1))
save("stump_small", dc(1, 6))
save("logs_pile", crop_opaque(DECOR.crop((5, 160, 28, 192))))
save("flowers_purple", crop_opaque(DECOR.crop((96, 336, 144, 368))))
save("flowers_red", crop_opaque(DECOR.crop((96, 368, 144, 400))))
save("fern", dc(4, 21))
save("carrot_wild", dc(0, 6))

# ================================================================ камни и руды

ORES = load("Outdoor decoration", "Ores.png")
ORE_ROWS = {"stone": 0, "copper": 1, "gold": 2, "emerald": 3, "diamond": 4, "amber": 5, "ruby": 6, "amethyst": 7}


def ore(c, row):
    return crop_opaque(cell(ORES, c, ORE_ROWS[row]))


STONE_RAMP = ["#262b44", "#3c4258", "#6c7c9d", "#8e9ab4", "#c0cbdc"]
save("ore_stone", ore(1, "stone"))
save("ore_stone2", ore(2, "stone"))
save("ore_stone3", ore(3, "stone"))
save("ore_iron", ore(0, "copper"))
save("ore_gold", ore(0, "gold"))
save("ore_diamond", ore(0, "diamond"))
save("ore_ruby", ore(0, "ruby"))
save("ore_emerald", ore(0, "emerald"))
save("ore_amber", ore(0, "amber"))
save("ore_amethyst", ore(0, "amethyst"))
save("crystal_amethyst", ore(4, "amethyst"))
save("crystal_diamond", ore(4, "diamond"))
save("crystal_ruby", ore(4, "ruby"))
save("crystal_gold", ore(4, "gold"))
coal = ore(0, "stone")
save("ore_coal", lum_map(coal, ["#050408", "#1b1a20", "#2e2c34"], mask=lambda p: hexc("#0c2e44") == p[:3] or hsv(p)[1] > 0.45))
save("ore_obsidian", lum_map(ore(1, "amethyst"), ["#07050c", "#1f1630", "#3a2a5a", "#6a4c9c", "#b8a0f0"]))
save("ore_sulfur", lum_map(ore(0, "amber"), ["#3d3a12", "#9a9a1a", "#cfd23a", "#eef070", "#fbffd0"],
                           mask=lambda p: hsv(p)[0] < 0.2 and hsv(p)[1] > 0.4))
save("ore_star", lum_map(ore(4, "gold"), ["#4a3a20", "#c9a640", "#f2d872", "#fff2b0", "#ffffff"]))
save("ice_block", lum_map(ore(1, "diamond"), ["#2a4660", "#5f93b8", "#a8d4f0", "#d8f0ff", "#ffffff"]))
save("rubble", ore(5, "stone"))
for _mat in ORE_ROWS:
    save(f"chunk_{_mat}", ore(3, _mat))
save("chunk_coal", lum_map(ore(3, "stone"), ["#050408", "#1b1a20", "#2e2c34", "#45424e"], mask=lambda p: p[:3] != hexc(OUTLINE)))
save("chunk_obsidian", lum_map(ore(3, "amethyst"), ["#07050c", "#1f1630", "#3a2a5a", "#6a4c9c"], mask=lambda p: p[:3] != hexc(OUTLINE)))
save("chunk_sulfur", lum_map(ore(3, "amber"), ["#3d3a12", "#9a9a1a", "#cfd23a", "#eef070"], mask=lambda p: p[:3] != hexc(OUTLINE)))
save("chunk_ice", lum_map(ore(3, "diamond"), ["#2a4660", "#5f93b8", "#a8d4f0", "#ffffff"], mask=lambda p: p[:3] != hexc(OUTLINE)))
save("chunk_star", lum_map(ore(3, "gold"), ["#4a3a20", "#c9a640", "#fff2b0", "#ffffff"], mask=lambda p: p[:3] != hexc(OUTLINE)))

# ================================================================ иконки ресурсов

RES = load("Icons", "Outline", "Resources_Icons_Outline.png")
FOOD = load("Icons", "Outline", "Food_Icons_Outline.png")
OTHER = load("Icons", "Outline", "Other_Icons_Outline.png")
OTHER2 = load("Icons", "Outline", "Other_Icons_2_Outline.png")
TOOL_ICONS = load("Icons", "Outline", "Tool_Icons_Outline.png")


def icon(name, im):
    save(f"ic_{name}", im, anchor=[0.5, 0.5])


icon("wood", cell(RES, 0, 4))
icon("stone", cell(RES, 1, 0))
icon("clay", swap(cell(RES, 2, 1), [("#b86f50", "#c46a4a")]))
icon("coal", cell(RES, 0, 5))
icon("iron", cell(ORES, 7, 0))
icon("gold", cell(ORES, 7, 2))
icon("sulfur", lum_map(cell(ORES, 5, 5), ["#3d3a12", "#9a9a1a", "#cfd23a", "#eef070", "#fbffd0"],
                       mask=lambda p: hsv(p)[0] < 0.2 and hsv(p)[1] > 0.4))
icon("obsidian", lum_map(cell(ORES, 6, 7), ["#07050c", "#1f1630", "#3a2a5a", "#6a4c9c", "#b8a0f0"],
                         mask=lambda p: p[:3] != hexc(OUTLINE)))
icon("ice", lum_map(cell(ORES, 2, 4), ["#2a4660", "#5f93b8", "#a8d4f0", "#d8f0ff", "#ffffff"],
                    mask=lambda p: p[:3] != hexc(OUTLINE)))
icon("diamond", cell(ORES, 6, 4))
icon("crystal", cell(ORES, 6, 7))
icon("ruby", cell(ORES, 6, 6))
icon("berries", cell(BERRIES, 3, 0))
icon("apples", cell(FOOD, 6, 3))
icon("mushrooms", cell(FOOD, 4, 0))
icon("carrots", cell(FOOD, 2, 4))
icon("herbs", cell(FOOD, 2, 10))
icon("fish", cell(FOOD, 0, 2))
icon("goldenApple", swap(cell(FOOD, 6, 3), ramp_pairs(APPLE, ["#9c4a00", "#ed7614", "#ffc825", "#fff3b0"])))
icon("egg", cell(FOOD, 6, 1))
icon("milk", cell(FOOD, 7, 0))
icon("honey", cell(FOOD, 7, 8))
icon("tool_axe", cell(TOOL_ICONS, 3, 0))
icon("tool_pickaxe", cell(TOOL_ICONS, 2, 0))
icon("tool_rod", cell(TOOL_ICONS, 7, 0))
icon("tool_hoe", cell(TOOL_ICONS, 5, 0))
for name, im in handmade.icons().items():
    icon(name, im)

# ================================================================ постройки и предметы

save("house", crop_opaque(load("Buildings", "Buildings", "Houses", "Wood", "House_1_Wood_Base_Blue.png")))
save("house_red", crop_opaque(load("Buildings", "Buildings", "Houses", "Wood", "House_3_Wood_Base_Red.png")))
save("well", crop_opaque(load("Outdoor decoration", "Well.png")))
save("windmill", crop_opaque(load("Buildings", "Buildings", "Unique_Buildings", "Windmill", "Windmill.png")))
save("greenhouse", crop_opaque(load("Buildings", "Buildings", "Unique_Buildings", "Greenhouse", "GreenHouse_Wood.png")))
save("tent", crop_opaque(load("Buildings", "Buildings", "Tent", "Tent_Small.png")))

chest = load("Buildings", "House_Decor", "Chest_Anim.png")
save("chest_anim", chest, anchor=foot_anchor(chest.crop((0, 0, 16, 16))), extra={"frame": 16})
gchest = load("Buildings", "House_Decor", "Golden_Chest_Anim.png")
save("chest_gold_anim", gchest, anchor=foot_anchor(gchest.crop((0, 0, 16, 16))), extra={"frame": 16})
jewel = load("Buildings", "House_Decor", "Golden_Jeweled_Chest_Anim.png")
save("chest_royal_anim", jewel.crop((0, 0, 96, 16)), anchor=foot_anchor(jewel.crop((0, 0, 16, 16))), extra={"frame": 16})
fountain = load("Outdoor decoration", "Outdoor_Decor_Animations", "Other_Animations", "Fountain_Anim.png")
save("fountain_anim", fountain, anchor=foot_anchor(fountain.crop((0, 0, 32, 48))), extra={"frame": 32})
smoke = load("Buildings", "House_Decor", "Chimney_smoke_Anim.png")
save("smoke_anim", smoke, anchor=[0.5, 0.0], extra={"frame": 32})
campfire = load("Outdoor decoration", "Outdoor_Decor_Animations", "Other_Animations", "Campfire_Anim.png")
save("campfire_anim", campfire, anchor=foot_anchor(campfire.crop((0, 0, 32, 32))), extra={"frame": 32})
torch = load("Outdoor decoration", "Outdoor_Decor_Animations", "Other_Animations", "Torch_Anim.png")
save("torch_anim", torch, anchor=foot_anchor(torch.crop((0, 0, 32, 32))), extra={"frame": 32})
fish = swap(load("Tiles", "Water", "Fish_Animated_Tile.png"), [])
_fp = fish.load()
for _y in range(fish.height):
    for _x in range(fish.width):
        if _fp[_x, _y][:3] == hexc("#0095e9"):
            _fp[_x, _y] = (0, 0, 0, 0)
save("fish_anim", fish, anchor=[0.5, 0.5], extra={"frame": 16})
for name, shade in (("swamp", "#16301f"), ("lava", "#5a1006"), ("star", "#140e36"), ("ice", "#16324e"), ("sea", "#004a6a")):
    save(f"fish_{name}_anim", swap(fish, [("#006da8", shade)]), anchor=[0.5, 0.5], extra={"frame": 16})
lily_anim = load("Outdoor decoration", "Outdoor_Decor_Animations", "Water_Decor_Animations", "Water_Plants", "Lillypad_Green_1_Anim.png")
save("lily_anim", lily_anim, anchor=[0.5, 0.5], extra={"frame": 16})
save("beehive", crop_opaque(load("Animals", "Bee", "Bee_Nest.png").crop((0, 24, 16, 48))))
save("beehive_full", crop_opaque(load("Animals", "Bee", "Bee_Nest.png").crop((16, 24, 32, 48))))
save("hay", crop_opaque(load("Outdoor decoration", "Hay_Bales.png").crop((16, 0, 48, 16))))
save("barrel", crop_opaque(load("Outdoor decoration", "barrels.png").crop((0, 0, 16, 32))))
save("scarecrow", crop_opaque(load("Outdoor decoration", "Scarecrows.png").crop((0, 0, 32, 32))))
save("basket", crop_opaque(load("Outdoor decoration", "Picnic_Basket.png").crop((0, 0, 16, 16))))
save("boat", crop_opaque(load("Outdoor decoration", "Boat.png")))

# Ворота в изгороди: кадры от закрытых к открытым (по 80x32).
gate = load("Outdoor decoration", "Outdoor_Decor_Animations", "Other_Animations", "Fence_Big_Gate.png")
gate_frames = [gate.crop((c * 80, 0, (c + 1) * 80, 32)) for c in range(3)] + \
              [gate.crop((c * 80, 32, (c + 1) * 80, 64)) for c in range(3)]
save("gate_anim", stack(gate_frames), anchor=foot_anchor(gate_frames[0]), extra={"frame": 80})
vgate = load("Outdoor decoration", "Outdoor_Decor_Animations", "Other_Animations", "Fence_Big_Gate_Vertical.png")
save("gate_v_anim", vgate, anchor=foot_anchor(vgate.crop((0, 0, 32, 80))), extra={"frame": 32})
stone_gate = lum_map(stack(gate_frames), ["#1a1a24", "#3c4258", "#6c7c9d", "#a8b4cc", "#dfe6f0"],
                     mask=lambda p: p[:3] != hexc(OUTLINE))
save("gate_stone_anim", stone_gate, anchor=foot_anchor(gate_frames[0]), extra={"frame": 80})
royal_gate = lum_map(stack(gate_frames), ["#3a1e06", "#9c4a00", "#ed7614", "#ffc825", "#fff3b0"],
                     mask=lambda p: p[:3] != hexc(OUTLINE))
save("gate_gold_anim", royal_gate, anchor=foot_anchor(gate_frames[0]), extra={"frame": 80})
signs = load("Outdoor decoration", "Signs.png")
save("sign_right", crop_opaque(signs.crop((16, 0, 32, 32))))
save("sign_left", crop_opaque(signs.crop((32, 0, 48, 32))))
save("sign", crop_opaque(signs.crop((0, 0, 16, 32))))

# ================================================================ частицы и мелочи

save("fx_leaf", crop_opaque(load("Trees", "Oak_Leaf_Particle.png")), anchor=[0.5, 0.5])
save("fx_leaf_birch", crop_opaque(load("Trees", "Birch_Leaf_Particle.png")), anchor=[0.5, 0.5])
save("fx_needle", crop_opaque(load("Trees", "Spruce_Needle_Particle.png")), anchor=[0.5, 0.5])
clouds = load("Weather effects", "Clouds.png")
save("cloud_shadow", crop_opaque(clouds.crop((0, 0, 64, 64))), anchor=[0.5, 0.5])
save("cloud_shadow2", crop_opaque(clouds.crop((64, 0, 128, 64))), anchor=[0.5, 0.5])

# ================================================================ нарисованные вручную

for name, im in handmade.sprites().items():
    save(name, im)

with open(os.path.join(OUT, "sp_manifest.json"), "w") as f:
    json.dump(manifest, f, indent=1, sort_keys=True)
print(f"{len(os.listdir(OUT))} files written to {OUT}")
