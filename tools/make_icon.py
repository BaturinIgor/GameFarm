"""Рисует иконку приложения 1024x1024: поляна, дерево, кирка и алмаз."""
import math
import random
import sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

FONT = "/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf"
SIZE = 1024


def emoji(ch, px):
    font = ImageFont.truetype(FONT, 109)
    tmp = Image.new("RGBA", (160, 160), (0, 0, 0, 0))
    ImageDraw.Draw(tmp).text((10, 10), ch, font=font, embedded_color=True)
    tmp = tmp.crop(tmp.getbbox())
    scale = px / max(tmp.size)
    return tmp.resize((max(1, int(tmp.width * scale)), max(1, int(tmp.height * scale))), Image.LANCZOS)


def paste(base, img, cx, cy, shadow=True):
    x, y = int(cx - img.width / 2), int(cy - img.height / 2)
    if shadow:
        sh = Image.new("RGBA", base.size, (0, 0, 0, 0))
        mask = img.split()[3].point(lambda a: int(a * 0.35))
        black = Image.new("RGBA", img.size, (20, 40, 10, 255))
        sh.paste(black, (x + 14, y + 22), mask)
        sh = sh.filter(ImageFilter.GaussianBlur(14))
        base.alpha_composite(sh)
    base.alpha_composite(img, (x, y))


img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 255))
d = ImageDraw.Draw(img)
top, bottom = (120, 205, 255), (126, 196, 96)
for y in range(SIZE):
    t = min(1, max(0, (y - 380) / 140))
    c = tuple(int(top[i] * (1 - t) + bottom[i] * t) for i in range(3))
    d.line([(0, y), (SIZE, y)], fill=c + (255,))
d.ellipse([-200, 430, 1224, 1400], fill=(110, 186, 84, 255))
rnd = random.Random(3)
for _ in range(260):
    x, y = rnd.randint(0, SIZE), rnd.randint(520, SIZE)
    d.line([(x, y), (x + rnd.randint(-4, 4), y - rnd.randint(10, 22))], fill=(84, 150, 66, 255), width=4)


paste(img, emoji("🌳", 560), 360, 450)
paste(img, emoji("🪨", 300), 760, 760)
paste(img, emoji("💎", 190), 800, 610)
paste(img, emoji("⛏️", 330), 610, 690)
paste(img, emoji("🍎", 130), 470, 880)
paste(img, emoji("🐕", 210), 200, 770)

img.convert("RGB").save(sys.argv[1])
print("ok", sys.argv[1])
