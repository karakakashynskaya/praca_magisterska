"""match_statistics/{tour}_{pid}.json -> match_statistics.csv

Każdy mecz występuje w plikach obu zawodników (bo dla obu byliśmy odpytywani) —
dedup po (match_id, player_id). player1/player2 w stats mapujemy po id, nie po
tym, czyj to był plik (player1 to zawsze zwycięzca, zgodnie z konwencją API).

Statystyki zawierają całą historię meczów zawodnika, więc zostawiamy tylko te
mecze, które trafiły do matches.csv (singiel, rozegrane, turnieje z przekroju)."""
import csv

from common import RAW_DIR, load_json, write_csv, DATA_SRC_DIR
from config import TIERS


def _load_all_stat_files(tier: str):
    player_tour = load_json(RAW_DIR / "players_index" / f"player_tour_{tier}.json") or {}
    for pid, tour in player_tour.items():
        data = load_json(RAW_DIR / "match_statistics" / f"{tour}_{pid}.json")
        if data:
            yield from data  # get_paginated zwraca listę bezpośrednio, bez wrappera "data"


def load_durations(tier: str) -> dict[str, str]:
    """match_id -> stats.duration (potrzebne w matches.py dla buffer_matches.match_duration)."""
    durations = {}
    for row in _load_all_stat_files(tier):
        stats = row.get("stats")
        if stats and stats.get("duration"):
            durations[str(row["id"])] = stats["duration"]
    return durations


def _load_valid_match_ids() -> set[str]:
    """match_id z już zapisanego matches.csv (run_transform zapisuje matches przed statystykami)."""
    with open(DATA_SRC_DIR / "matches.csv", encoding="utf-8", newline="") as f:
        return {r["id"] for r in csv.DictReader(f)}


def transform(tier: str):
    valid_match_ids = _load_valid_match_ids()
    seen = set()
    rows = []
    for row in _load_all_stat_files(tier):
        stats = row.get("stats")
        if not stats:
            continue
        match_id = row["id"]
        if str(match_id) not in valid_match_ids:
            continue
        for side in ("player1", "player2"):
            player_id = (row.get(side) or {}).get("id")
            if player_id is None:
                continue
            key = (match_id, player_id)
            if key in seen:
                continue
            seen.add(key)

            s = stats.get(side, {})
            bpc, bpc_of = s.get("breakPointsConverted"), s.get("breakPointsConvertedOf")
            perc = round((bpc or 0) / bpc_of, 3) if bpc_of else 0

            rows.append({
                "match_id": match_id,
                "player_id": player_id,
                "aces": s.get("aces", 0),
                "double_faults": s.get("doubleFaults", 0),
                "break_points_converted_perc": perc,
            })

    write_csv("matchstatistics.csv", ["match_id", "player_id", "aces", "double_faults", "break_points_converted_perc"], rows)
    print(f"Wierszy statystyk meczowych w przekroju '{tier}': {len(rows)}")


if __name__ == "__main__":
    import sys
    transform(sys.argv[1] if len(sys.argv) > 1 else "smoke")