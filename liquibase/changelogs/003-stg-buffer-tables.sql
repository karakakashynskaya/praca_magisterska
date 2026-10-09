--liquibase formatted sql
--changeset kkakashynskaya:3-stg-buffer-tables context:common splitStatements:false

-- ========== ref_country ========== --
-- STG BUFFER --
create table if not exists stg.buffer_ref_country (
    country_code VARCHAR
    , description VARCHAR
);

----- invalid records table -------------------------------------------------------
create table if not exists stg.buffer_ref_country_not_valid (
    country_code VARCHAR
    , description VARCHAR
    , run_id VARCHAR
    , error_description TEXT
);
-----------------------------------------------------------------------------------



-- ========== dim_players ========== --
-- STG BUFFER --
create table if not exists stg.buffer_players (
    id VARCHAR
    , first_name VARCHAR
    , second_name VARCHAR
    , country VARCHAR
    , date_of_birth VARCHAR
    , titles_won VARCHAR
    , is_active VARCHAR
);

create table if not exists stg.buffer_player_physical_details (
    player_id VARCHAR
    , height_cm VARCHAR
    , weight_kg VARCHAR
    , dominant_hand VARCHAR
);

----- invalid records table -------------------------------------------------------
create table if not exists stg.buffer_players_not_valid (
    id VARCHAR
    , first_name VARCHAR
    , second_name VARCHAR
    , country VARCHAR
    , date_of_birth VARCHAR
    , titles_won VARCHAR
    , is_active VARCHAR
    , run_id VARCHAR
    , error_description TEXT
);

create table if not exists stg.buffer_player_physical_details_not_valid (
    player_id VARCHAR
    , height_cm VARCHAR
    , weight_kg VARCHAR
    , dominant_hand VARCHAR
    , run_id VARCHAR
    , error_description TEXT
);
-----------------------------------------------------------------------------------



-- ========== dim_coaches ========== --
-- STG BUFFER --
create table if not exists stg.buffer_coaches (
    id VARCHAR
    , first_name VARCHAR
    , second_name VARCHAR
    , career_start_date VARCHAR
    , career_end_date VARCHAR
);

----- invalid records table -------------------------------------------------------
create table if not exists stg.buffer_coaches_not_valid (
    id VARCHAR
    , first_name VARCHAR
    , second_name VARCHAR
    , career_start_date VARCHAR
    , career_end_date VARCHAR
    , run_id VARCHAR
    , error_description TEXT
);
-----------------------------------------------------------------------------------



-- ========== fct_coaching_contracts ========== --
-- STG BUFFER --
create table if not exists stg.buffer_coaching_contracts (
    id VARCHAR
    , player_id VARCHAR
    , coach_id VARCHAR
    , is_active VARCHAR
);

----- invalid records table -------------------------------------------------------
create table if not exists stg.buffer_coaching_contracts_not_valid (
    id VARCHAR
    , player_id VARCHAR
    , coach_id VARCHAR
    , is_active VARCHAR
    , run_id VARCHAR
    , error_description TEXT
);
-----------------------------------------------------------------------------------



-- ========== dim_tournaments ========== --
-- STG BUFFER --
create table if not exists stg.buffer_tournaments (
    id VARCHAR
    , tournament_name VARCHAR
    , country VARCHAR
    , tournament_level VARCHAR
    , surface VARCHAR
    , tourn_start_date VARCHAR
    , tourn_end_date VARCHAR
);

----- invalid records table -------------------------------------------------------
create table if not exists stg.buffer_tournaments_not_valid (
    id VARCHAR
    , tournament_name VARCHAR
    , country VARCHAR
    , tournament_level VARCHAR
    , surface VARCHAR
    , tourn_start_date VARCHAR
    , tourn_end_date VARCHAR
    , run_id VARCHAR
    , error_description TEXT
);
-----------------------------------------------------------------------------------



-- ========== dim_matches ========== --
-- STG BUFFER --
create table if not exists stg.buffer_matches (
    id VARCHAR
    , tournament_id VARCHAR
    , date_of_match VARCHAR
    , match_round VARCHAR
    , player1_id VARCHAR
    , player2_id VARCHAR
    , winner_id VARCHAR
    , first_set_score VARCHAR
    , second_set_score VARCHAR
    , third_set_score VARCHAR
    , final_score VARCHAR
    , match_duration VARCHAR
);

----- invalid records table -------------------------------------------------------
create table if not exists stg.buffer_matches_not_valid (
    id VARCHAR
    , tournament_id VARCHAR
    , date_of_match VARCHAR
    , match_round VARCHAR
    , player1_id VARCHAR
    , player2_id VARCHAR
    , winner_id VARCHAR
    , first_set_score VARCHAR
    , second_set_score VARCHAR
    , third_set_score VARCHAR
    , final_score VARCHAR
    , match_duration VARCHAR
    , run_id VARCHAR
    , error_description TEXT
);
-----------------------------------------------------------------------------------



-- ========== fct_match_statistics ========== --
-- STG BUFFER --
create table if not exists stg.buffer_match_statistics (
    match_id VARCHAR
    , player_id VARCHAR
    , aces VARCHAR
    , double_faults VARCHAR
    , break_points_converted_perc VARCHAR
);

----- invalid records table -------------------------------------------------------
create table if not exists stg.buffer_match_statistics_not_valid (
    match_id VARCHAR
    , player_id VARCHAR
    , aces VARCHAR
    , double_faults VARCHAR
    , break_points_converted_perc VARCHAR
    , run_id VARCHAR
    , error_description TEXT
);
-----------------------------------------------------------------------------------


--rollback DROP TABLE IF EXISTS stg.buffer_match_statistics_not_valid;
--rollback DROP TABLE IF EXISTS stg.buffer_match_statistics;
--rollback DROP TABLE IF EXISTS stg.buffer_matches_not_valid;
--rollback DROP TABLE IF EXISTS stg.buffer_matches;
--rollback DROP TABLE IF EXISTS stg.buffer_tournaments_not_valid;
--rollback DROP TABLE IF EXISTS stg.buffer_tournaments;
--rollback DROP TABLE IF EXISTS stg.buffer_coaching_contracts_not_valid;
--rollback DROP TABLE IF EXISTS stg.buffer_coaching_contracts;
--rollback DROP TABLE IF EXISTS stg.buffer_coaches_not_valid;
--rollback DROP TABLE IF EXISTS stg.buffer_coaches;
--rollback DROP TABLE IF EXISTS stg.buffer_player_physical_details_not_valid;
--rollback DROP TABLE IF EXISTS stg.buffer_players_not_valid;
--rollback DROP TABLE IF EXISTS stg.buffer_player_physical_details;
--rollback DROP TABLE IF EXISTS stg.buffer_players;
--rollback DROP TABLE IF EXISTS stg.buffer_ref_country_not_valid;
--rollback DROP TABLE IF EXISTS stg.buffer_ref_country;
