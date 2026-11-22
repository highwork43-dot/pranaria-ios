#!/usr/bin/env bash
# Полный конвейер: Android APK → ресурсы и каталог → iOS-порт.
#
# Требуются: apksigner/zip, apktool, jadx, JDK 21, ffmpeg, python3 + Pillow.
# Запуск:  bash Tools/pipeline.sh /путь/к/apk
set -euo pipefail

APK="${1:?Укажите путь к APK (или XAPK)}"
WORK="${WORK_DIR:-/tmp/pranaria_rev}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PKG="melstudio.breathing.prana.meditate"

mkdir -p "$WORK"/{tools,dl}

echo "==> 1. Инструменты"
if [ ! -x "$WORK/tools/bin/jadx" ]; then
  curl -sSL -o "$WORK/tools/jdk.tar.gz" \
    "https://api.adoptium.net/v3/binary/latest/21/ga/linux/x64/jdk/hotspot/normal/eclipse"
  tar xzf "$WORK/tools/jdk.tar.gz" -C "$WORK/tools"
  curl -sSL -o "$WORK/tools/jadx.zip" \
    "https://github.com/skylot/jadx/releases/download/v1.5.2/jadx-1.5.2.zip"
  unzip -q -o "$WORK/tools/jadx.zip" -d "$WORK/tools"
  curl -sSL -o "$WORK/tools/apktool.jar" \
    "https://github.com/iBotPeaches/Apktool/releases/download/v2.11.1/apktool_2.11.1.jar"
fi
export JAVA_HOME="$(ls -d "$WORK"/tools/jdk-*/ | head -1)"

echo "==> 2. Декодирование ресурсов (apktool)"
"$JAVA_HOME/bin/java" -jar "$WORK/tools/apktool.jar" d -f -s \
  -o "$WORK/apk_res" "$APK"

echo "==> 3. Декомпиляция кода (jadx)"
"$JAVA_HOME/bin/java" -Xmx3g -jar "$WORK/tools/lib/jadx-1.5.2-all.jar" \
  -d "$WORK/jadx_out" --no-res --threads-count 4 --deobf "$APK" || true

echo "==> 4. Извлечение аудио, изображений и локализации"
python3 -I "$ROOT/Tools/extract_content.py" || true

echo "==> 5. Каталог 24 программ"
python3 -I "$ROOT/Tools/extract_programs.py" \
  --jadx "$WORK/jadx_out/sources/melstudio/breathing/prana/meditate" \
  --res  "$WORK/apk_res/res" \
  --out  "$ROOT/Content/programs.json"

echo "==> 6. Конвертация звуков AAC → M4A"
for f in "$ROOT"/Content/Audio/*.aac; do
  [ -e "$f" ] || continue
  ffmpeg -y -loglevel error -i "$f" -c:a copy "${f%.aac}.m4a"
done

echo "==> 7. Конвертация WebP → PNG"
python3 -I - <<'PY'
from PIL import Image
import glob, os
for p in glob.glob(os.path.join(os.environ.get("ROOT_DIR", "."), "Content/Images/*.webp")):
    Image.open(p).convert("RGBA").save(p[:-5] + ".png")
    os.remove(p)
PY

echo "==> Готово. Каталог: $ROOT/Content/programs.json"
