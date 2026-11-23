# Data quality

## Validation rules

`sql/06_data_quality.sql` records batch-level findings for:

- Missing member ID and member name.
- Missing or invalid mandatory enrollment date.
- Unsupported country code.
- Duplicate member IDs within a batch.
- Missing/invalid DOB, reported as a warning because it is optional.
- Stale-member records, reported for review.

The Python normalizer safely parses the source workbooks, normalizes known tier codes, computes age when DOB is valid, and marks a member stale only when a valid flight date is more than 90 days before the selected as-of date. Unparseable optional dates remain null.

## Findings in the provided workbooks

- `AUS.xlsx`: Mike has a `NULL` DOB.
- `AUS.xlsx`: Jonnathan has invalid enrollment date `2021-13-13`.
- `USA.xlsx`: enrollment and flight dates are numeric MMDDYYYY values and require format-aware parsing.
- Each workbook uses IDs 1–3; the values overlap across countries and are not globally unique.
- `USA.xlsx` has no DOB column, so all three DOB values from that workbook are missing.

The data quality SQL operates on the assessment's pipe-delimited production feed. The local Python tests operate on the supplied XLSX workbooks. A failed mandatory-field or duplicate-key rule should prevent the affected batch from being promoted; warning rules should be retained for remediation and audit.
