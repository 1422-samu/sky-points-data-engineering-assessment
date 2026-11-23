# SkyPoints Data Engineering Assessment — Solution

## 1. Completed deliverables

- Snowflake landing, staging, target, redemption, and data-quality DDL: [`sql/ddl.sql`](../sql/ddl.sql)
- Country routing and latest-record-wins transformation: [`sql/transform.sql`](../sql/transform.sql)
- Semi-structured JSON flattening and profile joins: [`sql/redemptions.sql`](../sql/redemptions.sql)
- Snowflake validation rules: [`sql/validations.sql`](../sql/validations.sql)
- Executable source-to-target Python pipeline: [`python/sky_points_pipeline.py`](../python/sky_points_pipeline.py)
- Unit and end-to-end tests: [`tests/test_sky_points_pipeline.py`](../tests/test_sky_points_pipeline.py)
- Generated pipeline results: [`output/`](../output)

## 2. Data processed

The source folder contains three Excel workbooks: `USA.xlsx`, `IND.xlsx`, and `AUS.xlsx`. Although the workbook names differ from the assessment wording, they contain the supplied source member records. The pipeline reads all 9 source rows and adds country context from the filename.

The PDF describes a pipe-delimited feed and a JSON redemption feed. No separate flat-file or JSON source file was supplied; the sample redemption object in the PDF is therefore reproduced by the pipeline in `redemption_transactions.csv`.

## 3. Transform rules

- Normalize USA, India, and Australia country codes to `USA`, `IND`, and `AU`.
- Parse Excel/native dates and numeric USA dates such as `6152022` as `2022-06-15`.
- Compute `age` from DOB for the selected `--as-of` date.
- Set `stale_member=true` when the last flight is more than 90 days before the as-of date.
- Rank records for the same country and `member_id` by latest flight date, then enrollment date, then source row order.
- The supplied workbooks use country-local IDs (`1`, `2`, `3` in each file). Therefore, the demo pipeline keys them as `(country, member_id)` to avoid falsely deduplicating nine distinct source rows. In a real feed, when `member_id` is the global loyalty key, use the Snowflake `PARTITION BY member_id` implementation to support country moves.
- Write the winner to exactly one country target.
- Retain source file and source row metadata for traceability.
- Flatten redemption records to one transaction per row.

## 4. Latest-record-wins design

Python ranks `(country, member_id)` for the country-local sample IDs. The production-oriented Snowflake implementation creates `_LATEST_MEMBERS` with `ROW_NUMBER()` partitioned by global `member_id`, ordered by:

1. Last flight date descending
2. Enrollment date descending
3. Loaded timestamp descending

A member is removed from an old target if the latest country is different. This prevents stale country records from remaining after a move.

## 5. JSON joining

The JSON object has a member-level key plus a `redemptions` array. Snowflake flattening uses `LATERAL FLATTEN` and exposes `txn_id`, `txn_date`, `partner`, `miles_redeemed`, and `status`. Join back to profile data using `member_id`, while `txn_id` is the transaction key.

For a real feed, use incremental batch IDs and add transaction de-duplication or merge keys. Use partitioning/clustering on member, feed date, transaction date, and batch ID for scale.

## 6. Validations

The pipeline and SQL include:

- Mandatory `member_id`
- Mandatory `member_name`
- Mandatory `enrollment_date`
- Member ID duplicate checks
- Known/normalized country checks
- Tier-code validation
- DOB and last-flight parseability
- Stale-member reporting

The supplied data also contains intentional quality issues:

- AUS Mike has DOB `NULL`
- AUS Jonnathan has the invalid enrollment date `2021-13-13`
- USA dates are stored as numeric values rather than dates
- Source IDs are reused only in a sample-like sense; the workbooks do not include a cross-country feed timestamp

Invalid values are preserved as null/invalid exceptions, logged in `data_quality_results.csv`, and not silently coerced to false dates.

## 7. Scale strategy

- Load raw data unchanged into Snowflake landing tables as VARIANT.
- Stage with idempotent batch IDs and source row metadata.
- Upsert by member ID and transaction ID.
- Use MERGE, clustering, micro-partition pruning, and per-country parallel loads.
- Use file staging and COPY INTO for billions of flat-file records.
- Use Snowflake VARIANT plus LATERAL FLATTEN for the JSON array.
- Partition orchestration in batches and reject/quarantine bad rows rather than failing all data.

## 8. Running locally

```powershell
.venv\Scripts\python.exe python\sky_points_pipeline.py
.venv\Scripts\python.exe -m pytest tests -q
```

Optional as-of date:

```powershell
.venv\Scripts\python.exe python\sky_points_pipeline.py --as-of 2024-12-31
```
