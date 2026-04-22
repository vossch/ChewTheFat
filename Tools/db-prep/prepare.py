#!/usr/bin/env python3
"""Build usda.sqlite and offs.sqlite for ChewTheFat's food-search RAG.

Inputs are consumed from a `sources/` folder next to this script (created by
`make db-refresh`). The outputs land in `ChewTheFat/Resources/`:

    usda.sqlite   — Foundation Foods + SR Legacy subset
    offs.sqlite   — Open Food Facts records with complete macros

Both files share the same schema:

    food_entry(id TEXT PK, name TEXT, description TEXT, source TEXT)
    serving(id INTEGER PK AUTOINCREMENT, food_entry_id TEXT, measurement_name TEXT,
            calories REAL, protein_g REAL, carbs_g REAL, fat_g REAL, fiber_g REAL)
    food_fts(name, description) FTS5 external-content view of food_entry.

Run:
    python3 Tools/db-prep/prepare.py --sources Tools/db-prep/sources \
            --out ChewTheFat/Resources
"""

from __future__ import annotations

import argparse
import csv
import gzip
import json
import os
import sqlite3
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Iterator


SCHEMA = """
CREATE TABLE food_entry (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    source TEXT NOT NULL
);

CREATE TABLE serving (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    food_entry_id TEXT NOT NULL REFERENCES food_entry(id) ON DELETE CASCADE,
    measurement_name TEXT NOT NULL,
    calories REAL NOT NULL,
    protein_g REAL NOT NULL,
    carbs_g REAL NOT NULL,
    fat_g REAL NOT NULL,
    fiber_g REAL NOT NULL
);

CREATE INDEX idx_serving_food_entry ON serving(food_entry_id);

CREATE VIRTUAL TABLE food_fts USING fts5(
    name,
    description,
    content='food_entry',
    content_rowid='rowid',
    tokenize='porter unicode61'
);

CREATE TRIGGER food_entry_ai AFTER INSERT ON food_entry BEGIN
    INSERT INTO food_fts(rowid, name, description)
    VALUES (new.rowid, new.name, coalesce(new.description, ''));
END;
"""


@dataclass(frozen=True)
class Serving:
    measurement_name: str
    calories: float
    protein_g: float
    carbs_g: float
    fat_g: float
    fiber_g: float


@dataclass(frozen=True)
class FoodRecord:
    id: str
    name: str
    description: str | None
    source: str
    servings: list[Serving]


def init_db(path: Path) -> sqlite3.Connection:
    if path.exists():
        path.unlink()
    conn = sqlite3.connect(path)
    conn.executescript(SCHEMA)
    return conn


def write_food(conn: sqlite3.Connection, food: FoodRecord) -> None:
    if not food.servings:
        return
    conn.execute(
        "INSERT INTO food_entry(id, name, description, source) VALUES (?, ?, ?, ?)",
        (food.id, food.name, food.description, food.source),
    )
    conn.executemany(
        "INSERT INTO serving(food_entry_id, measurement_name, calories, protein_g, "
        "carbs_g, fat_g, fiber_g) VALUES (?, ?, ?, ?, ?, ?, ?)",
        [
            (
                food.id,
                s.measurement_name,
                s.calories,
                s.protein_g,
                s.carbs_g,
                s.fat_g,
                s.fiber_g,
            )
            for s in food.servings
        ],
    )


def iter_usda(sources: Path) -> Iterator[FoodRecord]:
    """Iterate USDA Foundation + SR Legacy CSVs.

    Expected files (downloaded by `make db-refresh`):
        sources/usda/food.csv
        sources/usda/food_nutrient.csv
        sources/usda/nutrient.csv
        sources/usda/food_portion.csv     (optional but preferred)
        sources/usda/measure_unit.csv     (optional but preferred)
    """
    root = sources / "usda"
    if not (root / "food.csv").exists():
        raise FileNotFoundError(
            f"Missing {root/'food.csv'}. Run `make db-refresh` to fetch sources."
        )

    nutrient_ids = _usda_nutrient_ids(root / "nutrient.csv")
    nutrients_by_food = _usda_food_nutrients(
        root / "food_nutrient.csv", nutrient_ids
    )
    portions_by_food = _usda_food_portions(root, nutrient_ids)

    with open(root / "food.csv", newline="", encoding="utf-8") as fh:
        reader = csv.DictReader(fh)
        for row in reader:
            dtype = row.get("data_type", "")
            if dtype not in ("foundation_food", "sr_legacy_food"):
                continue
            fdc_id = row["fdc_id"]
            macros = nutrients_by_food.get(fdc_id)
            if not macros or not _has_complete_macros(macros):
                continue
            name = row.get("description", "").strip()
            if not name:
                continue
            servings = _usda_servings(fdc_id, macros, portions_by_food)
            if not servings:
                continue
            yield FoodRecord(
                id=fdc_id,
                name=name,
                description=None,
                source="usda",
                servings=servings,
            )


