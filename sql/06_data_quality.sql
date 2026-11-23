-- Run against the staged batch before routing it to country targets.
INSERT INTO DATA_QUALITY_RESULT
SELECT load_batch, 'member_id_mandatory', 'ERROR', COUNT(*),
       OBJECT_CONSTRUCT('batch_id', load_batch)
FROM RAW_MEMBER_PROFILE
WHERE raw_record:record_type::VARCHAR = 'D'
  AND NULLIF(TRIM(raw_record:member_id::VARCHAR), '') IS NULL
GROUP BY load_batch;

INSERT INTO DATA_QUALITY_RESULT
SELECT load_batch, 'member_name_mandatory', 'ERROR', COUNT(*),
       OBJECT_CONSTRUCT('batch_id', load_batch)
FROM RAW_MEMBER_PROFILE
WHERE raw_record:record_type::VARCHAR = 'D'
  AND NULLIF(TRIM(raw_record:member_name::VARCHAR), '') IS NULL
GROUP BY load_batch;

INSERT INTO DATA_QUALITY_RESULT
SELECT load_batch, 'enrollment_date_valid', 'ERROR', COUNT(*),
       OBJECT_CONSTRUCT('batch_id', load_batch)
FROM RAW_MEMBER_PROFILE
WHERE raw_record:record_type::VARCHAR = 'D'
  AND TRY_TO_DATE(raw_record:enrollment_date::VARCHAR, 'YYYYMMDD') IS NULL
GROUP BY load_batch;

INSERT INTO DATA_QUALITY_RESULT
SELECT load_batch, 'country_supported', 'ERROR', COUNT(*),
       OBJECT_CONSTRUCT('invalid_countries', ARRAY_AGG(DISTINCT country))
FROM RAW_MEMBER_PROFILE
WHERE raw_record:record_type::VARCHAR = 'D'
  AND country NOT IN ('USA', 'IND', 'AU', 'CAN', 'PHIL')
GROUP BY load_batch;

INSERT INTO DATA_QUALITY_RESULT
SELECT load_batch, 'member_id_unique_within_batch', 'ERROR', COUNT(*),
       OBJECT_CONSTRUCT('duplicate_member_ids', ARRAY_AGG(member_id))
FROM (
    SELECT load_batch, raw_record:member_id::VARCHAR AS member_id
    FROM RAW_MEMBER_PROFILE
    WHERE raw_record:record_type::VARCHAR = 'D'
    GROUP BY load_batch, raw_record:member_id::VARCHAR
    HAVING COUNT(*) > 1
)
GROUP BY load_batch;

INSERT INTO DATA_QUALITY_RESULT
SELECT batch_id, 'dob_valid_when_present', 'WARNING', COUNT(*),
       OBJECT_CONSTRUCT('batch_id', batch_id)
FROM STAGING_MEMBER_PROFILE
WHERE dob IS NULL
GROUP BY batch_id;

INSERT INTO DATA_QUALITY_RESULT
SELECT batch_id, 'stale_member_review', 'INFO', COUNT(*),
       OBJECT_CONSTRUCT('batch_id', batch_id)
FROM STAGING_MEMBER_PROFILE
WHERE stale_member = TRUE
GROUP BY batch_id;
