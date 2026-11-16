#!/usr/bin/env python3
"""Картинки достижений Game Center (512x512): иконка игры в круге и обод цвета ступени.
Ступени: 1 бронза, 2 серебро, 3 золото, 4-5 платина; трофеи гостиной - фиолетовый обод.
Запуск: python3 tools/appstore/make_gc_images.py (нужен Pillow)."""
import os
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(HERE, "gamecenter")
RIMS = {"tier1": ("#c9824a", "#7a4a22"), "tier2": ("#e4e8ee", "#8a94a3"), "tier3": ("#ffd54a", "#b07a12"),
        "tier4": ("#bff4ff", "#4aa3c8"), "trophy": ("#d6a8ff", "#6a3aa8")}
S = 512


def badge(top, bottom):
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    grad = Image.new("RGBA", (S, S))
    t, b = Image.new("RGB", (1, 1), top).getpixel((0, 0)), Image.new("RGB", (1, 1), bottom).getpixel((0, 0))
    d = ImageDraw.Draw(grad)
    for y in range(S):
        k = y / (S - 1)
        d.line([(0, y), (S, y)], fill=tuple(int(t[i] + (b[i] - t[i]) * k) for i in range(3)) + (255,))
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).ellipse([8, 8, S - 8, S - 8], fill=255)
    img.paste(grad, (0, 0), mask)
    icon = Image.open(os.path.join(ROOT, "godot/assets/app_icon.png")).convert("RGBA").resize((400, 400), Image.LANCZOS)
    m2 = Image.new("L", (400, 400), 0)
    ImageDraw.Draw(m2).ellipse([0, 0, 399, 399], fill=255)
    img.paste(icon, (56, 56), m2)
    ImageDraw.Draw(img).ellipse([54, 54, S - 54, S - 54], outline=(255, 255, 255, 200), width=4)
    return img


os.makedirs(OUT, exist_ok=True)
for name, (top, bottom) in RIMS.items():
    badge(top, bottom).save(os.path.join(OUT, name + ".png"), optimize=True)
    print(name)
