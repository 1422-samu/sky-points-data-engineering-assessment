CREATE DATABASE IF NOT EXISTS SKYPOINTS;
CREATE SCHEMA IF NOT EXISTS SKYPOINTS.MEMBER_PLATFORM;
USE SCHEMA SKYPOINTS.MEMBER_PLATFORM;

CREATE TABLE IF NOT EXISTS RAW_MEMBER_PROFILE (
    source_file VARCHAR NOT NULL,
    source_row_number NUMBER,
    raw_record VARIANT,
    country VARCHAR,
    load_batch VARCHAR,
    ingested_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE TABLE IF NOT EXISTS STAGING_MEMBER_PROFILE (
    batch_id VARCHAR NOT NULL,
    member_id VARCHAR,
    member_name VARCHAR,
    enrollment_date DATE,
    last_flight_date DATE,
    tier_code VARCHAR,
    agent_name VARCHAR,
    state VARCHAR,
    country VARCHAR,
    postal_code NUMBER(5,0),
    dob DATE,
    is_active VARCHAR,
    age NUMBER(3,0),
    stale_member BOOLEAN,
    source_file VARCHAR NOT NULL,
    source_row_number NUMBER,
    loaded_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(),
    unique_key VARCHAR
);

CREATE TABLE IF NOT EXISTS TARGET_INDIA LIKE STAGING_MEMBER_PROFILE;
CREATE TABLE IF NOT EXISTS TARGET_USA LIKE STAGING_MEMBER_PROFILE;
CREATE TABLE IF NOT EXISTS TARGET_AUSTRALIA LIKE STAGING_MEMBER_PROFILE;

CREATE TABLE IF NOT EXISTS RAW_REDEMPTION_JSON (
    batch_id VARCHAR NOT NULL,
    member_id VARCHAR,
    feed_date DATE,
    raw_json VARIANT NOT NULL,
    ingested_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE TABLE IF NOT EXISTS REDEMPTION_TRANSACTION (
    batch_id VARCHAR NOT NULL,
    member_id VARCHAR NOT NULL,
    feed_date DATE,
    txn_id VARCHAR NOT NULL,
    txn_date DATE,
    partner VARCHAR,
    miles_redeemed NUMBER(38,0),
    status VARCHAR,
    ingested_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE TABLE IF NOT EXISTS DATA_QUALITY_RESULT (
    batch_id VARCHAR NOT NULL,
    rule_name VARCHAR NOT NULL,
    severity VARCHAR NOT NULL,
    failed_row_count NUMBER,
    details VARIANT,
    checked_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Snowflake standard-table primary/unique constraints are informational.
-- Enforce uniqueness in 06_data_quality.sql and in idempotent MERGE operations.
