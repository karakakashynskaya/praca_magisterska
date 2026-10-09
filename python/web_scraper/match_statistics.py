from client import get_paginated, save_json, already_fetched
from config import TIERS
from matches import fetch_matches_for_tier


def fetch_match_stats_for_player(tour: str, player_id: int, years: list[int]):
    name = f"{tour}_{player_id}"
    if already_fetched("match_statistics", name):
        return

    year_filter = ",".join(str(y) for y in years)
    rows = get_paginated(
        f"/{tour}/player/past-matches/{player_id}",
        params={"include": "stat", "filter": f"GameYear:{year_filter}"},
    )
    save_json("match_statistics", name, rows)


def fetch_match_statistics_for_tier(tier_name: str):
    years = sorted({y for t in TIERS.values() for y in t["years"]})
    player_tour = fetch_matches_for_tier(tier_name)  # checkpointowane, ponowne wywołanie jest tanie
    items = list(player_tour.items())
    for i, (pid, tour) in enumerate(items, 1):
        fetch_match_stats_for_player(tour, pid, years)
        if i % 50 == 0:
            print(f"  match_statistics: {i}/{len(items)} zawodników przetworzonych")
    print(f"Gotowe: match_statistics dla {len(items)} zawodników (przekrój '{tier_name}')")


if __name__ == "__main__":
    import sys
    tier = sys.argv[1] if len(sys.argv) > 1 else "smoke"
    fetch_match_statistics_for_tier(tier)