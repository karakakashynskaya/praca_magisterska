--liquibase formatted sql

--changeset kkakashynskaya:2-create-log-table context:common
CREATE TABLE IF NOT EXISTS stg.log_table (
    id SERIAL PRIMARY KEY,
    run_id VARCHAR(100),
    exec_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    object_name VARCHAR(200),
    records_count INT,
    message TEXT
);
--rollback DROP TABLE IF EXISTS stg.log_table;
