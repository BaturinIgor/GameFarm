"""Мебель для дома, блюда кухни и прочие мелочи, нарисованные кодом в стиле пака."""
from PIL import Image

from handmade import MAT, Canvas, hexc

MAT.update({
    "furn": ("#4a2c1a", "#7a4a2c", "#a66a40"),
    "furnlight": ("#7a4a2c", "#a66a40", "#cf9460"),
    "sheet": ("#8fa8c8", "#dce8f6", "#ffffff"),
    "blanket": ("#6e1c2a", "#b0333f", "#e45e64"),
    "blanketblue": ("#1c3a6e", "#2f63b0", "#5e9ae4"),
    "pillow": ("#b8b0a0", "#efe8da", "#ffffff"),
    "glass": ("#3f6f96", "#86c0e6", "#dff4ff"),
    "rug": ("#5e1620", "#a12c38", "#cf4e58"),
    "rugtrim": ("#9c4a00", "#e9b030", "#ffe27a"),
    "gilt": ("#7a3a00", "#d29a24", "#ffe07a"),
    "paper": ("#c8b89a", "#f4ead2", "#ffffff"),
    "ceramic": ("#6a7ea8", "#c8d4ec", "#f6f9ff"),
    "crust": ("#8a4a1a", "#d0883a", "#f2c070"),
    "metal": ("#3c4258", "#7a8299", "#c0c8d8"),
    "stone": ("#3c3a44", "#6c6878", "#9c98a8"),
    "fire": ("#b8320e", "#ff7a1f", "#ffd060"),
    "pumpkin": ("#9c3a00", "#ed7614", "#ffb04a"),
    "snow": ("#9fb4cc", "#eef4fc", "#ffffff"),
    "slimeg": ("#1e6f20", "#4fc83a", "#a8f070"),
    "giftgreen": ("#1e6f50", "#33984b", "#5ac54f"),
    "stem": ("#3a4a1a", "#5a7a2a", "#8aaa3a"),
})


def bed():
    c = Canvas(32, 28)
    c.rect(2, 2, 29, 9, "furn")          # изголовье
    c.rect(3, 9, 28, 24, "sheet")        # матрас
    c.rect(5, 10, 13, 14, "pillow")
    c.rect(18, 10, 26, 14, "pillow")
    c.rect(3, 15, 28, 24, "blanket")     # одеяло
    c.rect(2, 24, 29, 26, "furn")        # изножье
    im = c.render()
    p = im.load()
    for x in range(4, 28):
        p[x, 16] = hexc("#e45e64")
    return im


def wardrobe():
    c = Canvas(24, 32)
    c.rect(1, 3, 22, 30, "furn")
    c.rect(0, 1, 23, 4, "furnlight")
    c.rect(3, 6, 11, 27, "furnlight")
    c.rect(12, 6, 20, 27, "furnlight")
    im = c.render()
    p = im.load()
    for y in range(6, 28):
        p[11, y] = hexc("#4a2c1a")
    for x, y in ((9, 16), (14, 16)):
        p[x, y] = hexc("#ffc825")
        p[x, y + 1] = hexc("#9c4a00")
    return im


def bookshelf():
    c = Canvas(24, 30)
    c.rect(1, 1, 22, 28, "furn")
    im = c.render()
    p = im.load()
    books = ["#c42430", "#2f63b0", "#33984b", "#ffc825", "#8a4ac8", "#e47a2a", "#e8e0d0"]
    k = 0
    for shelf_top in (3, 11, 19):
        for x in range(3, 21):
            if (x * 7 + shelf_top) % 9 == 0:
                continue
            col = hexc(books[k % len(books)])
            k += 1
            h = 6 if (x + shelf_top) % 3 else 5
            for y in range(shelf_top + (7 - h), shelf_top + 7):
                p[x, y] = col
        for x in range(2, 22):
            p[x, shelf_top + 7] = hexc("#4a2c1a")
    return im


