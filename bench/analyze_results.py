"""Statystyczne opracowanie wyników (rozdz. 6–7): mediany, rozstępy, ilorazy, elastyczności.

Wejście: bench_results/*.csv. Wyjście: bench_results/analysis/*.csv (tabele do pracy).
Użycie: python bench/analyze_results.py [katalog_wyników]
"""
import sys
from pathlib import Path

import numpy as np
import pandas as pd
from scipy import stats

IN = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent / "bench_results"
OUT = IN / "analysis"
OUT.mkdir(exist_ok=True)
TIERS = ["slams_1y", "mid_1y", "mid_5y", "mid_10y"]
P = {"slams_1y": "P1", "mid_1y": "P2", "mid_5y": "P3", "mid_10y": "P4"}


def med_rng(s: pd.Series) -> str:
    return f"{s.median():.3f} [{s.min():.3f}–{s.max():.3f}]"


def elasticity(n: pd.Series, y: pd.Series) -> dict:
    """log y = a + b log n (OLS na wszystkich powtórzeniach); b z 95% CI."""
    r = stats.linregress(np.log(n), np.log(y))
    t = stats.t.ppf(0.975, len(n) - 2)
    return dict(b=round(r.slope, 3), ci_low=round(r.slope - t * r.stderr, 3),
                ci_high=round(r.slope + t * r.stderr, 3), r2=round(r.rvalue ** 2, 4), n_obs=len(n))


def save(df: pd.DataFrame, name: str):
    df.to_csv(OUT / f"{name}.csv", index=False)
    print(f"\n### {name}\n{df.to_string(index=False)}")


etl = pd.read_csv(IN / "etl_runs.csv")
assert etl["error"].isna().all(), "przebiegi z błędami"
etl["size_arch_mb"] = np.where(etl.architecture == "DV", etl.size_dbo_mb + etl.size_dmart_mb, etl.size_star_mb)
etl["rows_arch"] = np.where(etl.architecture == "DV", etl.rows_dbo + etl.rows_dmart, etl.rows_star)

# ---- 6.1 / 6.5: pełne ładowanie ----
full = etl[etl.scenario == "full"]
rows = []
for tier in TIERS:
    g = full[full.tier == tier]
    dv, st = g[g.architecture == "DV"], g[g.architecture == "STAR"]
    rows.append(dict(
        przekroj=P[tier], mecze=int(g.matches.iloc[0]),
        dv_s=med_rng(dv.duration_s), star_s=med_rng(st.duration_s),
        ratio_dv_star=round(dv.duration_s.median() / st.duration_s.median(), 2),
        narzut_dv_pct=round(100 * (dv.duration_s.median() / st.duration_s.median() - 1), 1),
        dv_cpu_s=round(dv.cpu_net_s.median(), 2), star_cpu_s=round(st.cpu_net_s.median(), 2),
        dv_cpu_pct=round(dv.cpu_avg_pct.median(), 1), star_cpu_pct=round(st.cpu_avg_pct.median(), 1),
        dv_mem_peak_mb=round(dv.mem_peak_mb.median(), 1), star_mem_peak_mb=round(st.mem_peak_mb.median(), 1),
        dv_temp_mb=round(dv.temp_bytes.median() / 2**20, 1), star_temp_mb=round(st.temp_bytes.median() / 2**20, 1),
        dv_wal_mb=round(dv.wal_bytes.median() / 2**20, 1), star_wal_mb=round(st.wal_bytes.median() / 2**20, 1),
        stg_mb=round(g.size_stg_mb.median(), 2),
        dv_size_mb=round(dv.size_arch_mb.median(), 2), star_size_mb=round(st.size_arch_mb.median(), 2),
        size_ratio=round(dv.size_arch_mb.median() / st.size_arch_mb.median(), 2),
        dv_kb_per_match=round(1024 * dv.size_arch_mb.median() / g.matches.iloc[0], 2),
        star_kb_per_match=round(1024 * st.size_arch_mb.median() / g.matches.iloc[0], 2),
        dv_rows=int(dv.rows_arch.median()), star_rows=int(st.rows_arch.median()),
    ))
save(pd.DataFrame(rows), "t1_full_load")

