import os
from pathlib import Path
from dotenv import load_dotenv

_PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
load_dotenv(_PROJECT_ROOT / ".env")

HOST = "tennis-api-atp-wta-itf.p.rapidapi.com"
BASE_URL = f"https://{HOST}/tennis/v2"

API_KEY = os.environ.get("TENNIS_API_KEY", "")
HEADERS = {"X-RapidAPI-Key": API_KEY, "X-RapidAPI-Host": HOST}

DATA_DIR = Path(__file__).parent / "data" / "raw"
DATA_DIR.mkdir(parents=True, exist_ok=True)

REQUESTS_PER_MINUTE = 90

# Przekroje objętościowe: (tours, years, tour_ranks)
# tour_ranks: 2=Main tour (WTA 250+500), 3=Masters, 4=Grand Slam
TIERS = {
    "smoke": {"tours": ["wta"], "years": [2025], "tour_ranks": [4], "single_tournament": True},
    "slams_1y": {"tours": ["wta"], "years": [2025], "tour_ranks": [4]},
    "mid_1y": {"tours": ["wta"], "years": [2025], "tour_ranks": [2, 3, 4]},
    "mid_5y": {"tours": ["wta"], "years": [2021, 2022, 2023, 2024, 2025], "tour_ranks": [2, 3, 4]},
    "mid_5y_inc": {"tours": ["wta"], "years": [2021, 2022, 2023, 2024, 2025, 2026], "tour_ranks": [2, 3, 4]},
    "mid_10y": {
        "tours": ["wta"],
        "years": [2016, 2017, 2018, 2019, 2020, 2021, 2022, 2023, 2024, 2025],
        "tour_ranks": [2, 3, 4],
    },
    "all_years": {"tours": ["wta"], "years": [2016, 2017, 2018, 2019, 2020, 2021, 2022, 2023, 2024, 2025, 2026],
                  "tour_ranks": [2, 3, 4]},
}