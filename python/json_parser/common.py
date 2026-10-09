"""Wspólne narzędzia: ścieżki i zapis CSV zgodnie z formatem oczekiwanym przez COPY."""
import csv
import json
from pathlib import Path


_THIS_DIR = Path(__file__).resolve().parent
RAW_DIR = _THIS_DIR.parent / "web_scraper" / "data" / "raw"
DATA_SRC_DIR = _THIS_DIR.parent.parent / "liquibase" / "data_src"
DATA_SRC_DIR.mkdir(parents=True, exist_ok=True)


def write_csv(filename: str, fieldnames: list[str], rows: list[dict]):
    path = DATA_SRC_DIR / filename
    with path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)
    print(f"written: {path} ({len(rows)} wierszy)")
    return path


def load_json(path: Path):
    if not path.exists():
        return None
    return json.loads(path.read_text())


def empty_to_none(value):
    """Puste/None -> pusty string w CSV (COPY zamieni na NULL tylko z opcją NULL '',
    tu zostawiamy pusty string — buffer_* i tak jest cały VARCHAR)."""
    return "" if value is None else str(value)