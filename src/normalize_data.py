from __future__ import annotations

import argparse
import csv
import json
from datetime import date, datetime
from pathlib import Path
from typing import Any

import openpyxl

COUNTRY_BY_FILENAME = {
    "AUS.XLSX": "AU",
    "IND.XLSX": "IND",
    "USA.XLSX": "USA",
}
VALID_TIERS = {"SLV", "GLD", "PLT"}
OUTPUT_FIELDS = (
    "member_id",
    "source_member_id",
    "member_name",
    "country",
    "tier_code",
    "dob",
    "enrollment_date",
    "last_flight_date",
    "age",
    "stale_member",
    "individual_or_corporate",
    "source_file",
    "source_row_number",
)


def parse_date(value: Any) -> date | None:
    """Parse workbook date values, including the USA workbook's numeric MMDDYYYY values."""
    if value is None:
        return None
    if isinstance(value, datetime):
        return value.date()
    if isinstance(value, date):
        return value

    text = str(value).strip()
    if not text or text.upper() in {"NULL", "N/A", "NONE"}:
        return None

    if text.isdigit() and len(text) in {7, 8}:
        if len(text) == 7:
            text = text.zfill(8)
        numeric_formats = (
            ("%Y%m%d", "%m%d%Y")
            if len(text) == 8 and text.startswith(("19", "20"))
            else ("%m%d%Y",)
        )
        for fmt in numeric_formats:
            try:
                return datetime.strptime(text, fmt).date()
            except ValueError:
                continue

    formats = ["%Y-%m-%d", "%m-%d-%Y", "%m/%d/%Y"]
    for fmt in formats:
        try:
            return datetime.strptime(text, fmt).date()
        except ValueError:
            continue
    return None


def calculate_age(dob: date | None, as_of: date) -> int | None:
    if dob is None:
        return None
    return as_of.year - dob.year - ((as_of.month, as_of.day) < (dob.month, dob.day))


def _column_value(row: dict[str, Any], *names: str) -> Any:
    normalized = {key.lower().replace(" ", ""): value for key, value in row.items()}
    for name in names:
        value = normalized.get(name.lower().replace(" ", ""))
        if value is not None and str(value).strip():
            return value
    return None


def normalize_workbook(path: Path, as_of: date | None = None) -> list[dict[str, Any]]:
    """Read one provided workbook and normalize its rows to the common member schema."""
    country = COUNTRY_BY_FILENAME.get(path.name.upper())
    if country is None:
        raise ValueError(f"Unsupported source workbook: {path.name}")

    reference_date = as_of or date.today()
    workbook = openpyxl.load_workbook(path, read_only=True, data_only=True)
    try:
        sheet_name = "in" if "in" in workbook.sheetnames else workbook.sheetnames[0]
        sheet = workbook[sheet_name]
        values = sheet.iter_rows(values_only=True)
        headers = next(values, None)
        if headers is None:
            return []
        header_names = [str(value).strip() if value is not None else "" for value in headers]

        normalized_rows = []
        for row_number, values_row in enumerate(values, start=2):
            source = dict(zip(header_names, values_row))
            source_id = _column_value(source, "Unique ID", "ID")
            name = _column_value(source, "Member Name", "Name")
            tier_value = _column_value(source, "Tier Type", "TierCode")
            tier = str(tier_value).strip().upper() if tier_value is not None else None
            tier = tier if tier in VALID_TIERS else None

            dob = parse_date(_column_value(source, "Date of Birth", "DOB"))
            enrollment_date = parse_date(
                _column_value(source, "Date of Enrollment", "EnrollmentDate")
            )
            flight_date = parse_date(
                _column_value(source, "Date of Flight", "Flight Date", "FlightDate")
            )
            normalized_rows.append(
                {
                    # The supplied workbooks reuse IDs across countries; preserve them safely.
                    "member_id": f"{country}:{source_id}" if source_id is not None else None,
                    "source_member_id": str(source_id).strip() if source_id is not None else None,
                    "member_name": str(name).strip() if name is not None else None,
                    "country": country,
                    "tier_code": tier,
                    "dob": dob.isoformat() if dob else None,
                    "enrollment_date": enrollment_date.isoformat() if enrollment_date else None,
                    "last_flight_date": flight_date.isoformat() if flight_date else None,
                    "age": calculate_age(dob, reference_date),
                    "stale_member": (
                        (reference_date - flight_date).days > 90 if flight_date else None
                    ),
                    "individual_or_corporate": _column_value(
                        source, "Individual or Corporate"
                    ),
                    "source_file": path.name,
                    "source_row_number": row_number,
                }
            )
        return normalized_rows
    finally:
        workbook.close()


def normalize_workbooks(data_dir: Path, as_of: date | None = None) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    for filename in ("USA.xlsx", "IND.xlsx", "AUS.xlsx"):
        source = data_dir / filename
        if not source.is_file():
            raise FileNotFoundError(f"Required source workbook not found: {source}")
        records.extend(normalize_workbook(source, as_of))
    return records


def write_csv(records: list[dict[str, Any]], output_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", newline="", encoding="utf-8") as output_file:
        writer = csv.DictWriter(output_file, fieldnames=OUTPUT_FIELDS)
        writer.writeheader()
        writer.writerows(records)


def main() -> None:
    parser = argparse.ArgumentParser(description="Normalize the supplied SkyPoints workbooks.")
    parser.add_argument(
        "--data-dir",
        type=Path,
        default=Path(__file__).parents[1] / "data",
    )
    parser.add_argument("--as-of", type=date.fromisoformat, default=date.today())
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()

    records = normalize_workbooks(args.data_dir, args.as_of)
    if args.output:
        write_csv(records, args.output)
        print(f"Wrote {len(records)} normalized member rows to {args.output}")
    else:
        print(json.dumps(records, indent=2))


if __name__ == "__main__":
    main()
