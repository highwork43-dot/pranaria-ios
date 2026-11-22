#!/usr/bin/env python3
"""Извлекает каталог программ дыхания из декомпилированного Android-приложения.

Источники:
  * PDBHelper.java — seed-данные SQLite (таблица ttrain): параметры 24 программ.
  * res/values-ru/arrays.xml — названия, короткие/полные описания, категории.

Результат: Content/programs.json — формат, который читает iOS-порт
(PranariaApp/Sources/Store/ProgramCatalog.swift).

Запуск:
    python3 Tools/extract_programs.py \
        --jadx /path/to/jadx_out/sources/melstudio/breathing/prana/meditate \
        --res  /path/to/apktool_out/res \
        --out  Content/programs.json
"""

import argparse
import json
import os
import re

PHASE_KINDS = ["inhale", "holdIn", "exhale", "holdOut"]

# Цвета фона программ — из MPrograms.getBgColor()
BG_COLORS = {
    1: "#9F82D9", 2: "#D9B582", 3: "#BC82D9", 4: "#FF7373", 5: "#5C9970",
    6: "#FF884D", 7: "#FF5B4D", 8: "#8290D9", 9: "#FF8066", 10: "#82ADD9",
    11: "#F279A1", 12: "#73BF73", 13: "#73BF73", 14: "#8AC7E5", 15: "#82C5D9",
    16: "#60BFAF", 17: "#82BCD9", 18: "#FFA64D", 19: "#73BFE5", 20: "#8290D9",
    21: "#F2B230", 22: "#9191F2", 23: "#52B8CC", 24: "#FF99BB",
}

# Колонки таблицы ttrain в порядке INSERT-а
COLUMNS = [
    "name", "length", "difficulty", "difficultySettings", "timeInProportionDefault",
    "breatheTypeDefault", "breatheWayDefault", "soundsSettings", "mantras",
    "cycles", "comments", "isEditable", "deleted", "mode", "imageId",
]


def split_sql_values(values: str):
    """Разбирает список значений INSERT (строки в одинарных кавычках)."""
    out, buf, in_str, i = [], "", False, 0
    while i < len(values):
        ch = values[i]
        if in_str:
            if ch == "'":
                if i + 1 < len(values) and values[i + 1] == "'":
                    buf += "'"
                    i += 2
                    continue
                in_str = False
            else:
                buf += ch
        else:
            if ch == "'":
                in_str = True
            elif ch == ",":
                out.append(buf.strip())
                buf = ""
                i += 1
                continue
            else:
                buf += ch
        i += 1
    if buf.strip():
        out.append(buf.strip())
    return out


def parse_rows(pdbhelper_path):
    """Достаёт 24 seed-записи ttrain."""
    src = open(pdbhelper_path, encoding="utf-8").read()
    pattern = re.compile(
        r"insert into ttrain\((?P<cols>[^)]*)\) values \((?P<vals>.*?)\);",
        re.S,
    )
    rows = []
    for match in pattern.finditer(src):
        vals = split_sql_values(match.group("vals"))
        if len(vals) != len(COLUMNS):
            continue
        row = dict(zip(COLUMNS, vals))
        if not row.get("cycles"):
            continue  # пустые «черновики» 25..110
        rows.append(row)
    return rows


def parse_cycle_line(line: str):
    """Разбирает строку цикла вида '1:0:2.5:0:t1:w3-4:r2'."""
    parts = line.split(":")
    phases = []
    for index, raw in enumerate(parts[:4]):
        fixed = "!" in raw
        value = raw.replace("!", "")
        try:
            proportion = float(value)
        except ValueError:
            proportion = 0.0
        phases.append({
            "kind": PHASE_KINDS[index],
            "proportion": proportion,
            "fixed": fixed,
        })

    cycle = {
        "phases": phases,
        "repeats": 1,
        "timeInProportion": None,
        "breatheType": None,
        "wayInhale": None,
        "wayExhale": None,
        "swapMethods": False,
    }
    for extra in parts[4:]:
        if extra.startswith("w"):
            bits = extra[1:].split("-")
            if len(bits) == 2:
                try:
                    cycle["wayInhale"] = int(bits[0])
                    cycle["wayExhale"] = int(bits[1])
                except ValueError:
                    pass
        elif extra.startswith("t"):
            try:
                cycle["breatheType"] = int(extra[1:])
            except ValueError:
                pass
        elif extra.startswith("p"):
            try:
                cycle["timeInProportion"] = float(extra[1:])
            except ValueError:
                pass
        elif extra.startswith("r"):
            try:
                cycle["repeats"] = int(extra[1:])
            except ValueError:
                pass
        elif "s" in extra:
            cycle["swapMethods"] = True
    return cycle


