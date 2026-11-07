#!/usr/bin/env python3
"""Удаляет сертификаты разработчика, которые создаёт сборка в CI.

xcodebuild с -allowProvisioningUpdates на чистой машине GitHub каждый раз заводит новый сертификат
«Apple Development: Created via API». У команды их не больше 10, после этого сборка падает.
Скрипт удаляет только такие сертификаты (тип DEVELOPMENT, в имени «Created via API»):
дистрибуционный и личные сертификаты с Мака не трогает.
Запуск: python3 asc_ci_certs.py --issuer ... --key-id ... --key AuthKey.p8
"""
import argparse, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import asc_iap as A


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--issuer", required=True)
    ap.add_argument("--key-id", required=True)
    ap.add_argument("--key", required=True)
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()
    A.TOKEN = A.Token(a.issuer, a.key_id, a.key)
    certs = A.get_all("/v1/certificates?limit=200")
    gone = 0
    for c in certs:
        at = c["attributes"]
        if at.get("certificateType") != "DEVELOPMENT" or "Created via API" not in str(at.get("name", "")):
            continue
        print(f"{'удалить' if a.dry_run else 'удаляю'} {c['id']} {at.get('name')} до {at.get('expirationDate')}")
        if not a.dry_run:
            A.call("DELETE", f"/v1/certificates/{c['id']}")
        gone += 1
    print(f"Сертификатов CI: {gone}")


if __name__ == "__main__":
    main()
