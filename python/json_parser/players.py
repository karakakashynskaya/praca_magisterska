"""players_profile/*.json + players_titles/*.json (dla graczy z player_tour_{tier}.json)
-> players.csv + playersphysicaldetails.csv"""
from common import RAW_DIR, load_json, write_csv, empty_to_none
import re


def _split_name(full_name: str) -> tuple[str, str]:
    parts = (full_name or "").strip().split(maxsplit=1)
    if len(parts) == 2:
        return parts[0], parts[1]
    if len(parts) == 1:
        return parts[0], ""
    return "", ""


def _sum_titles(titles_data: dict | None) -> int:
    if not titles_data:
        return 0
    return sum(int(row.get("titlesWon") or 0) for row in titles_data.get("data", []))


def _dominant_hand(plays: str | None) -> str:
    if not plays:
        return ""
    hand = re.split(r"[,(]", plays)[0].strip()
    return hand.title()


def transform(tier: str):
    player_tour = load_json(RAW_DIR / "players_index" / f"player_tour_{tier}.json") or {}

    player_rows = []
    physical_rows = []

    for pid, tour in player_tour.items():
        profile_data = load_json(RAW_DIR / "players_profile" / f"{tour}_{pid}.json")
        if profile_data is None:
            print(f"pominięto (brak profilu): {tour}_{pid}")
            continue
        p = profile_data.get("data", {})

        first_name, second_name = _split_name(p.get("name"))
        birthday = (p.get("birthday") or "").split("T")[0]
        is_active = "true" if p.get("playerStatus") == "Active" else "false"

        titles_data = load_json(RAW_DIR / "players_titles" / f"{tour}_{pid}.json")

        player_rows.append({
            "id": pid,
            "first_name": first_name,
            "second_name": second_name,
            "country": empty_to_none(p.get("countryAcr")),
            "date_of_birth": birthday,
            "titles_won": _sum_titles(titles_data),
            "is_active": is_active,
        })

        info = p.get("information") or {}
        physical_rows.append({
            "player_id": pid,
            "height_cm": empty_to_none(info.get("height")),
            "weight_kg": empty_to_none(info.get("weight")),
            "dominant_hand": _dominant_hand(info.get("plays")),
        })

    write_csv("players.csv", ["id", "first_name", "second_name", "country", "date_of_birth", "titles_won", "is_active"], player_rows)
    write_csv("playersphysicaldetails.csv", ["player_id", "height_cm", "weight_kg", "dominant_hand"], physical_rows)


if __name__ == "__main__":
    import sys
    transform(sys.argv[1] if len(sys.argv) > 1 else "smoke")