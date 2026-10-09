"""data/raw/coaches/dim_coaches.json (zbudowane wcześniej przez tennis_scraper/coaches.py)
-> coaches.csv"""
from common import RAW_DIR, load_json, write_csv, empty_to_none


def transform():
    rows_in = load_json(RAW_DIR / "coaches" / "dim_coaches.json") or []
    rows = [
        {
            "id": r["coach_bk"],
            "first_name": empty_to_none(r.get("first_name")),
            "second_name": empty_to_none(r.get("second_name")),
            "career_start_date": empty_to_none(r.get("career_start_date")),
            "career_end_date": empty_to_none(r.get("career_end_date")),
        }
        for r in rows_in
    ]
    write_csv("coaches.csv", ["id", "first_name", "second_name", "career_start_date", "career_end_date"], rows)


if __name__ == "__main__":
    transform()