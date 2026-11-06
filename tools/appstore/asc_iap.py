#!/usr/bin/env python3
"""Заводит встроенные покупки Harvest Hollow в App Store Connect через API.

Что делает для каждой из 29 покупок (уже заведённое пропускает):
  1. создаёт покупку (тип, справочное имя, ID продукта);
  2. добавляет названия и описания на 17 языках;
  3. ставит цену в долларах (США как базовая страна, остальные страны Apple считает сама);
  4. открывает продажу во всех странах;
  5. загружает скриншот для ревью.

Запуск:
  python3 asc_iap.py --issuer <Issuer ID> --key-id <Key ID> [--key путь/к/AuthKey.p8] [--dry-run]

Нужны только python3 и openssl, они есть на любом Маке. Ключ .p8 никуда не отправляется:
им подписывается токен прямо на этом компьютере.
"""
import argparse, base64, glob, hashlib, json, os, subprocess, sys, tempfile, time
import urllib.request, urllib.error

HERE = os.path.dirname(os.path.abspath(__file__))
API = "https://api.appstoreconnect.apple.com"
BUNDLE = "com.personal.gamefarm"
TYPES = {"Consumable": "CONSUMABLE", "Non-Consumable": "NON_CONSUMABLE",
         "Non-Renewing Subscription": "NON_RENEWING_SUBSCRIPTION"}
# Код языка игры -> локаль App Store Connect
LOCALES = {"en": "en-US", "ru": "ru", "de": "de-DE", "fr": "fr-FR", "es": "es-ES", "pt-BR": "pt-BR",
           "it": "it", "tr": "tr", "pl": "pl", "zh-Hans": "zh-Hans", "zh-Hant": "zh-Hant", "ja": "ja",
           "ko": "ko", "id": "id", "vi": "vi", "th": "th", "hi": "hi"}


# ---------- токен ----------
def b64(b: bytes) -> str:
    return base64.urlsafe_b64encode(b).rstrip(b"=").decode()


def der_to_raw(sig: bytes) -> bytes:
    # ECDSA-подпись openssl в DER: SEQUENCE { INTEGER r, INTEGER s } -> r||s по 32 байта
    i = 2 if sig[1] < 0x80 else 2 + (sig[1] & 0x7F)
    out = b""
    for _ in range(2):
        assert sig[i] == 0x02
        n = sig[i + 1]
        v = sig[i + 2:i + 2 + n].lstrip(b"\x00")
        out += v.rjust(32, b"\x00")
        i += 2 + n
    return out


class Token:
    def __init__(self, issuer, key_id, key_path):
        self.issuer, self.key_id, self.key_path = issuer, key_id, key_path
        self.value, self.exp = "", 0

    def get(self):
        now = int(time.time())
        if now < self.exp - 60:
            return self.value
        head = b64(json.dumps({"alg": "ES256", "kid": self.key_id, "typ": "JWT"}).encode())
        body = b64(json.dumps({"iss": self.issuer, "iat": now, "exp": now + 1100,
                               "aud": "appstoreconnect-v1"}).encode())
        msg = f"{head}.{body}".encode()
        der = subprocess.run(["openssl", "dgst", "-sha256", "-sign", self.key_path],
                             input=msg, capture_output=True, check=True).stdout
        self.value = f"{head}.{body}.{b64(der_to_raw(der))}"
        self.exp = now + 1100
        return self.value


TOKEN: Token = None
DRY = False


def call(method, path, body=None, ok=(200, 201, 204)):
    url = path if path.startswith("http") else API + path
    data = json.dumps(body).encode() if body is not None else None
    for attempt in range(5):
        req = urllib.request.Request(url, data=data, method=method)
        req.add_header("Authorization", "Bearer " + TOKEN.get())
        if data is not None:
            req.add_header("Content-Type", "application/json")
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                raw = r.read()
                return json.loads(raw) if raw else {}
        except urllib.error.HTTPError as e:
            text = e.read().decode(errors="replace")
            if e.code == 429 or e.code >= 500:
                time.sleep(2 ** attempt * 2)
                continue
            raise RuntimeError(f"{method} {path} -> {e.code}: {text[:800]}")
        except urllib.error.URLError:
            time.sleep(2 ** attempt * 2)
    raise RuntimeError(f"{method} {path}: нет ответа после 5 попыток")


