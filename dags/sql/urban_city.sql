CREATE SCHEMA IF NOT EXISTS gold;

CREATE TABLE IF NOT EXISTS gold.urban_city_requests (
    created_date TIMESTAMP,
    closed_date TIMESTAMP,
    problem TEXT,
    problem_detail TEXT,
    location_type VARCHAR(100),
    incident_address TEXT,
    city VARCHAR(100),
    borough VARCHAR(100),
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION
);