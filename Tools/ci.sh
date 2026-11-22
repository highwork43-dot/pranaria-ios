#!/usr/bin/env bash
# Сборка iOS-версии в облачном CI (GitHub Actions, macos-14) и загрузка .ipa.
#
# Требуется gh (авторизован) и токен со scope `workflow`:
#   gh auth refresh -h github.com -s workflow
#
# Использование:
#   bash Tools/ci.sh              # запустить сборку и дождаться результата
#   bash Tools/ci.sh --download   # только скачать последний артефакт
set -euo pipefail

REPO="${REPO:-highwork43-dot/pranaria-ios}"
WORKDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACT="Pranaria-unsigned-ipa"
OUTDIR="$WORKDIR/build"

cd "$WORKDIR"

if [ "${1:-}" = "--download" ]; then
  mkdir -p "$OUTDIR"
  RUN_ID=$(gh run list --repo "$REPO" --workflow ci.yml --limit 1 --json databaseId -q '.[0].databaseId')
  echo "Последний прогон: $RUN_ID"
  gh run download "$RUN_ID" --repo "$REPO" --name "$ARTIFACT" --dir "$OUTDIR"
  ls -la "$OUTDIR"
  exit 0
fi

echo "==> Коммит и push"
git add -A
if git diff --cached --quiet; then
  echo "Изменений нет"
else
  git commit -q -m "ci: обновление проекта"
  git push -q origin HEAD
fi

echo "==> Запуск workflow"
gh workflow run ci.yml --repo "$REPO" || gh workflow run --repo "$REPO" -f ci.yml
sleep 5
RUN_ID=$(gh run list --repo "$REPO" --workflow ci.yml --limit 1 --json databaseId,status -q '.[0].databaseId')
echo "Прогон: $RUN_ID"

echo "==> Ожидание завершения"
gh run watch "$RUN_ID" --repo "$REPO" --exit-status

echo "==> Скачивание .ipa"
mkdir -p "$OUTDIR"
gh run download "$RUN_ID" --repo "$REPO" --name "$ARTIFACT" --dir "$OUTDIR"
ls -la "$OUTDIR"
echo
echo "Готово: $OUTDIR/Pranaria-unsigned.ipa"
echo "Установка на iPhone: docs/INSTALL.md"
