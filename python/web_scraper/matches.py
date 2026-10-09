from client import get, save_json, already_fetched, load_json
from tournaments import fetch_tier


def fetch_results(tour: str, season_id: int) -> dict:
    name = f"{tour}_{season_id}"
    cached = load_json("matches", name)
    if cached is not None:
        return cached
    data = get(f"/{tour}/tournament/results/{season_id}")
    save_json("matches", name, data)
    return data


def _extract_player_ids(results: dict) -> set[int]:
    ids = set()
    for bucket in ("singles", "qualifying"):  # doubles/doublesQualifying — osobny scenariusz (3.3)
        for row in results.get("data", {}).get(bucket, []):
            for key in ("player1Id", "player2Id"):
                if row.get(key):
                    ids.add(row[key])
    return ids


def fetch_matches_for_tier(tier_name: str) -> dict[int, str]:
    """Zwraca {player_id: tour} — tour bierzemy z turnieju, w którym zawodnik wystąpił
    (turnieje ATP — tylko mężczyźni, WTA — tylko kobiety, więc jest to jednoznaczne)."""
    tournaments = fetch_tier(tier_name)
    player_tour: dict[int, str] = {}
    for i, t in enumerate(tournaments, 1):
        results = fetch_results(t["_tour"], t["id"])
        for pid in _extract_player_ids(results):
            player_tour[pid] = t["_tour"]
        if i % 20 == 0:
            print(f"  results: {i}/{len(tournaments)} turniejów przetworzonych")
    save_json("players_index", f"player_tour_{tier_name}", player_tour)
    print(f"Unikalnych zawodników w meczach przekroju '{tier_name}': {len(player_tour)}")
    return player_tour


if __name__ == "__main__":
    import sys
    tier = sys.argv[1] if len(sys.argv) > 1 else "smoke"
    fetch_matches_for_tier(tier)