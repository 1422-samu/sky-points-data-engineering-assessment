-- Create a named stage and upload the delimited source file before running this script.
-- Run this script in the same Snowflake session as the downstream scripts.
SET LOAD_BATCH = UUID_STRING();

-- Expected record shape: |D|Name|Member_Id|Enrollment_Date|Last_Flight_Date|
--                        Tier_Code|Agent_Name|State|Country|DOB|Is_Active
-- (the assessment's source layout does not include Post Code).
CREATE FILE FORMAT IF NOT EXISTS MEMBER_PROFILE_PIPE_FORMAT
    TYPE = CSV
    FIELD_DELIMITER = '|'
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    NULL_IF = ('', 'NULL')
    EMPTY_FIELD_AS_NULL = TRUE;

-- Replace @MEMBER_PROFILE_STAGE with the actual named stage.
COPY INTO RAW_MEMBER_PROFILE (
    source_file,
    source_row_number,
    raw_record,
    country,
    load_batch
)
FROM (
    SELECT
        METADATA$FILENAME,
        METADATA$FILE_ROW_NUMBER,
        OBJECT_CONSTRUCT_KEEP_NULL(
            'record_type', $2::VARCHAR,
            'member_name', $3::VARCHAR,
            'member_id', $4::VARCHAR,
            'enrollment_date', $5::VARCHAR,
            'last_flight_date', $6::VARCHAR,
            'tier_code', $7::VARCHAR,
            'agent_name', $8::VARCHAR,
            'state', $9::VARCHAR,
            'country', $10::VARCHAR,
            'dob', $11::VARCHAR,
            'is_active', $12::VARCHAR
        ),
        UPPER($10::VARCHAR),
        $LOAD_BATCH
    FROM @MEMBER_PROFILE_STAGE
)
FILE_FORMAT = (FORMAT_NAME = MEMBER_PROFILE_PIPE_FORMAT)
ON_ERROR = 'ABORT_STATEMENT';

-- Landing-to-staging parsing, derived columns, and quarantine checks are in
-- 03_transform_members.sql and 06_data_quality.sql.
