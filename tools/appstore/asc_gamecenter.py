#!/usr/bin/env python3
"""Заводит Game Center для Harvest Hollow в App Store Connect через API.

По списку gamecenter/manifest.json (его пишет игра: godot --headless --path godot -- --gc-manifest <файл>):
  1. включает Game Center у приложения;
  2. создаёт достижения (69) и таблицы лидеров (3) с теми же id, что в игре (scripts/core/game_center.gd);
  3. добавляет названия и описания на 17 языках;
  4. загружает картинку достижения (gamecenter/tier*.png, trophy.png) для каждого языка.
Уже заведённое пропускает, поэтому запускать можно сколько угодно раз.

Запуск (как asc_iap.py, тот же ключ API):
  python3 asc_gamecenter.py --issuer <Issuer ID> --key-id <Key ID> [--key путь/к/AuthKey.p8] [--dry-run]

После этого в App Store Connect на странице версии 1.1 в разделе Game Center нужно отметить
достижения и таблицы, чтобы они ушли на проверку вместе с версией.
"""
import argparse, glob, hashlib, json, os, sys, urllib.request

import asc_iap
from asc_iap import Token, call, get_all, rel, LOCALES, BUNDLE

HERE = os.path.dirname(os.path.abspath(__file__))
GC = os.path.join(HERE, "gamecenter")
DRY = False


def image_for(a):
    if a["id"].startswith("hh.trophy."):
        return os.path.join(GC, "trophy.png")
    tier = int(a["id"].rsplit("_", 1)[-1])
    return os.path.join(GC, f"tier{min(tier, 4)}.png")


def ensure_detail(app_id):
    try:
        d = call("GET", f"/v1/apps/{app_id}/gameCenterDetail").get("data")
        if d:
            return d["id"]
    except RuntimeError:
        pass
    print("Включаю Game Center")
    if DRY:
        return None
    r = call("POST", "/v1/gameCenterDetails", {"data": {"type": "gameCenterDetails",
        "relationships": {"app": rel("apps", app_id)}}})
    return r["data"]["id"]


def upload(kind, rel_name, rel_kind, owner_id, path):
    blob = open(path, "rb").read()
    r = call("POST", f"/v1/{kind}", {"data": {"type": kind,
        "attributes": {"fileName": os.path.basename(path), "fileSize": len(blob)},
        "relationships": {rel_name: rel(rel_kind, owner_id)}}})
    iid = r["data"]["id"]
    for op in r["data"]["attributes"]["uploadOperations"]:
        part = blob[op["offset"]:op["offset"] + op["length"]]
        req = urllib.request.Request(op["url"], data=part, method=op["method"])
        for h in op.get("requestHeaders", []):
            req.add_header(h["name"], h["value"])
        urllib.request.urlopen(req, timeout=120, context=asc_iap.SSL).read()
    # У картинок Game Center нет sourceFileChecksum (в отличие от скриншотов покупок)
    call("PATCH", f"/v1/{kind}/{iid}", {"data": {"type": kind, "id": iid, "attributes": {"uploaded": True}}})


def ensure_achievement(detail_id, existing, a):
    if a["id"] in existing:
        return existing[a["id"]]
    print(f"  создаю достижение ({a['points']} очк.)")
    if DRY:
        return None
    r = call("POST", "/v1/gameCenterAchievements", {"data": {"type": "gameCenterAchievements",
        "attributes": {"referenceName": a["ref"], "vendorIdentifier": a["id"], "points": a["points"],
                       "showBeforeEarned": True, "repeatable": False},
        "relationships": {"gameCenterDetail": rel("gameCenterDetails", detail_id)}}})
    return r["data"]["id"]


def ensure_achievement_locs(ach_id, a):
    have = {}
    if ach_id:
        for x in get_all(f"/v1/gameCenterAchievements/{ach_id}/localizations?limit=50"):
            have[x["attributes"]["locale"]] = x["id"]
    added = 0
    for lang, loc in LOCALES.items():
        loc_id = have.get(loc)
        if not loc_id:
            added += 1
            if DRY:
                continue
            text = a["text"][lang]
            r = call("POST", "/v1/gameCenterAchievementLocalizations", {"data": {
                "type": "gameCenterAchievementLocalizations",
                "attributes": {"locale": loc, "name": a["names"][lang],
                               "beforeEarnedDescription": text, "afterEarnedDescription": text},
                "relationships": {"gameCenterAchievement": rel("gameCenterAchievements", ach_id)}}})
            loc_id = r["data"]["id"]
        if DRY:
            continue
        img = None
        try:
            img = call("GET", f"/v1/gameCenterAchievementLocalizations/{loc_id}/gameCenterAchievementImage").get("data")
        except RuntimeError:
            pass
        state = ((img or {}).get("attributes", {}).get("assetDeliveryState") or {}).get("state", "")
        if img and state not in ("UPLOAD_COMPLETE", "COMPLETE"):
            # Прошлая загрузка не закончилась (или упала): убираем и грузим заново
            call("DELETE", f"/v1/gameCenterAchievementImages/{img['id']}")
            img = None
        if not img:
            upload("gameCenterAchievementImages", "gameCenterAchievementLocalization",
                   "gameCenterAchievementLocalizations", loc_id, image_for(a))
    print(f"  языки: {'все уже есть' if added == 0 else f'добавлено {added}'}")


