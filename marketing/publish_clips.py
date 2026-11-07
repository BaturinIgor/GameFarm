#!/usr/bin/env python3
"""Публикация роликов на собственные аккаунты Harvest Hollow через официальные API.

Площадки: TikTok (Content Posting API), Instagram Reels (Instagram API with Instagram Login),
YouTube Shorts (YouTube Data API v3). Только стандартная библиотека Python, без пакетов.

Аккаунты создаются вручную в приложениях площадок; скрипт только входит в них через OAuth
и заливает ролики. Ключи приложений - в marketing/accounts.json (не в git, образец accounts.example.json),
токены - в ~/.harvest-hollow/tokens.json.

  python3 marketing/publish_clips.py login tiktok_en        # один раз на аккаунт: вход в браузере
  python3 marketing/publish_clips.py post clips/pegasus_en.mp4 --to tiktok_en youtube --dry-run
  python3 marketing/publish_clips.py next clips/             # по одному новому ролику на каждый аккаунт
  python3 marketing/publish_clips.py status                  # что уже опубликовано

Правило "не больше одного ролика в сутки на аккаунт" встроено: частые одинаковые публикации
площадки считают спамом. Снять его можно флагом --force.
"""
import argparse
import http.server
import json
import pathlib
import secrets
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import webbrowser

# Сертификаты из системы (Связка ключей macOS), а не только из набора Python: если VPN или антивирус
# проверяют HTTPS своим сертификатом, Python иначе падает с CERTIFICATE_VERIFY_FAILED.
# Ставится один раз: python3 -m pip install truststore
try:
    import truststore
    truststore.inject_into_ssl()
except ImportError:
    pass

HERE = pathlib.Path(__file__).resolve().parent
ACCOUNTS = HERE / "accounts.json"
STATE_DIR = pathlib.Path.home() / ".harvest-hollow"
TOKENS = STATE_DIR / "tokens.json"
POSTED = STATE_DIR / "posted.json"
DAY = 24 * 3600


# ---------- общие помощники ----------

def load(path: pathlib.Path, default):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return default


def save(path: pathlib.Path, data) -> None:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    path.chmod(0o600)


def http(method: str, url: str, *, data=None, json_body=None, headers=None, raw=False):
    """Запрос без внешних библиотек. Возвращает (json или байты, заголовки)."""
    headers = dict(headers or {})
    body = None
    if json_body is not None:
        body = json.dumps(json_body).encode()
        headers.setdefault("Content-Type", "application/json; charset=UTF-8")
    elif isinstance(data, dict):
        body = urllib.parse.urlencode(data).encode()
        headers.setdefault("Content-Type", "application/x-www-form-urlencoded")
    elif data is not None:
        body = data
    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=300) as r:
            payload = r.read()
            hdrs = dict(r.headers)
    except urllib.error.HTTPError as e:
        raise SystemExit(f"{method} {url.split('?')[0]} -> HTTP {e.code}: {e.read().decode(errors='replace')[:800]}")
    if raw:
        return payload, hdrs
    return (json.loads(payload) if payload.strip() else {}), hdrs


def upload_file(url: str, video: pathlib.Path, headers: dict) -> None:
    """PUT файла кусками по 1 МБ. Если сервер оборвал загрузку (Broken pipe), читаем, что он ответил,
    и пробуем ещё раз: так видно настоящую причину, а не только обрыв."""
    import http.client
    import ssl
    u = urllib.parse.urlsplit(url)
    path = u.path + ("?" + u.query if u.query else "")
    last = ""
    for attempt in range(3):
        conn = http.client.HTTPSConnection(u.hostname, u.port or 443, timeout=300, context=ssl.create_default_context())
        try:
            conn.putrequest("PUT", path, skip_accept_encoding=True)
            for k, v in headers.items():
                conn.putheader(k, v)
            conn.endheaders()
            with open(video, "rb") as f:
                while block := f.read(1024 * 1024):
                    conn.send(block)
            r = conn.getresponse()
            body = r.read().decode(errors="replace")[:800]
            if r.status < 300:
                return
            last = f"HTTP {r.status}: {body}"
        except (BrokenPipeError, ConnectionResetError, ssl.SSLError, OSError) as e:
            last = f"{type(e).__name__}: {e}"
            if isinstance(e, (BrokenPipeError, ConnectionResetError)):
                try:
                    r = conn.getresponse()
                    last += f" | сервер ответил HTTP {r.status}: {r.read().decode(errors='replace')[:800]}"
                except Exception:
                    pass
        finally:
            conn.close()
        if attempt < 2:
            print(f"  загрузка оборвалась ({last}), попытка {attempt + 2} из 3...", flush=True)
            time.sleep(3)
    raise SystemExit(f"PUT {u.hostname} не удался: {last}")


