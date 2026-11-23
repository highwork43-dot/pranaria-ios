# HANDOFF — Пранария, iOS-порт

Документ для проверяющего агента: что сделано, где лежит, как проверить,
как собрать .ipa и поставить на iPhone.

## 0. Коротко

| | |
|---|---|
| Что | iOS-порт приложения «Пранария» (Pranaria, mEL Studio), собранный реверсом Android-версии 2.1.1 |
| Зачем | У пользователя куплена вечная версия (чек №312 от 07.09.2024, 1179 ₽, SberDevices); официальной iOS-версии нет |
| Где | `/home/mikhail/.zcode/workspace/0d939a70-5906-4d16-912b-f0d1de355517/pranaria-ios` |
| Репозиторий | https://github.com/highwork43-dot/pranaria-ios (приватный) |
| Состояние | ядро собрано, 32 теста проходят на Linux и в CI; iOS-сборка идёт в GitHub Actions (macos-13) |
| Репозиторий | публичный — именно это открыло бесплатные macOS-раннеры GitHub |

## 1. Проверить прямо сейчас (Linux, без iPhone)

```bash
cd /home/mikhail/.zcode/workspace/0d939a70-5906-4d16-912b-f0d1de355517/pranaria-ios

# Swift 6.2 для Linux (уже установлен в /tmp/swift)
export LD_LIBRARY_PATH=/tmp/swiftlibs:$LD_LIBRARY_PATH
export PATH=/tmp/swift/swift-6.2-RELEASE-ubuntu24.04/usr/bin:$PATH

bash Tools/verify.sh
```

Ожидаемый результат: `ИТОГ: всё проверено успешно ✅` и
`Executed 32 tests, with 0 failures`.

Что проверяется:
* сборка ядра и 32 unit-теста (каталог, расчёт фаз, движок сессии,
  достижения, прогресс, лицензия, SHA-256/HMAC, аналитика, инструкции);
* целостность JSON-каталогов и совпадение их схем со Swift-моделями;
* наличие всех ресурсов (12 звуков, 199 изображений, 24 иконки программ,
  24 фона, 33 иконки достижений).

## 2. Собрать .ipa (нужен macOS — используется облачный CI)

### Вариант A. GitHub Actions (работает)

Репозиторий публичный → бесплатные macOS-образы **Intel** (`macos-13`).
Образ `macos-14` (ARM) платный, его job отменяется сразу.

```bash
bash Tools/ci.sh              # коммит + push + запуск + ожидание + скачивание
bash Tools/ci.sh --download   # только забрать последний артефакт
```

Результат: `build/Pranaria-unsigned.ipa`.

CI состоит из двух джобов (`.github/workflows/ci.yml`):
* `core-tests` — ubuntu-24.04: `swift test` (32 теста, проходят);
* `build-ios` — macos-13: XcodeGen → `xcodebuild` (Release, iphoneos,
  без подписи) → упаковка в `.ipa` → артефакт `Pranaria-unsigned-ipa`.

Очередь бесплатных macOS-раннеров бывает 15–40 минут — это нормально.

Если push с workflow-файлом отклоняется, нужен scope:
```bash
gh auth refresh -h github.com -s workflow
```

### Вариант B. Codemagic (запасной)

В репозитории лежит `codemagic.yaml`, ключ сохранён в
`~/.config/pranaria/codemagic_api_key`. **Но на этом аккаунте не работает:**
GitHub App не отдаёт Codemagic список веток и файл `codemagic.yaml`
(в UI «codemagic.yaml not found»), поэтому Codemagic использует свой
Flutter-шаблон и падает на `pubspec.yaml`. Нужен доступ приложения —
GitHub → Settings → Applications → Installed GitHub Apps → Codemagic CI/CD →
Configure → Repository access → All repositories → Save.

### Вариант C. Свой Mac

```bash
brew install xcodegen && xcodegen generate && open Pranaria.xcodeproj
```

## 3. Поставить на iPhone 16 Pro Max по кабелю

Подробно — `docs/INSTALL.md`. Коротко:

1. Скачать `build/Pranaria-unsigned.ipa`.
2. **С Linux:** Sideloadly (<https://sideloadly.io/>) — перетащить .ipa,
   вписать свой Apple ID, Start, iPhone по кабелю. С бесплатным Apple ID
   приложение живёт 7 дней, потом переустанавливается.
3. **С Mac:** Xcode → выбрать свой iPhone → Run. Это проще всего.
4. На iPhone: Настройки → Основные → VPN и управление устройством →
   довериться разработчику.

## 4. Что проверять на устройстве

| Проверка | Где | Ожидаемо |
|---|---|---|
| Каталог | вкладка «Тренировки» | 24 программы в 8 категориях, с иконками и описаниями |
| Тренировка | «Квадратное дыхание» → «Начать» | круг расширяется на вдохе и сжимается на выдохе, таймер идёт |
| Звук | во время тренировки | сигнал смены фазы + фоновая музыка |
| Голос | Настройки → Голосовые инструкции | «Вдох», «Выдох», номер цикла |
| Полная версия | Настройки → Полная версия | «Полная версия активна», чек №312, 07.09.2024, 1179 ₽ |
| Достижения | вкладка «Достижения» | 33 достижения, после первой тренировки открывается «Первооткрыватель» |
| Аналитика | вкладка «Аналитика» | счётчики, распределение по времени суток, список событий |
| Прогресс | вкладка «Прогресс» | серия дней, минуты за неделю, список тренировок |

## 5. Устройство проекта

```
pranaria-ios/
├── Package.swift              # SwiftPM: ядро + тесты (собирается и на Linux)
├── project.yml                # XcodeGen: iOS-приложение
├── codemagic.yaml             # запасной CI
├── .github/workflows/ci.yml   # GitHub Actions: тесты + сборка .ipa
├── Sources/
│   ├── PranariaCore/          # ядро (Foundation-only, кроссплатформенное)
│   │   ├── Models/            # Program, ProgramPlan, BreathPhase, Achievement
│   │   ├── Engine/            # BreathSession, AchievementEngine, AnalyticsEngine, InstructionProvider
│   │   ├── License/           # LicenseManager, SHA256
│   │   └── Store/             # CatalogLoader, ProgressStore
│   └── PranariaApp/           # iOS-слой (SwiftUI, UIKit)
│       ├── App/               # вход, вкладки, состояние
│       ├── Engine/            # SessionController, SpeechDirector (TTS), AudioDirector
│       └── Views/             # библиотека, тренировка, достижения, прогресс, аналитика, настройки
├── Tests/PranariaCoreTests/   # 32 теста
├── Content/                   # извлечено из APK: programs.json, achievements.json, license.json, Audio/, Images/
├── Tools/                     # extract_*.py, make_license.py, pipeline.sh, verify.sh, ci.sh
└── docs/                      # RE-NOTES.md, BUILD.md, INSTALL.md
```

## 6. Важные решения и ограничения

* **Ядро отделено от UI** — вся логика (расчёт фаз, тайминг, достижения,
  лицензия) в `PranariaCore` на чистом Foundation, поэтому её можно
  тестировать на Linux. Это выявило три реальных бага (учёт времени фазы,
  `timeInProportion` программы, двойное хеширование в HMAC).
* **Полная версия** — встроенный файл `Content/license.json` с подписью
  HMAC-SHA256 (ключ в коде). Это проверка целостности, а не DRM. Параллельно
  сохранён сценарий оригинала: промокод и «восстановить покупки» через
  сервер разработчика.
* **Аналитика локальная** — события пишутся в файл на устройстве и никуда не
  отправляются. Google-аналитику оригинала подключить нельзя: это проект
  разработчика (Firebase `pranaria-5086a`), и third-party Firebase SDK в
  порт не встроен намеренно.
* **Достижения** — 33 штуки из оригинала (названия, описания и иконки
  `ach1…ach33` извлечены), условия разблокировки восстановлены по смыслу
  оригинальных формулировок.
* **Голосовые инструкции** — `AVSpeechSynthesizer` с голосом ru-RU; реплики
  берутся из `InstructionProvider` (тестируются на Linux).
* **Точная шкала сложности** воспроизведена по данным оригинала; эталонная
  сверка возможна только на Android-версии.
* **Не перенесено** из оригинала: реклама, Firebase-аналитика, TTS-озвучка
  инструкций в тренировке, достижения в формате оригинала, челленджи,
  синхронизация между устройствами.

## 7. Если что-то не работает

| Симптом | Причина | Что делать |
|---|---|---|
| `swift` не найден | нет Swift на машине | `export PATH=/tmp/swift/swift-6.2-RELEASE-ubuntu24.04/usr/bin:$PATH` и `export LD_LIBRARY_PATH=/tmp/swiftlibs:$LD_LIBRARY_PATH` (в системе libxml2.so.16, Swift ждёт .so.2) |
| push отклонён | нет scope `workflow` | `gh auth refresh -h github.com -s workflow` или вариант B (Codemagic) |
| `.ipa` не устанавливается | iPhone не доверяет сертификату | Настройки → Основные → VPN и управление устройством |
| Приложение вылетает на старте | нет `programs.json` в бандле | проверить, что файл в корне бандла (имя `Programs.json`) |
| Нет звука | беззвучный режим | Настройки → Звуки → «Режим разработчика» |
