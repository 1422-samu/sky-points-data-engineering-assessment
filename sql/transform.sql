-- Route members after latest-record wins across all countries.
-- Ranking rule: last flight, enrollment date, and ingested timestamp.

CREATE OR REPLACE TEMP TABLE _LATEST_MEMBERS AS
SELECT * FROM (
    SELECT s.*,
           ROW_NUMBER() OVER (
               PARTITION BY member_id
               ORDER BY COALESCE(last_flight_date, '1900-01-01'::DATE) DESC,
                        COALESCE(enrollment_date, '1900-01-01'::DATE) DESC,
                        loaded_at DESC
           ) AS rn
    FROM STAGING_MEMBER_PROFILE s
) WHERE rn = 1;

-- Remove a member from all targets if latest country is another country.
DELETE FROM TARGET_INDIA t
WHERE EXISTS (
    SELECT 1 FROM _LATEST_MEMBERS l
    WHERE l.member_id=t.member_id AND l.country <> 'IND'
);
DELETE FROM TARGET_USA t
WHERE EXISTS (
    SELECT 1 FROM _LATEST_MEMBERS l
    WHERE l.member_id=t.member_id AND l.country <> 'USA'
);
DELETE FROM TARGET_AUSTRALIA t
WHERE EXISTS (
    SELECT 1 FROM _LATEST_MEMBERS l
    WHERE l.member_id=t.member_id AND l.country <> 'AU'
);

MERGE INTO TARGET_INDIA t USING (
    SELECT * FROM _LATEST_MEMBERS WHERE country='IND'
) s ON t.member_id=s.member_id
WHEN MATCHED THEN UPDATE SET
    member_name=s.member_name, enrollment_date=s.enrollment_date,
    last_flight_date=s.last_flight_date, tier_code=s.tier_code,
    agent_name=s.agent_name, state=s.state, country=s.country,
    dob=s.dob, is_active=s.is_active,
    individual_or_corporate=s.individual_or_corporate, age=s.age,
    stale_member=s.stale_member, source_file=s.source_file,
    source_row_number=s.source_row_number, loaded_at=s.loaded_at,
    unique_key=s.unique_key
WHEN NOT MATCHED THEN INSERT (
    batch_id,member_id,member_name,enrollment_date,last_flight_date,tier_code,
    agent_name,state,country,dob,is_active,individual_or_corporate,age,
    stale_member,source_file,source_row_number,loaded_at,unique_key
) VALUES (
    s.batch_id,s.member_id,s.member_name,s.enrollment_date,s.last_flight_date,s.tier_code,
    s.agent_name,s.state,s.country,s.dob,s.is_active,s.individual_or_corporate,s.age,
    s.stale_member,s.source_file,s.source_row_number,s.loaded_at,s.unique_key
);

MERGE INTO TARGET_USA t USING (
    SELECT * FROM _LATEST_MEMBERS WHERE country='USA'
) s ON t.member_id=s.member_id
WHEN MATCHED THEN UPDATE SET
    member_name=s.member_name, enrollment_date=s.enrollment_date,
    last_flight_date=s.last_flight_date, tier_code=s.tier_code,
    agent_name=s.agent_name, state=s.state, country=s.country,
    dob=s.dob, is_active=s.is_active,
    individual_or_corporate=s.individual_or_corporate, age=s.age,
    stale_member=s.stale_member, source_file=s.source_file,
    source_row_number=s.source_row_number, loaded_at=s.loaded_at,
    unique_key=s.unique_key
WHEN NOT MATCHED THEN INSERT (
    batch_id,member_id,member_name,enrollment_date,last_flight_date,tier_code,
    agent_name,state,country,dob,is_active,individual_or_corporate,age,
    stale_member,source_file,source_row_number,loaded_at,unique_key
) VALUES (
    s.batch_id,s.member_id,s.member_name,s.enrollment_date,s.last_flight_date,s.tier_code,
    s.agent_name,s.state,s.country,s.dob,s.is_active,s.individual_or_corporate,s.age,
    s.stale_member,s.source_file,s.source_row_number,s.loaded_at,s.unique_key
);

MERGE INTO TARGET_AUSTRALIA t USING (
    SELECT * FROM _LATEST_MEMBERS WHERE country='AU'
) s ON t.member_id=s.member_id
WHEN MATCHED THEN UPDATE SET
    member_name=s.member_name, enrollment_date=s.enrollment_date,
    last_flight_date=s.last_flight_date, tier_code=s.tier_code,
    agent_name=s.agent_name, state=s.state, country=s.country,
    dob=s.dob, is_active=s.is_active,
    individual_or_corporate=s.individual_or_corporate, age=s.age,
    stale_member=s.stale_member, source_file=s.source_file,
    source_row_number=s.source_row_number, loaded_at=s.loaded_at,
    unique_key=s.unique_key
WHEN NOT MATCHED THEN INSERT (
    batch_id,member_id,member_name,enrollment_date,last_flight_date,tier_code,
    agent_name,state,country,dob,is_active,individual_or_corporate,age,
    stale_member,source_file,source_row_number,loaded_at,unique_key
) VALUES (
    s.batch_id,s.member_id,s.member_name,s.enrollment_date,s.last_flight_date,s.tier_code,
    s.agent_name,s.state,s.country,s.dob,s.is_active,s.individual_or_corporate,s.age,
    s.stale_member,s.source_file,s.source_row_number,s.loaded_at,s.unique_key
);
