# Harvest Hollow на Godot: как устроен порт

Порт iOS-версии (SwiftUI + SpriteKit, папка `GameFarm/`) на Godot 4.5, GDScript.
Источник правды по правилам игры - Swift-код. Порт повторяет его логику, числа и тексты.

## Сборка и проверка

- Спрайты, карты и строки общие с iOS: `tools/godot_sync.sh` копирует `GameFarm/Resources/Layouts/*.json`
  в `godot/data/layouts/`, строки `GameFarm/Resources/Strings/*.json` в `godot/data/strings/` и распаковывает
  спрайты в `godot/assets/sprites/` (нужен `ASSETS_KEY`). Эти папки в git не попадают.
- Локально Godot не запускается. Синтаксис проверяем `gdparse <файлы>` (пакет gdtoolkit 4.5).
- Полная проверка - CI `.github/workflows/android.yml`: импорт, прогон без экрана, снимки экрана
  (`scripts/debug/shot_driver.gd`), сборка APK. Логи и снимки CI кладёт в ветку `ci-logs-android`.

## Координаты и масштаб

- Мир считается в "точках" iOS: 1 пиксель спрайта = 2 точки (`Sprites.SCALE`). Окно 390x844 точек,
  растяжение `canvas_items`.
- В Godot ось y смотрит вниз. В JSON-раскладках и в Swift ось y смотрит вверх. `MapLayout` переводит всё
  при загрузке: `y_godot = map_height - y_file`. При переносе кода из SpriteKit: `+y` (вверх) становится `-y`.
- Спрайт стоит на земле: позиция узла = точка опоры, якорь из манифеста задаёт смещение (`Sprites.make`).
- Сортировка по глубине: всё объёмное кладём в `world.entities` (y_sort), плоское - в `world.flat`,
  всплывающее - в `world.fx`.

## Автозагрузки

- `L` (`scripts/core/l10n.gd`): строки. `L.t("key", [arg0, arg1])` подставляет `{0}`, `{1}`.
  Встроенный `tr()` Godot не используем. Ключи те же, что в iOS (`tr("...")` в Swift).
- `Sprites` (`scripts/core/sprites.gd`): `texture(name)`, `make(name, pos)`, `animated(name, fps, pos)`,
  `icon(name)` (ic_<name>), `anchor(name)`, `info(name)`.
- `Game` (`scripts/core/game.gd`): состояние игры, порт `GameState`. Прогресс - словарь `Game.save` с теми же
  ключами и форматом, что iOS-сохранение (JSON), чтобы файл копии подходил обеим версиям. Даты - unix-секунды.
  Сигналы: `changed`, `toast(icon, text)`, `level_up(from, to)`, `event(name, data)`.

## Идентификаторы и данные

- Все перечисления Swift (`ResourceKind`, `LocationID`, `TalentID`, `AnimalID`, ...) - строки с теми же
  rawValue. Словари в `save` - по этим строкам.
- Таблицы данных - статические классы в `scripts/data/` (`Res`, `Nodes`, `Tools`, `Locations`, ...):
  `const` словари + `static func`. Цены `Cost` - словарь `{"coins": n, "items": [[kind, n], ...]}`.
- Вызовы `Swift: tr("x.\(id)")` -> `L.t("x." + id)`.

## Системы

`GameState` в Swift разбит на extension-ы. В Godot каждая крупная часть - система в `scripts/systems/`,
класс `extends RefCounted`, создаётся в `Game._ready()` и доступна как `Game.<имя>`:

| Система | Файл | Что внутри (порт из Swift) |
|---|---|---|
| `Game.talents` | `talent_system.gd` | Таланты: ранги, очки, изучение, сброс |
| `Game.workshop` | `tool_system.gd` | Мастерская: улучшение инструментов |
| `Game.animals` | `animal_system.gd` | Звери: звёзды, активные, приручение, пробуждение, редкие |
| `Game.quests` | `quest_system.gd` | Задания и достижения |
| `Game.house` | `house_system.gd` | Дом, уют, украшения, кухня и блюда, календарь входа |
| `Game.garden` | `garden_system.gd` | Огород, семена, лейка, удобрения, лавка и бродячий торговец |
| `Game.combat` | `combat_system.gd` | Здоровье героя, снаряжение и оружие, монстры, охота, подземелья |
| `Game.events` | `event_system.gd` | Ивенты, пропуск, этапы и усиления |
| `Game.collection` | `collection_system.gd` | Карты и созвездия |
| `Game.legacy` | `legacy_system.gd` | Перерождение, искры, наследие |
| `Game.premium` | `premium_system.gd` | Покупки, Pro, сад, удача, билеты, экспедиции |
| `Game.world_map` | `world_map_system.gd` | Проходы между локациями, открытие, карта мира, планеты |

Правила:
- Система хранит данные только в `Game.save`, своих полей-состояний почти нет (кроме временных).
- Характеристики считает только `Game.recalc()` (полный порт Swift `recalc`). Системы дают ему значения
  через функции с фиксированными именами (см. заглушки в `scripts/systems/`). Имена не менять.
- Значения по умолчанию в сохранении: функция `defaults(save)` системы, вызывается при загрузке.
- Связь между системами - через `Game.<система>` или событие `Game.emit_event("gather", {...})`;
  задания слушают события (`gather`, `harvest`, `deposit`, `sell`, `tame`, `kill`, `craft`, ...).
- После изменения `save`: `Game.mark_dirty()`; если менялось что-то, влияющее на характеристики: `Game.recalc()`.

## Сцена

- `World` (`scripts/world/world.gd`) - порт `GameScene`: строит карту, двигает героя, добыча, склад, проходы.
- Дополнительные куски сцены (звери-спутники, монстры, огород, дом, клады, торговцы) - "фичи" в
  `scripts/world/features/`: класс `extends WorldFeature` с `build(world)`, `process(world, dt)`, `clear()`.
  Список фич - в `World.FEATURES`.
- Эффекты - `Fx` (`scripts/world/fx.gd`).

## Интерфейс

- Стиль - `UiKit` (`scripts/ui/ui_kit.gd`): пергамент, дерево, тёмный контур, кнопки `UiKit.button(text, tone)`.
- Окна - наследники `Sheet` (`scripts/ui/sheet.gd`): заголовок, монеты, крестик, прокрутка; содержимое
  строится в `build()` и перестраивается после `Game.changed`. Открываются через `Hud.open_window(...)`.
- Шапка и кнопки - `Hud` (`scripts/ui/hud.gd`). `Hud.current` - текущая шапка. Кнопки нижней панели берутся
  из `Hud.WINDOWS` (кнопка появляется, когда файл окна существует), `Hud.current.open_named("talents")`.
- Карточки над кнопками (приручить зверя, проход, дом): `Hud.current.set_prompt("ключ", control)`,
  `set_prompt("ключ", null)` убирает.
- Общие элементы в `UiKit`: `button`, `icon`, `icon_any("px:..|res:..|an:..")`, `bar` (GameBar), `cost_view`
  (CostView), `stars`, `count_badge`. В шрифте нет символов вроде ★ и ✕: звёзды - иконка `star`, крестик - `×`.
- Все тексты из `L.t()`. Никаких строк прямо в коде, кроме чисел и значков.

## Стиль кода

- GDScript 4 со статическими типами, табы, `snake_case`. Комментарии по-русски, коротко, как в Swift-коде.
- Не оставлять закомментированный код и отладочные `print`.
