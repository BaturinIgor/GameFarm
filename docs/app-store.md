# Выпуск в App Store: что включить

Сборка через SideStore работает без платного аккаунта, поэтому iCloud, Game Center и запрос оценки в ней выключены.
Код для них уже есть (`GameFarm/App/Platform.swift`), включаются флагами в `project.yml` (Info.plist).

## 1. Аккаунт и идентификатор

1. Оформить Apple Developer Program.
2. В Certificates, Identifiers & Profiles создать App ID (например `com.<имя>.harvesthollow`) и указать его в `PRODUCT_BUNDLE_IDENTIFIER`.
3. Включить у App ID возможности: iCloud (Key-value storage), Game Center, In-App Purchase.

## 2. Синхронизация через iCloud

1. Добавить файл entitlements и указать его в `project.yml` (`CODE_SIGN_ENTITLEMENTS`):
   ```xml
   <key>com.apple.developer.ubiquity-kvstore-identifier</key>
   <string>$(TeamIdentifierPrefix)$(CFBundleIdentifier)</string>
   ```
2. В `project.yml` поставить `HHCloudSync: true`.

Как работает: при каждом сохранении (не чаще раза в минуту и при уходе в фон) прогресс уходит в iCloud key-value storage.
Если в облаке прогресс дальше локального (перерождения, затем уровень, затем опыт), игра спрашивает, загрузить ли его.
Облако никогда не затирается более слабым прогрессом.

## 3. Рейтинги Game Center

1. В App Store Connect создать игру и в разделе Game Center завести таблицы рекордов с этими ID:
   - `hh.event.stage` - лучший этап ивента, повторяющаяся раз в неделю (в понедельник), больше = лучше;
   - `hh.dungeon.floor` - сумма лучших этажей всех подземелий, классическая;
   - `hh.level` - лучший уровень, классическая;
   - `hh.rebirths` - число перерождений, классическая.
2. В entitlements добавить `com.apple.developer.game-center` = `true`.
3. В `project.yml` поставить `HHGameCenter: true`. В профиле появится карточка "Рейтинги".

## 4. Оценка в App Store

`HHAppStore: true` включает системное окно оценки: после круглого уровня (10, 20, ...) и первой победы над боссом подземелья, не чаще раза за версию.

## 5. Обратная связь

В `Feedback.address` (`Platform.swift`) вписать почту для писем из игры. Пока она пустая, письмо открывается без адресата.

## 6. Остальное перед выпуском

- Заменить тестовые идентификаторы AdMob на свои (`Ads.swift` и `GADApplicationIdentifier` в `project.yml`).
- Завести покупки в App Store Connect с теми же ID, что в `Store.swift`.
- Подпись в CI: сертификат и профиль в секретах GitHub, экспорт `.ipa` для App Store.
