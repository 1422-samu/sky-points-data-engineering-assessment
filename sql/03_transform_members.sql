MERGE INTO STAGING_MEMBER_PROFILE t
USING (
    SELECT
        load_batch AS batch_id,
        NULLIF(TRIM(raw_record:member_id::VARCHAR), '') AS member_id,
        NULLIF(TRIM(raw_record:member_name::VARCHAR), '') AS member_name,
        TRY_TO_DATE(raw_record:enrollment_date::VARCHAR, 'YYYYMMDD') AS enrollment_date,
        TRY_TO_DATE(raw_record:last_flight_date::VARCHAR, 'YYYYMMDD') AS last_flight_date,
        NULLIF(TRIM(raw_record:tier_code::VARCHAR), '') AS tier_code,
        NULLIF(TRIM(raw_record:agent_name::VARCHAR), '') AS agent_name,
        NULLIF(TRIM(raw_record:state::VARCHAR), '') AS state,
        CASE UPPER(NULLIF(TRIM(country), ''))
            WHEN 'AUS' THEN 'AU'
            WHEN 'AUSTRALIA' THEN 'AU'
            ELSE UPPER(NULLIF(TRIM(country), ''))
        END AS country,
        TRY_TO_DATE(raw_record:dob::VARCHAR, 'MMDDYYYY') AS dob,
        NULLIF(TRIM(raw_record:is_active::VARCHAR), '') AS is_active,
        source_file,
        source_row_number,
        SHA2(CONCAT_WS('|', load_batch, source_file, source_row_number::VARCHAR), 256) AS unique_key
    FROM RAW_MEMBER_PROFILE
    WHERE load_batch = $LOAD_BATCH
      AND raw_record:record_type::VARCHAR = 'D'
) s
ON t.unique_key = s.unique_key
WHEN NOT MATCHED THEN INSERT (
    batch_id,
    member_id,
    member_name,
    enrollment_date,
    last_flight_date,
    tier_code,
    agent_name,
    state,
    country,
    dob,
    is_active,
    age,
    stale_member,
    source_file,
    source_row_number,
    unique_key
) VALUES (
    s.batch_id,
    s.member_id,
    s.member_name,
    s.enrollment_date,
    s.last_flight_date,
    s.tier_code,
    s.agent_name,
    s.state,
    s.country,
    s.dob,
    s.is_active,
    CASE
        WHEN s.dob IS NULL THEN NULL
        ELSE DATEDIFF(year, s.dob, CURRENT_DATE())
             - IFF(
                 DATEADD(year, DATEDIFF(year, s.dob, CURRENT_DATE()), s.dob) > CURRENT_DATE(),
                 1,
                 0
             )
    END,
    IFF(
        s.last_flight_date IS NULL,
        NULL,
        DATEDIFF(day, s.last_flight_date, CURRENT_DATE()) > 90
    ),
    s.source_file,
    s.source_row_number,
    s.unique_key
);
