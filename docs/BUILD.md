# Сборка и установка на iPhone 16 Pro Max

## Важно: нужен macOS

Сборку iOS-приложения выполняет только Xcode, а Xcode работает только на macOS.
На Linux/macOS-сборку можно вынести в облачный CI.

## Вариант A — GitHub Actions (работает, бесплатно)

Репозиторий публичный → macOS-Intel-раннеры бесплатны.

```bash
gh workflow run ci.yml
gh run watch $(gh run list --workflow ci.yml --limit 1 --json databaseId -q '.[0].databaseId')
bash Tools/ci.sh --download     # забрать build/Pranaria-unsigned.ipa
```

Важно: образ `macos-14` (ARM) платный и job отменяется — нужен `macos-13`.

## Вариант B — Codemagic (запасной)

Конфиг `codemagic.yaml` в корне репозитория. Требуется API-ключ:

```bash
mkdir -p ~/.config/pranaria
printf '%s' 'ВАШ_КЛЮЧ' > ~/.config/pranaria/codemagic_api_key
bash Tools/codemagic_build.sh
```

## Вариант C — свой Mac

1. Установить [XcodeGen](https://github.com/yonaskolb/XcodeGen):
   ```bash
   brew install xcodegen
   ```
2. Сгенерировать проект:
   ```bash
   cd pranaria-ios
   xcodegen generate
   open Pranaria.xcodeproj
   ```
3. В Xcode выбрать свой Apple ID (Xcode → Settings → Accounts → «Manage
   Certificates» → **Apple Development**). Это бесплатная подпись на 7 дней;
   приложение ставится на телефон через кабель или «Devices & Simulators».
4. Выбрать свой iPhone как target → **Run** (⌘R). Первая установка попросит
   на iPhone подтвердить доверие: Настройки → Основные → VPN и управление
   устройством → доверять разработчику.

## Вариант B — без Mac (облачный CI)

Пример на GitHub Actions (раннер `macos-14`):

```yaml
name: Build IPA
on: [push]
jobs:
  build:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - run: brew install xcodegen
      - run: xcodegen generate
      - name: Archive
        run: |
          xcodebuild -project Pranaria.xcodeproj -scheme Pranaria \
            -configuration Release -destination 'generic/platform=iOS' \
            -archivePath build/Pranaria.xcarchive archive
      - uses: actions/upload-artifact@v4
        with:
          name: ipa
          path: build/Pranaria.xcodeproj/export/Pranaria.ipa
```

Альтернативы: Codemagic, Bitrise, MacStadium, Xcode Cloud.

## Вариант C — подписька и установка на телефон

Подписанный `.ipa` ставится на iPhone 16 Pro Max:

* **AltStore / SideStore / Sideloadly** — бесплатно, без аккаунта разработчика,
  нужен компьютер (Windows/macOS/Linux) и доверие к сертификату;
* **TestFlight** — если собрать с аккаунтом Apple Developer ($99/год);
* **прямая установка через Xcode** — самый простой путь, если есть Mac.

## Структура ресурсов

`project.yml` подключает папками:

* `Content/Audio` → 12 файлов `.m4a` (фон, метроном, сигналы фаз);
* `Content/Images` → 199 PNG (иконки программ, фоны, достижения);
* `Content/programs.json` → каталог 24 программ.

Если файлы лежат в других местах, поправьте секцию `resources` в `project.yml`
или перенесите папки в `Content/`.

## Проверка после установки

1. «Тренировки» → откройте «Квадратное дыхание» → «Начать»: круг должен
   расширяться на вдохе и сжиматься на выдохе, звуки фаз — играть.
2. «Настройки» → «Полная версия»: без промокода доступна базовая часть
   программ; медитации помечены замком.
3. «Прогресс»: завершённая тренировка появляется в списке и на графике.

## Пересборка каталога программ

Если менялся исходный APK:

```bash
python3 Tools/extract_programs.py \
    --jadx /path/to/jadx_out/sources/melstudio/breathing/prana/meditate \
    --res  /path/to/apktool_out/res \
    --out  Content/programs.json
```