def rug():
    c = Canvas(34, 18)
    c.ellipse(17, 9, 16.5, 8.5, "rugtrim")
    c.ellipse(17, 9, 14.5, 6.6, "rug")
    im = c.render(light=False)
    p = im.load()
    for x, y in ((17, 9), (11, 9), (23, 9), (17, 6), (17, 12)):
        p[x, y] = hexc("#ffe27a")
    return im


def painting():
    c = Canvas(18, 15)
    c.rect(0, 0, 17, 14, "gilt")
    im = c.render()
    p = im.load()
    for y in range(2, 13):
        for x in range(2, 16):
            if y < 8:
                p[x, y] = hexc("#8fd0ff") if y > 3 else hexc("#bfe6ff")
            elif (x - 9) ** 2 / 30 + (y - 12) ** 2 / 10 <= 1 or y > 10:
                p[x, y] = hexc("#33984b") if y < 11 else hexc("#1e6f50")
            else:
                p[x, y] = hexc("#5ac54f")
    for x, y in ((12, 4), (13, 4), (12, 5), (13, 5)):
        p[x, y] = hexc("#ffc825")
    return im


def clock():
    c = Canvas(14, 14)
    c.disc(7, 7, 6.5, "furn")
    c.disc(7, 7, 4.8, "paper")
    im = c.render()
    p = im.load()
    for y in range(4, 8):
        p[7, y] = hexc("#262b44")
    for x in range(7, 10):
        p[x, 7] = hexc("#262b44")
    return im


def window():
    c = Canvas(20, 20)
    c.rect(0, 0, 19, 19, "furnlight")
    c.rect(2, 2, 17, 17, "glass")
    im = c.render()
    p = im.load()
    for i in range(2, 18):
        p[i, 9] = hexc("#a66a40")
        p[i, 10] = hexc("#7a4a2c")
        p[9, i] = hexc("#a66a40")
        p[10, i] = hexc("#7a4a2c")
    for k in range(4):
        p[4 + k, 6 - k] = hexc("#ffffff")
        p[13 + k, 15 - k] = hexc("#dff4ff")
    return im


def calendar():
    c = Canvas(16, 17)
    c.rect(1, 3, 14, 16, "paper")
    c.rect(1, 3, 14, 6, "red")
    im = c.render()
    p = im.load()
    for x in (4, 11):
        p[x, 1] = hexc("#3c4258")
        p[x, 2] = hexc("#7a8299")
    for y in (9, 12, 14):
        for x in range(3, 13, 3):
            p[x, y] = hexc("#7a8299")
    p[9, 12] = hexc("#c42430")
    return im


def stove_icon():
    c = Canvas(16, 16)
    c.rect(2, 3, 13, 14, "metal")
    c.rect(4, 8, 11, 12, "dark")
    im = c.render()
    p = im.load()
    for x, y in ((6, 11), (7, 10), (8, 11), (9, 10), (7, 11), (8, 10)):
        p[x, y] = hexc("#ff7a1f")
    p[7, 9] = hexc("#ffd060")
    return im


def bowl(soup, extra=None):
    c = Canvas(16, 16)
    c.ellipse(8, 9, 7, 3, "ceramic")
    c.rect(2, 9, 13, 11, "ceramic")
    c.ellipse(8, 11.5, 5.2, 2.6, "ceramic")
    im = c.render()
    p = im.load()
    for y in range(7, 11):
        for x in range(2, 14):
            if ((x + 0.5 - 8) / 6) ** 2 + ((y + 0.5 - 9) / 2.2) ** 2 <= 1:
                p[x, y] = hexc(soup[0] if y > 8 else soup[1])
    for x, y in (extra or []):
        p[x, y] = hexc("#5ac54f")
    # пар
    for x, y in ((6, 4), (6, 3), (7, 2), (10, 4), (10, 3), (9, 2)):
        p[x, y] = (255, 255, 255, 150)
    return im


