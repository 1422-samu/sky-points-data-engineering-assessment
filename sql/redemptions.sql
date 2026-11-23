-- Flatten the partner-airline redemption JSON feed.
CREATE OR REPLACE TEMP TABLE _FLAT_REDEMPTIONS AS
SELECT
    r.batch_id,
    r.member_id,
    r.feed_date,
    t.value:txn_id::VARCHAR AS txn_id,
    TRY_TO_DATE(t.value:txn_date::VARCHAR, 'YYYYMMDD') AS txn_date,
    t.value:partner::VARCHAR AS partner,
    t.value:miles_redeemed::NUMBER(38,0) AS miles_redeemed,
    t.value:status::VARCHAR AS status
FROM RAW_REDEMPTION_JSON r,
LATERAL FLATTEN(input => r.raw_json:redemptions) t;

MERGE INTO REDEMPTION_TRANSACTION dst
USING _FLAT_REDEMPTIONS src
ON dst.txn_id = src.txn_id
WHEN MATCHED THEN UPDATE SET
    batch_id=src.batch_id, member_id=src.member_id, feed_date=src.feed_date,
    txn_date=src.txn_date, partner=src.partner,
    miles_redeemed=src.miles_redeemed, status=src.status
WHEN NOT MATCHED THEN INSERT (
    batch_id,member_id,feed_date,txn_id,txn_date,partner,miles_redeemed,status
) VALUES (
    src.batch_id,src.member_id,src.feed_date,src.txn_id,src.txn_date,
    src.partner,src.miles_redeemed,src.status
);

-- Profile-to-redemption join
SELECT p.member_id, p.member_name, p.country,
       r.txn_id, r.txn_date, r.partner, r.miles_redeemed, r.status
FROM STAGING_MEMBER_PROFILE p
LEFT JOIN REDEMPTION_TRANSACTION r ON r.member_id=p.member_id;
