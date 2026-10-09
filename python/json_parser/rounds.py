"""reference/round.json -> rounds.csv (słownik rund; nowy obiekt w teście elastyczności T23)"""
from common import RAW_DIR, load_json, write_csv, empty_to_none


def transform():
    data = load_json(RAW_DIR / "reference" / "round.json") or {}
    rows = [
        {"round_id": empty_to_none(r.get("round_id")), "round_name": empty_to_none(r.get("round_name"))}
        for r in data.get("data", [])
        if r.get("round_id") is not None
    ]
    write_csv("rounds.csv", ["round_id", "round_name"], rows)


if __name__ == "__main__":
    transform()
