import sys, os, json, shutil
from loguru import logger
logger.remove()
import zipfile
from androguard.core.apk import APK

APK_PATH = '/tmp/pranaria_rev/x/melstudio.breathing.prana.meditate.apk'
OUT = '/tmp/pranaria_rev/content'
os.makedirs(OUT, exist_ok=True)

apk = APK(APK_PATH)
res = apk.get_android_resources()

# 1) Localized strings (all locales) -> resources/strings/<lang>.json
strings = res.get_resolved_strings()
print('resolved string buckets:', len(strings))
os.makedirs(f'{OUT}/strings', exist_ok=True)
for lang, table in strings.items():
    clean = {}
    for name, val in table.items():
        v = val
        if isinstance(v, (list, tuple)):
            v = v[0] if v else ''
        if isinstance(v, str) and v.strip():
            clean[name] = v
    with open(f'{OUT}/strings/{lang}.json', 'w', encoding='utf-8') as f:
        json.dump(clean, f, ensure_ascii=False, indent=1)
    print(f'  {lang}: {len(clean)} strings')

# 2) Raw resources: audio + images
z = zipfile.ZipFile(APK_PATH)
os.makedirs(f'{OUT}/audio', exist_ok=True)
os.makedirs(f'{OUT}/images', exist_ok=True)
audio_ext = ('.aac', '.mp3', '.ogg', '.wav', '.m4a')
img_ext = ('.png', '.webp', '.jpg', '.jpeg')
for n in z.namelist():
    low = n.lower()
    base = os.path.basename(n)
    if '/raw/' in low and low.endswith(audio_ext):
        with open(f'{OUT}/audio/{base}', 'wb') as f:
            f.write(z.read(n))
    elif ('/drawable' in low or '/mipmap' in low) and low.endswith(img_ext):
        # keep only reasonably sized originals (nodpi preferred), skip -vXX variants of same name
        with open(f'{OUT}/images/{base}', 'wb') as f:
            f.write(z.read(n))
print('audio files:', len(os.listdir(f'{OUT}/audio')))
print('image files:', len(os.listdir(f'{OUT}/images')))
