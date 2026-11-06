#!/usr/bin/env python3
"""Заливает переводы страницы App Store (версия в подготовке) из listing_i18n.json.

Подзаголовок -> appInfoLocalizations, описание/ключевые слова/промо -> appStoreVersionLocalizations.
Ничего не удаляет. Если языка нет, создаёт его; если есть, обновляет поля.
Запуск: python3 asc_listing.py --issuer ... --key-id ... [--dry-run]
"""
import argparse, glob, json, os, sys

import asc_iap as A

HERE = os.path.dirname(os.path.abspath(__file__))


def upsert(kind, parent_rel, parent_id, existing, locale, attrs, dry):
    cur = existing.get(locale.lower())
    if dry:
        print(f"  {kind} {locale}: {'обновить' if cur else 'создать'} {list(attrs)}")
        return
    if cur:
        A.call("PATCH", f"/v1/{kind}/{cur}", {"data": {"type": kind, "id": cur, "attributes": attrs}})
    else:
        A.call("POST", f"/v1/{kind}", {"data": {"type": kind,
               "attributes": dict(locale=locale, **attrs),
               "relationships": {parent_rel: {"data": {"type": parent_rel + "s", "id": parent_id}}}}})


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--issuer", required=True)
    ap.add_argument("--key-id", required=True)
    ap.add_argument("--key")
    ap.add_argument("--data", default=os.path.join(HERE, "listing_i18n.json"))
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()
    key = a.key
    if not key:
        for pat in [os.path.join(HERE, f"AuthKey_{a.key_id}.p8"),
                    os.path.expanduser(f"~/Downloads/**/AuthKey_{a.key_id}.p8")]:
            found = glob.glob(pat, recursive=True)
            if found:
                key = found[0]
                break
    if not key:
        sys.exit("Не нашёл AuthKey_*.p8, укажи --key")
    A.TOKEN = A.Token(a.issuer, a.key_id, key)
    data = json.load(open(a.data, encoding="utf-8"))

    app = A.call("GET", f"/v1/apps?filter[bundleId]={A.BUNDLE}")["data"][0]
    app_id = app["id"]
    # Версия, которую ещё можно править
    vers = A.call("GET", f"/v1/apps/{app_id}/appStoreVersions?filter[platform]=IOS&limit=10")["data"]
    editable = ("PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED")
    ver = next((v for v in vers if v["attributes"].get("appStoreState") in editable), None)
    if not ver:
        sys.exit("Нет версии в статусе «Готовится к отправке»")
    infos = A.call("GET", f"/v1/apps/{app_id}/appInfos")["data"]
    info = next((i for i in infos if i["attributes"].get("appStoreState") != "READY_FOR_SALE"), infos[0])
    print(f"Версия {ver['attributes']['versionString']}, appInfo {info['id']}")

    vlocs = {x["attributes"]["locale"].lower(): x["id"]
             for x in A.get_all(f"/v1/appStoreVersions/{ver['id']}/appStoreVersionLocalizations?limit=50")}
    ilocs = {x["attributes"]["locale"].lower(): x["id"]
             for x in A.get_all(f"/v1/appInfos/{info['id']}/appInfoLocalizations?limit=50")}

    errors = []
    for loc, t in data.items():
        print(loc)
        try:
            upsert("appInfoLocalizations", "appInfo", info["id"], ilocs, loc,
                   {"name": "Harvest Hollow", "subtitle": t["subtitle"],
                    "privacyPolicyUrl": "https://baturinigor.github.io/GameFarm/privacy.html"}, a.dry_run)
            upsert("appStoreVersionLocalizations", "appStoreVersion", ver["id"], vlocs, loc,
                   {"description": t["description"], "keywords": t["keywords"],
                    "promotionalText": t["promo"],
                    "supportUrl": "https://baturinigor.github.io/GameFarm/",
                    "marketingUrl": "https://baturinigor.github.io/GameFarm/"}, a.dry_run)
        except Exception as e:
            errors.append(f"{loc}: {e}")
            print("  ОШИБКА", e)
    print("\nГотово." if not errors else "\nОшибки:\n" + "\n".join(errors))


if __name__ == "__main__":
    main()
