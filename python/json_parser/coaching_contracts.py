"""data/raw/coaches/fct_coaching_contracts.json (zbudowane wcześniej przez
tennis_scraper/coaching_contracts.py) -> coachingcontracts.csv"""
from common import RAW_DIR, load_json, write_csv


def transform():
    rows_in = load_json(RAW_DIR / "coaches" / "fct_coaching_contracts.json") or []
    rows = [
        {
            "id": r["contract_bk"],
            "player_id": r["player_bk"],
            "coach_id": r["coach_bk"],
            "is_active": "true" if r.get("is_active") else "false",
        }
        for r in rows_in
    ]
    write_csv("coachingcontracts.csv", ["id", "player_id", "coach_id", "is_active"], rows)


if __name__ == "__main__":
    transform()