def accounts() -> dict:
    if not ACCOUNTS.exists():
        raise SystemExit(f"Нет {ACCOUNTS}. Скопируйте accounts.example.json и впишите ключи приложений.")
    return load(ACCOUNTS, {})["accounts"]


def account(name: str) -> dict:
    acc = accounts()
    if name not in acc:
        raise SystemExit(f"Аккаунта {name} нет в accounts.json, есть: {', '.join(acc)}")
    return acc[name]


def ask_code(auth_url: str, redirect: str) -> str:
    """TikTok и Instagram пускают только на https-адрес: открываем вход, человек вставляет адрес, куда его вернуло."""
    print("\nОткройте ссылку, войдите в нужный аккаунт и разрешите доступ:\n\n" + auth_url + "\n")
    webbrowser.open(auth_url)
    back = input(f"После входа браузер откроет {redirect}?code=...\nВставьте сюда этот адрес целиком: ").strip()
    q = urllib.parse.parse_qs(urllib.parse.urlparse(back).query)
    if "code" not in q:
        raise SystemExit("В адресе нет code=. Попробуйте ещё раз.")
    return q["code"][0].removesuffix("#_")


def loopback_code(auth_url_for) -> tuple[str, str]:
    """Google разрешает вход с возвратом на 127.0.0.1: ловим code локальным сервером."""
    got: dict = {}

    class H(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            got.update(urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query))
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            self.wfile.write("Готово, можно закрыть вкладку.".encode())

        def log_message(self, *_):
            pass

    srv = http.server.HTTPServer(("127.0.0.1", 0), H)
    redirect = f"http://127.0.0.1:{srv.server_port}"
    url = auth_url_for(redirect)
    print("\nОткройте ссылку и войдите в аккаунт канала:\n\n" + url + "\n")
    webbrowser.open(url)
    while "code" not in got and "error" not in got:
        srv.handle_request()
    if "error" in got:
        raise SystemExit(f"Вход отменён: {got['error'][0]}")
    return got["code"][0], redirect


# ---------- TikTok: Content Posting API ----------
# https://developers.tiktok.com/doc/content-posting-api-get-started
# До аудита приложения TikTok публикует только приватно (SELF_ONLY), поэтому по умолчанию ролик уходит
# черновиком во "Входящие" приложения TikTok: там добавляете трендовый звук и публикуете одним нажатием.

TT = "https://open.tiktokapis.com/v2"


def tiktok_login(name: str, acc: dict) -> dict:
    state = secrets.token_urlsafe(16)
    url = "https://www.tiktok.com/v2/auth/authorize/?" + urllib.parse.urlencode({
        "client_key": acc["client_key"], "response_type": "code", "state": state,
        # Черновики во "Входящие" требуют только video.upload; video.publish нужен для "mode": "direct"
        "scope": "user.info.basic,video.upload" + (",video.publish" if acc.get("mode") == "direct" else ""),
        "redirect_uri": acc["redirect_uri"]})
    code = ask_code(url, acc["redirect_uri"])
    tok, _ = http("POST", f"{TT}/oauth/token/", data={
        "client_key": acc["client_key"], "client_secret": acc["client_secret"], "code": code,
        "grant_type": "authorization_code", "redirect_uri": acc["redirect_uri"]})
    return tiktok_store(tok)


def tiktok_store(tok: dict) -> dict:
    if "access_token" not in tok:
        raise SystemExit(f"TikTok не выдал токен: {tok}")
    now = time.time()
    return {"access_token": tok["access_token"], "refresh_token": tok["refresh_token"],
            "expires_at": now + int(tok.get("expires_in", 86400)) - 300,
            "refresh_expires_at": now + int(tok.get("refresh_expires_in", 365 * DAY))}


def tiktok_token(name: str, acc: dict, tokens: dict) -> str:
    t = tokens.get(name)
    if not t:
        raise SystemExit(f"Сначала: publish_clips.py login {name}")
    if time.time() > t["expires_at"]:
        tok, _ = http("POST", f"{TT}/oauth/token/", data={
            "client_key": acc["client_key"], "client_secret": acc["client_secret"],
            "grant_type": "refresh_token", "refresh_token": t["refresh_token"]})
        tokens[name] = tiktok_store(tok)
        save(TOKENS, tokens)
    return tokens[name]["access_token"]


