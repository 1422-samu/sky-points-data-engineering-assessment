from __future__ import annotations

import argparse
import json
import re
import uuid
from datetime import date, datetime
from pathlib import Path
from typing import Any

import openpyxl
import pandas as pd

COUNTRY_MAP = {"USA": "USA", "IND": "IND", "AUS": "AU", "AU": "AU", "AUSTRALIA": "AU"}


def parse_date(value: Any) -> date | None:
    if value is None:
        return None
    if isinstance(value, datetime):
        return value.date()
    if isinstance(value, date):
        return value
    text = str(value).strip()
    if not text or text.upper() in {"NULL", "N/A", "NONE", ""}:
        return None
    text = text.replace("/", "-")
    for fmt in ("%Y-%m-%d", "%Y%m%d", "%m%d%Y", "%m-%d-%Y"):
        try:
            return datetime.strptime(text, fmt).date()
        except ValueError:
            pass
    return None


def parse_excel_date(value: Any) -> date | None:
    if isinstance(value, (int, float)):
        text = str(int(value)).strip()
        if len(text) in {7, 8}:
            text = text.zfill(8)
            return datetime.strptime(text, "%m%d%Y").date()
    return parse_date(value)


def normalize_tier(value: Any) -> str | None:
    if value is None:
        return None
    tier = str(value).strip().upper()
    return tier if tier in {"SLV", "GLD", "PLT"} else None


def age_on(dob: date | None, as_of: date) -> int | None:
    if dob is None:
        return None
    return as_of.year - dob.year - ((as_of.month, as_of.day) < (dob.month, dob.day))


def extract_rows(source: Path) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    workbook = openpyxl.load_workbook(source, data_only=True)
    sheet_name = "in" if "in" in workbook.sheetnames else workbook.sheetnames[0]
    sheet = workbook[sheet_name]
    headers = [str(c.value).strip() if c.value is not None else "" for c in sheet[1]]
    rows: list[dict[str, Any]] = []
    country = {"USA.xlsx": "USA", "IND.xlsx": "IND", "AUS.xlsx": "AU"}[source.name]

    for row_number, values in enumerate(sheet.iter_rows(min_row=2, values_only=True), start=2):
        raw = dict(zip(headers, values))
        lower = {k.lower().replace(" ", ""): v for k, v in raw.items()}

        member_id = lower.get("uniqueid") or lower.get("id")
        name = lower.get("membername") or lower.get("name")
        tier = lower.get("tiertype") or lower.get("tiercode")

        enrollment_value = lower.get("dateofenrollment") or lower.get("enrollmentdate")
        flight_value = lower.get("dateofflight") or lower.get("flightdate")
        dob_value = lower.get("dateofbirth") or lower.get("dob")

        row = {
            "batch_id": "",
            "member_id": str(member_id).strip() if member_id is not None else None,
            "member_name": str(name).strip() if name is not None else None,
            "enrollment_date": parse_excel_date(enrollment_value) if country == "USA" else parse_date(enrollment_value),
            "last_flight_date": parse_excel_date(flight_value) if country == "USA" else parse_date(flight_value),
            "tier_code": normalize_tier(tier),
            "agent_name": None,
            "state": None,
            "country": country,
            "dob": parse_date(dob_value),
            "is_active": "A",
            "individual_or_corporate": lower.get("individualorcorporate"),
            "source_file": source.name,
            "source_row_number": row_number,
        }
        rows.append(row)
    return rows, []


