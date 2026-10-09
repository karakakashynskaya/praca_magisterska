--liquibase formatted sql
--changeset kkakashynskaya:7-dv-sat-tables context:common splitStatements:false

-- ========== dim_players ========== --
-- DBO --
create table if not exists dbo.sat_player_date_of_birth (
    player_sk CHAR(32) not null
    , load_dt TIMESTAMP not null
    , rec_src VARCHAR(50) not null
    , load_end_dt TIMESTAMP
    , hash_diff CHAR(32) not null
    , date_of_birth DATE not null
    , primary key (player_sk, load_dt)
);

create table if not exists dbo.sat_player_personal_info (
    player_sk CHAR(32) not null
    , load_dt TIMESTAMP not null
    , rec_src VARCHAR(50) not null
    , load_end_dt TIMESTAMP
    , hash_diff CHAR(32) not null
    , first_name VARCHAR(50) not null
    , second_name VARCHAR(100) not null
    , country CHAR(3)
    , titles_won SMALLINT
    , is_active BOOLEAN not null
    , primary key (player_sk, load_dt)
);

-- fizyczne dane gracza
create table if not exists dbo.sat_player_physical_details (
    player_sk CHAR(32) not null
    , load_dt TIMESTAMP not null
    , rec_src VARCHAR(50) not null
    , load_end_dt TIMESTAMP
    , hash_diff CHAR(32) not null
    , height_cm SMALLINT
    , weight_kg SMALLINT
    , dominant_hand VARCHAR(50)
    , primary key (player_sk, load_dt)
);



-- ========== dim_coaches ========== --
-- DBO --
create table if not exists dbo.sat_coach_personal_info (
    coach_sk CHAR(32) not null
    , load_dt TIMESTAMP not null
    , rec_src VARCHAR(50) not null
    , load_end_dt TIMESTAMP
    , hash_diff CHAR(32) not null
    , first_name VARCHAR(50) not null
    , second_name VARCHAR(100) not null
    , career_start_date DATE
    , career_end_date DATE
    , primary key (coach_sk, load_dt)
);



-- ========== fct_coaching_contracts ========== --
-- DBO --
create table if not exists dbo.sat_coaching_contract_details (
    coaching_contract_sk CHAR(32) not null
    , load_dt TIMESTAMP not null
    , rec_src VARCHAR(50) not null
    , load_end_dt TIMESTAMP
    , hash_diff CHAR(32) not null
    , is_active BOOLEAN not null
    , primary key (coaching_contract_sk, load_dt)
);



-- ========== dim_tournaments ========== --
-- DBO --
create table if not exists dbo.sat_tournament_details (
    tournament_sk CHAR(32) not null
    , load_dt TIMESTAMP not null
    , rec_src VARCHAR(50) not null
    , load_end_dt TIMESTAMP
    , hash_diff CHAR(32) not null
    , tournament_name VARCHAR(75) not null
    , country VARCHAR(50) not null
    , tournament_level VARCHAR(25) not null
    , surface VARCHAR(20)
    , tourn_start_date DATE not null
    , tourn_end_date DATE not null
    , primary key (tournament_sk, load_dt)
);



-- ========== dim_matches ========== --
-- DBO --
create table if not exists dbo.sat_match_details (
    match_sk CHAR(32) not null
    , load_dt TIMESTAMP not null
    , rec_src VARCHAR(50) not null
    , load_end_dt TIMESTAMP
    , hash_diff CHAR(32) not null
    , date_of_match DATE not null
    , match_round VARCHAR(5) not null
    , match_duration TIME
    , primary key (match_sk, load_dt)
);

-- wynik konkretnego gracza w meczu (link_match_player jako rodzic)
create table if not exists dbo.sat_match_player_result (
    match_player_sk CHAR(32) not null
    , load_dt TIMESTAMP not null
    , rec_src VARCHAR(50) not null
    , load_end_dt TIMESTAMP
    , hash_diff CHAR(32) not null
    , first_set_score INT not null
    , second_set_score INT not null
    , third_set_score INT
    , final_score INT not null
    , is_winner BOOLEAN not null
    , primary key (match_player_sk, load_dt)
);



-- ========== fct_match_statistics ========== --
-- DBO --
create table if not exists dbo.sat_match_statistics_details (
    match_statistics_sk CHAR(32) not null
    , load_dt TIMESTAMP not null
    , rec_src VARCHAR(50) not null
    , load_end_dt TIMESTAMP
    , hash_diff CHAR(32) not null
    , aces SMALLINT not null
    , double_faults SMALLINT not null
    , break_points_converted_perc DECIMAL(4,3) not null
    , primary key (match_statistics_sk, load_dt)
);


--rollback DROP TABLE IF EXISTS dbo.sat_match_statistics_details;
--rollback DROP TABLE IF EXISTS dbo.sat_match_player_result;
--rollback DROP TABLE IF EXISTS dbo.sat_match_details;
--rollback DROP TABLE IF EXISTS dbo.sat_tournament_details;
--rollback DROP TABLE IF EXISTS dbo.sat_coaching_contract_details;
--rollback DROP TABLE IF EXISTS dbo.sat_coach_personal_info;
--rollback DROP TABLE IF EXISTS dbo.sat_player_physical_details;
--rollback DROP TABLE IF EXISTS dbo.sat_player_personal_info;
--rollback DROP TABLE IF EXISTS dbo.sat_player_date_of_birth;