# ---- 6.4 / 6.6: elastyczności ----
rows = []
for metric in ["duration_s", "cpu_net_s", "size_arch_mb", "wal_bytes", "mem_peak_mb"]:
    for arch in ["DV", "STAR"]:
        g = full[full.architecture == arch]
        rows.append(dict(metryka=metric, architektura=arch, **elasticity(g.matches, g[metric])))
save(pd.DataFrame(rows), "t19_elasticity_etl")

# model afiniczny t = c + k*n: koszt stały c [s] i krańcowy k [s / 1000 meczów]
rows = []
for arch in ["DV", "STAR"]:
    g = full[full.architecture == arch]
    r = stats.linregress(g.matches, g.duration_s)
    tq = stats.t.ppf(0.975, len(g) - 2)
    rows.append(dict(architektura=arch, fixed_cost_s=round(r.intercept, 3),
                     s_per_1000=round(1000 * r.slope, 3),
                     s_per_1000_ci=f"{1000 * (r.slope - tq * r.stderr):.3f}–{1000 * (r.slope + tq * r.stderr):.3f}",
                     r2=round(r.rvalue ** 2, 4),
                     predicted_full_9601_s=round(r.intercept + r.slope * 9601, 2)))
save(pd.DataFrame(rows), "t19_affine_etl")

# koszt krańcowy: nachylenie liniowe P3->P4 (s i MB na 1000 meczów)
m = full.groupby(["architecture", "tier"]).agg(n=("matches", "first"), t=("duration_s", "median"),
                                               mb=("size_arch_mb", "median")).reset_index()
rows = []
for arch in ["DV", "STAR"]:
    a = m[(m.architecture == arch) & (m.tier == "mid_5y")].iloc[0]
    b = m[(m.architecture == arch) & (m.tier == "mid_10y")].iloc[0]
    rows.append(dict(architektura=arch, s_per_1000_matches=round(1000 * (b.t - a.t) / (b.n - a.n), 3),
                     mb_per_1000_matches=round(1000 * (b.mb - a.mb) / (b.n - a.n), 3)))
save(pd.DataFrame(rows), "t20_marginal_cost")

# ---- 6.1 T2: struktura czasu (etapy) ----
stg_ = pd.read_csv(IN / "etl_stages.csv")
stg_["dt"] = stg_.groupby("run_id").t_since_start_s.diff().fillna(stg_.t_since_start_s)


def layer(row) -> str:
    o = row.object_name
    if o.startswith(("sp_truncate_", "sp_load_buffer_", "sp_load_raw_")):
        return "stg"
    if o.startswith("analyze_"):
        return "ANALYZE (" + o.split("_", 1)[1] + ")"
    if o.startswith("sp_load_star_"):
        return "star: fakty" if "_fct_" in o else "star: wymiary"
    if o.startswith(("sp_load_hub_", "sp_load_link_")) or o == "sp_load_ref_country" and row.seq < 50:
        return "dbo: huby i linki"
    if o.startswith("sp_load_sat_") and o.endswith("_status"):
        return "dbo: satelity statusu"
    if o.startswith("sp_load_sat_"):
        return "dbo: satelity opisowe"
    if o.startswith(("sp_load_dim_", "sp_load_fct_", "sp_load_ref_country")):
        return "dmart"
    return "inne"


runs_full = full.run_id.unique()
s = stg_[stg_.run_id.isin(runs_full)].copy()
s["layer"] = s.apply(layer, axis=1)
s = s.merge(full[["run_id", "tier", "architecture"]], on="run_id")
agg = s.groupby(["tier", "architecture", "run_id", "layer"]).dt.sum().reset_index()
agg = agg.groupby(["tier", "architecture", "layer"]).dt.median().reset_index()
agg["share_pct"] = (100 * agg.dt / agg.groupby(["tier", "architecture"]).dt.transform("sum")).round(1)
agg["dt"] = agg.dt.round(3)
agg = agg[agg.tier == "mid_10y"].drop(columns="tier")
save(agg, "t2_stage_breakdown_P4")