def pie():
    c = Canvas(16, 16)
    c.ellipse(8, 9, 7, 4.5, "crust")
    im = c.render()
    p = im.load()
    for y in range(6, 12):
        for x in range(3, 13):
            if ((x + 0.5 - 8) / 5.5) ** 2 + ((y + 0.5 - 9) / 3) ** 2 <= 1:
                p[x, y] = hexc("#c42430") if (x + y) % 3 else hexc("#f2c070")
    return im


def juice():
    c = Canvas(16, 16)
    c.rect(4, 3, 11, 14, "glass")
    im = c.render()
    p = im.load()
    for y in range(6, 14):
        for x in range(5, 11):
            p[x, y] = hexc("#7a2a9a") if y > 7 else hexc("#a64dd6")
    for y in range(4, 13):
        p[5, y] = hexc("#e6b3ff") if y > 7 else hexc("#dff4ff")
    return im


def popcorn():
    c = Canvas(16, 16)
    c.rect(4, 7, 11, 14, "red")
    im = c.render()
    p = im.load()
    for y in range(7, 15):
        for x in (6, 9):
            p[x, y] = hexc("#ffffff")
    for x, y in ((4, 5), (5, 4), (6, 5), (7, 3), (8, 4), (9, 3), (10, 4), (11, 5), (5, 6), (7, 5), (9, 5), (11, 6), (6, 3), (8, 2)):
        p[x, y] = hexc("#fff3b0")
    for x, y in ((4, 4), (6, 2), (8, 1), (10, 2), (12, 4), (3, 6), (12, 6)):
        p[x, y] = hexc("#0e071b")
    return im


def pen_sign():
    c = Canvas(16, 16)
    c.rect(7, 8, 8, 15, "furn")
    c.rect(1, 2, 14, 9, "furnlight")
    im = c.render()
    p = im.load()
    for x, y in ((5, 5), (6, 4), (7, 5), (8, 5), (9, 4), (10, 5), (6, 6), (9, 6)):
        p[x, y] = hexc("#4a2c1a")
    return im


def quest_board():
    c = Canvas(34, 34)
    c.rect(4, 16, 6, 33, "furn")
    c.rect(27, 16, 29, 33, "furn")
    c.rect(1, 3, 32, 22, "furnlight")
    c.rect(0, 1, 33, 3, "furn")
    c.rect(4, 6, 12, 15, "paper")
    c.rect(15, 5, 22, 13, "paper")
    c.rect(24, 7, 30, 17, "paper")
    c.rect(13, 15, 20, 20, "paper")
    im = c.render()
    p = im.load()
    for x, y in ((8, 6), (18, 5), (27, 7), (16, 15)):
        p[x, y] = hexc("#c42430")
    for y in (8, 10, 12):
        for x in range(5, 11):
            if (x + y) % 3:
                p[x, y] = hexc("#7a8299")
    for y in (7, 9, 11):
        for x in range(16, 21):
            if (x + y) % 4:
                p[x, y] = hexc("#7a8299")
    # череп на объявлении об охоте
    for x, y in ((26, 10), (27, 10), (28, 10), (26, 11), (28, 11), (27, 12)):
        p[x, y] = hexc("#3c4258")
    return im


def slime_gel():
    c = Canvas(16, 16)
    c.ellipse(8, 10, 6.5, 4.5, "leaf")
    c.disc(8, 6.5, 3.2, "leaf")
    im = c.render()
    p = im.load()
    for x, y in ((6, 5), (7, 5), (5, 8)):
        p[x, y] = hexc("#c8f0a0")
    return im


def bone():
    c = Canvas(16, 16)
    c.line(4, 12, 12, 4, "pillow", width=2.2)
    for x, y in ((3, 11), (5, 13), (11, 3), (13, 5)):
        c.disc(x, y, 1.6, "pillow")
    return c.render()


