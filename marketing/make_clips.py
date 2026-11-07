#!/usr/bin/env python3
"""Сборка роликов 9:16 для TikTok, Reels и Shorts из записей Godot Movie Maker.

Записи (raw/<сценарий>_<язык>.avi) делает .github/workflows/clips.yml или вручную:
  godot --path godot --resolution 1080x1920 --fixed-fps 30 --write-movie raw/chests_en.avi -- --clip chests --lang en

Дальше:
  python3 marketing/make_clips.py raw out                # все ролики из marketing/clips.json на всех языках записей
  python3 marketing/make_clips.py raw out --only chests10 --lang ru

Как устроен кадр 1080x1920:
  - фон в цветах заставки игры (фиолетово-розовое небо, холмы, медленно вращающиеся лучи);
  - сверху карточка с вопросом-хуком в стиле окон игры (кремовая, с коричневой рамкой), въезжает сверху;
  - под ней окно с геймплеем со скруглёнными углами, рамкой и тенью;
  - в конце окно уходит, на том же фоне появляются логотип игры и кнопка «Бесплатно в App Store».
Звук: чистая музыка игры из исходного файла (в записи она заикается, поэтому в игре глушится)
плюс звуки эффектов из записи.

На выходе out/<id>_<язык>.mp4 (H.264, 30 к/с, AAC) и out/<id>_<язык>.json с подписью и хэштегами для
marketing/publish_clips.py. Нужны ffmpeg и Pillow.
"""
import argparse
import json
import math
import pathlib
import random
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
FONTS = ROOT / "godot" / "fonts"
MUSIC = ROOT / "GameFarm" / "Resources" / "Audio"
ICON = ROOT / "marketing" / "assets" / "app_icon.png"
W, H, FPS = 1080, 1920, 30
OUTRO = 3.2  # секунды финальной заставки
GAME_W, GAME_H, GAME_Y = 840, 1493, 372  # окно с геймплеем
CARD_Y, CARD_H = 64, 268  # карточка с хуком

# Цвета интерфейса игры
CREAM = (255, 244, 220)
BROWN = (92, 58, 30)
DARK = (58, 34, 16)
GREEN = (91, 191, 58)
GREEN_DARK = (46, 112, 28)

FONT_BY_LANG = {
    "ja": "NotoSansJP-Bold-sub.otf", "ko": "NotoSansKR-Bold-sub.otf",
    "zh": "NotoSansSC-Bold-sub.otf", "zh-Hans": "NotoSansSC-Bold-sub.otf", "zh-Hant": "NotoSansTC-Bold-sub.otf",
    "hi": "Poppins-Devanagari-sub.ttf", "th": "Unifont-Thai-sub.otf",
}


def font(lang: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FONTS / FONT_BY_LANG.get(lang, "Nunito-900.ttf")), size)


# ---------- графика (Pillow) ----------

def wrap_px(draw: ImageDraw.ImageDraw, text: str, f: ImageFont.FreeTypeFont, width: int) -> list[str]:
    """Перенос по ширине в пикселях; для языков без пробелов - по символам."""
    tokens = text.split(" ") if " " in text else list(text)
    sep = " " if " " in text else ""
    lines, cur = [], ""
    for t in tokens:
        test = (cur + sep + t) if cur else t
        if draw.textlength(test, font=f) <= width:
            cur = test
        else:
            if cur:
                lines.append(cur)
            cur = t
    if cur:
        lines.append(cur)
    return lines


def fit_text(text: str, lang: str, width: int, height: int, start: int, lo: int = 40):
    """Самый крупный кегль, при котором текст влезает в рамку, и строки."""
    probe = ImageDraw.Draw(Image.new("RGB", (1, 1)))
    for size in range(start, lo - 1, -2):
        f = font(lang, size)
        lines = wrap_px(probe, text, f, width)
        line_h = int(size * 1.18)
        if len(lines) * line_h <= height and len(lines) <= 3:
            return f, lines, line_h
    f = font(lang, lo)
    return f, wrap_px(probe, text, f, width), int(lo * 1.18)


