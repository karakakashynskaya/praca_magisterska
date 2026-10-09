"""Zapytania analityczne Q1–Q7 w trzech wariantach: star / dmart / dv."""
import argparse
import csv
import datetime as dt
import json
import os
from pathlib import Path

import psycopg2
from dotenv import load_dotenv

from plan_metrics import extract_metrics

ROOT = Path(__file__).resolve().parent.parent
QUERIES_DIR = ROOT / "bench" / "queries"
OUT_DIR = ROOT / "bench_results"
load_dotenv(ROOT / "env" / "app.env")

CONN = dict(host="localhost", port=5532, dbname="wta_dwh",
            user=os.environ.get("DB_USER"), password=os.environ.get("DB_PASSWORD"))
VARIANTS = ("star", "dmart", "dv")

TOP_PAIR_SQL = """
select least(p1.player_bk, p2.player_bk), greatest(p1.player_bk, p2.player_bk)
from star.fct_match_statistics as f
join star.dim_player as p1 on p1.dim_player_sk = f.dim_player1_sk
join star.dim_player as p2 on p2.dim_player_sk = f.dim_player2_sk
where f.is_current
group by 1, 2
order by count(*) desc, 1, 2
limit 1
"""


def discover_queries() -> dict[str, dict[str, str]]:
    queries = {}
    for qdir in sorted(p for p in QUERIES_DIR.iterdir() if p.is_dir()):
        variants = {v: (qdir / f"{v}.sql").read_text() for v in VARIANTS if (qdir / f"{v}.sql").exists()}
        missing = set(VARIANTS) - set(variants)
        if missing:
            raise SystemExit(f"{qdir.name}: brak wariantów {sorted(missing)}")
        queries[qdir.name] = variants
    return queries


def resolve_params(cur) -> dict:
    path = QUERIES_DIR / "params.json"
    params = json.loads(path.read_text()) if path.exists() else {}
    if not params.get("player_a") or not params.get("player_b"):
        cur.execute(TOP_PAIR_SQL)
        params["player_a"], params["player_b"] = cur.fetchone()
    if not params.get("as_of"):
        cur.execute("select localtimestamp::text")
        params["as_of"] = cur.fetchone()[0]
    return params


def append_csv(name: str, rows: list[dict]):
    path = OUT_DIR / name
    new = not path.exists()
    with path.open("a", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]))
        if new:
            w.writeheader()
        w.writerows(rows)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tier", required=True, help="etykieta przekroju danych, np. mid_10y")
    ap.add_argument("--repetitions", type=int, default=5)
    ap.add_argument("--load", action="store_true", help="załaduj obie architektury przed pomiarem")
    a = ap.parse_args()

    OUT_DIR.mkdir(exist_ok=True)
    run_id = "qbench_" + dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    queries = discover_queries()

    conn = psycopg2.connect(**CONN)
    conn.autocommit = True
    cur = conn.cursor()

    if a.load:
        cur.execute("call dbo.sp_load_all_dv_full(%s, localtimestamp)", (run_id + "_dv",))
        cur.execute("call star.sp_load_star_full(%s, localtimestamp)", (run_id + "_star",))
        cur.execute("select count(*) from stg.log_table where message like 'Error:%%'")
        if cur.fetchone()[0]:
            raise SystemExit("Ładowanie zakończone błędami — patrz stg.log_table")
        cur.execute("vacuum analyze")

    params = resolve_params(cur)
    cur.execute("select count(*) from star.dim_match where is_current")
    volume = cur.fetchone()[0]
    print(f"run_id={run_id} volume={volume} params={params}")

    # ---- 2. kontrola poprawności ----
    checks = []
    for qname, variants in queries.items():
        results = {}
        for v, sql in variants.items():
            cur.execute(sql, params)
            results[v] = cur.fetchall()
        for v in VARIANTS:
            ok = results[v] == results["star"]
            checks.append(dict(run_id=run_id, tier=a.tier, query_name=qname, variant=v,
                               rows=len(results[v]), equal_to_star=ok,
                               params=json.dumps(params)))
            if not ok:
                print(f"NIEZGODNOŚĆ {qname}: {v} ({len(results[v])} wierszy) != star ({len(results['star'])})")
    append_csv("query_checks.csv", checks)

    # ---- 3. pomiar ----
    runs = []
    for qname, variants in queries.items():
        for v, sql in variants.items():                       # rozgrzewka
            cur.execute("explain (analyze, buffers, format json) " + sql, params)
            cur.fetchone()
        for rep in range(1, a.repetitions + 1):
            for v, sql in variants.items():
                cur.execute("explain (analyze, buffers, format json) " + sql, params)
                m = extract_metrics(cur.fetchone()[0])
                runs.append(dict(run_id=run_id, tier=a.tier, volume=volume, query_name=qname,
                                 variant=v, repetition=rep, **m))
        med = {v: sorted(r["exec_time_ms"] for r in runs if r["query_name"] == qname and r["variant"] == v)[a.repetitions // 2]
               for v in VARIANTS}
        print(f"{qname}: " + ", ".join(f"{v}={t:.2f}ms" for v, t in med.items()))
    append_csv("query_runs.csv", runs)
    conn.close()
    print(f"Gotowe. run_id={run_id}")


if __name__ == "__main__":
    main()