def armor():
    c = Canvas(16, 16)
    c.rect(3, 3, 12, 13, "metal")
    c.rect(1, 3, 3, 7, "metal")
    c.rect(12, 3, 14, 7, "metal")
    im = c.render()
    p = im.load()
    for y in range(5, 13):
        p[7, y] = hexc("#3c4258")
    for x in range(5, 11):
        p[x, 3] = hexc("#262b44")
    return im


def heart():
    c = Canvas(16, 16)
    c.disc(5.5, 6, 3.4, "red")
    c.disc(10.5, 6, 3.4, "red")
    poly = [(2.2, 7), (13.8, 7), (8, 14)]
    from handmade import _inside
    for y in range(16):
        for x in range(16):
            if _inside(x + 0.5, y + 0.5, poly):
                c.put(x, y, "red")
    im = c.render()
    im.load()[5, 4] = hexc("#ffb0b8")
    return im


def cards_icon():
    c = Canvas(16, 16)
    c.rect(2, 4, 9, 14, "paper")
    c.rect(6, 1, 13, 11, "blanketblue")
    im = c.render()
    p = im.load()
    for x, y in ((9, 4), (9, 5), (8, 6), (9, 6), (10, 6), (9, 7), (8, 8), (10, 8)):
        p[x, y] = hexc("#ffc825")
    return im


# ---------------------------------------------------------------- ивенты

def gift(body):
    c = Canvas(14, 14)
    c.rect(1, 5, 12, 13, body)          # коробка
    c.rect(0, 3, 13, 5, body)           # крышка
    im = c.render()
    p = im.load()
    gold, gold_dark = hexc("#ffc825"), hexc("#ed7614")
    for y in range(3, 14):
        p[6, y] = gold
        p[7, y] = gold_dark
    for x in range(0, 14):
        if p[x, 4][3]:
            p[x, 4] = gold
    # бант
    for x, y in ((4, 1), (5, 2), (4, 2), (9, 1), (8, 2), (9, 2), (6, 2), (7, 2)):
        p[x, y] = gold
    for x, y in ((3, 1), (3, 2), (10, 1), (10, 2), (4, 0), (9, 0)):
        p[x, y] = hexc("#0e071b")
    return im


def gift_paper():
    c = Canvas(18, 8)
    for x, y, mat in ((2, 5, "red"), (6, 6, "blanketblue"), (11, 5, "giftgreen"), (15, 6, "red"), (8, 3, "gold")):
        c.rect(x, y, x + 1, y + 1, mat)
    return c.render(light=False)


def sandcastle():
    c = Canvas(28, 26)
    c.rect(3, 12, 24, 24, "sand")        # стена
    c.rect(1, 6, 7, 24, "sand")          # левая башня
    c.rect(20, 6, 26, 24, "sand")        # правая башня
    c.rect(10, 4, 17, 24, "sand")        # центр
    for x in (1, 4, 7, 20, 23, 26):
        c.rect(x, 4, x, 5, "sand")
    for x in (10, 12, 14, 17):
        c.rect(x, 2, x, 3, "sand")
    im = c.render()
    p = im.load()
    for y in range(17, 25):                # ворота
        for x in range(12, 16):
            if y > 17 or x in (13, 14):
                p[x, y] = hexc("#7a4a2c")
    for x, y in ((4, 11), (23, 11), (13, 9), (14, 9)):  # окошки
        p[x, y] = hexc("#7a4a2c")
        p[x, y + 1] = hexc("#7a4a2c")
    # флажок
    for y in range(0, 4):
        p[13, y] = hexc("#3c4258")
    for x, y in ((14, 0), (15, 0), (16, 1), (14, 1), (15, 1)):
        p[x, y] = hexc("#c42430")
    for x, y in ((6, 20), (21, 19), (17, 14)):   # ракушки
        p[x, y] = hexc("#ffb8dc")
    return im


def sand_pile():
    c = Canvas(18, 8)
    c.ellipse(9, 7, 8.5, 5, "sand")
    return c.render()


