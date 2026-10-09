"""Orkiestrator: uruchamia kroki 1-5 po kolei dla wybranego przekroju objętości.
Kroki 6-7 (coaches) — osobno, nie zależą od przekroju, uruchamiaj ręcznie po przygotowaniu plików.

Użycie:
    python run_pipeline.py smoke        # 1 turniej, smoke-test
    python run_pipeline.py slams_1y     # 1 rok, tylko Grand Slam
    python run_pipeline.py mid_1y       # 1 rok, 500+Masters+Slam
    python run_pipeline.py mid_5y       # 5 lat, 500+Masters+Slam
"""
import sys

from client import request_count
from config import TIERS
from reference_data import fetch_reference_data
from tournaments import fetch_tier
from matches import fetch_matches_for_tier
from players import fetch_players_for_tier
from match_statistics import fetch_match_statistics_for_tier


def run(tier_name: str):
    if tier_name not in TIERS:
        raise SystemExit(f"Nieznany przekrój '{tier_name}'. Dostępne: {list(TIERS)}")

    print(f"=== Przekrój: {tier_name} ===")
    start = request_count()

    print("\n[1/5] Słowniki referencyjne...")
    fetch_reference_data()

    print("\n[2/5] Tournament calendar...")
    tournaments = fetch_tier(tier_name)
    print(f"  {len(tournaments)} turniejów")

    print("\n[3/5] Tournament results (mecze + lista zawodników)...")
    fetch_matches_for_tier(tier_name)

    print("\n[4/5] Player profile + titles...")
    fetch_players_for_tier(tier_name)

    print("\n[5/5] Match statistics...")
    fetch_match_statistics_for_tier(tier_name)

    used = request_count() - start
    print(f"\n=== Gotowe. Zapytań zużytych w tym przebiegu: {used} (łącznie od początku: {request_count()}) ===")


if __name__ == "__main__":
    tier = sys.argv[1] if len(sys.argv) > 1 else "smoke"
    run(tier)