def _usda_nutrient_ids(path: Path) -> dict[str, str]:
    wanted = {
        "Energy": "calories",
        "Energy (Atwater General Factors)": "calories",
        "Protein": "protein_g",
        "Carbohydrate, by difference": "carbs_g",
        "Total lipid (fat)": "fat_g",
        "Fiber, total dietary": "fiber_g",
    }
    mapping: dict[str, str] = {}
    with open(path, newline="", encoding="utf-8") as fh:
        for row in csv.DictReader(fh):
            label = row.get("name", "").strip()
            unit = row.get("unit_name", "").strip().lower()
            key = wanted.get(label)
            if not key:
                continue
            if key == "calories" and unit != "kcal":
                continue
            if key != "calories" and unit != "g":
                continue
            mapping[row["id"]] = key
    return mapping


def _usda_food_nutrients(
    path: Path, nutrient_ids: dict[str, str]
) -> dict[str, dict[str, float]]:
    by_food: dict[str, dict[str, float]] = {}
    with open(path, newline="", encoding="utf-8") as fh:
        for row in csv.DictReader(fh):
            key = nutrient_ids.get(row.get("nutrient_id", ""))
            if not key:
                continue
            try:
                amount = float(row.get("amount", "") or 0.0)
            except ValueError:
                continue
            fdc_id = row.get("fdc_id", "")
            if not fdc_id:
                continue
            by_food.setdefault(fdc_id, {})[key] = amount
    return by_food


def _has_complete_macros(macros: dict[str, float]) -> bool:
    required = {"calories", "protein_g", "carbs_g", "fat_g"}
    if not required.issubset(macros.keys()):
        return False
    return all(macros[k] >= 0 for k in required)


def _usda_food_portions(
    root: Path, _nutrient_ids: dict[str, str]
) -> dict[str, list[tuple[str, float]]]:
    portions_csv = root / "food_portion.csv"
    units_csv = root / "measure_unit.csv"
    if not portions_csv.exists() or not units_csv.exists():
        return {}
    units: dict[str, str] = {}
    with open(units_csv, newline="", encoding="utf-8") as fh:
        for row in csv.DictReader(fh):
            units[row["id"]] = row.get("name", "").strip()
    result: dict[str, list[tuple[str, float]]] = {}
    with open(portions_csv, newline="", encoding="utf-8") as fh:
        for row in csv.DictReader(fh):
            fdc_id = row.get("fdc_id", "")
            unit = units.get(row.get("measure_unit_id", ""), "")
            amount_str = row.get("amount", "")
            gram_weight = row.get("gram_weight", "")
            try:
                amount = float(amount_str or 1.0)
                grams = float(gram_weight or 0.0)
            except ValueError:
                continue
            if grams <= 0:
                continue
            label = f"{amount:g} {unit}".strip() if unit else f"{grams:g}g"
            result.setdefault(fdc_id, []).append((label, grams))
    return result


def _usda_servings(
    fdc_id: str,
    macros: dict[str, float],
    portions_by_food: dict[str, list[tuple[str, float]]],
) -> list[Serving]:
    # USDA macros are per 100 g. Always emit a 100g serving; emit named portions
    # rescaled to grams when we have them.
    base = Serving(
        measurement_name="100 g",
        calories=macros.get("calories", 0.0),
        protein_g=macros.get("protein_g", 0.0),
        carbs_g=macros.get("carbs_g", 0.0),
        fat_g=macros.get("fat_g", 0.0),
        fiber_g=macros.get("fiber_g", 0.0),
    )
    servings: list[Serving] = [base]
    for label, grams in portions_by_food.get(fdc_id, []):
        factor = grams / 100.0
        servings.append(
            Serving(
                measurement_name=label,
                calories=base.calories * factor,
                protein_g=base.protein_g * factor,
                carbs_g=base.carbs_g * factor,
                fat_g=base.fat_g * factor,
                fiber_g=base.fiber_g * factor,
            )
        )
    return servings