def shadowed(size, radius, box, blur=18, offset=(0, 14), alpha=110) -> Image.Image:
    sh = Image.new("RGBA", size, (0, 0, 0, 0))
    x0, y0, x1, y1 = box
    ImageDraw.Draw(sh).rounded_rectangle((x0 + offset[0], y0 + offset[1], x1 + offset[0], y1 + offset[1]),
                                         radius, fill=(20, 8, 30, alpha))
    return sh.filter(ImageFilter.GaussianBlur(blur))


def make_background(path: pathlib.Path, seed: int) -> None:
    """Небо заставки: фиолетовый сверху, розовый к горизонту, холмы и искры."""
    rnd = random.Random(seed)
    img = Image.new("RGB", (W, H))
    px = img.load()
    stops = [(0.0, (46, 32, 120)), (0.45, (122, 66, 170)), (0.72, (236, 132, 170)), (1.0, (250, 190, 170))]
    for y in range(H):
        t = y / (H - 1)
        for (a, ca), (b, cb) in zip(stops, stops[1:]):
            if a <= t <= b:
                k = (t - a) / (b - a)
                c = tuple(int(ca[i] + (cb[i] - ca[i]) * k) for i in range(3))
                break
        for x in range(W):
            px[x, y] = c
    d = ImageDraw.Draw(img, "RGBA")
    for _ in range(90):
        x, y, r = rnd.randrange(W), rnd.randrange(int(H * 0.75)), rnd.choice([2, 2, 3, 4])
        d.ellipse((x - r, y - r, x + r, y + r), fill=(255, 255, 255, rnd.randrange(90, 220)))
    # Холмы внизу, как на заставке
    d.ellipse((-500, H - 330, 900, H + 700), fill=(98, 186, 82))
    d.ellipse((350, H - 260, 1700, H + 700), fill=(76, 160, 66))
    d.ellipse((-300, H - 140, 1400, H + 900), fill=(58, 136, 56))
    img.save(path)


def make_rays(path: pathlib.Path) -> None:
    """Лучи из центра; ffmpeg их медленно вращает."""
    s = 2300
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = s / 2
    n = 18
    for i in range(n):
        a0 = 2 * math.pi * i / n
        a1 = a0 + math.pi / n * 0.8
        d.polygon([(c, c), (c + s * math.cos(a0), c + s * math.sin(a0)), (c + s * math.cos(a1), c + s * math.sin(a1))],
                  fill=(255, 255, 255, 26))
    img.save(path)


def make_card(path: pathlib.Path, text: str, lang: str) -> None:
    """Карточка с хуком в стиле окон игры: кремовая, рамка, тень, тёмно-коричневый текст."""
    img = Image.new("RGBA", (W, CARD_H + 40), (0, 0, 0, 0))
    box = (48, 6, W - 48, CARD_H)
    img.alpha_composite(shadowed(img.size, 44, box, blur=14, offset=(0, 12), alpha=120))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle(box, 44, fill=CREAM, outline=BROWN, width=8)
    d.rounded_rectangle((box[0] + 14, box[1] + 14, box[2] - 14, box[3] - 14), 34, outline=(232, 206, 160), width=3)
    f, lines, lh = fit_text(text, lang, box[2] - box[0] - 90, box[3] - box[1] - 60, 82)
    y = (box[1] + box[3]) / 2 - len(lines) * lh / 2 + lh * 0.02
    for line in lines:
        d.text((W / 2, y + lh / 2), line, font=f, fill=DARK, anchor="mm")
        y += lh
    img.save(path)


