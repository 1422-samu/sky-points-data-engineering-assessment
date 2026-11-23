# SkyPoints Data Engineering Assessment

End-to-end data engineering solution for the supplied airline loyalty member datasets and redemption-feed specification.

## Run locally

```powershell
python -m pip install -r requirements.txt
python -m src.normalize_data --as-of 2026-11-23 --output normalized_members.csv
python -m pytest -q
```

## Repository structure

```text
data/       Source workbooks and assessment PDF
sql/        Snowflake DDL, loading, transforms, routing, and validations
src/        Python normalization module
tests/      Focused normalization tests
docs/       Architecture and data-quality notes
```

See [docs/architecture.md](docs/architecture.md) and [docs/data_quality.md](docs/data_quality.md) for design decisions, assumptions, and findings.
