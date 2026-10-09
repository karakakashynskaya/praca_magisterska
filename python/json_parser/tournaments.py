"""tournaments/{tour}_*.json + matches/{tour}_{season_id}.json (dla tourn_end_date)
-> tournaments.csv"""
from common import RAW_DIR, load_json, write_csv, empty_to_none
from config import TIERS

_EXCLUDED_NAME_PARTS = ("qualifying", "elite trophy")

def _is_excluded_name(row: dict) -> bool:
    name = (row.get("name") or "").lower()
    return any(p in name for p in _EXCLUDED_NAME_PARTS)

def _normalize_level(t: dict) -> str | None:
    """Ujednolica nazwy kategorii (od 2021 WTA zmieniła nazewnictwo):
    Premier Mandatory/Premier 5 -> WTA 1000, Premier -> WTA 500."""
    tier = (t.get("tier") or "").strip()
    if tier.lower() == "championships":
        return "Championships"
    rank = t.get("rankId")
    if rank == 4:
        return "Grand Slam"
    if rank == 3:
        return "WTA 1000"
    if rank == 2:
        return "WTA 500"
    return empty_to_none(tier)

def _collect_tournaments(tier_name: str) -> list[dict]:
    cfg = TIERS[tier_name]
    ranks = cfg.get("tour_ranks")
    seen = {}
    for tour in cfg["tours"]:
        for path in (RAW_DIR / "tournaments").glob(f"{tour}_*.json"):
            rows = load_json(path) or []
            for r in rows:
                if _is_excluded_name(r):
                    continue
                if ranks and r.get("rankId") not in ranks:
                    continue
                year = (r.get("date") or "")[:4]
                if year.isdigit() and int(year) in cfg["years"]:
                    seen[(tour, r["id"])] = {**r, "_tour": tour}
    return list(seen.values())

def _tourn_end_date(tour: str, tournament_id) -> str | None:
    matches = load_json(RAW_DIR / "matches" / f"{tour}_{tournament_id}.json")
    if not matches:
        return None
    dates = [
        row["date"] for row in matches.get("data", {}).get("singles", [])
        if row.get("result_type") == "completed" and row.get("date")
    ]
    return max(dates) if dates else None


def transform(tier: str):
    tournaments = _collect_tournaments(tier)
    rows = []
    for t in tournaments:
        start_date = t.get("date")
        end_date = _tourn_end_date(t["_tour"], t["id"]) or start_date
        rows.append({
            "id": t["id"],
            "tournament_name": empty_to_none(t.get("name")),
            "country": empty_to_none((t.get("country") or {}).get("acronym")),
            "tournament_level": _normalize_level(t),
            "surface": empty_to_none((t.get("court") or {}).get("name")),
            "tourn_start_date": (start_date or "").split("T")[0],
            "tourn_end_date": (end_date or "").split("T")[0],
        })

    write_csv(
        "tournaments.csv",
        ["id", "tournament_name", "country", "tournament_level", "surface", "tourn_start_date", "tourn_end_date"],
        rows,
    )
    print(f"Turniejów w przekroju '{tier}': {len(rows)}")


if __name__ == "__main__":
    import sys
    transform(sys.argv[1] if len(sys.argv) > 1 else "smoke")