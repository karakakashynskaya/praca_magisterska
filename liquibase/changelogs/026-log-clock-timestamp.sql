--liquibase formatted sql

--changeset kkakashynskaya:26-log-clock-timestamp context:common
alter table stg.log_table alter column exec_date set default clock_timestamp();
--rollback alter table stg.log_table alter column exec_date set default current_timestamp;
