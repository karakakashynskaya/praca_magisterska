"""T23 — elastyczność: dodanie nowego obiektu (runda) wraz z relacją do meczu."""
import argparse
import datetime as dt
import time
from contextlib import closing
from pathlib import Path

import run_etl_benchmark as etl

EVOLUTION_DIR = Path(__file__).resolve().parent / "evolution" / "t23_round"
CATALOG_SCHEMAS = ["stg", "dbo", "biz", "dmart", "star"]
ARCH_OF_SCHEMA = {"stg": "shared", "dbo": "DV", "biz": "DV", "dmart": "DV", "star": "STAR"}

DDL_STEPS = [("shared", "00_stg.sql"), ("DV", "10_dv.sql"), ("DV", "20_dmart.sql"), ("STAR", "30_star.sql")]
BACKFILL_STEPS = [
    ("shared", ["call stg.sp_load_rounds(%s, localtimestamp)"]),
    ("DV", ["call dbo.sp_load_rounds(%s, localtimestamp)", "call dmart.sp_load_rounds(%s, localtimestamp)"]),
    ("STAR", ["call star.sp_load_star_rounds(%s, localtimestamp)"]),
]

CATALOG_SQL = """
select n.nspname, 'table', c.relname,
       md5(string_agg(a.attname || ' ' || format_type(a.atttypid, a.atttypmod), ',' order by a.attnum))
from pg_class c join pg_namespace n on n.oid = c.relnamespace
join pg_attribute a on a.attrelid = c.oid and a.attnum > 0 and not a.attisdropped
where c.relkind = 'r' and n.nspname = any(%(s)s) group by n.nspname, c.relname
union all
select n.nspname, 'index', c.relname, md5(pg_get_indexdef(c.oid))
from pg_class c join pg_namespace n on n.oid = c.relnamespace
where c.relkind = 'i' and n.nspname = any(%(s)s)
union all
select n.nspname, 'view', c.relname, md5(pg_get_viewdef(c.oid))
from pg_class c join pg_namespace n on n.oid = c.relnamespace
where c.relkind = 'v' and n.nspname = any(%(s)s)
union all
select n.nspname, 'procedure', p.proname, md5(pg_get_functiondef(p.oid))
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where p.prokind in ('p', 'f') and n.nspname = any(%(s)s)
"""

ROUND_CHECK_SQL = {
    "STAR": """select coalesce(d.round_name, '?'), count(*) from star.fct_match_statistics f
               left join star.dim_round d on d.dim_round_sk = f.dim_round_sk
               where f.is_current group by 1 order by 1""",
    "DMART": """select coalesce(d.round_name, '?'), count(*) from dmart.fct_match_statistics f
                left join dmart.dim_rounds d on d.dim_round_sk = f.dim_round_sk
                where f.row_expired_dt is null group by 1 order by 1""",
    "DV": """select coalesce(s.round_name, '?'), count(*) from dbo.hub_matches hm
             left join dbo.link_match_round l on l.match_sk = hm.match_sk
             left join dbo.sat_round_details s on s.round_sk = l.round_sk and s.load_end_dt is null
             group by 1 order by 1""",
}


def catalog(cur) -> dict[tuple, str]:
    cur.execute(CATALOG_SQL, {"s": CATALOG_SCHEMAS})
    return {(s, k, n): h for s, k, n, h in cur.fetchall()}


def table_stats(cur) -> dict[str, tuple[int, int, int]]:
    etl.db_blocks(cur)
    cur.execute("select schemaname || '.' || relname, n_tup_ins, n_tup_upd, n_tup_del "
                "from pg_stat_user_tables where schemaname = any(%s)", (CATALOG_SCHEMAS,))
    return {t: (i, u, d) for t, i, u, d in cur.fetchall()}