def tiktok_post(name: str, acc: dict, tokens: dict, video: pathlib.Path, meta: dict, private: bool) -> str:
    token = tiktok_token(name, acc, tokens)
    auth = {"Authorization": f"Bearer {token}"}
    size = video.stat().st_size
    # Файлы до 64 МБ уходят одним куском; наши ролики 15-30 с весят 5-20 МБ
    if size > 64 * 1024 * 1024:
        raise SystemExit(f"{video.name}: больше 64 МБ, пережмите ролик")
    source = {"source": "FILE_UPLOAD", "video_size": size, "chunk_size": size, "total_chunk_count": 1}
    mode = acc.get("mode", "draft")
    if mode == "direct":
        info, _ = http("POST", f"{TT}/post/publish/creator_info/query/", json_body={}, headers=auth)
        options = info["data"]["privacy_level_options"]
        privacy = "SELF_ONLY" if private or "PUBLIC_TO_EVERYONE" not in options else "PUBLIC_TO_EVERYONE"
        body = {"post_info": {"title": meta["caption"][:2200], "privacy_level": privacy,
                              "disable_comment": False, "disable_duet": False, "disable_stitch": False,
                              "video_cover_timestamp_ms": 1500},
                "source_info": source}
        init, _ = http("POST", f"{TT}/post/publish/video/init/", json_body=body, headers=auth)
    else:
        init, _ = http("POST", f"{TT}/post/publish/inbox/video/init/", json_body={"source_info": source}, headers=auth)
    data = init["data"]
    upload_file(data["upload_url"], video, {
        "Content-Type": "video/mp4", "Content-Length": str(size), "Content-Range": f"bytes 0-{size - 1}/{size}"})
    for _ in range(60):
        st, _ = http("POST", f"{TT}/post/publish/status/fetch/", json_body={"publish_id": data["publish_id"]}, headers=auth)
        status = st["data"].get("status")
        if status in ("PUBLISH_COMPLETE", "SEND_TO_USER_INBOX"):
            break
        if status == "FAILED":
            raise SystemExit(f"TikTok отклонил ролик: {st['data'].get('fail_reason')}")
        time.sleep(5)
    else:
        raise SystemExit(f"TikTok за 5 минут не закончил обработку ({status}). Проверить позже: "
                         f"publish_clips.py check {name} {data['publish_id']}")
    where = "черновик во «Входящих» TikTok, подпись: " + meta["caption"] if mode != "direct" else status
    return f"{data['publish_id']} ({where})"


# ---------- Instagram Reels: Instagram API with Instagram Login ----------
# https://developers.facebook.com/docs/instagram-platform/content-publishing
# Нужен профессиональный аккаунт (Business или Creator). Ролик заливается напрямую (resumable upload),
# поэтому публичный адрес видео не нужен.

IG = "https://graph.instagram.com/v21.0"


def instagram_login(name: str, acc: dict) -> dict:
    url = "https://www.instagram.com/oauth/authorize?" + urllib.parse.urlencode({
        "client_id": acc["app_id"], "redirect_uri": acc["redirect_uri"], "response_type": "code",
        "scope": "instagram_business_basic,instagram_business_content_publish"})
    code = ask_code(url, acc["redirect_uri"])
    short, _ = http("POST", "https://api.instagram.com/oauth/access_token", data={
        "client_id": acc["app_id"], "client_secret": acc["app_secret"], "grant_type": "authorization_code",
        "redirect_uri": acc["redirect_uri"], "code": code})
    long, _ = http("GET", "https://graph.instagram.com/access_token?" + urllib.parse.urlencode({
        "grant_type": "ig_exchange_token", "client_secret": acc["app_secret"], "access_token": short["access_token"]}))
    return {"access_token": long["access_token"], "user_id": str(short["user_id"]),
            "expires_at": time.time() + int(long.get("expires_in", 60 * DAY))}


def instagram_token(name: str, tokens: dict) -> dict:
    t = tokens.get(name)
    if not t:
        raise SystemExit(f"Сначала: publish_clips.py login {name}")
    # Долгий токен живёт 60 дней; продлеваем, когда осталось меньше 10
    if t["expires_at"] - time.time() < 10 * DAY:
        r, _ = http("GET", "https://graph.instagram.com/refresh_access_token?" + urllib.parse.urlencode({
            "grant_type": "ig_refresh_token", "access_token": t["access_token"]}))
        t["access_token"] = r["access_token"]
        t["expires_at"] = time.time() + int(r.get("expires_in", 60 * DAY))
        save(TOKENS, tokens)
    return t


