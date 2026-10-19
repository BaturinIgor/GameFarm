"""Каталог строк: ru.json и en.json в GameFarm/Resources/Strings.

Использование из других скриптов:
    from i18n import add, save
    add("key", "русский", "english")
    save()
"""
import json
import os

ROOT = os.path.join(os.path.dirname(__file__), "..", "GameFarm", "Resources", "Strings")
_cache = {}


def _load(code):
    if code not in _cache:
        path = os.path.join(ROOT, f"{code}.json")
        _cache[code] = json.load(open(path, encoding="utf-8")) if os.path.exists(path) else {}
    return _cache[code]


def add(key, ru, en):
    _load("ru")[key] = ru
    _load("en")[key] = en


def save():
    for code, data in _cache.items():
        path = os.path.join(ROOT, f"{code}.json")
        with open(path, "w", encoding="utf-8") as f:
            json.dump(dict(sorted(data.items())), f, ensure_ascii=False, indent=1)
            f.write("\n")