def parse_difficulty_settings(raw: str):
    """Шаги сложности: 'p:in:hold:ex:total' или 'p:in:hold:ex:total:flag'."""
    steps = []
    for token in raw.split():
        bits = token.split(":")
        try:
            values = [float(b) for b in bits]
        except ValueError:
            continue
        if len(values) < 4:
            continue
        steps.append({
            "phases": values[:4],
            "total": values[4] if len(values) > 4 else 0.0,
            "multiply": bool(len(values) > 5 and values[5] == 1.0),
        })
    return steps


def parse_breathe_way(raw: str):
    """'1:2' → [1,0,2,0]; '0:0:1:1' → как есть; мусор → нули."""
    ways = [0, 0, 0, 0]
    if not raw:
        return ways
    parts = raw.split(":")
    try:
        numbers = [int(p) for p in parts]
    except ValueError:
        return ways
    if len(numbers) >= 4:
        return numbers[:4]
    if len(numbers) == 2:
        ways[0], ways[2] = numbers[0], numbers[1]
    elif len(numbers) == 1:
        ways[0] = numbers[0]
    return ways


def read_string_array(res_dir, name, locales=("values-ru", "values")):
    """Читает <string-array name="..."> из values*/arrays.xml."""
    for locale in locales:
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


def unescape(text: str) -> str:
    return (
        text.replace("&lt;", "<")
        .replace("&gt;", ">")
        .replace("&quot;", '"')
        .replace("&apos;", "'")
        .replace("&amp;", "&")
        .strip()
    )


def read_strings(res_dir, locales=("values-ru", "values")):
    """Читает <string name="..."> из values*/strings.xml."""
    table = {}
    for locale in locales:
        path = os.path.join(res_dir, locale, "strings.xml")
        if not os.path.exists(path):
            continue
        text = open(path, encoding="utf-8").read()
        for match in re.finditer(r'<string name="([^"]+)"[^>]*>(.*?)</string>', text, re.S):
            value = unescape(match.group(2))
            if value and not value.startswith("@string/"):
                table.setdefault(match.group(1), value)
    return table


def resolve_refs(value: str, strings: dict) -> str:
    """Разрешает ссылки вида '@string/pCatName1' в реальный текст."""
    prefix = "@string/"
    if value.startswith(prefix):
        key = value[len(prefix):]
        if key in strings:
            return strings[key]
    return value


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--jadx", required=True, help="корень декомпилированных исходников")
    parser.add_argument("--res", required=True, help="каталог res (после apktool)")
    parser.add_argument("--out", required=True, help="куда писать programs.json")
    args = parser.parse_args()

    pdbhelper = os.path.join(args.jadx, "p061db", "PDBHelper.java")
    if not os.path.exists(pdbhelper):
        pdbhelper = os.path.join(args.jadx, "db", "PDBHelper.java")
    rows = parse_rows(pdbhelper)
    print(f"Найдено программ: {len(rows)}")

    names = read_string_array(args.res, "pNames")
    shorts = read_string_array(args.res, "pShortDescr")
    longs = read_string_array(args.res, "pLongDescr")
    categories = read_string_array(args.res, "pCategoryNames")
    category_descrs = read_string_array(args.res, "pCategoryDescrs")
    strings = read_strings(args.res)
    categories = [resolve_refs(c, strings) for c in categories]
    category_descrs = [resolve_refs(c, strings) for c in category_descrs]
    print(f"Названий: {len(names)}, кратких: {len(shorts)}, полных: {len(longs)}, категорий: {len(categories)}")
    print("Категории:", ", ".join(dict.fromkeys(c for c in categories if c)))

    programs = []
    for index, row in enumerate(rows):
        pid = index + 1
        cycles_raw = row["cycles"].split()
        programs.append({
            "id": f"program-{pid:02d}",
            "index": pid,
            "name": names[index] if index < len(names) else f"Программа {pid}",
            "shortDescription": shorts[index] if index < len(shorts) else "",
            "description": longs[index] if index < len(longs) else "",
            "category": categories[index] if index < len(categories) else "",
            "categoryDescription": category_descrs[index] if index < len(category_descrs) else "",
            "lengthMinutes": int(row["length"] or 0),
            "difficulty": int(row["difficulty"] or 0),
            "mode": "meditation" if row["mode"].strip() == "1" else "training",
            "timeInProportion": float(row["timeInProportionDefault"] or 0),
            "breatheType": int(row["breatheTypeDefault"] or 0),
            "breatheWay": parse_breathe_way(row["breatheWayDefault"]),
            "soundsSettings": row["soundsSettings"],
            "backgroundColor": BG_COLORS.get(pid, "#B7A6F0"),
            "icon": f"pr{pid}",
            "backgroundImage": f"prog{pid:02d}",
            "cycles": [parse_cycle_line(c) for c in cycles_raw],
            "difficultySteps": parse_difficulty_settings(row["difficultySettings"]),
        })

    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as handle:
        json.dump(programs, handle, ensure_ascii=False, indent=1)
    print(f"Записано: {args.out}")


if __name__ == "__main__":
    main()
