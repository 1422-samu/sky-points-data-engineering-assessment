-- Upload daily JSON files to the named stage, then load one raw VARIANT per file.
COPY INTO RAW_REDEMPTION_JSON (batch_id, member_id, feed_date, raw_json)
FROM (
    SELECT
        $LOAD_BATCH,
        $1:member_id::VARCHAR,
        TRY_TO_DATE($1:feed_date::VARCHAR, 'YYYYMMDD'),
        $1
    FROM @REDEMPTION_JSON_STAGE
)
FILE_FORMAT = (TYPE = JSON)
ON_ERROR = 'ABORT_STATEMENT';

CREATE OR REPLACE TEMP TABLE FLAT_REDEMPTIONS AS
SELECT
    r.batch_id,
    r.member_id,
    r.feed_date,
    f.value:txn_id::VARCHAR AS txn_id,
    TRY_TO_DATE(f.value:txn_date::VARCHAR, 'YYYYMMDD') AS txn_date,
    f.value:partner::VARCHAR AS partner,
    TRY_TO_NUMBER(f.value:miles_redeemed::VARCHAR, 38, 0) AS miles_redeemed,
    f.value:status::VARCHAR AS status
FROM RAW_REDEMPTION_JSON r,
LATERAL FLATTEN(INPUT => r.raw_json:redemptions) f;

MERGE INTO REDEMPTION_TRANSACTION t
USING FLAT_REDEMPTIONS s
ON t.txn_id = s.txn_id
WHEN MATCHED THEN UPDATE SET
    batch_id=s.batch_id, member_id=s.member_id, feed_date=s.feed_date,
    txn_date=s.txn_date, partner=s.partner,
    miles_redeemed=s.miles_redeemed, status=s.status
WHEN NOT MATCHED THEN INSERT (
    batch_id,member_id,feed_date,txn_id,txn_date,partner,miles_redeemed,status
) VALUES (
    s.batch_id,s.member_id,s.feed_date,s.txn_id,s.txn_date,s.partner,
    s.miles_redeemed,s.status
);

-- Join to the current member data using the globally unique member_id.
SELECT
    m.member_id,
    m.member_name,
    m.country,
    r.txn_id,
    r.txn_date,
    r.partner,
    r.miles_redeemed,
    r.status
FROM LATEST_MEMBER_PROFILE m
LEFT JOIN REDEMPTION_TRANSACTION r
    ON r.member_id = m.member_id;
