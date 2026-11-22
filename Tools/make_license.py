#!/usr/bin/env python3
"""Генерирует файл лицензии (Content/license.json) с подписью HMAC-SHA256.

Лицензия подтверждает право на полную версию чеком от 07.09.2024
(ООО «СалютДевайсы», 1179 ₽) и подписывается тем же ключом и тем же
каноническим представлением полезной нагрузки, что и Swift-код
(Sources/PranariaCore/License/LicenseManager.swift).

Запуск:  python3 Tools/make_license.py --out Content/license.json
"""

import argparse
import hashlib
import hmac
import json
import os

SIGNING_KEY = "pranaria.personal.2026.11.owner.license.key"

LICENSE = {
    "licenseId": "PRANARIA-OWNER-2024-0907-HW43",
    "holder": "Михаил Тарасов",
    "email": "highwork43@gmail.com",
    "level": "pro",
    "issuedAt": "2026-11-22",
    "expiresAt": None,
    "purchase": {
        "date": "2024-09-07",
        "amount": 1179.0,
        "currency": "RUB",
        "receipt": "312",
        "seller": "ООО «СалютДевайсы»",
        "fiscalDocument": "7380440800824083",
        "documentNumber": "57033",
        "sign": "633983494",
    },
}


def canonical_bytes(license):
    parts = [
        "v1",
        license["licenseId"],
        license["holder"],
        license["email"],
        license["level"],
        license["issuedAt"],
        license["expiresAt"] or "",
    ]
    purchase = license.get("purchase")
    if purchase:
        parts.append("|".join([
            purchase["date"],
            f"{purchase['amount']:.2f}",
            purchase["currency"],
            purchase["receipt"],
            purchase["seller"],
            purchase["fiscalDocument"],
            purchase["documentNumber"],
            purchase["sign"],
        ]))
    else:
        parts.append("")
    return "\n".join(parts).encode("utf-8")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", required=True)
    parser.add_argument("--key", default=SIGNING_KEY)
    args = parser.parse_args()

    signature = hmac.new(
        args.key.encode("utf-8"), canonical_bytes(LICENSE), hashlib.sha256
    ).hexdigest()

    envelope = {"version": 1, "payload": LICENSE, "signature": signature}
    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as handle:
        json.dump(envelope, handle, ensure_ascii=False, indent=1)
    print(f"Записано: {args.out}")
    print(f"Подпись: {signature}")


if __name__ == "__main__":
    main()
