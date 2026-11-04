"""Лестница между этажами дома: сквозной пролёт через заднюю стену в этаж выше.
Рисунок свой (не из пака), поэтому лежит открыто в godot/assets/art.

    python3 tools/make_stairs.py godot/assets/art

hm_stair_flight.png - 32x84 пикселя (64x168 точек): сверху нижний край этажа выше (16 пикселей),
дальше 4 ряда задней стены (64 пикселя) и нижняя ступень на полу (4 пикселя).
hm_stair_boards.png - доски крест-накрест поверх пролёта, пока этаж выше или ниже не построен.
Размеры и места - в godot/scripts/world/features/home_feature.gd (_build_stairs).
"""
import os
import sys

from PIL import Image

OUTLINE = (14, 7, 27, 255)
W, H = 32, 84
SLAB = 16       # нижняя стена этажа выше
STEP = 8        # высота ступени


def hexc(s, a=255):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), a)


def shade(c, k):
    return (min(255, int(c[0] * k)), min(255, int(c[1] * k)), min(255, int(c[2] * k)), c[3])


def flight():
    im = Image.new("RGBA", (W, H))
    p = im.load()
    tread_hi, tread, riser, riser_lo = hexc("#dfa56c"), hexc("#c08850"), hexc("#8a5434"), hexc("#6e4426")
    string_hi, string, string_lo = hexc("#91533b"), hexc("#743f39"), hexc("#5a2f2a")
    steps = (H - 4) // STEP
    for y in range(H):
        # Ступени от нижней: проступь светлая, подступёнок тёмный. Чем выше, тем глубже в пролёте
        from_bottom = H - 1 - y
        i = from_bottom // STEP
        ly = from_bottom % STEP
        depth = 0.62 + 0.38 * (i / max(1, steps))
        for x in range(4, W - 4):
            if ly >= STEP - 3:
                c = tread_hi if ly == STEP - 1 else tread
            else:
                c = riser if ly > 1 else riser_lo
            # блик на кромке ступени и тень у тетив
            if ly == STEP - 1 and x in (4, W - 5):
                c = tread
            elif ly < STEP - 3 and x in (4, W - 5):
                c = riser_lo
            p[x, y] = shade(c, depth)
        # Тетивы по бокам с перилами
        for x in (0, 1, 2, 3, W - 4, W - 3, W - 2, W - 1):
            edge = x in (0, W - 1)
            inner = x in (3, W - 4)
            c = OUTLINE if edge else (string_lo if inner else (string_hi if x in (1, W - 2) else string))
            p[x, y] = c
    # Столбики перил на каждой второй ступени
    for i in range(0, steps + 1, 2):
        y = H - 1 - i * STEP - (STEP - 1)
        for x in (1, 2, W - 3, W - 2):
            for dy in (0, 1):
                if 0 <= y + dy < H:
                    p[x, y + dy] = hexc("#ffd870") if dy == 0 else hexc("#c8902a")
    # Проём в нижней стене этажа выше: тёмная кромка и тень от перекрытия на ступенях
    for y in range(SLAB):
        k = 0.55 + 0.45 * (y / SLAB)
        for x in range(4, W - 4):
            p[x, y] = shade(p[x, y], k)
    for x in range(W):
        p[x, 0] = OUTLINE
        p[x, SLAB] = shade(p[x, SLAB], 0.7) if 4 <= x < W - 4 else p[x, SLAB]
    # Нижняя ступень чуть шире, контур снизу
    for x in range(W):
        p[x, H - 1] = OUTLINE
    return im


def boards():
    """Две доски крест-накрест с гвоздями."""
    w, h = 32, 40
    im = Image.new("RGBA", (w, h))
    p = im.load()
    board, board_hi, board_lo = hexc("#a0603c"), hexc("#c88458"), hexc("#743f39")

    def plank(x0, y0, x1, y1):
        n = max(abs(x1 - x0), abs(y1 - y0))
        for t in range(n + 1):
            cx = x0 + (x1 - x0) * t / n
            cy = y0 + (y1 - y0) * t / n
            for d in range(-3, 4):
                x, y = int(round(cx)), int(round(cy + d))
                if 0 <= x < w and 0 <= y < h:
                    c = OUTLINE if abs(d) == 3 else (board_hi if d == -2 else (board_lo if d == 2 else board))
                    if p[x, y][3] == 0 or abs(d) < 3:
                        p[x, y] = c

    plank(1, 6, 30, 33)
    plank(1, 33, 30, 6)
    for x, y in ((4, 9), (27, 9), (4, 30), (27, 30), (15, 19)):
        p[x, y] = hexc("#c0c8d8")
    return im


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "godot/assets/art"
    os.makedirs(out, exist_ok=True)
    flight().save(os.path.join(out, "hm_stair_flight.png"))
    boards().save(os.path.join(out, "hm_stair_boards.png"))


if __name__ == "__main__":
    main()
