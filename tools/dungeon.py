#!/usr/bin/env python3
"""Арены подземелий: стены и пол из Pixel Crawler, перекрашенные под каждое подземелье.

    python3 tools/dungeon.py <папка с паками> <папка спрайтов> <папка раскладок>

Пишет sp_ground_d*.png и layout_d*.json. Спрайты для арен (колонны, факелы,
портал) отдаёт props() - их сохраняет sprites.py.
"""
import json
import os
import random
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from handmade import MAT, Canvas, hexc  # noqa: E402

T = 16
PT = 32
W, H = 20, 26
WALL_ROWS = 3
OUTLINE = (14, 7, 27, 255)
PC = ("Pixel Crawler - Free Pack 2", "Pixel Crawler - Free Pack")


def pc(src, *parts):
    return Image.open(os.path.join(src, *PC, *parts)).convert("RGBA")


def lum(c):
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def recolor(im, ramp):
    """Перекраска по яркости в палитру подземелья."""
    stops = [hexc(c) for c in ramp]
    px = im.load()
    out = im.copy()
    op = out.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            t = min(1, lum((r, g, b)) / 140)
            f = t * (len(stops) - 1)
            i = min(int(f), len(stops) - 2)
            k = f - i
            c0, c1 = stops[i], stops[i + 1]
            op[x, y] = tuple(round(c0[j] + (c1[j] - c0[j]) * k) for j in range(3)) + (a,)
    return out


THEMES = {
    "dSlime": dict(floor=["#0c1a12", "#173a24", "#24563a", "#3a7a52"], wall=["#08120c", "#16301e", "#2a5236", "#4a7a52"]),
    "dCrypt": dict(floor=["#121018", "#24202e", "#3a3448", "#585070"], wall=["#0c0a12", "#201c2a", "#3a3448", "#6a6280"]),
    "dOrc": dict(floor=["#1a120a", "#3a2614", "#5a3c20", "#7a5630"], wall=["#120c06", "#2e1e10", "#4e341c", "#7a5630"]),
    "dFrost": dict(floor=["#0a1424", "#1a3456", "#2e5a8a", "#6a9ad0"], wall=["#081020", "#16284a", "#2e4e80", "#8ab4e8"]),
    "dFire": dict(floor=["#1a0806", "#3a120a", "#5e2210", "#8a3a14"], wall=["#120404", "#2e0c08", "#5a1a0c", "#a03c14"]),
}

# Что разбросано по арене (спрайты из sprites.py)
DECOR = {
    "dSlime": ["rubble", "dg_slime_puddle", "mushroom_tiny_blue", "rubble"],
    "dCrypt": ["dg_bones", "dg_grave", "rubble", "dg_bones"],
    "dOrc": ["dg_bones", "hm_crate", "rubble", "logs_pile"],
    "dFrost": ["chunk_ice", "rubble", "dg_bones", "chunk_ice"],
    "dFire": ["rubble", "dg_bones", "chunk_ruby", "rubble"],
}
BANNER = {"dSlime": "dg_banner_green", "dCrypt": "dg_banner_blue", "dOrc": "dg_banner_red",
          "dFrost": "dg_banner_blue", "dFire": "dg_banner_red"}


# ================================================================ спрайты

MAT.update({
    "pillar": ("#262230", "#4a4458", "#7a7090"),
    "flame": ("#b8320e", "#ff9a1f", "#ffe070"),
    "bonemat": ("#a89a88", "#e8e0d0", "#ffffff"),
    "portal": ("#3a1a7a", "#8a4ae8", "#e0c0ff"),
    "slimepud": ("#1e6f20", "#4fc83a", "#a8f070"),
})


def pillar():
    c = Canvas(30, 44)
    c.rect(3, 8, 26, 41, "pillar")
    c.rect(0, 2, 29, 9, "pillar")
    c.rect(0, 38, 29, 43, "pillar")
    im = c.render()
    p = im.load()
    for y in range(12, 38, 6):
        for x in range(5, 25):
            p[x, y] = hexc("#262230")
    return im


def torch():
    c = Canvas(10, 20)
    c.rect(3, 9, 6, 19, "board")
    c.ellipse(4.5, 6, 4, 5.5, "flame")
    return c.render()


def bones():
    c = Canvas(20, 10)
    c.line(2, 7, 12, 3, "bonemat", 2)
    c.line(8, 8, 18, 6, "bonemat", 2)
    c.disc(14, 4, 2.5, "bonemat")
    im = c.render()
    p = im.load()
    p[13, 4] = hexc("#0e071b")
    return im


def grave():
    c = Canvas(14, 18)
    c.ellipse(7, 6, 6, 5.5, "pillar")
    c.rect(1, 6, 12, 17, "pillar")
    im = c.render()
    p = im.load()
    for y in range(5, 12):
        p[7, y] = hexc("#262230")
    for x in range(5, 10):
        p[x, 7] = hexc("#262230")
    return im


def puddle():
    c = Canvas(24, 10)
    c.ellipse(12, 5, 11.5, 4.5, "slimepud")
    return c.render()


def portal():
    c = Canvas(40, 24)
    c.ellipse(20, 12, 19.5, 11.5, "portal")
    c.ellipse(20, 12, 13, 7, "violet")
    c.ellipse(20, 12, 7, 3.5, "pearl")
    return c.render(light=False)