def get_all(path):
    out, url = [], path
    while url:
        r = call("GET", url)
        out += r.get("data", [])
        url = r.get("links", {}).get("next")
    return out


def rel(kind, id_):
    return {"data": {"type": kind, "id": id_}}


# ---------- шаги ----------
def ensure_iap(app_id, existing, p):
    if p["id"] in existing:
        return existing[p["id"]], False
    print(f"  создаю покупку {p['id']} ({p['type']})")
    if DRY:
        return None, True
    r = call("POST", "/v2/inAppPurchases", {"data": {
        "type": "inAppPurchases",
        "attributes": {"name": p["ref"], "productId": p["id"], "inAppPurchaseType": TYPES[p["type"]],
                       "familySharable": False},
        "relationships": {"app": rel("apps", app_id)}}})
    return r["data"]["id"], True


def ensure_locs(iap_id, p):
    have = {}
    if iap_id:
        for l in get_all(f"/v2/inAppPurchases/{iap_id}/inAppPurchaseLocalizations?limit=50"):
            have[l["attributes"]["locale"]] = l
    added = 0
    for code, _ln, name, desc in p["locs"]:
        loc = LOCALES[code]
        cur = have.get(loc)
        if cur:
            a = cur["attributes"]
            if a.get("name") != name or (a.get("description") or "") != desc:
                if not DRY:
                    call("PATCH", f"/v1/inAppPurchaseLocalizations/{cur['id']}", {"data": {
                        "type": "inAppPurchaseLocalizations", "id": cur["id"],
                        "attributes": {"name": name, "description": desc}}})
                added += 1
            continue
        if not DRY:
            call("POST", "/v1/inAppPurchaseLocalizations", {"data": {
                "type": "inAppPurchaseLocalizations",
                "attributes": {"locale": loc, "name": name, "description": desc},
                "relationships": {"inAppPurchaseV2": rel("inAppPurchases", iap_id)}}})
        added += 1
    print(f"  языки: {added} добавлено или исправлено, {len(p['locs']) - added} уже были")


def ensure_price(iap_id, p):
    if not iap_id:
        print(f"  цена ${p['price']}")
        return
    try:
        sched = call("GET", f"/v2/inAppPurchases/{iap_id}/iapPriceSchedule?include=manualPrices")
        if sched.get("included"):
            print("  цена уже стоит")
            return
    except RuntimeError:
        pass
    points = get_all(f"/v2/inAppPurchases/{iap_id}/pricePoints?filter[territory]=USA&limit=200")
    pp = next((x for x in points if x["attributes"]["customerPrice"] == p["price"]), None)
    if not pp:
        raise RuntimeError(f"не нашёл ценовую точку ${p['price']} для {p['id']}")
    print(f"  ставлю цену ${p['price']}")
    if DRY:
        return
    call("POST", "/v1/inAppPurchasePriceSchedules", {
        "data": {"type": "inAppPurchasePriceSchedules",
                 "relationships": {"inAppPurchase": rel("inAppPurchases", iap_id),
                                   "baseTerritory": rel("territories", "USA"),
                                   "manualPrices": {"data": [{"type": "inAppPurchasePrices", "id": "${p0}"}]}}},
        "included": [{"type": "inAppPurchasePrices", "id": "${p0}",
                      "attributes": {"startDate": None},
                      "relationships": {"inAppPurchasePricePoint": rel("inAppPurchasePricePoints", pp["id"])}}]})


TERRITORIES = []


def ensure_availability(iap_id):
    if not iap_id:
        print("  продажа во всех странах")
        return
    try:
        r = call("GET", f"/v2/inAppPurchases/{iap_id}/inAppPurchaseAvailability")
        if r.get("data"):
            print("  страны уже выбраны")
            return
    except RuntimeError:
        pass
    global TERRITORIES
    if not TERRITORIES:
        TERRITORIES = [t["id"] for t in get_all("/v1/territories?limit=200")]
    print(f"  открываю продажу в {len(TERRITORIES)} странах")
    if DRY:
        return
    call("POST", "/v1/inAppPurchaseAvailabilities", {"data": {
        "type": "inAppPurchaseAvailabilities",
        "attributes": {"availableInNewTerritories": True},
        "relationships": {"inAppPurchase": rel("inAppPurchases", iap_id),
                          "availableTerritories": {"data": [{"type": "territories", "id": t} for t in TERRITORIES]}}}})


