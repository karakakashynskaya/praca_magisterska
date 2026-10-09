"""Pomiar ETL: Data Vault (stg -> dbo -> dmart) vs Star Schema (stg -> star)."""
import argparse
import csv
import random
import datetime as dt
import os
import subprocess
import sys
import threading
import time
from contextlib import closing
from pathlib import Path

import psycopg2
from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parent.parent
load_dotenv(ROOT / "env" / "app.env")

OUT_DIR = ROOT / "bench_results"
CONTAINER, DB, TPL = "wta_postgres", "wta_dwh", "wta_tpl"
CONN = dict(host="localhost", port=5532, user=os.environ["DB_USER"], password=os.environ["DB_PASSWORD"])
SCHEMAS = ["stg", "dbo", "dmart", "star"]
STOP_FILE = "/tmp/mem_sampler.stop"

ARCH = {
    "DV": dict(
        proc="dbo.sp_load_all_dv_full",
        matches="select count(*) from dmart.dim_matches where row_expired_dt is null",
        facts="select count(*) from dmart.fct_match_statistics where row_expired_dt is null",
    ),
    "STAR": dict(
        proc="star.sp_load_star_full",
        matches="select count(*) from star.dim_match where is_current",
        facts="select count(*) from star.fct_match_statistics where is_current",
    ),
}


# ---------- docker / cgroup ----------
def sh(*cmd: str) -> str:
    return subprocess.run(cmd, check=True, capture_output=True, text=True).stdout


def cpu_usec() -> int:
    stat = sh("docker", "exec", CONTAINER, "cat", "/sys/fs/cgroup/cpu.stat")
    return int(next(l.split()[1] for l in stat.splitlines() if l.startswith("usage_usec")))


class MemSampler:
    """memory.current co 100 ms; pętla w kontenerze kończy się sama po utworzeniu STOP_FILE."""

    def __init__(self):
        loop = (f"rm -f {STOP_FILE}; while [ ! -e {STOP_FILE} ]; do "
                f"cat /sys/fs/cgroup/memory.current; sleep 0.1; done; rm -f {STOP_FILE}")
        self.samples: list[int] = []
        self.proc = subprocess.Popen(["docker", "exec", CONTAINER, "sh", "-c", loop],
                                     stdout=subprocess.PIPE, text=True)
        self.thread = threading.Thread(target=self._read, daemon=True)
        self.thread.start()
        while not self.samples:
            time.sleep(0.01)

    def _read(self):
        for line in self.proc.stdout:
            self.samples.append(int(line))

    def stop(self) -> list[int]:
        sh("docker", "exec", CONTAINER, "touch", STOP_FILE)
        self.proc.wait(timeout=10)
        self.thread.join(timeout=1)
        return self.samples


# ---------- baza ----------
def connect(dbname: str):
    conn = psycopg2.connect(dbname=dbname, **CONN)
    conn.autocommit = True
    return conn


def wait_ready(timeout_s: int = 60):
    deadline = time.time() + timeout_s
    while True:
        try:
            connect(DB).close()
            return
        except psycopg2.OperationalError:
            if time.time() > deadline:
                raise
            time.sleep(0.5)


def build_template():
    """wta_tpl = kopia świeżo zmigrowanej (pustej) wta_dwh — aktualna wersja procedur."""
    with closing(connect(DB)) as conn, conn.cursor() as cur:
        cur.execute("select count(*) from stg.log_table")
        if cur.fetchone()[0]:
            sys.exit("wta_dwh zawiera dane — uruchom najpierw: make clear up update-common")
    with closing(connect("postgres")) as conn, conn.cursor() as cur:
        cur.execute(f"drop database if exists {TPL}")
        cur.execute(f"create database {TPL} template {DB}")


def reset_db():
    with closing(connect("postgres")) as conn, conn.cursor() as cur:
        cur.execute(f"drop database if exists {DB} with (force)")
        cur.execute(f"create database {DB} template {TPL}")
    sh("docker", "restart", CONTAINER)
    wait_ready()


