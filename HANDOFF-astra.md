# Задача для Астры Ультра 6.2: доустановить «Пранарию» на iPhone

## Цель

Приложение **«Пранария»** (iOS-порт) собрано — осталось **подписать и поставить на
реальный iPhone 16 Pro Max по USB**. Сейчас установка упирается в SRP-аутентификацию
в Apple (клиент зависает). Нужно довести до рабочего состояния на устройстве.

## Окружение

| | |
|---|---|
| Устройство | iPhone 16 Pro Max (`iPhone17,2`), **iOS 27.2.1**, UDID `00008140-001138AA019B001C` |
| Подключение | USB, компьютер доверен, **режим разработчика включён** (`amfi developer-mode-status` → true) |
| Машина | Linux (Ubuntu 26.04), **без macOS**, без sudo, с VPN hiddify-core (TUN) |
| Codex | `codex` (модель `gpt-6.2-astra`), `codex exec` для неинтерактивного запуска |
| Ограничение | Только бесплатные пути. Платная подписка Apple Developer Program ($99/год) недоступна |

## Что уже сделано (не переделывать)

1. **Реверс Android-оригинала** `melstudio.breathing.prana.meditate` 2.1.1:
   - каталог из **24 программ** с реальными пропорциями фаз и уровнями сложности
     (`Content/programs.json`, скрипт `Tools/extract_programs.py`);
   - **33 достижения** (`Content/achievements.json`, `Tools/extract_achievements.py`);
   - 12 звуков и 199 PNG (`Content/Audio`, `Content/Images`).
2. **Ядро на чистом Foundation** (`Sources/PranariaCore`) + 32 unit-теста
   (`Tests/PranariaCoreTests`) — проходят локально и в CI.
3. **iOS-приложение** (`Sources/PranariaApp`, SwiftUI): каталог, тренировка с
   анимацией круга, звуки, TTS-инструкции, прогресс, аналитика, достижения,
   полная версия (встроенная лицензия `Content/license.json` с подписью HMAC-SHA256).
4. **`.ipa` собран** в GitHub Actions (раннер `macos-15`, бесплатно для публичного
   репозитория): `pranaria-ios/build/Pranaria-unsigned.ipa` (62,7 МБ, 222 файла).
   Сборка воспроизводима: `.github/workflows/ci.yml` + `bash Tools/ci.sh`.
5. **Обход несовместимости iOS 26**: Sideloader падал на
   `plist.InvalidIndexException ... No entry with index 'X-Apple-I-MD-RINFO'`
   (на новых iOS устройство не возвращает этот ключ). Патч внесён в
   `Provision/lib/provision/adi.d` (ключи `X-Apple-I-MD-RINFO`, `ptm`, `tk` сделаны
   необязательными), **собран** LDC 1.34 → бинарник
   `tools/sideloader-patched` (проверен: «Device provisioned successfully»).

## Что не работает (главное)

Команда:

```bash
cd pranaria-ios
SIDELOADER_BIN=../tools/sideloader-patched bash Tools/sideload_install.sh build/Pranaria-unsigned.ipa
```

Дошла до: `Provisioning device... → Device provisioned successfully → Logging in...`
(Apple ID и пароль подаются автоматически из `~/.config/pranaria/apple_creds`).
**Дальше процесс висит** — соединение с Apple в состоянии CLOSE-WAIT, клиент получил
~34 КБ и не читает их. Никакой ошибки не печатается.

### Что уже проверено (не повторять)

- `gs.apple.com` и `gsa.apple.com` **не проходили TLS-проверку**: в Ubuntu 26 нет
  старого **Apple Root CA** (RSA). Исправлено: корень выгружен с сервера Apple и
  добавлен в `~/.config/pranaria/ca-bundle.crt`; скрипт выставляет
  `SSL_CERT_FILE`. После этого `gs.apple.com` отвечает 302, `gsa.apple.com` — 401
  (то есть SRP-хосты достижимы).
- `auth.apple.com` недоступен из этой сети (curl → 000) — но в коде Sideloader
  не используется.
- Ответ `https://idmsa.apple.com/appleauth/auth/signin` — **HTML-страница на 47 КБ**,
  а не plist. Похоже, Apple отдаёт веб-страницу входа вместо SRP-plist
  (клиент ждёт plist и зависает на разборе).
