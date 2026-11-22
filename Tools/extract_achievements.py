#!/usr/bin/env python3
"""Собирает каталог достижений (33 штуки) из ресурсов оригинального APK.

Названия и описания берутся из res/values-ru/arrays.xml (achNames, achDescr),
иконки — res/drawable (ach1 … ach33). Условия разблокировки восстановлены по
смыслу оригинальных формулировок.

Результат: Content/achievements.json — формат модели Achievement (Swift).
"""

import argparse
import json
import os
import re

# id → (правило, порог, отрезки суток)
RULES = {
    1:  ("member", 0, []),          # Пранария — стать участником сообщества
    2:  ("sessionCount", 1, []),
    3:  ("sessionCount", 5, []),
    4:  ("sessionCount", 10, []),
    5:  ("sessionCount", 25, []),
    6:  ("sessionCount", 50, []),
    7:  ("sessionCount", 100, []),
    8:  ("sessionCount", 250, []),
    9:  ("sessionCount", 500, []),
    10: ("programCreated", 0, []),
    11: ("meditationCount", 1, []),
    12: ("meditationCount", 10, []),
    13: ("meditationCount", 50, []),
    14: ("meditationCount", 100, []),
    15: ("streakDays", 3, []),
    16: ("streakDays", 5, []),
    17: ("streakDays", 7, []),
    18: ("streakDays", 14, []),
    19: ("streakDays", 30, []),
    20: ("healthLevel", 1, []),
    21: ("healthLevel", 2, []),
    22: ("healthLevel", 3, []),
    23: ("healthLevel", 5, []),
    24: ("allDifficulties", 0, []),
    25: ("distinctPrograms", 3, []),
    26: ("distinctPrograms", 5, []),
    27: ("distinctPrograms", 10, []),
    28: ("shared", 0, []),
    29: ("timeOfDay", 0, ["night"]),
    30: ("timeOfDay", 0, ["day"]),
    31: ("timeOfDay", 0, ["morning"]),
    32: ("timeOfDay", 0, ["evening"]),
    33: ("timeOfDay", 0, []),        # все четыре отрезка суток
}


def read_string_array(res_dir, name):
    for locale in ("values-ru", "values"):
        path = os.path.join(res_dir, locale, "arrays.xml")
        if not os.path.exists(path):
            continue
        text = open(path, encoding="utf-8").read()
        match = re.search(
            r'<string-array name="%s"[^>]*>(.*?)</string-array>' % re.escape(name),
            text, re.S,
        )
        if not match:
            continue
        items = re.findall(r"<item>(.*?)</item>", match.group(1), re.S)
        if items:
            return [unescape(i) for i in items]
    return []


def unescape(text):
    return (
        text.replace("&lt;", "<")
        .replace("&gt;", ">")
        .replace("&quot;", '"')
        .replace("&apos;", "'")
        .replace("&amp;", "&")
        .strip()
    )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--res", required=True, help="каталог res (после apktool)")
    parser.add_argument("--out", required=True, help="куда писать achievements.json")
    args = parser.parse_args()

    names = read_string_array(args.res, "achNames")
    descriptions = read_string_array(args.res, "achDescr")
    print(f"Названий: {len(names)}, описаний: {len(descriptions)}")

    achievements = []
    for index in range(1, 34):
        kind, threshold, buckets = RULES[index]
        achievements.append({
            "id": index,
            "name": names[index - 1] if index - 1 < len(names) else f"Достижение {index}",
            "description": descriptions[index - 1] if index - 1 < len(descriptions) else "",
            "icon": f"ach{index}",
            "rule": {
                "kind": kind,
                "threshold": threshold,
                "buckets": buckets,
            },
        })

    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as handle:
        json.dump(achievements, handle, ensure_ascii=False, indent=1)
    print(f"Записано: {args.out} ({len(achievements)} достижений)")


if __name__ == "__main__":
    main()