def iter_offs(sources: Path) -> Iterator[FoodRecord]:
    """Iterate Open Food Facts TSV, filtered to rows with complete macros."""
    path = sources / "offs" / "en.openfoodfacts.org.products.csv.gz"
    if not path.exists():
        raise FileNotFoundError(
            f"Missing {path}. Run `make db-refresh` to fetch the OFFs dump."
        )
    fields = {
        "code": None,
        "product_name": None,
        "brands": None,
        "energy-kcal_100g": None,
        "proteins_100g": None,
        "carbohydrates_100g": None,
        "fat_100g": None,
        "fiber_100g": None,
        "serving_size": None,
    }
    with gzip.open(path, "rt", encoding="utf-8", errors="replace") as fh:
        reader = csv.DictReader(fh, delimiter="\t")
        for row in reader:
            code = (row.get("code") or "").strip()
            name = (row.get("product_name") or "").strip()
            if not code or not name:
                continue
            try:
                cal = float(row.get("energy-kcal_100g") or "")
                p = float(row.get("proteins_100g") or "")
                c = float(row.get("carbohydrates_100g") or "")
                f = float(row.get("fat_100g") or "")
            except ValueError:
                continue
            if cal <= 0 or any(v < 0 for v in (p, c, f)):
                continue
            fiber = _optional_float(row.get("fiber_100g"))
            brand = (row.get("brands") or "").split(",")[0].strip() or None
            servings: list[Serving] = [
                Serving("100 g", cal, p, c, f, fiber or 0.0)
            ]
            serving_label = (row.get("serving_size") or "").strip()
            grams = _parse_offs_serving_grams(serving_label)
            if grams and grams > 0 and abs(grams - 100.0) > 0.5:
                factor = grams / 100.0
                servings.append(
                    Serving(
                        measurement_name=serving_label,
                        calories=cal * factor,
                        protein_g=p * factor,
                        carbs_g=c * factor,
                        fat_g=f * factor,
                        fiber_g=(fiber or 0.0) * factor,
                    )
                )
            yield FoodRecord(
                id=code,
                name=name,
                description=brand,
                source="offs",
                servings=servings,
            )


def _optional_float(raw: str | None) -> float | None:
    if not raw:
        return None
    try:
        return float(raw)
    except ValueError:
        return None


def _parse_offs_serving_grams(label: str) -> float | None:
    lowered = label.lower().strip()
    if not lowered:
        return None
    # Handles "30 g", "30g", "1 cup (240 ml)" → grams only.
    import re

    match = re.search(r"([\d.]+)\s*g\b", lowered)
    if not match:
        return None
    try:
        return float(match.group(1))
    except ValueError:
        return None


def build(sources: Path, output: Path) -> None:
    output.mkdir(parents=True, exist_ok=True)

    usda_path = output / "usda.sqlite"
    offs_path = output / "offs.sqlite"
    print(f"→ Building {usda_path}")
    conn = init_db(usda_path)
    n = 0
    for food in iter_usda(sources):
        write_food(conn, food)
        n += 1
        if n % 5000 == 0:
            conn.commit()
            print(f"  … {n} USDA rows")
    conn.commit()
    conn.execute("INSERT INTO food_fts(food_fts) VALUES ('rebuild')")
    conn.execute("VACUUM")
    conn.close()
    print(f"  done: {n} USDA rows")

    print(f"→ Building {offs_path}")
    conn = init_db(offs_path)
    n = 0
    for food in iter_offs(sources):
        write_food(conn, food)
        n += 1
        if n % 10000 == 0:
            conn.commit()
            print(f"  … {n} OFFs rows")
    conn.commit()
    conn.execute("INSERT INTO food_fts(food_fts) VALUES ('rebuild')")
    conn.execute("VACUUM")
    conn.close()
    print(f"  done: {n} OFFs rows")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--sources",
        type=Path,
        default=Path(__file__).parent / "sources",
        help="Path to the folder holding USDA + OFFs source files.",
    )
    parser.add_argument(
        "--out",
        type=Path,
        default=Path(__file__).resolve().parents[2] / "ChewTheFat" / "Resources",
        help="Output folder for the generated .sqlite files.",
    )
    args = parser.parse_args(argv)
    build(args.sources, args.out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