def make_frame_and_mask(frame_path: pathlib.Path, mask_path: pathlib.Path) -> None:
    """Тень и рамка вокруг окна с геймплеем + маска скруглённых углов."""
    r = 46
    x0 = (W - GAME_W) // 2
    box = (x0, GAME_Y, x0 + GAME_W, GAME_Y + GAME_H)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    img.alpha_composite(shadowed(img.size, r, box, blur=22, offset=(0, 18), alpha=140))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((box[0] - 10, box[1] - 10, box[2] + 10, box[3] + 10), r + 10, fill=CREAM, outline=BROWN, width=6)
    img.save(frame_path)
    m = Image.new("L", (GAME_W, GAME_H), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, GAME_W - 1, GAME_H - 1), r, fill=255)
    m.save(mask_path)


def make_logo(path: pathlib.Path) -> None:
    """Логотип как на заставке игры: иконка и название. Иконка - marketing/assets/app_icon.png
    (актуальная, из релиза 1.1), логотип рисует тот же tools/make_splash.py, что и заставку."""
    icon = ICON if ICON.exists() else ROOT / "godot" / "assets" / "app_icon.png"
    tmp = path.with_name("splash_logo.png")
    subprocess.run([sys.executable, str(ROOT / "tools" / "make_splash.py"), str(icon),
                    str(FONTS / "Nunito-900.ttf"), str(tmp)], check=True, stdout=subprocess.DEVNULL)
    logo = Image.open(tmp).convert("RGBA")
    logo = logo.crop(logo.getbbox())
    k = min(740 / logo.width, 900 / logo.height)
    logo = logo.resize((int(logo.width * k), int(logo.height * k)), Image.LANCZOS)
    logo.save(path)


def make_cta(path: pathlib.Path, button: str, note: str, lang: str) -> None:
    """Зелёная кнопка как в игре + строка «Ссылка в профиле»."""
    img = Image.new("RGBA", (W, 330), (0, 0, 0, 0))
    f, lines, _ = fit_text(button, lang, 700, 90, 66)
    label = " ".join(lines)
    bw = min(940, int(ImageDraw.Draw(img).textlength(label, font=f)) + 140)
    box = ((W - bw) // 2, 20, (W + bw) // 2, 170)
    img.alpha_composite(shadowed(img.size, 75, box, blur=12, offset=(0, 12), alpha=130))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((box[0], box[1] + 12, box[2], box[3] + 12), 75, fill=GREEN_DARK)
    d.rounded_rectangle(box, 75, fill=GREEN, outline=GREEN_DARK, width=6)
    d.rounded_rectangle((box[0] + 18, box[1] + 12, box[2] - 18, box[1] + 50), 20, fill=(140, 220, 110))
    d.text((W / 2, (box[1] + box[3]) / 2 + 4), label, font=f, fill="white", anchor="mm", stroke_width=4,
           stroke_fill=GREEN_DARK)
    d.text((W / 2, 262), note, font=font(lang, 50), fill="white", anchor="mm", stroke_width=5, stroke_fill=(60, 30, 90))
    img.save(path)


# ---------- видео (ffmpeg) ----------

def duration_of(path: pathlib.Path) -> float:
    out = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(path)],
                         capture_output=True, text=True, check=True).stdout.strip()
    return float(out)


def local(cfg: dict, key: str, lang: str) -> str:
    return cfg[key].get(lang) or cfg[key]["en"]


