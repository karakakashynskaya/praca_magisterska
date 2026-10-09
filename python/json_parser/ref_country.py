"""ref_country.json -> ref_country.csv"""
from common import RAW_DIR, load_json, write_csv, empty_to_none


def transform():
    data = load_json(RAW_DIR / "reference" / "countries.json")
    rows = [
        {
            "country_code": empty_to_none(c.get("country_acronym")),
            "description": empty_to_none(c.get("country_name")),
        }
        for c in data.get("data", [])
        if (c.get("country_acronym") or "").strip()
        and (c.get("country_acronym") or "").strip().upper() != "N/A"
        and (c.get("country_name") or "").strip()
    ]
    write_csv("ref_country.csv", ["country_code", "description"], rows)


if __name__ == "__main__":
    transform()