def ensure_board(detail_id, existing, b):
    if b["id"] in existing:
        return existing[b["id"]]
    print("  создаю таблицу")
    if DRY:
        return None
    r = call("POST", "/v1/gameCenterLeaderboards", {"data": {"type": "gameCenterLeaderboards",
        "attributes": {"referenceName": b["ref"], "vendorIdentifier": b["id"], "defaultFormatter": "INTEGER",
                       "submissionType": "BEST_SCORE", "scoreSortType": "DESC"},
        "relationships": {"gameCenterDetail": rel("gameCenterDetails", detail_id)}}})
    return r["data"]["id"]


def ensure_board_locs(board_id, b):
    have = set()
    if board_id:
        have = {x["attributes"]["locale"] for x in get_all(f"/v1/gameCenterLeaderboards/{board_id}/localizations?limit=50")}
    for lang, loc in LOCALES.items():
        if loc in have or DRY:
            continue
        call("POST", "/v1/gameCenterLeaderboardLocalizations", {"data": {
            "type": "gameCenterLeaderboardLocalizations",
            "attributes": {"locale": loc, "name": b["names"][lang]},
            "relationships": {"gameCenterLeaderboard": rel("gameCenterLeaderboards", board_id)}}})


def main():
    global DRY
    ap = argparse.ArgumentParser()
    ap.add_argument("--issuer", required=True)
    ap.add_argument("--key-id", required=True)
    ap.add_argument("--key", help="путь к AuthKey_*.p8 (по умолчанию ищу рядом и в ~/Downloads)")
    ap.add_argument("--data", default=os.path.join(GC, "manifest.json"))
    ap.add_argument("--dry-run", action="store_true", help="только показать, что будет сделано")
    a = ap.parse_args()
    DRY = a.dry_run
    key = a.key
    if not key:
        for pat in [os.path.join(HERE, f"AuthKey_{a.key_id}.p8"), os.path.expanduser(f"~/Downloads/**/AuthKey_{a.key_id}.p8")]:
            found = glob.glob(pat, recursive=True)
            if found:
                key = found[0]
                break
    if not key or not os.path.exists(key):
        sys.exit(f"Не нашёл файл AuthKey_{a.key_id}.p8. Укажи путь: --key /путь/к/AuthKey_{a.key_id}.p8")
    asc_iap.TOKEN = Token(a.issuer, a.key_id, key)
    data = json.load(open(a.data))

    apps = call("GET", f"/v1/apps?filter[bundleId]={BUNDLE}")["data"]
    if not apps:
        sys.exit(f"Приложение с bundle id {BUNDLE} не найдено в App Store Connect")
    app_id = apps[0]["id"]
    print(f"Приложение: {apps[0]['attributes']['name']} ({app_id})")
    detail_id = ensure_detail(app_id)
    have_ach, have_boards = {}, {}
    if detail_id:
        have_ach = {x["attributes"]["vendorIdentifier"]: x["id"]
                    for x in get_all(f"/v1/gameCenterDetails/{detail_id}/gameCenterAchievements?limit=200")}
        have_boards = {x["attributes"]["vendorIdentifier"]: x["id"]
                       for x in get_all(f"/v1/gameCenterDetails/{detail_id}/gameCenterLeaderboards?limit=200")}
    print(f"Уже заведено: достижений {len(have_ach)}, таблиц {len(have_boards)}\n")

    errors = []
    items = [("ach", x) for x in data["achievements"]] + [("board", x) for x in data["leaderboards"]]
    for n, (kind, x) in enumerate(items, 1):
        print(f"[{n}/{len(items)}] {x['id']}  {x['names']['en']}")
        try:
            if kind == "ach":
                ensure_achievement_locs(ensure_achievement(detail_id, have_ach, x), x)
            else:
                ensure_board_locs(ensure_board(detail_id, have_boards, x), x)
        except Exception as e:
            print(f"  ОШИБКА: {e}")
            errors.append((x["id"], str(e)))
    print()
    if errors:
        print(f"Готово с ошибками ({len(errors)}):")
        for pid, e in errors:
            print(f"  {pid}: {e[:300]}")
        print("Запусти скрипт ещё раз: готовое он пропустит.")
        sys.exit(1)
    print("Готово." + (" (пробный прогон, ничего не менял)" if DRY else
          " Теперь на странице версии 1.1 в разделе Game Center отметь достижения и таблицы."))


if __name__ == "__main__":
    main()
