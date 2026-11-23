from datetime import date
from pathlib import Path
import sys

ROOT = Path(__file__).parents[1]
sys.path.insert(0, str(ROOT / "python"))

from sky_points_pipeline import age_on, parse_date, parse_excel_date, run_pipeline, validate


def test_parse_excel_numeric_dates():
    assert parse_excel_date(6152022) == date(2022, 6, 15)
    assert parse_excel_date(8202022) == date(2022, 8, 20)
    assert parse_excel_date(12282021) == date(2021, 12, 28)


def test_parse_invalid_and_null_dates():
    assert parse_date("2021-13-13") is None
    assert parse_date("NULL") is None


def test_age_calculation():
    assert age_on(date(2000, 1, 1), date(2026, 11, 23)) == 26
    assert age_on(date(2000, 11, 24), date(2026, 11, 23)) == 25


def test_validation_flags_missing_enrollment():
    rows = [{
        "member_id": "1", "member_name": "A", "enrollment_date": None,
        "tier_code": None, "dob": None, "last_flight_date": None,
        "source_file": "test.xlsx", "source_row_number": 2,
    }]
    result = validate(rows)
    rules = {r["rule_name"]: r["failed_row_count"] for r in result["rules"]}
    assert rules["enrollment_date_mandatory"] == 1
    assert rules["dob_parseable"] == 1


def test_end_to_end_pipeline(tmp_path):
    summary = run_pipeline(ROOT / "csv", tmp_path, date(2026, 11, 23))
    assert summary["source_row_count"] == 9
    assert summary["latest_member_count"] == 9
    assert (tmp_path / "staging_member_profile.csv").exists()
    assert (tmp_path / "redemption_transactions.csv").exists()
    assert (tmp_path / "target_india.csv").exists()