def instagram_post(name: str, acc: dict, tokens: dict, video: pathlib.Path, meta: dict, private: bool) -> str:
    if private:
        raise SystemExit("Instagram не умеет приватные публикации через API: уберите --private для Instagram")
    t = instagram_token(name, tokens)
    auth = {"Authorization": f"Bearer {t['access_token']}"}
    c, _ = http("POST", f"{IG}/{t['user_id']}/media", headers=auth, data={
        "media_type": "REELS", "upload_type": "resumable", "caption": meta["caption"][:2200], "share_to_feed": "true"})
    size = video.stat().st_size
    http("POST", c["uri"], data=video.read_bytes(), raw=True, headers={
        "Authorization": f"OAuth {t['access_token']}", "offset": "0", "file_size": str(size)})
    for _ in range(60):
        st, _ = http("GET", f"{IG}/{c['id']}?fields=status_code,status", headers=auth)
        if st.get("status_code") == "FINISHED":
            break
        if st.get("status_code") == "ERROR":
            raise SystemExit(f"Instagram не принял ролик: {st.get('status')}")
        time.sleep(5)
    pub, _ = http("POST", f"{IG}/{t['user_id']}/media_publish", headers=auth, data={"creation_id": c["id"]})
    return pub["id"]


# ---------- YouTube Shorts: YouTube Data API v3 ----------
# https://developers.google.com/youtube/v3/docs/videos/insert
# Вертикальный ролик до 3 минут сам становится Shorts. Пока проект Google Cloud не прошёл аудит,
# YouTube оставляет загруженные через API ролики приватными - откройте их в YouTube Studio.
# Квота 10 000 единиц в сутки, одна загрузка - 1600, то есть до 6 роликов в день.

def youtube_login(name: str, acc: dict) -> dict:
    def url(redirect):
        return "https://accounts.google.com/o/oauth2/v2/auth?" + urllib.parse.urlencode({
            "client_id": acc["client_id"], "redirect_uri": redirect, "response_type": "code",
            "scope": "https://www.googleapis.com/auth/youtube.upload", "access_type": "offline", "prompt": "consent"})
    code, redirect = loopback_code(url)
    tok, _ = http("POST", "https://oauth2.googleapis.com/token", data={
        "client_id": acc["client_id"], "client_secret": acc["client_secret"], "code": code,
        "grant_type": "authorization_code", "redirect_uri": redirect})
    return {"access_token": tok["access_token"], "refresh_token": tok["refresh_token"],
            "expires_at": time.time() + int(tok["expires_in"]) - 120}


def youtube_token(name: str, acc: dict, tokens: dict) -> str:
    t = tokens.get(name)
    if not t:
        raise SystemExit(f"Сначала: publish_clips.py login {name}")
    if time.time() > t["expires_at"]:
        tok, _ = http("POST", "https://oauth2.googleapis.com/token", data={
            "client_id": acc["client_id"], "client_secret": acc["client_secret"],
            "grant_type": "refresh_token", "refresh_token": t["refresh_token"]})
        t["access_token"] = tok["access_token"]
        t["expires_at"] = time.time() + int(tok["expires_in"]) - 120
        save(TOKENS, tokens)
    return t["access_token"]


def youtube_post(name: str, acc: dict, tokens: dict, video: pathlib.Path, meta: dict, private: bool) -> str:
    token = youtube_token(name, acc, tokens)
    size = video.stat().st_size
    title = (meta["title"] + " #Shorts")[:100]
    body = {"snippet": {"title": title, "description": meta["caption"] + "\n\n" + acc.get("link", ""),
                        "tags": [h.lstrip("#") for h in meta["hashtags"]] + ["Harvest Hollow"],
                        "categoryId": "20", "defaultLanguage": meta["lang"]},
            "status": {"privacyStatus": "private" if private else "public", "selfDeclaredMadeForKids": False}}
    _, hdrs = http("POST", "https://www.googleapis.com/upload/youtube/v3/videos?uploadType=resumable&part=snippet,status",
                   json_body=body, raw=True, headers={"Authorization": f"Bearer {token}",
                                                      "X-Upload-Content-Type": "video/mp4",
                                                      "X-Upload-Content-Length": str(size)})
    location = hdrs.get("Location") or hdrs.get("location")
    res, _ = http("PUT", location, data=video.read_bytes(), headers={
        "Authorization": f"Bearer {token}", "Content-Type": "video/mp4", "Content-Length": str(size)})
    return f"https://youtube.com/shorts/{res['id']}"


PLATFORMS = {
    "tiktok": (tiktok_login, tiktok_post),
    "instagram": (instagram_login, instagram_post),
    "youtube": (youtube_login, youtube_post),
}


