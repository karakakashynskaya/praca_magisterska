"""Uruchamia wszystkie transformacje JSON -> CSV dla wybranego przekroju."""
import sys

import ref_country
import players
import coaches
import coaching_contracts
import tournaments
import matches
import match_statistics
import rounds


def run(tier: str):
    print(f"=== Transformacja JSON -> CSV: {tier} ===")
    ref_country.transform()
    players.transform(tier)
    coaches.transform()
    tournaments.transform(tier)
    matches.transform(tier)
    match_statistics.transform(tier)
    coaching_contracts.transform()
    rounds.transform()
    print("=== Gotowe ===")


if __name__ == "__main__":
    run(sys.argv[1] if len(sys.argv) > 1 else "smoke")