def measure(cur, run_id: str, statements: list[tuple[str, tuple]], base_tables: set[str]) -> dict:
    cat0, st0 = catalog(cur), table_stats(cur)
    cur.execute("select pg_current_wal_lsn()")
    wal0 = cur.fetchone()[0]
    t0 = time.perf_counter()
    for sql, params in statements:
        cur.execute(sql, params)
    duration = time.perf_counter() - t0
    cat1, st1 = catalog(cur), table_stats(cur)
    cur.execute("select pg_wal_lsn_diff(pg_current_wal_lsn(), %s)::bigint", (wal0,))
    wal = cur.fetchone()[0]

    delta = {t: tuple(a - b for a, b in zip(v, st0.get(t, (0, 0, 0)))) for t, v in st1.items()}
    new_objs = sorted(f"{k}:{s}.{n}" for (s, k, n) in cat1.keys() - cat0.keys())
    mod_objs = sorted(f"{k}:{s}.{n}" for key in cat1.keys() & cat0.keys() if cat1[key] != cat0[key]
                      for (s, k, n) in [key])
    return dict(
        duration_s=round(duration, 3), wal_bytes=wal,
        rows_ins_new_tables=sum(d[0] for t, d in delta.items() if t not in base_tables),
        rows_ins_existing_tables=sum(d[0] for t, d in delta.items() if t in base_tables),
        rows_upd_del_existing_tables=sum(d[1] + d[2] for t, d in delta.items() if t in base_tables),
        existing_tables_touched=";".join(sorted(t for t, d in delta.items() if t in base_tables and any(d))),
        objects_new=len(new_objs), objects_modified=len(mod_objs),
        new_list=";".join(new_objs), modified_list=";".join(mod_objs),
    )


def run_rep(session: str, tier: str, rep: int):
    etl.reset_db()
    with closing(etl.connect(etl.DB)) as conn, conn.cursor() as cur:
        cur.execute("call dbo.sp_load_all_dv_full(%s, localtimestamp)", (f"{session}_base_dv",))
        cur.execute("call star.sp_load_star_full(%s, localtimestamp)", (f"{session}_base_star",))
        cur.execute("vacuum analyze")
        base_tables = set(table_stats(cur))
        rows = []
        for arch, fname in DDL_STEPS:
            m = measure(cur, session, [((EVOLUTION_DIR / fname).read_text(), None)], base_tables)
            rows.append(dict(session=session, tier=tier, rep=rep, phase="ddl", step=fname, architecture=arch, **m))
        for arch, calls in BACKFILL_STEPS:
            m = measure(cur, session, [(c, (f"{session}_backfill",)) for c in calls], base_tables)
            rows.append(dict(session=session, tier=tier, rep=rep, phase="backfill", step=arch, architecture=arch, **m))

        # walidacja: zmienione procedury nadrzędne + zgodność rozkładu rund
        cur.execute("call dbo.sp_load_all_dv_full(%s, localtimestamp)", (f"{session}_valid_dv",))
        cur.execute("call star.sp_load_star_full(%s, localtimestamp)", (f"{session}_valid_star",))
        cur.execute("select string_agg(object_name || ': ' || message, ' | ') from stg.log_table where message like 'Error:%%'")
        errors = cur.fetchone()[0]
        dist = {}
        for k, sql in ROUND_CHECK_SQL.items():
            cur.execute(sql)
            dist[k] = cur.fetchall()
    for r in rows:
        print(f"rep={rep} {r['phase']:8} {r['step']:12} {r['duration_s']:7.3f}s new={r['objects_new']} "
              f"mod={r['objects_modified']} upd_existing={r['rows_upd_del_existing_tables']} {r['modified_list']}")
    etl.append_csv("evolution_runs.csv", rows)
    etl.append_csv("evolution_checks.csv", [dict(
        session=session, tier=tier, rep=rep, errors=errors,
        star_equals_dmart=dist["STAR"] == dist["DMART"], star_equals_dv=dist["STAR"] == dist["DV"],
        distribution=str(dist["STAR"]))])
    if errors or dist["STAR"] != dist["DMART"] or dist["STAR"] != dist["DV"]:
        print(f"WALIDACJA NIEUDANA: errors={errors} dist={dist}")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("tier")
    p.add_argument("--reps", type=int, default=5)
    a = p.parse_args()
    etl.OUT_DIR.mkdir(exist_ok=True)
    session = "evo_" + dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    etl.build_template()
    etl.transform(a.tier)
    for rep in range(1, a.reps + 1):
        run_rep(f"{session}_r{rep}", a.tier, rep)
    print(f"Gotowe. session={session}")


if __name__ == "__main__":
    main()