# ---- 6.2: ładowanie przyrostowe ----
inc = etl[etl.scenario.isin(["inc_base", "incremental"])]
rows = []
for arch in ["DV", "STAR"]:
    b = inc[(inc.architecture == arch) & (inc.scenario == "inc_base")]
    i = inc[(inc.architecture == arch) & (inc.scenario == "incremental")]
    rows.append(dict(architektura=arch, base_P3_s=med_rng(b.duration_s), incremental_s=med_rng(i.duration_s),
                     inc_to_full_ratio=round(i.duration_s.median() / b.duration_s.median(), 2),
                     rows_written=int(i.rows_arch.median()), wal_mb=round(i.wal_bytes.median() / 2**20, 1),
                     temp_mb=round(i.temp_bytes.median() / 2**20, 1)))
t = pd.DataFrame(rows)
t["ratio_dv_star"] = round(inc[(inc.scenario == "incremental") & (inc.architecture == "DV")].duration_s.median()
                           / inc[(inc.scenario == "incremental") & (inc.architecture == "STAR")].duration_s.median(), 2)
save(t, "t4_t5_incremental")

# ---- 6.2 T7: zmiana atrybutu ----
chg = etl[etl.scenario == "changes"].copy()
chg["pct"] = chg.tier.str.split(":").str[1]
chg["changed"] = chg.tier.str.split(":").str[2].astype(int)
t = chg.groupby(["pct", "changed", "architecture"]).agg(
    duration_s=("duration_s", "median"), rows_written=("rows_arch", "median"),
    wal_mb=("wal_bytes", lambda x: round(x.median() / 2**20, 3))).reset_index()
t["rows_per_change"] = (t.rows_written / t.changed).round(2)
save(t.sort_values(["changed", "architecture"]), "t7_attribute_change")
rows = []
for arch in ["DV", "STAR"]:
    g = chg[chg.architecture == arch]
    r = stats.linregress(g.changed, g.wal_bytes)
    rows.append(dict(architektura=arch, wal_bytes_per_changed_player=round(r.slope), r2=round(r.rvalue ** 2, 4),
                     rows_per_changed_player=round(stats.linregress(g.changed, g.rows_arch).slope, 2)))
save(pd.DataFrame(rows), "t7_marginal_write_cost")

# ---- 6.3: zapytania ----
q = pd.read_csv(IN / "query_runs.csv")
chk = pd.read_csv(IN / "query_checks.csv")
assert chk.equal_to_star.all(), "niezgodne wyniki wariantów"
qm = q.groupby(["tier", "query_name", "variant"]).agg(
    exec_ms=("exec_time_ms", "median"), exec_min=("exec_time_ms", "min"), exec_max=("exec_time_ms", "max"),
    plan_ms=("planning_time_ms", "median"), blks=("shared_blks_hit", "median"),
    blks_read=("shared_blks_read", "max"), volume=("volume", "first")).reset_index()
w = qm.pivot_table(index=["tier", "query_name"], columns="variant", values=["exec_ms", "plan_ms", "blks"])
w.columns = [f"{a}_{b}" for a, b in w.columns]
w = w.reset_index()
w["dmart_vs_star"] = (w.exec_ms_dmart / w.exec_ms_star).round(2)
w["dv_vs_star"] = (w.exec_ms_dv / w.exec_ms_star).round(2)
w["dv_vs_dmart_blks"] = (w.blks_dv / w.blks_dmart).round(2)
w["tier"] = pd.Categorical(w.tier, TIERS)
save(w.sort_values(["tier", "query_name"]).round(3), "t9_t12_queries")
rows = []
for (qn, v), g in q.groupby(["query_name", "variant"]):
    rows.append(dict(query=qn, variant=v, **elasticity(g.volume, g.exec_time_ms)))
save(pd.DataFrame(rows), "t19_elasticity_queries")

# ---- 7.2 T23: ewolucja schematu ----
ev = pd.read_csv(IN / "evolution_runs.csv")
evc = pd.read_csv(IN / "evolution_checks.csv")
assert evc.errors.isna().all() and evc.star_equals_dmart.all() and evc.star_equals_dv.all()
t = ev.groupby(["phase", "step", "architecture"]).agg(
    duration_s=("duration_s", "median"), wal_mb=("wal_bytes", lambda x: round(x.median() / 2**20, 2)),
    rows_new_tables=("rows_ins_new_tables", "median"),
    rows_rewritten_existing=("rows_upd_del_existing_tables", "median"),
    objects_new=("objects_new", "median"), objects_modified=("objects_modified", "median"),
    modified=("modified_list", "first")).reset_index()
save(t, "t23_evolution")
print(f"\nZapisano do {OUT}")