def run_pipeline(csv_dir: Path, output_dir: Path, as_of: date) -> dict[str, Any]:
    output_dir.mkdir(parents=True, exist_ok=True)
    batch_id = str(uuid.uuid4())
    profiles: list[dict[str, Any]] = []

    for source_name in ("USA.xlsx", "IND.xlsx", "AUS.xlsx"):
        source = csv_dir / source_name
        if not source.exists():
            continue
        source_rows, _ = extract_rows(source)
        for row in source_rows:
            row["batch_id"] = batch_id
            dob = row["dob"]
            flight = row["last_flight_date"]
            row["age"] = age_on(dob, as_of)
            row["stale_member"] = bool(flight and (as_of - flight).days > 90)
            row["unique_key"] = f"{batch_id}:{row['member_id']}:{row['source_file']}:{row['source_row_number']}"
            profiles.append(row)

    # Latest record wins across countries, with flight date, enrollment date, then source order as rank criteria.
    ranked = sorted(
        profiles,
        key=lambda r: (
            r["last_flight_date"] or date.min,
            r["enrollment_date"] or date.min,
            r["source_row_number"],
        ),
        reverse=True,
    )
    latest: dict[tuple[str, str], dict[str, Any]] = {}
    for row in ranked:
        if row["member_id"]:
            key = (row["country"], row["member_id"])
            if key not in latest:
                latest[key] = row

    latest_rows = list(latest.values())
    for row in latest_rows:
        row["country"] = COUNTRY_MAP[row["country"]]

    columns = [
        "batch_id", "member_id", "member_name", "enrollment_date", "last_flight_date",
        "tier_code", "agent_name", "state", "country", "dob", "is_active",
        "individual_or_corporate", "age", "stale_member", "source_file",
        "source_row_number", "unique_key"
    ]

    staging = pd.DataFrame(profiles, columns=columns)
    staging.to_csv(output_dir / "staging_member_profile.csv", index=False)
    pd.DataFrame(latest_rows, columns=columns).to_csv(output_dir / "latest_member_profile.csv", index=False)

    for country, filename in (("IND", "target_india.csv"), ("USA", "target_usa.csv"), ("AU", "target_australia.csv")):
        pd.DataFrame([r for r in latest_rows if r["country"] == country], columns=columns).to_csv(output_dir / filename, index=False)

    redemptions = [
        {"member_id": "223457", "feed_date": "20240115", "redemptions": [
            {"txn_id": "RX10091", "txn_date": "20240110", "partner": "AeroLink", "miles_redeemed": 12000, "status": "COMPLETED"},
            {"txn_id": "RX10092", "txn_date": "20240113", "partner": "SkyPoints", "miles_redeemed": 5000, "status": "PENDING"},
        ]}
    ]
    flat = []
    for feed in redemptions:
        for txn in feed["redemptions"]:
            flat.append({
                "batch_id": batch_id,
                "member_id": feed["member_id"],
                "feed_date": parse_date(feed["feed_date"]),
                **txn,
            })
    pd.DataFrame(flat).to_csv(output_dir / "redemption_transactions.csv", index=False)

    dq = validate(profiles)
    pd.DataFrame(dq["rows"]).to_csv(output_dir / "data_quality_results.csv", index=False)

    summary = {
        "batch_id": batch_id,
        "as_of": as_of.isoformat(),
        "source_row_count": len(profiles),
        "latest_member_count": len(latest_rows),
        "country_counts": pd.DataFrame(latest_rows).groupby("country").size().to_dict() if latest_rows else {},
        "dq_failed_rule_count": sum(r["failed_row_count"] > 0 for r in dq["rules"]),
        "rules": dq["rules"],
    }
    (output_dir / "pipeline_summary.json").write_text(json.dumps(summary, indent=2, default=str), encoding="utf-8")
    return summary


def validate(profiles: list[dict[str, Any]]) -> dict[str, Any]:
    rules: list[dict[str, Any]] = []
    failures: list[dict[str, Any]] = []

    def add_rule(name: str, severity: str, predicate):
        bad = [row for row in profiles if predicate(row)]
        rules.append({"rule_name": name, "severity": severity, "failed_row_count": len(bad)})
        for row in bad:
            failures.append({"rule_name": name, "severity": severity, "source_file": row["source_file"], "source_row_number": row["source_row_number"]})

    add_rule("member_id_mandatory", "ERROR", lambda r: not r["member_id"])
    add_rule("member_name_mandatory", "ERROR", lambda r: not r["member_name"])
    add_rule("enrollment_date_mandatory", "ERROR", lambda r: r["enrollment_date"] is None)
    add_rule("invalid_member_tier", "WARNING", lambda r: not r["tier_code"])
    add_rule("dob_parseable", "WARNING", lambda r: r["dob"] is None)
    add_rule("last_flight_parseable", "WARNING", lambda r: r["last_flight_date"] is None)

    seen: set[tuple[str, str]] = set()
    duplicate_keys: set[tuple[str, str]] = set()
    for row in profiles:
        member_id = row["member_id"]
        if member_id:
            key = (row.get("country", "UNKNOWN"), member_id)
            if key in seen:
                duplicate_keys.add(key)
            seen.add(key)
    add_rule("member_id_duplicate_within_country", "WARNING", lambda r: (r.get("country", "UNKNOWN"), r["member_id"] ) in duplicate_keys)

    return {"rules": rules, "rows": failures}


def main() -> None:
    parser = argparse.ArgumentParser(description="Run the SkyPoints assessment pipeline")
    parser.add_argument("--csv-dir", type=Path, default=Path(__file__).parents[1] / "csv")
    parser.add_argument("--output-dir", type=Path, default=Path(__file__).parents[1] / "output")
    parser.add_argument("--as-of", type=str, default=date.today().isoformat())
    args = parser.parse_args()
    as_of = date.fromisoformat(args.as_of)
    summary = run_pipeline(args.csv_dir, args.output_dir, as_of)
    print(json.dumps(summary, indent=2, default=str))


if __name__ == "__main__":
    main()