def jack_lantern():
    c = Canvas(18, 16)
    c.ellipse(9, 9.5, 8.5, 6.5, "pumpkin")
    c.rect(8, 1, 9, 3, "stem")
    im = c.render()
    p = im.load()
    for y in range(5, 15):                 # дольки
        for x in (5, 12):
            if p[x, y][3] and p[x, y] != hexc("#0e071b"):
                p[x, y] = hexc("#c45a10")
    glow, deep = hexc("#ffe27a"), hexc("#ffb04a")
    for x, y in ((5, 7), (6, 7), (6, 8), (11, 7), (12, 7), (11, 8)):   # глаза
        p[x, y] = glow
    for x in range(5, 14):                                              # улыбка
        p[x, 11] = glow if x % 2 else deep
    for x in (6, 8, 10, 12):
        p[x, 12] = glow
    return im


def snowman():
    c = Canvas(18, 26)
    c.disc(9, 19.5, 6.5, "snow")
    c.disc(9, 10.5, 4.8, "snow")
    c.rect(5, 1, 12, 5, "dark")          # шляпа
    c.rect(3, 5, 14, 6, "dark")
    im = c.render()
    p = im.load()
    for x, y in ((7, 9), (11, 9)):
        p[x, y] = hexc("#262b44")
    for x in (9, 10, 11):
        p[x, 11] = hexc("#ed7614")
    for y in (16, 19, 22):
        p[9, y] = hexc("#262b44")
    for x in range(5, 13):                # шарф
        p[x, 14] = hexc("#c42430")
    p[11, 15] = hexc("#c42430")
    p[11, 16] = hexc("#891e2b")
    return im


def slime_lamp():
    c = Canvas(14, 18)
    c.rect(2, 4, 11, 17, "glass")
    c.rect(3, 9, 10, 16, "slimeg")
    c.rect(1, 1, 12, 3, "metal")
    im = c.render()
    p = im.load()
    for x, y in ((5, 11), (8, 13), (6, 14)):
        p[x, y] = hexc("#e8ffd0")
    p[3, 6] = hexc("#ffffff")
    p[3, 7] = hexc("#dff4ff")
    return im


def slime_blob():
    c = Canvas(12, 10)
    c.ellipse(6, 7, 5.5, 3.5, "slimeg")
    c.disc(6, 4.5, 2.6, "slimeg")
    im = c.render()
    im.load()[5, 4] = hexc("#e8ffd0")
    return im


def sprites():
    return {
        "gift_red": gift("red"),
        "gift_blue": gift("blanketblue"),
        "gift_green": gift("giftgreen"),
        "gift_paper": gift_paper(),
        "sandcastle": sandcastle(),
        "sand_pile": sand_pile(),
        "jack_lantern": jack_lantern(),
        "snowman": snowman(),
        "slime_lamp": slime_lamp(),
        "slime_blob": slime_blob(),
        "quest_board": quest_board(),
        "bed": bed(),
        "wardrobe": wardrobe(),
        "bookshelf": bookshelf(),
        "rug": rug(),
        "painting": painting(),
        "clock": clock(),
        "window": window(),
    }


def icons():
    return {
        "calendar": calendar(),
        "stove": stove_icon(),
        "dish_soup": bowl(("#d0701e", "#f0a040"), [(6, 8), (10, 9)]),
        "dish_salad": bowl(("#33984b", "#5ac54f"), [(5, 8), (8, 7), (11, 8)]),
        "dish_pumpkinSoup": bowl(("#e08a10", "#ffc825")),
        "dish_stew": bowl(("#a8201e", "#e04a30"), [(7, 8)]),
        "dish_pie": pie(),
        "dish_juice": juice(),
        "dish_popcorn": popcorn(),
        "pen": pen_sign(),
        "slime": slime_gel(),
        "bone": bone(),
        "tool_armor": armor(),
        "heart": heart(),
        "cards": cards_icon(),
    }
