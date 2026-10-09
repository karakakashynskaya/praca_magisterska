# tournament calendar wg (tour, year) + post-filtr 500
from client import get_paginated, save_json, already_fetched, load_json
from config import TIERS

_EXCLUDED_NAME_PARTS = ("qualifying", "elite trophy")

def _keep_row(row: dict) -> bool:
    name = (row.get("name") or "").lower()
    if any(p in name for p in _EXCLUDED_NAME_PARTS):
        return False
    rank_id = row.get("rankId")
    if rank_id in (3, 4):
        return True
    if rank_id == 2:
        tier = (row.get("tier") or "").strip().lower()
        return "500" in tier or tier == "premier"
    return False


def fetch_calendar(tour: str, year: int, tour_ranks: list[int]) -> list[dict]:
    rank_key = "-".join(str(r) for r in sorted(tour_ranks))
    name = f"{tour}_{year}_{rank_key}"
    cached = load_json("tournaments", name)
    if cached is not None:
        print(f"skip (już jest): tournaments/{name}")
        return cached

    rank_filter = ",".join(str(r) for r in tour_ranks)
    rows = get_paginated(
        f"/{tour}/tournament/calendar/{year}",
        params={"filter": f"TourRank:{rank_filter}"},
    )
    filtered = [r for r in rows if _keep_row(r)]
    save_json("tournaments", name, filtered)
    print(f"saved: tournaments/{name} ({len(filtered)} turniejów z {len(rows)})")
    return filtered


def fetch_tier(tier_name: str) -> list[dict]:
    cfg = TIERS[tier_name]
    all_tournaments = []
    for tour in cfg["tours"]:
        for year in cfg["years"]:
            rows = fetch_calendar(tour, year, cfg["tour_ranks"])
            for r in rows:
                r["_tour"] = tour
            all_tournaments.extend(rows)
            if cfg.get("single_tournament"):
                return all_tournaments[:1]
    return all_tournaments


if __name__ == "__main__":
    import sys
    tier = sys.argv[1] if len(sys.argv) > 1 else "smoke"
    result = fetch_tier(tier)
    print(f"Łącznie turniejów w przekroju '{tier}': {len(result)}")