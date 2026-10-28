"""Перекраска мебели Pixel Crawler в тёплую палитру Cute Fantasy.

Тёмное серо-коричневое дерево переходит в рыжее дерево мира, чёрный контур
становится фиолетово-тёмным, остальные цвета чуть светлее и насыщеннее.
"""
import colorsys

from PIL import Image

OUTLINE = (14, 7, 27)
WOOD = [(0x3f, 0x28, 0x32), (0x74, 0x3f, 0x39), (0x91, 0x53, 0x3b), (0xb8, 0x6f, 0x50), (0xe4, 0xa6, 0x72), (0xf6, 0xca, 0x9f)]


def _lum(r, g, b):
    return 0.299 * r + 0.587 * g + 0.114 * b


def _ramp(t, stops):
    t = max(0.0, min(1.0, t))
    f = t * (len(stops) - 1)
    i = min(int(f), len(stops) - 2)
    k = f - i
    a, b = stops[i], stops[i + 1]
    return tuple(round(a[j] + (b[j] - a[j]) * k) for j in range(3))


def warm(im, lo=20, hi=150):
    """lo..hi - диапазон яркости дерева в исходнике, растягивается на всю тёплую шкалу."""
    im = im.convert("RGBA")
    out = im.copy()
    src = im.load()
    dst = out.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = src[x, y]
            if a == 0:
                continue
            if r + g + b < 40:
                dst[x, y] = OUTLINE + (a,)
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            deg = h * 360
            woodish = (deg <= 45 or deg >= 340) and s < 0.75 and v < 0.8
            if woodish:
                t = (_lum(r, g, b) - lo) / (hi - lo)
                dst[x, y] = _ramp(t, WOOD) + (a,)
            else:
                s2 = min(1, s * 1.18)
                v2 = min(1, v * 1.22 + 0.04)
                rr, gg, bb = colorsys.hsv_to_rgb(h, s2, v2)
                dst[x, y] = (round(rr * 255), round(gg * 255), round(bb * 255), a)
    return out
