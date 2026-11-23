#!/usr/bin/env bash
# Установка .ipa на подключённый iPhone через Sideloader CLI (свободный Apple ID).
#
# Учётные данные НЕ передаются через чат и не попадают в историю команд:
#   1) пользователь кладёт Apple ID и пароль в файл ~/.config/pranaria/apple_creds
#      (две строки: Apple ID, затем пароль);
#   2) когда придёт запрос кода 2FA — пользователь кладёт 6 цифр в файл
#      ~/.config/pranaria/apple_2fa_code, скрипт подхватит их автоматически.
#
# Запуск:
#   bash Tools/sideload_install.sh [путь/к/ipa]
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="${SIDELOADER_BIN:-$ROOT/../tools/sideloader-patched}"
IPA="${1:-$ROOT/build/Pranaria-unsigned.ipa}"
CREDS="${CREDS_FILE:-$HOME/.config/pranaria/apple_creds}"
CODE_FILE="${CODE_FILE:-$HOME/.config/pranaria/apple_2fa_code}"
UDID="${UDID:-$(cat "$HOME/.config/pranaria/device_udid" 2>/dev/null)}"
OUT="/tmp/sideloader_out.$$"
FIFO="/tmp/sideloader_in.$$"

[ -x "$BIN" ] || { echo "Не найден Sideloader CLI: $BIN"; exit 1; }
[ -f "$IPA" ] || { echo "Не найден .ipa: $IPA"; exit 1; }
[ -f "$CREDS" ] || { echo "Нет файла с учётными данными: $CREDS"; exit 1; }
[ -n "$UDID" ] || { echo "Не известен UDID устройства"; exit 1; }

# Ubuntu 26 не содержит старого Apple Root CA (RSA) — без него TLS-проверка
# к gs.apple.com (SRP-сервер Apple) падает. Добавляем выписку в bundle.
CA_BUNDLE="$HOME/.config/pranaria/ca-bundle.crt"
if [ -f "$CA_BUNDLE" ]; then
  export SSL_CERT_FILE="$CA_BUNDLE"
fi

APPLE_ID=$(sed -n '1p' "$CREDS")
PASSWORD=$(sed -n '2p' "$CREDS")

echo "==> Устройство: $UDID"
echo "==> Запускаю Sideloader"
rm -f "$FIFO" "$OUT"; mkfifo "$FIFO"

# script даёт псевдо-TTY (нужен для getpass), stdout перенаправляем в файл,
# чтобы можно было опрашивать состояние по мере появления подсказок.
script -qec "$BIN install -i -d --udid $UDID '$IPA'" /dev/null < "$FIFO" > "$OUT" 2>&1 &
SCRIPT_PID=$!
exec 3> "$FIFO"

cleanup() { exec 3>&- 2>/dev/null; rm -f "$FIFO" "$OUT"; }
trap cleanup EXIT

feed() { printf '%s\n' "$1" >&3; }

wait_for() {  # wait_for <шаблон> <таймаут_сек>
  local pattern="$1" limit="${2:-60}" i=0
  while [ $i -lt $((limit * 4)) ]; do
    grep -q "$pattern" "$OUT" 2>/dev/null && return 0
    kill -0 $SCRIPT_PID 2>/dev/null || return 1
    sleep 0.25; i=$((i + 1))
  done
  return 1
}

echo "==> Ввожу Apple ID и пароль"
feed "$APPLE_ID"
sleep 1
feed "$PASSWORD"

# Код 2FA: ждём файл с кодом (пользователь кладёт его, когда получит push от Apple)
if wait_for "code has been sent|type it here|Enter the code|security code" 180; then
  echo "==> Запрошен код 2FA. Положите 6 цифр в $CODE_FILE"
  i=0
  while [ $i -lt 400 ]; do   # до 100 секунд
    if [ -s "$CODE_FILE" ]; then
      CODE=$(tr -d '[:space:]' < "$CODE_FILE")
      rm -f "$CODE_FILE"
      echo "==> Ввожу код 2FA"
      feed "$CODE"
      break
    fi
    kill -0 $SCRIPT_PID 2>/dev/null || break
    sleep 0.25; i=$((i + 1))
  done
fi

echo "==> Жду завершения установки"
wait $SCRIPT_PID
STATUS=$?
exec 3>&- 2>/dev/null; rm -f "$FIFO"

echo "==> Итог (код $STATUS)"
tr '\r' '\n' < "$OUT" | grep -viE "completed$" | grep -vE "^\s*$" | tail -30
exit $STATUS