# ---------- команды ----------

def meta_for(video: pathlib.Path) -> dict:
    j = video.with_suffix(".json")
    if not j.exists():
        raise SystemExit(f"Нет {j.name} рядом с роликом (его пишет make_clips.py)")
    return json.loads(j.read_text(encoding="utf-8"))


def targets(names: list[str] | None, lang: str | None) -> list[str]:
    """Имена аккаунтов; "tiktok" без суффикса - все аккаунты TikTok на языке ролика."""
    acc = accounts()
    out = []
    for n in names or list(acc):
        if n in acc:
            out.append(n)
        elif n in PLATFORMS:
            out += [k for k, v in acc.items() if v["platform"] == n]
        else:
            raise SystemExit(f"Не знаю {n}: ни аккаунта, ни площадки с таким именем")
    return [n for n in dict.fromkeys(out) if lang is None or acc[n].get("lang", lang) == lang]


def publish(video: pathlib.Path, names: list[str], a) -> None:
    meta = meta_for(video)
    tokens = load(TOKENS, {})
    posted = load(POSTED, [])
    for name in targets(names, meta["lang"]):
        acc = account(name)
        if any(p["account"] == name and p["clip"] == video.name for p in posted):
            print(f"{name}: {video.name} уже опубликован, пропускаю")
            continue
        last = max((p["at"] for p in posted if p["account"] == name), default=0)
        if time.time() - last < DAY and not a.force:
            print(f"{name}: сегодня уже был ролик, следующий через {int((last + DAY - time.time()) / 3600) + 1} ч (--force, чтобы не ждать)")
            continue
        if a.dry_run:
            print(f"[dry-run] {name} ({acc['platform']}): {video.name} | {meta['caption']}")
            continue
        print(f"{name}: загружаю {video.name}...", flush=True)
        ref = PLATFORMS[acc["platform"]][1](name, acc, tokens, video, meta, a.private)
        posted.append({"account": name, "clip": video.name, "at": int(time.time()), "ref": ref})
        save(POSTED, posted)
        print(f"{name}: готово, {ref}")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    lg = sub.add_parser("login", help="войти в аккаунт (один раз)")
    lg.add_argument("account")
    for name in ("post", "next"):
        p = sub.add_parser(name, help="опубликовать ролик" if name == "post" else "по одному новому ролику на аккаунт")
        p.add_argument("path", type=pathlib.Path, help="ролик .mp4" if name == "post" else "папка с роликами")
        p.add_argument("--to", nargs="*", help="аккаунты или площадки (tiktok, instagram, youtube); по умолчанию все")
        p.add_argument("--dry-run", action="store_true", help="показать, что уйдёт, ничего не публикуя")
        p.add_argument("--private", action="store_true", help="TikTok и YouTube: приватно, для проверки")
        p.add_argument("--force", action="store_true", help="не ждать сутки между роликами")
    sub.add_parser("status", help="что уже опубликовано")
    ck = sub.add_parser("check", help="TikTok: состояние загрузки по publish_id")
    ck.add_argument("account")
    ck.add_argument("publish_id")
    a = ap.parse_args()

    if a.cmd == "login":
        acc = account(a.account)
        tokens = load(TOKENS, {})
        tokens[a.account] = PLATFORMS[acc["platform"]][0](a.account, acc)
        save(TOKENS, tokens)
        print(f"{a.account}: вход выполнен, токен в {TOKENS}")
    elif a.cmd == "check":
        acc = account(a.account)
        token = tiktok_token(a.account, acc, load(TOKENS, {}))
        st, _ = http("POST", f"{TT}/post/publish/status/fetch/", json_body={"publish_id": a.publish_id},
                     headers={"Authorization": f"Bearer {token}"})
        print(json.dumps(st, ensure_ascii=False, indent=2))
    elif a.cmd == "post":
        publish(a.path, a.to, a)
    elif a.cmd == "next":
        posted = load(POSTED, [])
        for name in targets(a.to, None):
            lang = account(name).get("lang")
            done = {p["clip"] for p in posted if p["account"] == name}
            fresh = [v for v in sorted(a.path.glob("*.mp4")) if v.name not in done
                     and (lang is None or meta_for(v)["lang"] == lang)]
            if not fresh:
                print(f"{name}: новых роликов нет")
                continue
            publish(fresh[0], [name], a)
    else:
        for p in load(POSTED, []):
            print(time.strftime("%Y-%m-%d %H:%M", time.localtime(p["at"])), p["account"], p["clip"], p["ref"])


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(130)