def db_blocks(cur) -> tuple[int, int, int]:
    # wymuszenie zrzutu liczników tej sesji (PG15+) przed odczytem pg_stat_database
    cur.execute("select pg_stat_force_next_flush()")
    cur.execute("select blks_hit, blks_read, temp_bytes from pg_stat_database where datname = current_database()")
    return cur.fetchone()


def rows_written(cur) -> dict[str, int]:
    """Wywoływać bezpośrednio po db_blocks (liczniki tej sesji już zrzucone)."""
    cur.execute("select schemaname, sum(n_tup_ins + n_tup_upd + n_tup_del) from pg_stat_user_tables "
                "where schemaname = any(%s) group by 1", (SCHEMAS,))
    return {k: int(v) for k, v in cur.fetchall()}


def mutate_players(pct: float, seed: int = 42) -> int:
    """T7: titles_won + 1 u pct % zawodniczek (deterministycznie). Zmienia się jeden atrybut:
    w DV jeden satelita (sat_player_personal_info), w Star cały wiersz wymiaru."""
    path = ROOT / "liquibase" / "data_src" / "players.csv"
    with path.open(encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        fields, rows = reader.fieldnames, list(reader)
    chosen = random.Random(seed).sample(range(len(rows)), round(len(rows) * pct / 100))
    for i in chosen:
        rows[i]["titles_won"] = str(int(rows[i]["titles_won"] or 0) + 1)
    with path.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        w.writerows(rows)
    return len(chosen)


def transform(tier: str):
    subprocess.run([sys.executable, "run_transform.py", tier], cwd=ROOT / "python" / "json_parser",
                   check=True, stdout=subprocess.DEVNULL)


# ---------- jeden przebieg ----------
def run_once(session: str, scenario: str, tier: str, arch: str, rep: int, pos: int) -> dict:
    run_id = f"{session}_{scenario}_{tier}_{arch}_r{rep}"
    with closing(connect(DB)) as conn, conn.cursor() as cur:
        cur.execute("select coalesce(max(id), 0) from stg.log_table")
        log_id0 = cur.fetchone()[0]
        hit0, read0, temp0 = db_blocks(cur)
        rows0 = rows_written(cur)
        cur.execute("select pg_current_wal_lsn()")
        wal0 = cur.fetchone()[0]

        mem = MemSampler()
        c0 = cpu_usec(); time.sleep(1.0); idle_rate = (cpu_usec() - c0) / 1e6  # CPU tła [s/s]
        n_pre = len(mem.samples)

        cur.execute("select clock_timestamp()")
        start_ts = cur.fetchone()[0]
        error = None
        cpu0, t0 = cpu_usec(), time.perf_counter()
        try:
            cur.execute(f"call {ARCH[arch]['proc']}(%s, localtimestamp)", (run_id,))
        except psycopg2.Error as e:
            error = str(e).strip()[:500]
        duration = time.perf_counter() - t0
        cpu_s = (cpu_usec() - cpu0) / 1e6
        samples = mem.stop()

        hit1, read1, temp1 = db_blocks(cur)
        rows1 = rows_written(cur)
        cur.execute("select pg_wal_lsn_diff(pg_current_wal_lsn(), %s)::bigint", (wal0,))
        wal_bytes = cur.fetchone()[0]

        cur.execute("select string_agg(object_name || ': ' || message, ' | ' order by id) "
                    "from stg.log_table where id > %s and message like 'Error:%%'", (log_id0,))
        error = error or cur.fetchone()[0]

        cur.execute("select n.nspname, coalesce(sum(pg_total_relation_size(c.oid)), 0) / 1048576.0 "
                    "from pg_namespace n left join pg_class c on c.relnamespace = n.oid and c.relkind = 'r' "
                    "where n.nspname = any(%s) group by 1", (SCHEMAS,))
        sizes = dict(cur.fetchall())
        cur.execute(ARCH[arch]["matches"]); matches = cur.fetchone()[0]
        cur.execute(ARCH[arch]["facts"]); fct_rows = cur.fetchone()[0]

        cur.execute("select row_number() over (order by id), object_name, records_count, "
                    "round(extract(epoch from exec_date - %s)::numeric, 3) "
                    "from stg.log_table where id > %s order by id", (start_ts, log_id0))
        stages = [dict(run_id=run_id, seq=s, object_name=o, records_count=r, t_since_start_s=t)
                  for s, o, r, t in cur.fetchall()]

    run_mem = samples[n_pre:] or samples[-1:]
    cpu_net = max(cpu_s - idle_rate * duration, 0.0)
    row = dict(
        session=session, run_id=run_id, scenario=scenario, tier=tier, architecture=arch, rep=rep, order_pos=pos,
        duration_s=round(duration, 3), cpu_s=round(cpu_s, 3), cpu_idle_rate=round(idle_rate, 4),
        cpu_net_s=round(cpu_net, 3), cpu_avg_pct=round(100 * cpu_net / duration, 1),
        mem_base_mb=round(sum(samples[:n_pre]) / max(n_pre, 1) / 2**20, 1),
        mem_avg_mb=round(sum(run_mem) / len(run_mem) / 2**20, 1), mem_peak_mb=round(max(run_mem) / 2**20, 1),
        mem_samples=len(run_mem),
        blks_hit=hit1 - hit0, blks_read=read1 - read0, temp_bytes=temp1 - temp0,
        **{f"rows_{s}": rows1.get(s, 0) - rows0.get(s, 0) for s in SCHEMAS},
        wal_bytes=wal_bytes,
        **{f"size_{s}_mb": round(float(sizes.get(s, 0)), 2) for s in SCHEMAS},
        matches=matches, fct_rows=fct_rows, error=error, ts=dt.datetime.now().isoformat(timespec="seconds"),
    )
    append_csv("etl_runs.csv", [row])
    append_csv("etl_stages.csv", stages)
    print(f"{run_id}: {duration:.3f}s cpu={cpu_net:.2f}s peak={row['mem_peak_mb']}MB "
          f"matches={matches}{'  ERROR: ' + error if error else ''}", flush=True)
    return row


def append_csv(name: str, rows: list[dict]):
    if not rows:
        return
    path = OUT_DIR / name
    new = not path.exists()
    with path.open("a", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]))
        if new:
            w.writeheader()
        w.writerows(rows)


