--liquibase formatted sql
--changeset kkakashynskaya:4-stg-raw-tables context:common splitStatements:false

-- ========== ref_country ========== --
-- STG RAW --
create table if not exists stg.raw_ref_country (
    country_sk CHAR(32) not null
    , country_code_bk CHAR(3) not null
    , country_name VARCHAR(50) not null
    , rec_src VARCHAR(50) not null
    , load_dt TIMESTAMP not null
);



-- ========== dim_players ========== --
-- STG RAW --
create table if not exists stg.raw_players (
    player_sk CHAR(32) not null
    , player_bk VARCHAR(100) not null
    , first_name VARCHAR(50) not null
    , second_name VARCHAR(100) not null
    , country CHAR(3)
    , date_of_birth DATE not null
    , titles_won SMALLINT
    , is_active BOOLEAN
    , sat_player_date_of_birth_hash_key CHAR(32) not null
    , sat_player_personal_info_hash_key CHAR(32) not null
    , rec_src VARCHAR(50) not null
    , load_dt TIMESTAMP not null
    , hash_diff CHAR(32) not null
);

create table if not exists stg.raw_player_physical_details (
    player_sk CHAR(32) not null
    , player_bk VARCHAR(100) not null
    , height_cm SMALLINT
    , weight_kg SMALLINT
    , dominant_hand VARCHAR(50)
    , sat_player_physical_details_hash_key CHAR(32) not null
    , rec_src VARCHAR(50) not null
    , load_dt TIMESTAMP not null
    , hash_diff CHAR(32) not null
);



-- ========== dim_coaches ========== --
-- STG RAW --
create table if not exists stg.raw_coaches (
    coach_sk CHAR(32) not null
    , coach_bk VARCHAR(100) not null
    , first_name VARCHAR(50) not null
    , second_name VARCHAR(100) not null
    , career_start_date DATE
    , career_end_date DATE
    , sat_coach_personal_info_hash_key CHAR(32) not null
    , rec_src VARCHAR(50) not null
    , load_dt TIMESTAMP not null
    , hash_diff CHAR(32) not null
);



-- ========== fct_coaching_contracts ========== --
-- STG RAW --
create table if not exists stg.raw_coaching_contracts (
    coaching_contract_sk CHAR(32) not null
    , player_sk CHAR(32) not null
    , player_bk VARCHAR(100) not null
    , coach_sk CHAR(32) not null
    , coach_bk VARCHAR(100) not null
    , is_active BOOLEAN not null
    , sat_coaching_contract_details_hash_key CHAR(32) not null
    , rec_src VARCHAR(50) not null
    , load_dt TIMESTAMP not null
    , hash_diff CHAR(32) not null
);



-- ========== dim_tournaments ========== --
-- STG RAW --
create table if not exists stg.raw_tournaments (
    tournament_sk CHAR(32) not null
    , tournament_bk VARCHAR(100) not null
    , tournament_name VARCHAR(75) not null
    , country VARCHAR(50) not null
    , tournament_level VARCHAR(25) not null
    , surface VARCHAR(20)
    , tourn_start_date DATE not null
    , tourn_end_date DATE not null
    , sat_tournament_details_hash_key CHAR(32) not null
    , rec_src VARCHAR(50) not null
    , load_dt TIMESTAMP not null
    , hash_diff CHAR(32) not null
);



-- ========== dim_matches ========== --
-- STG RAW --
create table if not exists stg.raw_matches (
    match_sk CHAR(32) not null
    , match_bk VARCHAR(100) not null
    , tournament_sk CHAR(32) not null
    , tournament_bk VARCHAR(100) not null
    , date_of_match DATE not null
    , match_round VARCHAR(5) not null
    , player1_sk CHAR(32) not null
    , player1_bk VARCHAR(100) not null
    , player2_sk CHAR(32) not null
    , player2_bk VARCHAR(100) not null
    , winner_sk CHAR(32) not null
    , winner_bk VARCHAR(100) not null
    , first_set_score VARCHAR(11) not null
    , second_set_score VARCHAR(11) not null
    , third_set_score VARCHAR(11)
    , final_score CHAR(3) not null
    , match_duration TIME
    , match_tournament_sk CHAR(32) not null
    , match_player1_sk CHAR(32) not null
    , match_player2_sk CHAR(32) not null
    , player1_first_set_score INT not null
    , player2_first_set_score INT not null
    , player1_second_set_score INT not null
    , player2_second_set_score INT not null
    , player1_third_set_score INT
    , player2_third_set_score INT
    , player1_final_score INT not null
    , player2_final_score INT not null
    , sat_match_details_hash_key CHAR(32) not null
    , sat_match_player1_result_hash_key CHAR(32) not null
    , sat_match_player2_result_hash_key CHAR(32) not null
    , rec_src VARCHAR(50) not null
    , load_dt TIMESTAMP not null
    , hash_diff CHAR(32) not null
);



-- ========== fct_match_statistics ========== --
-- STG RAW --
create table if not exists stg.raw_match_statistics (
    match_statistics_sk CHAR(32) not null
    , match_sk CHAR(32) not null
    , match_bk VARCHAR(100) not null
    , player_sk CHAR(32) not null
    , player_bk VARCHAR(100) not null
    , aces SMALLINT default 0
    , double_faults SMALLINT default 0
    , break_points_converted_perc decimal(4,3) default 0
    , sat_match_statistics_details_hash_key CHAR(32) not null
    , rec_src VARCHAR(50) not null
    , load_dt TIMESTAMP not null
    , hash_diff CHAR(32) not null
);


--rollback DROP TABLE IF EXISTS stg.raw_match_statistics;
--rollback DROP TABLE IF EXISTS stg.raw_matches;
--rollback DROP TABLE IF EXISTS stg.raw_tournaments;
--rollback DROP TABLE IF EXISTS stg.raw_coaching_contracts;
--rollback DROP TABLE IF EXISTS stg.raw_coaches;
--rollback DROP TABLE IF EXISTS stg.raw_player_physical_details;
--rollback DROP TABLE IF EXISTS stg.raw_players;
--rollback DROP TABLE IF EXISTS stg.raw_ref_country;
