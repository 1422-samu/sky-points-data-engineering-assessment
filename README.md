# SkyPoints Data Engineering Assessment

Completed end-to-end solution for the supplied member profile workbooks and redemption-feed specification.

## Run

```powershell
.venv\Scripts\python.exe python\sky_points_pipeline.py
.venv\Scripts\python.exe -m pytest tests -q
```

## Deliverables

- `sql/` — Snowflake DDL, latest-record routing, redemption flattening, and validations
- `python/` — executable workbook/profile pipeline
- `output/` — generated staging, target, redemption, and quality-control results
- `tests/` — unit and end-to-end tests
- `docs/SOLUTION.md` — implementation and architecture documentation

See [the solution documentation](docs/SOLUTION.md) for assumptions, data-quality findings, join design, and scaling guidance.
