from datetime import date
from pathlib import Path
import sys

import pytest

ROOT = Path(__file__).parents[1]
sys.path.insert(0, str(ROOT))

from src.normalize_data import calculate_age, normalize_workbooks, parse_date


def test_parse_source_date_formats_and_invalid_dates():
    assert parse_date("2021-13-13") is None
    assert parse_date("NULL") is None
    assert parse_date("6152022") == date(2022, 6, 15)
    assert parse_date("8202022") == date(2022, 8, 20)
    assert parse_date("20240115") == date(2024, 1, 15)


def test_age_before_birthday():
    assert calculate_age(date(2000, 11, 24), date(2026, 11, 23)) == 25


def test_normalizes_all_workbooks_without_colliding_country_local_ids():
    records = normalize_workbooks(ROOT / "data", date(2026, 11, 23))

    assert len(records) == 9
    assert len({record["member_id"] for record in records}) == 9
    assert {record["country"] for record in records} == {"USA", "IND", "AU"}
    assert next(record for record in records if record["member_name"] == "Jonnathan")[
        "enrollment_date"
    ] is None
    assert next(record for record in records if record["member_name"] == "Mike")["dob"] is None


def test_missing_source_workbook_is_reported(tmp_path):
    with pytest.raises(FileNotFoundError, match="USA.xlsx"):
        normalize_workbooks(tmp_path)
