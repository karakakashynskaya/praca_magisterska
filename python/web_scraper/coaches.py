"""lokalne wczytanie coaches.csv / coached_players.csv (bez API)."""
import csv
from pathlib import Path

from client import save_json

SOURCE_DIR = Path(__file__).parent / "data" / "coaches_source"


def _clean(value: str | None):
    if value is None:
        return None
    value = value.strip()
    return None if value in ("", "--") else value


def load_coaches() -> list[dict]:
    path = SOURCE_DIR / "coaches.csv"
    with path.open(encoding="utf-8") as f:
        reader = csv.DictReader(f)
        rows = [
            {
                "coach_bk": row["coachId"],
                "first_name": _clean(row["firstName"]),
                "second_name": _clean(row["lastName"]),
                "full_name": _clean(row["fullName"]),
                "career_start_date": _clean(row["careerStartDate"]),
                "career_end_date": _clean(row["careerEndDate"]),
            }
            for row in reader
        ]
    save_json("coaches", "dim_coaches", rows)
    print(f"coaches: {len(rows)} wierszy")
    return rows


def load_coached_players() -> list[dict]:
    path = SOURCE_DIR / "coached_players.csv"
    with path.open(encoding="utf-8") as f:
        reader = csv.DictReader(f)
        rows = [{"coach_bk": row["coachId"], "player_bk": row["playerId"]} for row in reader]
    save_json("coaches", "coached_players", rows)
    print(f"coached_players: {len(rows)} wierszy")
    return rows


if __name__ == "__main__":
    load_coaches()
    load_coached_players()