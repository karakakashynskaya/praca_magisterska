"""Metryki z planu EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)."""

def extract_metrics(explain_json: list) -> dict:
    root = explain_json[0]
    plan = root["Plan"]
    return {
        "planning_time_ms": root["Planning Time"],
        "exec_time_ms": root["Execution Time"],
        "shared_blks_hit": plan.get("Shared Hit Blocks", 0),
        "shared_blks_read": plan.get("Shared Read Blocks", 0),
        "temp_blks_written": plan.get("Temp Written Blocks", 0),
    }
