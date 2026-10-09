""" profile + titles dla każdego unikalnego player_id z kroku 3."""
from client import get, save_json, already_fetched
from matches import fetch_matches_for_tier


def fetch_player(tour: str, player_id: int):
    if not already_fetched("players_profile", f"{tour}_{player_id}"):
        profile = get(f"/{tour}/player/profile/{player_id}")
        save_json("players_profile", f"{tour}_{player_id}", profile)

    if not already_fetched("players_titles", f"{tour}_{player_id}"):
        titles = get(f"/{tour}/player/titles/{player_id}")
        save_json("players_titles", f"{tour}_{player_id}", titles)


def fetch_players_for_tier(tier_name: str):
    player_tour = fetch_matches_for_tier(tier_name)
    items = list(player_tour.items())
    for i, (pid, tour) in enumerate(items, 1):
        fetch_player(tour, pid)
        if i % 50 == 0:
            print(f"  players: {i}/{len(items)} przetworzonych")
    print(f"Gotowe: profile+titles dla {len(items)} zawodników (przekrój '{tier_name}')")


if __name__ == "__main__":
    import sys
    tier = sys.argv[1] if len(sys.argv) > 1 else "smoke"
    fetch_players_for_tier(tier)