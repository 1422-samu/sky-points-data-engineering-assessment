-- Use the globally unique member_id in the production feed. This ranking uses all
-- staged history so a later country change removes the member from the old target.
CREATE OR REPLACE TEMP TABLE LATEST_MEMBER_PROFILE AS
SELECT * EXCLUDE (record_rank)
FROM (
    SELECT
        s.*,
        ROW_NUMBER() OVER (
            PARTITION BY member_id
            ORDER BY
                loaded_at DESC,
                COALESCE(last_flight_date, '1900-01-01'::DATE) DESC,
                COALESCE(enrollment_date, '1900-01-01'::DATE) DESC,
                source_file DESC,
                source_row_number DESC
        ) AS record_rank
    FROM STAGING_MEMBER_PROFILE s
    WHERE member_id IS NOT NULL
)
WHERE record_rank = 1;

BEGIN TRANSACTION;

DELETE FROM TARGET_INDIA t
WHERE EXISTS (
    SELECT 1 FROM LATEST_MEMBER_PROFILE l
    WHERE l.member_id = t.member_id AND l.country <> 'IND'
);
DELETE FROM TARGET_USA t
WHERE EXISTS (
    SELECT 1 FROM LATEST_MEMBER_PROFILE l
    WHERE l.member_id = t.member_id AND l.country <> 'USA'
);
DELETE FROM TARGET_AUSTRALIA t
WHERE EXISTS (
    SELECT 1 FROM LATEST_MEMBER_PROFILE l
    WHERE l.member_id = t.member_id AND l.country <> 'AU'
);

MERGE INTO TARGET_INDIA t
USING (SELECT * FROM LATEST_MEMBER_PROFILE WHERE country = 'IND') s
ON t.member_id = s.member_id
WHEN MATCHED THEN UPDATE SET
    batch_id=s.batch_id, member_name=s.member_name, enrollment_date=s.enrollment_date,
    last_flight_date=s.last_flight_date, tier_code=s.tier_code, agent_name=s.agent_name,
    state=s.state, country=s.country, dob=s.dob, is_active=s.is_active, age=s.age,
    stale_member=s.stale_member, source_file=s.source_file,
    source_row_number=s.source_row_number, loaded_at=s.loaded_at, unique_key=s.unique_key
WHEN NOT MATCHED THEN INSERT (
    batch_id,member_id,member_name,enrollment_date,last_flight_date,tier_code,agent_name,
    state,country,dob,is_active,age,stale_member,source_file,source_row_number,loaded_at,unique_key
) VALUES (
    s.batch_id,s.member_id,s.member_name,s.enrollment_date,s.last_flight_date,s.tier_code,
    s.agent_name,s.state,s.country,s.dob,s.is_active,s.age,s.stale_member,s.source_file,
    s.source_row_number,s.loaded_at,s.unique_key
);

MERGE INTO TARGET_USA t
USING (SELECT * FROM LATEST_MEMBER_PROFILE WHERE country = 'USA') s
ON t.member_id = s.member_id
WHEN MATCHED THEN UPDATE SET
    batch_id=s.batch_id, member_name=s.member_name, enrollment_date=s.enrollment_date,
    last_flight_date=s.last_flight_date, tier_code=s.tier_code, agent_name=s.agent_name,
    state=s.state, country=s.country, dob=s.dob, is_active=s.is_active, age=s.age,
    stale_member=s.stale_member, source_file=s.source_file,
    source_row_number=s.source_row_number, loaded_at=s.loaded_at, unique_key=s.unique_key
WHEN NOT MATCHED THEN INSERT (
    batch_id,member_id,member_name,enrollment_date,last_flight_date,tier_code,agent_name,
    state,country,dob,is_active,age,stale_member,source_file,source_row_number,loaded_at,unique_key
) VALUES (
    s.batch_id,s.member_id,s.member_name,s.enrollment_date,s.last_flight_date,s.tier_code,
    s.agent_name,s.state,s.country,s.dob,s.is_active,s.age,s.stale_member,s.source_file,
    s.source_row_number,s.loaded_at,s.unique_key
);

MERGE INTO TARGET_AUSTRALIA t
USING (SELECT * FROM LATEST_MEMBER_PROFILE WHERE country = 'AU') s
ON t.member_id = s.member_id
WHEN MATCHED THEN UPDATE SET
    batch_id=s.batch_id, member_name=s.member_name, enrollment_date=s.enrollment_date,
    last_flight_date=s.last_flight_date, tier_code=s.tier_code, agent_name=s.agent_name,
    state=s.state, country=s.country, dob=s.dob, is_active=s.is_active, age=s.age,
    stale_member=s.stale_member, source_file=s.source_file,
    source_row_number=s.source_row_number, loaded_at=s.loaded_at, unique_key=s.unique_key
WHEN NOT MATCHED THEN INSERT (
    batch_id,member_id,member_name,enrollment_date,last_flight_date,tier_code,agent_name,
    state,country,dob,is_active,age,stale_member,source_file,source_row_number,loaded_at,unique_key
) VALUES (
    s.batch_id,s.member_id,s.member_name,s.enrollment_date,s.last_flight_date,s.tier_code,
    s.agent_name,s.state,s.country,s.dob,s.is_active,s.age,s.stale_member,s.source_file,
    s.source_row_number,s.loaded_at,s.unique_key
);

COMMIT;