def arch_order(rep: int) -> tuple[str, str]:
    return ("DV", "STAR") if rep % 2 else ("STAR", "DV")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("scenario", choices=["full", "incremental", "changes"])
    p.add_argument("tiers", nargs="+", help="full: tier ...; incremental: base:inc ...; changes: tier:pct ...")
    p.add_argument("--reps", type=int, default=5)
    a = p.parse_args()

    if not sh("docker", "exec", CONTAINER, "sh", "-c", "test -f /sys/fs/cgroup/cpu.stat && echo ok").strip():
        sys.exit("Brak cgroup v2 w kontenerze — pomiar CPU/RAM niemożliwy")
    OUT_DIR.mkdir(exist_ok=True)
    session = "etl_" + dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    build_template()

    for spec in a.tiers:
        if a.scenario == "full":
            transform(spec)
        for rep in range(1, a.reps + 1):
            for pos, arch in enumerate(arch_order(rep), 1):
                reset_db()
                if a.scenario == "full":
                    run_once(session, "full", spec, arch, rep, pos)
                elif a.scenario == "changes":
                    tier, pct = spec.split(":")
                    transform(tier)
                    run_once(session, "chg_base", f"{tier}:{pct}%", arch, rep, pos)
                    n = mutate_players(float(pct))
                    run_once(session, "changes", f"{tier}:{pct}%:{n}", arch, rep, pos)
                else:
                    base, inc = spec.split(":")
                    transform(base)
                    run_once(session, "inc_base", base, arch, rep, pos)
                    transform(inc)
                    run_once(session, "incremental", inc, arch, rep, pos)
    print(f"Gotowe. session={session}")


if __name__ == "__main__":
    main()