def join_parts(raw_dir: pathlib.Path, clip: dict, lang: str, tmp: pathlib.Path) -> pathlib.Path:
    """Ролик из нескольких кусков разных записей: склеиваем их в один промежуточный файл."""
    args, chains = [], []
    for i, part in enumerate(clip["parts"]):
        raw = raw_dir / f"{part['scenario']}_{lang}.avi"
        if not raw.exists():
            raise SystemExit(f"{clip['id']}: нет записи {raw.name}")
        args += ["-ss", f"{float(part.get('start', 0)):.2f}", "-t", f"{float(part['duration']):.2f}", "-i", str(raw)]
        chains.append(f"[{i}:v]fps={FPS},scale={W}:{H},setsar=1[v{i}];[{i}:a]aresample=48000[a{i}]")
    n = len(clip["parts"])
    joined = "".join(f"[v{i}][a{i}]" for i in range(n))
    out = tmp / f"joined_{clip['id']}_{lang}.mkv"
    subprocess.run(["ffmpeg", "-v", "error", "-y", *args, "-filter_complex",
                    ";".join(chains) + f";{joined}concat=n={n}:v=1:a=1[v][a]", "-map", "[v]", "-map", "[a]",
                    "-c:v", "libx264", "-crf", "12", "-preset", "veryfast", "-c:a", "pcm_s16le", str(out)], check=True)
    return out


