# Architecture

## Repository layout

- `data/` contains the three supplied workbooks and the assessment PDF.
- `src/normalize_data.py` normalizes workbook columns and dates into a common member schema.
- `sql/01_create_tables.sql` through `sql/06_data_quality.sql` implement the Snowflake landing, staging, transformation, routing, redemption, and validation flow.
- `tests/` verifies date parsing, age calculation, and workbook normalization.

## Processing flow

1. Run `01_create_tables.sql`, create/upload to named stages, then run `02_load_staging.sql` for the daily pipe-delimited member file. The script creates a batch ID and preserves source filename, row number, raw fields, and country.
2. Run `03_transform_members.sql` to parse dates, derive age and `stale_member`, and idempotently populate staging. Invalid values remain null for explicit quality reporting.
3. Run `06_data_quality.sql` and stop routing when error-severity findings exist.
4. Run `04_country_routing.sql` to rank all member history by ingestion time (then business dates as tie-breakers), merge the winning profile into its country's table, and remove it from any previous country target.
5. Upload the partner JSON files to the configured named stage and run `05_redemption_json.sql` to load raw VARIANT records, flatten each `redemptions` array into one transaction per row, and merge by transaction ID.
6. Join profile and redemption data using the globally unique member ID.

## Identity assumption in the provided workbooks

The supplied workbooks reuse `1`, `2`, and `3` for different country datasets and do not provide a global member ID or a feed timestamp. The Python normalizer therefore creates country-prefixed IDs such as `USA:1` and retains `source_member_id`. This prevents unrelated members from being incorrectly collapsed. Production country-move processing in SQL assumes the actual feed supplies a globally unique member ID.

## Scale and reliability

For production volumes, use Snowflake staged files and `COPY INTO`, batch IDs, incremental `MERGE`, and warehouse sizing/concurrency appropriate to the workload. Keep raw records for replay and audit. Quarantine or prevent routing of batches with error-severity quality findings. Cluster only after validating query patterns and measured pruning benefits.

## Running locally

```powershell
python -m pip install -r requirements.txt
python -m src.normalize_data --as-of 2026-11-23 --output normalized_members.csv
python -m pytest -q
```
