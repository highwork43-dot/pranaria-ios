#!/usr/bin/env bash
# Проверка проекта на Linux: сборка ядра, тесты, целостность ресурсов.
#
# Запуск:  bash Tools/verify.sh
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

FAILED=0
ok()   { echo "  ✅ $1"; }
fail() { echo "  ❌ $1"; FAILED=1; }

echo "==> 1. Сборка и тесты ядра"
if command -v swift >/dev/null 2>&1; then
  swift build 2>&1 | tail -3
  swift test 2>&1 | grep -E "Executed [0-9]+ tests" | tail -1
  if swift test >/dev/null 2>&1; then ok "тесты ядра прошли"; else fail "тесты ядра упали"; fi
else
  echo "  ⚠️  swift не найден — пропускаю (в CI он ставится через setup-swift)"
fi

echo
echo "==> 2. Каталоги данных"
python3 - <<'PY'
import json, os, sys

ok = True
programs = json.load(open('Content/programs.json', encoding='utf-8'))
achievements = json.load(open('Content/achievements.json', encoding='utf-8'))
license_env = json.load(open('Content/license.json', encoding='utf-8'))

checks = [
    (len(programs) == 24, f'программ: {len(programs)} (ожидается 24)'),
    (len(achievements) == 33, f'достижений: {len(achievements)} (ожидается 33)'),
    (license_env['payload']['level'] == 'pro', 'уровень лицензии: pro'),
    (license_env['payload']['purchase']['receipt'] == '312', 'чек №312 на месте'),
    (all(p['icon'] for p in programs), 'у всех программ есть иконка'),
    (all(p['backgroundImage'] for p in programs), 'у всех программ есть фон'),
    (all(len(c['phases']) == 4 for p in programs for c in p['cycles']), 'в каждом цикле 4 фазы'),
    (all(p['difficultySteps'] for p in programs), 'у всех программ есть уровни сложности'),
]
for passed, label in checks:
    print(('  ✅ ' if passed else '  ❌ ') + label)
    ok = ok and passed
sys.exit(0 if ok else 1)
PY
[ $? -eq 0 ] || FAILED=1

echo
echo "==> 3. Ресурсы"
AUDIO=$(ls Content/Audio/*.m4a 2>/dev/null | wc -l)
IMAGES=$(ls Content/Images/*.png 2>/dev/null | wc -l)
PROG_ICON=$(ls Content/Images/pr[0-9]*.png 2>/dev/null | wc -l)
PROG_BG=$(ls Content/Images/prog*.png 2>/dev/null | wc -l)
ACH_ICON=$(ls Content/Images/ach*.png 2>/dev/null | wc -l)
[ "$AUDIO" -eq 12 ] && ok "звуков: $AUDIO" || fail "звуков: $AUDIO (ожидается 12)"
[ "$IMAGES" -ge 199 ] && ok "изображений: $IMAGES" || fail "изображений: $IMAGES (ожидается ≥199)"
[ "$PROG_ICON" -eq 24 ] && ok "иконок программ: $PROG_ICON" || fail "иконок программ: $PROG_ICON (ожидается 24)"
[ "$PROG_BG" -eq 24 ] && ok "фонов программ: $PROG_BG" || fail "фонов программ: $PROG_BG (ожидается 24)"
[ "$ACH_ICON" -ge 33 ] && ok "иконок достижений: $ACH_ICON" || fail "иконок достижений: $ACH_ICON (ожидается ≥33)"

echo
echo "==> 4. Целостность JSON для Swift-моделей"
python3 - <<'PY'
import json, sys
prog_keys = {"id","index","name","shortDescription","description","category","categoryDescription",
             "lengthMinutes","difficulty","mode","timeInProportion","breatheType","breatheWay",
             "soundsSettings","backgroundColor","icon","backgroundImage","cycles","difficultySteps"}
cycle_keys = {"phases","repeats","timeInProportion","breatheType","wayInhale","wayExhale","swapMethods"}
phase_keys = {"kind","proportion","fixed"}
step_keys = {"phases","total","multiply"}
ach_keys = {"id","name","description","icon","rule"}
rule_keys = {"kind","threshold","buckets"}

programs = json.load(open('Content/programs.json', encoding='utf-8'))
achievements = json.load(open('Content/achievements.json', encoding='utf-8'))
ok = True
for p in programs:
    ok &= set(p) == prog_keys
    for c in p['cycles']:
        ok &= set(c) == cycle_keys
        for ph in c['phases']:
            ok &= set(ph) == phase_keys
    for s in p['difficultySteps']:
        ok &= set(s) == step_keys
for a in achievements:
    ok &= set(a) == ach_keys and set(a['rule']) == rule_keys
print('  ✅ схемы JSON совпадают с Swift-моделями' if ok else '  ❌ расхождение схем')
sys.exit(0 if ok else 1)
PY
[ $? -eq 0 ] || FAILED=1

echo
if [ $FAILED -eq 0 ]; then
  echo "ИТОГ: всё проверено успешно ✅"
else
  echo "ИТОГ: есть проблемы ❌"
fi
exit $FAILED
