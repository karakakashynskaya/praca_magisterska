import json
import time
from pathlib import Path

import requests

from config import BASE_URL, HEADERS, DATA_DIR, REQUESTS_PER_MINUTE

_MIN_INTERVAL = 60.0 / REQUESTS_PER_MINUTE
_last_call = 0.0
_counter_file = DATA_DIR.parent / "request_count.txt"


def request_count() -> int:
    if _counter_file.exists():
        return int(_counter_file.read_text().strip() or 0)
    return 0


def _bump_count():
    _counter_file.write_text(str(request_count() + 1))


def get(path: str, params: dict | None = None, max_retries: int = 5) -> dict:
    global _last_call
    url = f"{BASE_URL}{path}"

    for attempt in range(max_retries):
        elapsed = time.monotonic() - _last_call
        if elapsed < _MIN_INTERVAL:
            time.sleep(_MIN_INTERVAL - elapsed)

        resp = requests.get(url, headers=HEADERS, params=params, timeout=20)
        _last_call = time.monotonic()
        _bump_count()

        if resp.status_code == 200:
            return resp.json()
        if resp.status_code == 429:
            wait = 2 ** attempt * 2
            print(f"429, czekamy {wait}s: {resp.url}")
            time.sleep(wait)
            continue
        if resp.status_code >= 500:
            wait = 2 ** attempt
            print(f"{resp.status_code}, retry za {wait}s: {resp.url}")
            time.sleep(wait)
            continue

        resp.raise_for_status()

    raise RuntimeError(f"Nie udało się wykonać zapytania po {max_retries} próbach: {url}")


def get_paginated(path: str, params: dict | None = None, page_size: int = 500) -> list[dict]:
    params = dict(params or {})
    params["pageSize"] = page_size
    all_rows = []
    page = 1
    while True:
        params["pageNo"] = page
        resp = get(path, params=params)
        rows = resp.get("data", [])
        all_rows.extend(rows)
        if not resp.get("hasNextPage"):
            break
        page += 1
    return all_rows


def save_json(subdir: str, name: str, data) -> Path:
    out_dir = DATA_DIR / subdir
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / f"{name}.json"
    out_path.write_text(json.dumps(data, ensure_ascii=False, indent=1))
    return out_path


def load_json(subdir: str, name: str):
    path = DATA_DIR / subdir / f"{name}.json"
    if not path.exists():
        return None
    return json.loads(path.read_text())


def already_fetched(subdir: str, name: str) -> bool:
    return (DATA_DIR / subdir / f"{name}.json").exists()