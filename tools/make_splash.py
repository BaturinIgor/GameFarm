"""Картинка экрана загрузки (boot splash) для Godot-версии: иконка игры и название.

    python3 tools/make_splash.py <AppIcon.png> <Nunito-900.ttf> <out.png>

Фон прозрачный, его цвет задаёт application/boot_splash/bg_color. Картинка в масштабе 3x
(390x500 точек): Godot растягивает её по ширине экрана, сцена scenes/splash.tscn
показывает её так же и рисует под названием полоску загрузки (см. scripts/splash.gd).
"""
import sys

from PIL import Image, ImageDraw, ImageFont

S = 3  # пикселей в точке
W, H = 390, 500  # размер в точках, менять вместе с scripts/splash.gd
ICON, ICON_TOP = 150, 28
TITLE_SIZE = 62
LINES = [("Harvest", 236), ("Hollow", 302)]  # строка и центр по высоте
OUTLINE_W, SHADOW = 5, 5  # обводка и тень вниз, в точках

OUTLINE = (43, 26, 15, 255)  # UiKit.OUTLINE
SHADOW_C = (43, 26, 15, 110)
GOLD = [(255, 247, 214), (255, 217, 90), (242, 169, 42)]  # верх, середина, низ


def gradient(w, h, stops):
    """Вертикальный градиент по трём цветам."""
    img = Image.new("RGBA", (w, h))
    px = img.load()
    for y in range(h):
        t = y / max(h - 1, 1)
        a, b, k = (stops[0], stops[1], t * 2) if t < 0.5 else (stops[1], stops[2], t * 2 - 1)
        c = tuple(int(a[i] + (b[i] - a[i]) * k) for i in range(3)) + (255,)
        for x in range(w):
            px[x, y] = c
    return img


def rounded(size, radius):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255)
    return m


def draw_icon(canvas, icon_path):
    side = ICON * S
    border = 4 * S
    radius = int(side * 0.2237)
    x = (W * S - side) // 2
    y = ICON_TOP * S
    d = ImageDraw.Draw(canvas)
    # Тень и тёмная рамка как у кнопок UiKit
    d.rounded_rectangle((x - border, y - border + SHADOW * S, x + side + border, y + side + border + SHADOW * S),
                        radius=radius + border, fill=SHADOW_C)
    d.rounded_rectangle((x - border, y - border, x + side + border, y + side + border),
                        radius=radius + border, fill=OUTLINE)
    icon = Image.open(icon_path).convert("RGBA").resize((side, side), Image.LANCZOS)
    canvas.paste(icon, (x, y), rounded((side, side), radius))


def draw_title(canvas, font_path):
    font = ImageFont.truetype(font_path, TITLE_SIZE * S)
    stroke = OUTLINE_W * S
    for text, cy in LINES:
        cx = W * S // 2
        cy *= S
        layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
        # Тень, затем обводка
        d.text((cx, cy + SHADOW * S), text, font=font, anchor="mm", fill=SHADOW_C,
               stroke_width=stroke, stroke_fill=SHADOW_C)
        canvas.alpha_composite(layer)
        layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
        d.text((cx, cy), text, font=font, anchor="mm", fill=OUTLINE, stroke_width=stroke, stroke_fill=OUTLINE)
        canvas.alpha_composite(layer)
        # Заливка буквы золотым градиентом
        mask = Image.new("L", canvas.size, 0)
        ImageDraw.Draw(mask).text((cx, cy), text, font=font, anchor="mm", fill=255)
        box = mask.getbbox()
        if box:
            g = gradient(box[2] - box[0], box[3] - box[1], GOLD)
            fill = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
            fill.paste(g, box[:2])
            canvas.paste(fill, (0, 0), mask)


def main():
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    icon_path, font_path, out = sys.argv[1:]
    canvas = Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0))
    draw_icon(canvas, icon_path)
    draw_title(canvas, font_path)
    canvas.save(out, optimize=True)


if __name__ == "__main__":
    main()
