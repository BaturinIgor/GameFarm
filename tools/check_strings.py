"""Проверяет, что все ключи tr("...") из кода есть в en.json и ru.json, и что в переводах те же плейсхолдеры."""
import glob
import json
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(__file__), "..")
SRC = os.path.join(ROOT, "GameFarm")
STRINGS = os.path.join(SRC, "Resources", "Strings")


def swift_cases(enum_name):
    for path in glob.glob(os.path.join(SRC, "**", "*.swift"), recursive=True):
        text = open(path, encoding="utf-8").read()
        m = re.search(r"enum " + enum_name + r"\b[^{]*\{(.*?)\n\}", text, re.S)
        if m:
            body = m.group(1)
            cases = []
            for line in re.findall(r"^\s*case ([^\n=]+)$", body, re.M):
                if ":" in line or "(" in line:
                    continue
                cases += [c.strip() for c in line.split(",")]
            return cases
    return []


def required_keys():
    keys = set()
    dynamic = []
    for path in glob.glob(os.path.join(SRC, "**", "*.swift"), recursive=True):
        text = open(path, encoding="utf-8").read()
        for k in re.findall(r'tr\("([^"\\]+)"', text):
            keys.add(k)
        for k in re.findall(r'tr\("([^"]*\\\([^"]*)"', text):
            dynamic.append(k)
    return keys, dynamic


def placeholders(s):
    return sorted(set(re.findall(r"\{\d\}", s)))


def main():
    keys, dynamic = required_keys()
    en = json.load(open(os.path.join(STRINGS, "en.json"), encoding="utf-8"))
    expand = {
        "cat.": "ResourceCategory", "res.": "ResourceKind", "tool.": "ToolKind", "node.": "NodeType",
        "loc.": "LocationID", "animal.": "AnimalID", "talent.": "TalentID", "branch.": "TalentBranch",
        "skin.": "Skin", "product.": None, "effect.yield.": "ResourceCategory", "ach.": None,
    }
    problems = 0
    for k in sorted(keys):
        if k not in en:
            print("missing in en:", k)
            problems += 1
    print("static keys:", len(keys), "dynamic patterns:", sorted(set(dynamic)))
    for code_path in sorted(glob.glob(os.path.join(STRINGS, "*.json"))):
        code = os.path.basename(code_path)[:-5]
        data = json.load(open(code_path, encoding="utf-8"))
        missing = [k for k in en if k not in data]
        extra = [k for k in data if k not in en]
        bad = [k for k in en if k in data and placeholders(en[k]) != placeholders(data[k])]
        if missing or extra or bad:
            problems += 1
        print(f"{code}: {len(data)} keys, missing {len(missing)}, extra {len(extra)}, placeholder mismatch {len(bad)}")
        for k in (missing[:5] + extra[:5] + bad[:5]):
            print("   ", k)
    for prefix, enum in expand.items():
        if not enum:
            continue
        for case in swift_cases(enum):
            if prefix == "talent.":
                need = [f"talent.{case}", f"talent.{case}.text"]
            elif prefix == "tool.":
                need = [f"tool.{case}", f"tool.{case}.purpose"]
            elif prefix == "loc.":
                need = [f"loc.{case}", f"loc.{case}.blurb"]
            else:
                need = [prefix + case]
            for k in need:
                if k not in en:
                    print("missing dynamic key:", k)
                    problems += 1
    fonts_check()
    sys.exit(1 if problems else 0)


def fonts_check():
    """Предупреждение: в строках есть символ, которого нет в шрифтах-заменах (будет квадратик)."""
    try:
        from fontTools.ttLib import TTFont
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        import make_fallback_fonts as mf
    except ImportError:
        return
    files = {code: name for code, (_, name) in mf.CJK_FACES.items()}
    files["hi"] = mf.DEVANAGARI_FILE
    for code, name in files.items():
        path = os.path.join(mf.OUT, name)
        if not os.path.exists(path):
            print(f"fonts: нет {name}, запусти tools/make_fallback_fonts.py")
            continue
        cmap = TTFont(path).getBestCmap()
        lost = [c for c in mf.chars_of(code) if ord(c) not in cmap and (code != "hi" or 0x0900 <= ord(c) <= 0x097F)]
        if lost:
            print(f"fonts: {code} - нет символов {''.join(lost[:20])}, запусти tools/make_fallback_fonts.py")


main()
