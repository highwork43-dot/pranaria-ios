#!/usr/bin/env bash
# Сборка .ipa через Codemagic API и скачивание артефакта.
#
# Подготовка (один раз):
#   1. codemagic.io → Settings → API keys → создать ключ
#   2. export CODEMAGIC_API_KEY=<ключ>
#   3. Codemagic должен быть подключён к репозиторию
#      highwork43-dot/pranaria-ios (иначе скрипт создаст проект сам)
#
# Запуск:
#   bash Tools/codemagic_build.sh             # запустить сборку и дождаться
#   bash Tools/codemagic_build.sh --download  # забрать последний артефакт
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTDIR="$ROOT/build"
REPO_SLUG="${REPO_SLUG:-highwork43-dot/pranaria-ios}"
API="https://api.codemagic.io/v1"

: "${CODEMAGIC_API_KEY:?Задайте CODEMAGIC_API_KEY (Settings → API keys на codemagic.io)}"
AUTH=(-H "Authorization: Bearer $CODEMAGIC_API_KEY" -H "Content-Type: application/json")

api() {  # api <METHOD> <PATH> [json]
  local method="$1" path="$2" body="${3:-}"
  if [ -n "$body" ]; then
    curl -sS -X "$method" "${AUTH[@]}" -d "$body" "$API$path"
  else
    curl -sS -X "$method" "${AUTH[@]}" "$API$path"
  fi
}

find_project_id() {
  api GET "/projects" \
    | python3 -c "
import json,sys
projects = json.load(sys.stdin)
for p in projects:
    slug = (p.get('repository') or {}).get('slug') or ''
    name = p.get('name') or ''
    if '$REPO_SLUG'.lower() in slug.lower() or '$REPO_SLUG'.lower() in name.lower():
        print(p['id']); break
"
}

if [ "${1:-}" = "--download" ]; then
  BUILD_ID=$(api GET "/builds" \
    | python3 -c "
import json,sys
builds = json.load(sys.stdin)
for b in builds:
    if b.get('status') == 'SUCCESS':
        print(b['id']); break
")
  [ -n "$BUILD_ID" ] || { echo "Нет успешных сборок"; exit 1; }
  echo "Сборка: $BUILD_ID"
  mkdir -p "$OUTDIR"
  api GET "/builds/$BUILD_ID/artifacts" > /tmp/cm_artifacts.json
  python3 - "$OUTDIR" <<'PY'
import json, sys, subprocess, os
outdir = sys.argv[1]
artifacts = json.load(open('/tmp/cm_artifacts.json'))
target = next((a for a in artifacts if a.get('name','').endswith('.ipa')), None) or artifacts[0]
print('Артефакт:', target.get('name'), target.get('path', ''))
with open(os.path.join(outdir, target.get('name', 'artifact.bin')), 'wb') as f:
    subprocess.run(['curl', '-sSL', '-H', f"Authorization: Bearer {os.environ['CODEMAGIC_API_KEY']}",
                    target['download_url'], '-o', f.name], check=True)
PY
  ls -la "$OUTDIR"
  exit 0
fi

PROJECT_ID="$(find_project_id)"
if [ -z "$PROJECT_ID" ]; then
  echo "Проект не найден в Codemagic — создаю"
  PROJECT_ID=$(api POST "/projects" "{
    \"app_store_app_id\": \"ru.melstudio.pranaria.personal\",
    \"name\": \"Pranaria iOS\",
    \"repo_type\": \"github\",
    \"repo_owner\": \"highwork43-dot\",
    \"repo_name\": \"pranaria-ios\"
  }" | python3 -c "import json,sys; print(json.load(sys.stdin).get('id',''))")
fi
[ -n "$PROJECT_ID" ] || { echo "Не удалось определить проект"; exit 1; }
echo "Проект Codemagic: $PROJECT_ID"

echo "==> Запуск сборки"
BUILD_ID=$(api POST "/builds" "{\"projectId\": $PROJECT_ID, \"branch\": \"main\"}" \
  | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('id',''))")
[ -n "$BUILD_ID" ] || { echo "Не удалось запустить сборку"; exit 1; }
echo "Сборка: $BUILD_ID"

echo "==> Ожидание"
for i in $(seq 1 120); do
  STATUS=$(api GET "/builds/$BUILD_ID" | python3 -c "import json,sys; print(json.load(sys.stdin).get('status',''))")
  echo "  [$i] $STATUS"
  case "$STATUS" in
    SUCCESS) echo "Сборка успешна"; break ;;
    FAILED|ERROR|CANCELLED) echo "Сборка не удалась: $STATUS"; exit 1 ;;
  esac
  sleep 20
done

"$0" --download
