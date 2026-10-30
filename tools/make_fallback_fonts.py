#!/usr/bin/env python3
"""Шрифты-замены для языков, которых нет в Nunito: японский, корейский, китайский (упрощённый и традиционный)
и хинди. Без них Godot рисует вместо букв квадратики с кодом символа.

Берутся только символы, которые есть в строках игры (GameFarm/Resources/Strings/<язык>.json) и в названиях
языков (L.NAMES), поэтому файлы маленькие. После правки строк этих языков скрипт нужно запустить снова
(tools/check_strings.py предупредит, если символа нет в шрифтах).

Исходники (лицензия SIL OFL 1.1, как у Nunito):
  - Noto Sans CJK Bold (пакет fonts-noto-cjk): /usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc
  - Poppins Bold (деванагари): /usr/share/fonts/truetype/google-fonts/Poppins-Bold.ttf
Тайский не входит: свободного шрифта под рукой нет, тайский берётся из системы телефона (SystemFont в UiKit).

Запуск: python3 tools/make_fallback_fonts.py
"""
import json
import os
import re
import sys

from fontTools import subset
from fontTools.ttLib import TTCollection, TTFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STRINGS = os.path.join(ROOT, "GameFarm", "Resources", "Strings")
OUT = os.path.join(ROOT, "godot", "fonts")
CJK = "/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc"
DEVANAGARI = "/usr/share/fonts/truetype/google-fonts/Poppins-Bold.ttf"

# язык -> (семейство в коллекции Noto CJK, имя файла)
CJK_FACES = {
    "ja": ("Noto Sans CJK JP", "NotoSansJP-Bold-sub.otf"),
    "ko": ("Noto Sans CJK KR", "NotoSansKR-Bold-sub.otf"),
    "zh-Hans": ("Noto Sans CJK SC", "NotoSansSC-Bold-sub.otf"),
    "zh-Hant": ("Noto Sans CJK TC", "NotoSansTC-Bold-sub.otf"),
}
DEVANAGARI_FILE = "Poppins-Devanagari-sub.ttf"


def language_names():
    src = open(os.path.join(ROOT, "godot", "scripts", "core", "l10n.gd"), encoding="utf-8").read()
    block = src[src.index("const NAMES"):]
    block = block[:block.index("}")]
    return dict(re.findall(r'"([A-Za-z-]+)":\s*"([^"]*)"', block))


def chars_of(code):
    data = json.load(open(os.path.join(STRINGS, code + ".json"), encoding="utf-8"))
    text = "".join(str(v) for v in data.values()) + language_names().get(code, "")
    # Латиница и кириллица есть в Nunito, эмодзи - в системе телефона
    return sorted({c for c in text if ord(c) > 0x024F and not 0x0400 <= ord(c) <= 0x052F
                   and not 0x1F000 <= ord(c) <= 0x1FFFF})


def save_subset(font, chars, path):
    opts = subset.Options()
    opts.layout_features = ["*"]
    opts.name_IDs = ["*"]
    opts.name_languages = ["*"]
    opts.notdef_outline = True
    opts.glyph_names = False
    sub = subset.Subsetter(options=opts)
    cmap = font.getBestCmap()
    have = [c for c in chars if ord(c) in cmap]
    sub.populate(unicodes=[ord(c) for c in have])
    sub.subset(font)
    font.save(path)
    return len(have), len(chars)


def main():
    collection = TTCollection(CJK)
    faces = {}
    for f in collection.fonts:
        faces[f["name"].getDebugName(1)] = f
    for code, (family, name) in CJK_FACES.items():
        font = faces.get(family)
        if font is None:
            sys.exit("нет начертания " + family)
        # Отдельная копия начертания: подмножество меняет шрифт на месте
        path = os.path.join(OUT, name)
        tmp = path + ".full.otf"
        font.save(tmp)
        got, want = save_subset(TTFont(tmp), chars_of(code), path)
        os.remove(tmp)
        print("%s: %d/%d символов, %d КБ" % (name, got, want, os.path.getsize(path) // 1024))
    chars = [c for c in chars_of("hi") if 0x0900 <= ord(c) <= 0x097F or ord(c) in (0x200C, 0x200D)]
    path = os.path.join(OUT, DEVANAGARI_FILE)
    got, want = save_subset(TTFont(DEVANAGARI), chars, path)
    print("%s: %d/%d символов, %d КБ" % (DEVANAGARI_FILE, got, want, os.path.getsize(path) // 1024))


if __name__ == "__main__":
    main()
