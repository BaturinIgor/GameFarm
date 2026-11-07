#!/usr/bin/env python3
"""Нарезка роликов 9:16 для TikTok, Reels и Shorts из записей Godot Movie Maker.

Записи (raw/<сценарий>_<язык>.avi) делает .github/workflows/clips.yml или вручную:
  godot --path godot --resolution 1080x1920 --write-movie raw/chests_en.avi --fixed-fps 30 -- --clip chests --lang en

Дальше:
  python3 marketing/make_clips.py raw out                # все ролики из marketing/clips.json на всех языках записей
  python3 marketing/make_clips.py raw out --only chests10 --lang ru

На выходе для каждого ролика out/<id>_<язык>.mp4 (1080x1920, H.264, 30 к/с, AAC) и out/<id>_<язык>.json
с подписью и хэштегами - его читает marketing/publish_clips.py.
Нужен только ffmpeg, без пакетов Python.
"""
import argparse
import json
import pathlib
import subprocess
import sys
import tempfile
import textwrap

ROOT = pathlib.Path(__file__).resolve().parent.parent
FONTS = ROOT / "godot" / "fonts"
W, H, FPS = 1080, 1920, 30
OUTRO = 2.5  # секунды финальной плашки с названием
HOOK = 3.5  # секунды крупной подписи в начале

# Nunito - латиница и кириллица; для остальных языков шрифты из игры
FONT_BY_LANG = {
    "ja": "NotoSansJP-Bold-sub.otf", "ko": "NotoSansKR-Bold-sub.otf",
    "zh": "NotoSansSC-Bold-sub.otf", "zh-Hans": "NotoSansSC-Bold-sub.otf", "zh-Hant": "NotoSansTC-Bold-sub.otf",
    "hi": "Poppins-Devanagari-sub.ttf", "th": "Unifont-Thai-sub.otf",
}


def font(lang: str) -> str:
    return str(FONTS / FONT_BY_LANG.get(lang, "Nunito-900.ttf"))


def esc(path: str) -> str:
    """Путь внутри фильтра ffmpeg: экранируем \\, : и '."""
    return path.replace("\\", "\\\\").replace(":", "\\:").replace("'", "\\'")


def wrap(text: str, lang: str, width: int) -> str:
    if lang in ("ja", "ko", "zh", "zh-Hans", "zh-Hant", "th"):
        n = max(1, width // 2)
        return "\n".join(text[i:i + n] for i in range(0, len(text), n))
    return "\n".join(textwrap.wrap(text, width)) or text


def text_file(tmp: pathlib.Path, name: str, text: str) -> str:
    p = tmp / name
    p.write_text(text, encoding="utf-8")
    return esc(str(p))


def duration_of(path: pathlib.Path) -> float:
    out = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(path)],
                         capture_output=True, text=True, check=True).stdout.strip()
    return float(out)


def render(raw: pathlib.Path, out: pathlib.Path, clip: dict, lang: str, cfg: dict, tmp: pathlib.Path) -> None:
    start = float(clip.get("start", 0))
    dur = min(float(clip["duration"]), duration_of(raw) - start)
    if dur < 3:
        raise SystemExit(f"{raw.name}: запись короче {start + 3:.0f} с, ролик {clip['id']} не собрать")
    f = esc(font(lang))
    hook = text_file(tmp, f"{clip['id']}_{lang}_hook.txt", wrap(clip["hook"].get(lang) or clip["hook"]["en"], lang, 20))
    title = text_file(tmp, "title.txt", "Harvest Hollow")
    outro = text_file(tmp, f"outro_{lang}.txt", cfg["outro"].get(lang) or cfg["outro"]["en"])
    end = dur - OUTRO
    box = "box=1:boxcolor=black@0.45:boxborderw=28"
    vf = ",".join([
        f"scale={W}:{H}:force_original_aspect_ratio=increase:flags=neighbor",
        f"crop={W}:{H}",
        f"fps={FPS}",
        # Хук: крупно сверху, исчезает через HOOK секунд
        f"drawtext=fontfile='{f}':textfile='{hook}':fontsize=78:fontcolor=white:borderw=6:bordercolor=black"
        f":line_spacing=14:text_align=center:x=(w-text_w)/2:y=h*0.13:{box}:enable='lt(t,{HOOK})'",
        # Финальная плашка: затемнение, название и "Бесплатно в App Store"
        f"drawbox=x=0:y=0:w=iw:h=ih:color=black@0.6:t=fill:enable='gte(t,{end:.2f})'",
        f"drawtext=fontfile='{esc(font('en'))}':textfile='{title}':fontsize=120:fontcolor=#FFE08A:borderw=8:bordercolor=#3A2410"
        f":x=(w-text_w)/2:y=h*0.40:enable='gte(t,{end:.2f})'",
        f"drawtext=fontfile='{f}':textfile='{outro}':fontsize=64:fontcolor=white:borderw=5:bordercolor=black"
        f":x=(w-text_w)/2:y=h*0.40+170:enable='gte(t,{end:.2f})'",
    ])
    af = f"afade=t=in:d=0.3,afade=t=out:st={dur - 1.2:.2f}:d=1.2,loudnorm=I=-16:TP=-1.5:LRA=11,aresample=48000"
    cmd = ["ffmpeg", "-v", "error", "-y", "-ss", f"{start:.2f}", "-t", f"{dur:.2f}", "-i", str(raw),
           "-vf", vf, "-af", af,
           "-c:v", "libx264", "-preset", "slow", "-crf", "20", "-pix_fmt", "yuv420p", "-profile:v", "high",
           "-c:a", "aac", "-b:a", "160k", "-ac", "2", "-movflags", "+faststart", str(out)]
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
        for clip in cfg["clips"]:
            if a.only and clip["id"] not in a.only:
                continue
            for raw in sorted(a.raw.glob(f"{clip['scenario']}_*.avi")):
                lang = raw.stem[len(clip["scenario"]) + 1:]
                if a.lang and lang not in a.lang:
                    continue
                out = a.out / f"{clip['id']}_{lang}.mp4"
                print(f"{out.name} <- {raw.name}", flush=True)
                render(raw, out, clip, lang, cfg, tmp)
                caption = clip["caption"].get(lang) or clip["caption"]["en"]
                tags = cfg["hashtags"].get(lang) or cfg["hashtags"]["en"]
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
