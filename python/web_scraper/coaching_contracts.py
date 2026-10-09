import json

from client import DATA_DIR, save_json
from coaches import load_coaches, load_coached_players


def _normalize(name: str | None) -> str | None:
    return name.strip().lower() if name else None


def _load_all_profiles() -> dict[str, str | None]:
    """player_bk -> aktualny coach (string z API), None jeśli brak danych."""
    result = {}
    profile_dir = DATA_DIR / "players_profile"
    if not profile_dir.exists():
        return result
    for path in profile_dir.glob("*.json"):
        data = json.loads(path.read_text()).get("data", {})
        pid = data.get("id")
        if pid is not None:
            information = data.get("information") or {}
            result[str(pid)] = information.get("coach") or data.get("coach")
    return result


def build_coaching_contracts() -> list[dict]:
    coaches = {c["coach_bk"]: c for c in load_coaches()}
    pairs = load_coached_players()
    current_coach_by_player = _load_all_profiles()

    contracts = []
    for pair in pairs:
        coach = coaches.get(pair["coach_bk"])
        if coach is None:
            continue  # coach_bk z coached_players.csv bez wpisu w coaches.csv — pomijamy
        current_coach_name = current_coach_by_player.get(pair["player_bk"])
        is_active = _normalize(current_coach_name) == _normalize(coach["full_name"])
        contracts.append(
            {
                "contract_bk": f"{pair['player_bk']};{pair['coach_bk']}",
                "player_bk": pair["player_bk"],
                "coach_bk": pair["coach_bk"],
                "is_active": is_active,
            }
        )

    save_json("coaches", "fct_coaching_contracts", contracts)
    active_count = sum(1 for c in contracts if c["is_active"])
    print(f"fct_coaching_contracts: {len(contracts)} wierszy, {active_count} aktywnych")
    return contracts


if __name__ == "__main__":
    build_coaching_contracts()