def ensure_screenshot(iap_id, shot):
    if not iap_id:
        print("  скриншот для ревью")
        return
    try:
        r = call("GET", f"/v2/inAppPurchases/{iap_id}/appStoreReviewScreenshot")
        d = r.get("data")
        if d and (d.get("attributes", {}).get("assetDeliveryState") or {}).get("state") != "FAILED":
            print("  скриншот уже есть")
            return
    except RuntimeError:
        pass
    blob = open(shot, "rb").read()
    print("  загружаю скриншот")
    if DRY:
        return
    r = call("POST", "/v1/inAppPurchaseAppStoreReviewScreenshots", {"data": {
        "type": "inAppPurchaseAppStoreReviewScreenshots",
        "attributes": {"fileName": os.path.basename(shot), "fileSize": len(blob)},
        "relationships": {"inAppPurchaseV2": rel("inAppPurchases", iap_id)}}})
    sid = r["data"]["id"]
    for op in r["data"]["attributes"]["uploadOperations"]:
        part = blob[op["offset"]:op["offset"] + op["length"]]
        req = urllib.request.Request(op["url"], data=part, method=op["method"])
        for h in op.get("requestHeaders", []):
            req.add_header(h["name"], h["value"])
        urllib.request.urlopen(req, timeout=120).read()
    call("PATCH", f"/v1/inAppPurchaseAppStoreReviewScreenshots/{sid}", {"data": {
        "type": "inAppPurchaseAppStoreReviewScreenshots", "id": sid,
        "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(blob).hexdigest()}}})


def main():
    global TOKEN, DRY
    ap = argparse.ArgumentParser()
    ap.add_argument("--issuer", required=True)
    ap.add_argument("--key-id", required=True)
    ap.add_argument("--key", help="путь к AuthKey_*.p8 (по умолчанию ищу рядом и в ~/Downloads)")
    ap.add_argument("--data", default=os.path.join(HERE, "iap_data.json"))
    ap.add_argument("--shot", default=os.path.join(HERE, "review_screenshot.png"))
    ap.add_argument("--only", help="ID продукта или его конец, чтобы завести одну покупку")
    ap.add_argument("--dry-run", action="store_true", help="только показать, что будет сделано")
    a = ap.parse_args()
    DRY = a.dry_run
    key = a.key
    if not key:
        pats = [os.path.join(HERE, f"AuthKey_{a.key_id}.p8"),
                os.path.expanduser(f"~/Downloads/**/AuthKey_{a.key_id}.p8")]
        for pat in pats:
            found = glob.glob(pat, recursive=True)
            if found:
                key = found[0]
                break
    if not key or not os.path.exists(key):
        sys.exit(f"Не нашёл файл AuthKey_{a.key_id}.p8. Укажи путь: --key /путь/к/AuthKey_{a.key_id}.p8")
    TOKEN = Token(a.issuer, a.key_id, key)
    products = json.load(open(a.data))
    if a.only:
        products = [p for p in products if p["id"].endswith(a.only)]

    apps = call("GET", f"/v1/apps?filter[bundleId]={BUNDLE}")["data"]
    if not apps:
        sys.exit(f"Приложение с bundle id {BUNDLE} не найдено в App Store Connect")
    app_id = apps[0]["id"]
    print(f"Приложение: {apps[0]['attributes']['name']} ({app_id})")
    existing = {x["attributes"]["productId"]: x["id"]
                for x in get_all(f"/v1/apps/{app_id}/inAppPurchasesV2?limit=200")}
    print(f"Уже заведено покупок: {len(existing)}\n")

    errors = []
    for n, p in enumerate(products, 1):
        print(f"[{n}/{len(products)}] {p['ref']}  ${p['price']}")
        try:
            iap_id, _ = ensure_iap(app_id, existing, p)
            ensure_locs(iap_id, p)
            ensure_price(iap_id, p)
            ensure_availability(iap_id)
            ensure_screenshot(iap_id, a.shot)
        except Exception as e:
            print(f"  ОШИБКА: {e}")
            errors.append((p["id"], str(e)))
    print()
    if errors:
        print(f"Готово с ошибками ({len(errors)}):")
        for pid, e in errors:
            print(f"  {pid}: {e[:300]}")
        print("Запусти скрипт ещё раз: готовое он пропустит.")
        sys.exit(1)
    print("Готово: все покупки заведены." + (" (пробный прогон, ничего не менял)" if DRY else ""))


if __name__ == "__main__":
    main()