def props(src):
    dp = pc(src, "Environment", "Props", "Static", "Dungeon_Props.png")
    def opaque(im):
        box = im.getchannel("A").getbbox()
        return im.crop(box) if box else im
    return {
        "dg_pillar": pillar(),
        "dg_torch": torch(),
        "dg_bones": bones(),
        "dg_grave": grave(),
        "dg_slime_puddle": puddle(),
        "dg_portal": portal(),
        "dg_banner_red": opaque(dp.crop((64, 64, 80, 96))),
        "dg_banner_blue": opaque(dp.crop((80, 64, 96, 96))),
        "dg_banner_green": opaque(dp.crop((96, 64, 112, 96))),
        "dg_coffin": opaque(dp.crop((112, 0, 128, 24))),
    }


# ================================================================ арены

def build(src, did, theme):
    tiles = pc(src, "Environment", "Tilesets", "Dungeon_Tiles.png")
    floor_tile = recolor(tiles.crop((96, 16, 128, 48)), theme["floor"])
    wall_strip = recolor(tiles.crop((16, 0, 32, 48)), theme["wall"])
    img = Image.new("RGBA", (W * T, H * T))
    for y in range(WALL_ROWS * T, (H - 1) * T, 32):
        for x in range(T, (W - 1) * T, 32):
            img.alpha_composite(floor_tile.crop((0, 0, min(32, (W - 1) * T - x), min(32, (H - 1) * T - y))), (x, y))
    for x in range(T, (W - 1) * T, T):
        img.alpha_composite(wall_strip, (x, 0))
    dark = hexc(theme["wall"][0])
    mid = hexc(theme["wall"][1])
    px = img.load()
    for y in range(H * T):
        for x in list(range(T)) + list(range((W - 1) * T, W * T)):
            px[x, y] = OUTLINE if x in (T - 1, (W - 1) * T) else (dark if (x // 4 + y // 4) % 2 else mid)
    for x in range(W * T):
        for y in range((H - 1) * T, H * T):
            px[x, y] = OUTLINE if y == (H - 1) * T else (dark if (x // 4 + y // 4) % 2 else mid)
    # тень от стены
    for x in range(T, (W - 1) * T):
        for dy, k in ((0, 0.55), (1, 0.7), (2, 0.85)):
            y = WALL_ROWS * T + dy
            r, g, b, a = px[x, y]
            px[x, y] = (int(r * k), int(g * k), int(b * k), a)
    # затемнение по краям: свет от центра
    cx, cy = W * T / 2, H * T * 0.55
    for y in range(WALL_ROWS * T, (H - 1) * T):
        for x in range(T, (W - 1) * T):
            d = ((x - cx) / (W * T * 0.6)) ** 2 + ((y - cy) / (H * T * 0.6)) ** 2
            k = max(0.55, 1 - d * 0.45)
            r, g, b, a = px[x, y]
            px[x, y] = (int(r * k), int(g * k), int(b * k), a)

    grid = [["L"] * W for _ in range(H)]
    for r in range(H):
        for c in range(W):
            if r < WALL_ROWS or r == H - 1 or c in (0, W - 1):
                grid[r][c] = "B"
    props = []

    def place(name, x, y, block=()):
        props.append([name, round(x * PT), round((H - y) * PT), 0])
        for c, r in block:
            grid[r][c] = "B"

    # колонны
    for c, r in ((4, 8), (14, 8), (4, 17), (14, 17)):
        place("dg_pillar", c + 1.0, r + 2.0, [(c, r + 1), (c + 1, r + 1)])
    # факелы и знамёна на стене
    for x in (3.5, 16.5):
        place("dg_torch", x, 2.4)
    for x in (7.0, 13.0):
        place(BANNER[did], x, 2.6)
    rng = random.Random(sum(ord(ch) for ch in did))
    decor = DECOR[did]
    spots = [(2.5, 6.0), (17.5, 6.5), (2.6, 13.0), (17.4, 12.5), (8.0, 21.5), (12.5, 22.0), (2.5, 22.5), (17.5, 22.5),
             (9.0, 5.2), (11.5, 14.5)]
    for i, (x, y) in enumerate(spots):
        place(decor[i % len(decor)], x + rng.uniform(-0.3, 0.3), y + rng.uniform(-0.3, 0.3))
    if did == "dCrypt":
        place("dg_coffin", 6.5, 13.0, [(6, 12)])
        place("dg_coffin", 13.5, 13.0, [(13, 12)])

    spawns = [(4, 5), (10, 5), (15, 5), (7, 11), (13, 11), (3, 13), (16, 13), (8, 15), (12, 15), (4, 20), (16, 20), (10, 19)]
    slots = [[f"spawn_{i}", round((c + 0.5) * PT), round((H - r - 0.5) * PT)] for i, (c, r) in enumerate(spawns)]
    data = dict(
        id=did, w=W, h=H, cell=PT, edge="void",
        rows=["".join(row) for row in grid],
        base=[round(W / 2 * PT), round(2.5 * PT)],
        gates=[], spots=[], props=props, border=[], farm=[], stations=[], slots=slots,
    )
    return img, data


def main():
    src, sprites_dir, layouts_dir = sys.argv[1], sys.argv[2], sys.argv[3]
    for did, theme in THEMES.items():
        img, data = build(src, did, theme)
        img.save(os.path.join(sprites_dir, f"sp_ground_{did}.png"))
        with open(os.path.join(layouts_dir, f"layout_{did}.json"), "w") as f:
            json.dump(data, f, separators=(",", ":"))
        print(f"{did}: {len(data['props'])} props")


if __name__ == "__main__":
    main()
