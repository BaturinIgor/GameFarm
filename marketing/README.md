# Ролики для TikTok, Reels и Shorts

План продвижения: https://claude.ai/artifact/BXMpojD8CmrrqMK6iwXvZh

Три шага: игра сама записывает геймплей, скрипт режет его в вертикальные ролики с подписями,
второй скрипт публикует их на ваши аккаунты через официальные API.

## 1. Запись и нарезка (GitHub Actions)

Actions → **Marketing clips** → Run workflow. Поля: языки (`en ru`) и сценарии
(`walk chests hatch mine tour`). Через 15–25 минут в артефакте **clips** запуска лежат
`<ролик>_<язык>.mp4` (1080x1920, 30 к/с) и `<ролик>_<язык>.json` с подписью и хэштегами.

| Сценарий | Что в кадре |
| --- | --- |
| walk | герой бегает по поляне, добывает ресурсы и несёт их на склад |
| chests | окно сундуков, открытие 10 сундуков, затем древний сундук |
| hatch | инкубатор: золотое яйцо трясётся, вылупляется пегас |
| mine | Шахта Глубин: ходы по самым большим группам до победы |
| tour | звери, сад, гардероб, ивенты, таланты, усадьба, коллекция |

Кадр: фон в цветах заставки игры, сверху карточка с вопросом в стиле окон игры, под ней окно с геймплеем.
В конце окно уходит и появляются логотип и зелёная кнопка «Играй бесплатно на iPhone». Музыка берётся
из исходных файлов игры (в записи она заикается, поэтому при записи глушится), эффекты остаются из игры.

Сценарии живут в `godot/scripts/debug/clip_driver.gd`, подписи, тайминги и музыка в `marketing/clips.json`.
Новый ролик из той же записи: добавьте запись с другим `start`/`duration` и хуком. Ролик из нескольких
записей: поле `parts` (как у `best_of`, подборки на ~45 с).

Локально (нужны Godot 4.5 и ffmpeg, а для спрайтов - распакованные ассеты):

```
godot --path godot --resolution 1080x1920 --fixed-fps 30 --write-movie raw/chests_en.avi -- --clip chests --lang en
python3 marketing/make_clips.py raw clips
```

Сценарии меняют сохранение, поэтому локально запускайте их на копии проекта, а не на своей игре.

## 2. Аккаунты (вручную, один раз)

Аккаунты создаются руками, скрипт только входит в них: автосоздание аккаунтов нарушает правила площадок
и заканчивается баном всей сетки. Предлагаемый набор: TikTok EN, TikTok RU, Instagram, YouTube.

| Площадка | Где завести приложение | Что включить |
| --- | --- | --- |
| TikTok | developers.tiktok.com → Manage apps | Login Kit + Content Posting API, scopes `video.upload`, `video.publish`; Redirect URI `https://baturinigor.github.io/GameFarm/oauth.html`. Для публичных постов через API - подать на аудит |
| Instagram | developers.facebook.com → приложение типа Business → Instagram API with Instagram Login | права `instagram_business_basic`, `instagram_business_content_publish`; тот же Redirect URI; аккаунт Instagram переключить в Professional |
| YouTube | console.cloud.google.com → YouTube Data API v3 → OAuth client типа Desktop app | scope `youtube.upload`; для публичных роликов через API - аудит (до него загрузки приватные) |

Ключи впишите в `marketing/accounts.json` (образец `accounts.example.json`, сам файл в `.gitignore`).

## 3. Публикация

```
python3 marketing/publish_clips.py login tiktok_en      # вход в браузере, один раз на аккаунт
python3 marketing/publish_clips.py next clips/ --dry-run  # что уйдёт
python3 marketing/publish_clips.py next clips/            # по одному новому ролику на каждый аккаунт
python3 marketing/publish_clips.py status
```

- TikTok по умолчанию (`"mode": "draft"`) кладёт ролик во «Входящие» приложения TikTok: там добавляете
  трендовый звук и публикуете. После аудита можно поставить `"mode": "direct"`.
- YouTube до аудита проекта делает загрузки приватными - откройте их в YouTube Studio.
- Не больше одного ролика в сутки на аккаунт (`--force`, чтобы не ждать). Токены и журнал публикаций лежат
  в `~/.harvest-hollow/`.
- `next` можно повесить на cron/launchd, например раз в день в 18:00.
