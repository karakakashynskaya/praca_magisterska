"""Kopia TIERS z tennis_scraper/config.py — potrzebna do zebrania turniejów danego przekroju
po latach, niezależnie od tego, jak nazwany jest plik cache w data/raw/tournaments/.
Klucz 'tour_ranks' jest opcjonalny: jeśli go brak, turnieje nie są filtrowane po randze."""
TIERS = {
    "smoke": {"tours": ["wta"], "years": [2025]},
    "slams_1y": {"tours": ["wta"], "years": [2025], "tour_ranks": [4]},
    "mid_1y": {"tours": ["wta"], "years": [2025]},
    "mid_5y": {"tours": ["wta"], "years": [2021, 2022, 2023, 2024, 2025]},
    "mid_5y_inc": {"tours": ["wta"], "years": [2021, 2022, 2023, 2024, 2025, 2026]},
    "mid_10y": {"tours": ["wta"], "years": [2016, 2017, 2018, 2019, 2020, 2021, 2022, 2023, 2024, 2025]},
}