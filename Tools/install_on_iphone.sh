#!/usr/bin/env bash
# Подпись .ipa сертификатом разработчика и установка на подключённый iPhone.
#
# Нужны два файла (скачиваются с developer.apple.com):
#   cert.p12               — «Apple Development» сертификат с приватным ключом
#   profile.mobileprovision — профиль разработки для этого устройства
# и пароль от p12 (в переменной P12_PASSWORD).
#
# Использование:
#   export P12_PASSWORD='пароль_от_p12'
#   bash Tools/install_on_iphone.sh /путь/к/cert.p12 /путь/к/profile.mobileprovision
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV="${VENV:-$ROOT/../.venv-pmd}"
PMD="$VENV/bin/pymobiledevice3"
ZSIGN="${ZSIGN:-$ROOT/../tools/zsign}"

CERT="${1:-}"
PROFILE="${2:-}"
IPA_IN="$ROOT/build/Pranaria-unsigned.ipa"
IPA_OUT="$ROOT/build/Pranaria-signed.ipa"

[ -f "$CERT" ] || { echo "Не найден сертификат: $CERT"; exit 1; }
[ -f "$PROFILE" ] || { echo "Не найден профиль: $PROFILE"; exit 1; }
[ -f "$IPA_IN" ] || { echo "Не найден $IPA_IN — сначала соберите приложение"; exit 1; }
: "${P12_PASSWORD:?Задайте P12_PASSWORD — пароль от p12}"

echo "==> 1. Устройство"
"$PMD" usbmux list | python3 -c "
import json,sys
d = json.load(sys.stdin)
for dev in d:
    print('   ', dev.get('DeviceName'), '|', dev.get('ProductType'), '| iOS', dev.get('ProductVersion'))
    print('    UDID:', dev.get('UniqueDeviceID'))
"
UDID=$("$PMD" usbmux list | python3 -c "import json,sys; d=json.load(sys.stdin); print(d[0]['UniqueDeviceID'] if d else '')")
[ -n "$UDID" ] || { echo "Устройство не найдено по USB"; exit 1; }

echo "==> 2. Режим разработчика"
DEV_MODE=$("$PMD" amfi developer-mode-status 2>/dev/null | tr -d '[:space:]')
echo "   developer mode: $DEV_MODE"
[ "$DEV_MODE" = "true" ] || { echo "Включите Режим разработчика: Настройки → Основные → VPN и управление устройством"; exit 1; }

echo "==> 3. Подпись ($ZSIGN)"
"$ZSIGN" -c "$CERT" -p "$P12_PASSWORD" -m "$PROFILE" -o "$IPA_OUT" "$IPA_IN"
ls -la "$IPA_OUT"

echo "==> 4. Установка на устройство $UDID"
"$PMD" apps install "$IPA_OUT"

echo "==> 5. Проверка"
"$PMD" apps list | python3 -c "
import json,sys
d = json.load(sys.stdin)
found = False
for app in d:
    bid = app.get('CFBundleIdentifier','')
    name = app.get('CFBundleDisplayName') or app.get('CFBundleName') or ''
    if 'pranaria' in bid.lower() or 'ранария' in name.lower():
        found = True
        print('    УСТАНОВЛЕНО:', bid, '|', name)
print('    приложение не найдено' if not found else '')
"
echo
echo "Готово. При первом запуске подтвердите разработчика:"
echo "  Настройки → Основные → VPN и управление устройством → Доверять разработчику"
