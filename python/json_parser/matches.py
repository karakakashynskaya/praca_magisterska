"""matches/{tour}_{season_id}.json -> matches.csv

final_score (CHAR(3)) liczymy sami jako bilans setów "W-L" (nie surowy 'result'):
player1 wg konwencji API zawsze jest zwycięzcą (match_winner == player1Id),
więc final_score to zawsze coś w rodzaju '2-0'/'2-1'/'3-0' itd."""
from common import RAW_DIR, load_json, write_csv, empty_to_none
from tournaments import _collect_tournaments
from match_statistics import load_durations
from config import TIERS
import re


def _parse_sets(result: str) -> tuple[list[str], str]:
    set_scores = [re.sub(r"\(.*?\)", "", s) for s in (result or "").split()[:3]]
    p1_wins = p2_wins = 0
    for s in set_scores:
        try:
            a, b = (int(x) for x in s.split("-"))
        except ValueError:
            continue
        if a > b:
            p1_wins += 1
        elif b > a:
            p2_wins += 1
    set_scores += [""] * (3 - len(set_scores))
    return set_scores, f"{p1_wins}-{p2_wins}"

def _clean_duration(v) -> str:
    if not v:
        return ""
    t = str(v).strip().split(" ")[-1]
    return t if len(t.split(":")) == 3 else ""

def transform(tier: str):
    tournaments = _collect_tournaments(tier)
    durations = load_durations(tier)
    rows = []
    for t in tournaments:
        data = load_json(RAW_DIR / "matches" / f"{t['_tour']}_{t['id']}.json")
        if not data:
            continue
        for m in data.get("data", {}).get("singles", []):
            if m.get("result_type") != "completed":
                continue
            set_scores, final_score = _parse_sets(m.get("result"))
            rows.append({
                "id": m["id"],
                "tournament_id": m.get("tournamentId", t["id"]),
                "date_of_match": (m.get("date") or "").split("T")[0],
                "match_round": empty_to_none(m.get("roundId")),
                "player1_id": m.get("player1Id"),
                "player2_id": m.get("player2Id"),
                "winner_id": m.get("match_winner"),
                "first_set_score": set_scores[0],
                "second_set_score": set_scores[1],
                "third_set_score": set_scores[2],
                "final_score": final_score,
                "match_duration": _clean_duration(durations.get(str(m["id"]), "")),
            })

    write_csv(
        "matches.csv",
        [
            "id", "tournament_id", "date_of_match", "match_round", "player1_id", "player2_id",
            "winner_id", "first_set_score", "second_set_score", "third_set_score", "final_score",
            "match_duration",
        ],
        rows,
    )
    print(f"Meczów w przekroju '{tier}': {len(rows)}")



if __name__ == "__main__":
    import sys
    transform(sys.argv[1] if len(sys.argv) > 1 else "smoke")