- Sideloader CLI из релизов (1.0-pre4, 10.2024) и свежая сборка из CI проекта
  (main, 06.11.2026) ведут себя одинаково — проблема не в версии CLI.
- Попытка скорректировать `Provision` локально не сработала: `dub` копирует
  path-зависимость в кэш `~/.dub/packages/provision/<commit>/` и собирает **из кэша**.
  Рабочий путь: патчить `~/.dub/packages/provision/645d56d8.../provision/lib/provision/adi.d`
  и пересобирать `dub build --build=release --compiler=ldc2 --force` из
  `/tmp/sideloader_src/frontends/cli` (компилятор: `/tmp/dlang/ldc/bin/ldc2`,
  `LD_LIBRARY_PATH=/tmp/swiftlibs`).

## Где что лежит

```
pranaria-ios/
  build/Pranaria-unsigned.ipa     готовый .ipa (подписанный не нужен — Sideloader подпишет сам)
  Tools/sideload_install.sh       установщик (FIFO + псевдо-TTY, читает креды и код 2FA из файлов)
  Tools/ci.sh, Tools/verify.sh    сборка .ipa и проверка проекта
  HANDOFF.md                      общий документ по проекту
tools/sideloader-patched          патченый Sideloader CLI (LDC 1.34)
~/.config/pranaria/apple_creds    Apple ID + пароль (строка 1 — ID, строка 2 — пароль)
~/.config/pranaria/apple_2fa_code сюда кладётся 6-значный код 2FA, когда придёт запрос
~/.config/pranaria/ca-bundle.crt системные CA + Apple Root CA
~/.config/pranaria/device_udid    UDID iPhone
```

## Подсказки, куда копать (с моей точки зрения)

1. **Проверить, не мешает ли VPN.** Трафик идёт через hiddify-core (TUN,
   `--listen 127.0.0.1:17079`). Есть вариант пустить запросы к Apple напрямую,
   минуя прокси (hiddify умеет direct-правила для доменов), или через
   `HTTPS_PROXY=127.0.0.1:17079` с корректным `SSL_CERT_FILE`.
2. **Проверить фактический ответ SRP.** `curl` к
   `https://gsa.apple.com/grandslam/GsService2/lookup` без корректного OTP даёт
   401 (172 байта HTML). С корректным OTP от устройства должен прийти plist с
   URL-мешком (`urls`). Стоит снять реальный ответ через `strace`/`gdb` на
   процессе или перехватить его mitm-прокси с корректным CA (у нас уже есть
   выгрузка цепочки от Apple).
3. **Альтернативные клиенты.** Стоит проверить более свежие реализации Apple ID
   SRP: `sidecli` (Rust, Linux, iOS 17+), `AltStore`/`SideStore`, `Apple Configurator`.
   Возможно, проще — не Sideloader, а другой инструмент для free-профиля.
4. **План B — платная подписка Apple Developer Program ($99/год).** Тогда открывается
   портал `developer.apple.com/account/resources/certificates` (сейчас отдаёт
   «Access Unavailable» для аккаунта без подписки), и сертификат+профиль можно
   сделать самому через `zsign` + `pymobiledevice3 apps install`. Это решение
   требует решения владельца (платёж).
5. **Уже есть готовая связка для подписи:** `zsign` (1.1.3) подписывает .ipa
   сертификатом + .mobileprovision; `pymobiledevice3` ставит подписанный .ipa
   по USB. Нужен лишь .p12 и .mobileprovision.

## Как проверить результат

```bash
cd ~/.../pranaria-ios
../.venv-pmd/bin/pymobiledevice3 apps list | python3 -c "
import json,sys
d=json.load(sys.stdin)
for k,v in d.items():
    if 'pranaria' in k.lower() or 'ранария' in (v.get('CFBundleDisplayName') or ''):
        print('УСТАНОВЛЕНО:', k, v.get('CFBundleDisplayName'))
"
```

После установки на устройстве: Настройки → Основные → VPN и управление устройством →
довериться разработчику; затем «Пранария» → «Тренировки» → любая программа → «Начать».

## Что просят от агента

1. Довести установку до работающего приложения на устройстве.
2. Не ломать уже собранный `.ipa` и исходники приложения.
3. Секреты (пароль Apple ID, коды 2FA) не выводить в отчёт и не коммитить.
4. Отчёт: что сделано, чем проверено (с реальными командами), что осталось.