def render(raw: pathlib.Path, out: pathlib.Path, clip: dict, lang: str, cfg: dict, tmp: pathlib.Path) -> None:
    start = float(clip.get("start", 0))
    dur = min(float(clip.get("duration", 1e9)), duration_of(raw) - start)
    if dur < 3:
        raise SystemExit(f"{raw.name}: запись короче {start + 3:.0f} с, ролик {clip['id']} не собрать")
    total = dur + OUTRO
    card = tmp / f"card_{clip['id']}_{lang}.png"
    make_card(card, local(clip, "hook", lang), lang)
    cta = tmp / f"cta_{lang}.png"
    make_cta(cta, local(cfg, "outro", lang), local(cfg, "cta", lang), lang)
    music = MUSIC / f"mus_{clip.get('music', 'meadow')}.m4a"

    gx, cx = (W - GAME_W) // 2, 0
    out_t = dur - 0.35  # окно с геймплеем начинает уходить
    fc = ";".join([
        # Фон и лучи (лучи вращаются вокруг точки за логотипом)
        f"[2:v]format=rgba,rotate=a=t*0.06:c=none:ow=2300:oh=2300,crop={W}:{H}:(iw-{W})/2:(ih-{H})/2-260[rays]",
        f"[1:v][rays]overlay=0:0[bg]",
        # Геймплей: окно со скруглёнными углами; в конце уезжает вниз и гаснет
        f"[0:v]fps={FPS},scale={GAME_W}:{GAME_H}:force_original_aspect_ratio=increase:flags=lanczos,"
        f"crop={GAME_W}:{GAME_H},format=rgba[g0]",
        f"[g0][5:v]alphamerge,tpad=stop_mode=clone:stop_duration={OUTRO},fade=t=out:st={out_t:.2f}:d=0.45:alpha=1[game]",
        f"[4:v]format=rgba,fade=t=out:st={out_t:.2f}:d=0.45:alpha=1[frame]",
        f"[3:v]format=rgba,fade=t=in:st=0:d=0.25:alpha=1,fade=t=out:st={out_t:.2f}:d=0.4:alpha=1[card]",
        f"[6:v]format=rgba,fade=t=in:st={dur:.2f}:d=0.5:alpha=1[logo]",
        f"[7:v]format=rgba,fade=t=in:st={dur + 0.6:.2f}:d=0.4:alpha=1[cta]",
        f"[bg][frame]overlay=x=0:y='({H})*pow(max(0,t-{out_t:.2f})/0.45,2)'[a]",
        f"[a][game]overlay=x={gx}:y='{GAME_Y}+({H})*pow(max(0,t-{out_t:.2f})/0.45,2)'[b]",
        # Карточка въезжает сверху за 0,35 с с лёгким перелётом
        f"[b][card]overlay=x={cx}:y='{CARD_Y}-6-320*pow(max(0,1-t/0.35),2)':eof_action=pass[c]",
        f"[c][logo]overlay=x=(W-w)/2:y='250+120*pow(max(0,1-(t-{dur:.2f})/0.5),3)':enable='gte(t,{dur:.2f})'[d]",
        f"[d][cta]overlay=x=0:y='1250+60*pow(max(0,1-(t-{dur + 0.6:.2f})/0.4),3)':enable='gte(t,{dur + 0.6:.2f})',"
        f"format=yuv420p[v]",
        # Звук: чистая музыка + эффекты из записи; лимитер вместо клиппинга
        f"[8:a]atrim=0:{total:.2f},volume=0.7,afade=t=in:d=0.6,afade=t=out:st={total - 1.6:.2f}:d=1.6[mus]",
        f"[0:a]aresample=48000,volume=0.8,apad=whole_dur={total:.2f}[sfx]",
        "[mus][sfx]amix=inputs=2:normalize=0:duration=first,alimiter=limit=0.89:level=false,aresample=48000[aout]",
    ])
    loop = lambda p: ["-loop", "1", "-framerate", str(FPS), "-t", f"{total:.2f}", "-i", str(p)]
    cmd = ["ffmpeg", "-v", "error", "-y",
           "-ss", f"{start:.2f}", "-t", f"{dur:.2f}", "-i", str(raw),
           *loop(tmp / "bg.png"), *loop(tmp / "rays.png"), *loop(card), *loop(tmp / "frame.png"),
           "-i", str(tmp / "mask.png"), *loop(tmp / "logo.png"), *loop(cta),
           "-stream_loop", "-1", "-i", str(music),
           "-filter_complex", fc, "-map", "[v]", "-map", "[aout]", "-t", f"{total:.2f}", "-r", str(FPS),
           "-c:v", "libx264", "-preset", "slow", "-crf", "19", "-profile:v", "high",
           "-c:a", "aac", "-b:a", "192k", "-ac", "2", "-movflags", "+faststart", str(out)]
    subprocess.run(cmd, check=True)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("raw", type=pathlib.Path, help="папка с записями <сценарий>_<язык>.avi")
    ap.add_argument("out", type=pathlib.Path, help="куда класть готовые ролики")
    ap.add_argument("--config", type=pathlib.Path, default=ROOT / "marketing" / "clips.json")
    ap.add_argument("--only", nargs="*", help="id роликов из clips.json")
    ap.add_argument("--lang", nargs="*", help="языки (по умолчанию все, что есть в записях)")
    a = ap.parse_args()

    cfg = json.loads(a.config.read_text(encoding="utf-8"))
    a.out.mkdir(parents=True, exist_ok=True)
    made = 0
    with tempfile.TemporaryDirectory() as t:
        tmp = pathlib.Path(t)
        make_background(tmp / "bg.png", 7)
        make_rays(tmp / "rays.png")
        make_frame_and_mask(tmp / "frame.png", tmp / "mask.png")
        make_logo(tmp / "logo.png")
        for clip in cfg["clips"]:
            if a.only and clip["id"] not in a.only:
                continue
            first = clip["parts"][0]["scenario"] if "parts" in clip else clip["scenario"]
            for raw in sorted(a.raw.glob(f"{first}_*.avi")):
                lang = raw.stem[len(first) + 1:]
                if a.lang and lang not in a.lang:
                    continue
                out = a.out / f"{clip['id']}_{lang}.mp4"
                print(f"{out.name} <- {raw.name}", flush=True)
                if "parts" in clip:
                    raw = join_parts(a.raw, clip, lang, tmp)
                render(raw, out, clip, lang, cfg, tmp)
                caption = local(clip, "caption", lang)
                tags = local(cfg, "hashtags", lang)
                meta = {"id": clip["id"], "lang": lang, "file": out.name,
                        "title": caption.split(".")[0][:90],
                        "caption": f"{caption} {tags}",
                        "hashtags": tags.split()}
                (a.out / f"{clip['id']}_{lang}.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")
                made += 1
    if made == 0:
        sys.exit("Ни одного ролика: нет записей raw/<сценарий>_<язык>.avi для clips.json")
    print(f"готово: {made} роликов в {a.out}")


if __name__ == "__main__":
    main()
