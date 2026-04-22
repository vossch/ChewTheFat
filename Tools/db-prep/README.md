# db-prep — bundled food-reference databases

`prepare.py` produces the two read-only SQLite databases the RAG pipeline queries:

- `ChewTheFat/Resources/usda.sqlite` — USDA Foundation + SR Legacy foods.
- `ChewTheFat/Resources/offs.sqlite` — curated Open Food Facts rows with complete macros.

Both files share the same schema and carry a pre-built `food_fts` (FTS5) virtual table
so the app never has to build an index at runtime. The app treats these files as
read-only; see `Specs/research.md §3a` for the storage boundary.

## One-shot build

```bash
make db-refresh   # downloads sources + runs prepare.py
```

## Step-by-step

```bash
./Tools/db-prep/fetch_sources.sh      # ~600 MB download, one time
python3 Tools/db-prep/prepare.py      # writes ChewTheFat/Resources/*.sqlite
python3 Tools/db-prep/verify.py       # schema + non-empty sanity check
```

## Environment overrides

`fetch_sources.sh` respects `USDA_URL` and `OFFS_URL` if the public dataset URLs
rotate between USDA / Open Food Facts releases.

## Output layout

```
ChewTheFat/Resources/
├── usda.sqlite   (LFS-tracked)
└── offs.sqlite   (LFS-tracked)
```

Both outputs are tracked by Git LFS via `.gitattributes` (`ChewTheFat/Resources/*.sqlite`).
