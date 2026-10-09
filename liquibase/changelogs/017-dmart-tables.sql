--liquibase formatted sql
--changeset kkakashynskaya:17-dmart-tables context:common splitStatements:false

-- ========== ref_country ========== --
-- DMART --
create table if not exists dmart.ref_country (
    country_sk CHAR(32) not null
    , row_load_dt TIMESTAMP not null
    , country_code_bk CHAR(3) not null
    , country_name VARCHAR(50) not null
    , primary key (country_sk)
);



-- ========== dim_players ========== --
-- DMART --
create table if not exists dmart.dim_players (
    dim_player_sk CHAR(32) not null
    , player_hash_key CHAR(32) not null
    , row_load_dt TIMESTAMP not null
    , row_expired_dt TIMESTAMP
    , player_bk VARCHAR(100) not null
    , date_of_birth DATE not null
    , first_name VARCHAR(50) not null
    , second_name VARCHAR(100) not null
    , country_name VARCHAR(50)
    , titles_won SMALLINT default 0
    , is_active BOOLEAN
    , height_cm SMALLINT
    , weight_kg SMALLINT
    , dominant_hand VARCHAR(50)
    , primary key (dim_player_sk)
);



-- ========== dim_coaches ========== --
-- DMART --
create table if not exists dmart.dim_coaches (
    dim_coach_sk CHAR(32) not null
    , coach_hash_key CHAR(32) not null
    , row_load_dt TIMESTAMP not null
    , row_expired_dt TIMESTAMP
    , coach_bk VARCHAR(100) not null
    , first_name VARCHAR(50) not null
    , second_name VARCHAR(100) not null
    , career_start_date DATE
    , career_end_date DATE
    , primary key (dim_coach_sk)
);



-- ========== fct_coaching_contracts ========== --
-- DMART --
create table if not exists dmart.fct_coaching_contracts (
    fct_coaching_contract_sk CHAR(32) not null
    , coaching_contract_hash_key CHAR(32) not null
    , row_load_dt TIMESTAMP not null
    , row_expired_dt TIMESTAMP
    , dim_player_sk CHAR(32) not null
    , dim_coach_sk CHAR(32) not null
    , is_active BOOLEAN
    , primary key (fct_coaching_contract_sk)
);



-- ========== dim_matches ========== --
-- DMART --
-- Uwaga: modelowane jako dimension, nie fact — właściwe miary biznesowe
-- (aces, double faults, bp%) leżą w fct_match_statistics, tu tylko kontekst opisowy meczu.
create table if not exists dmart.dim_matches (
    dim_match_sk CHAR(32) not null
    , match_hash_key CHAR(32) not null
    , row_load_dt TIMESTAMP not null
    , row_expired_dt TIMESTAMP
    , match_bk VARCHAR(100) not null
    , date_of_match DATE not null
    , match_round VARCHAR(5) not null
    , first_set_score VARCHAR(11) not null
    , second_set_score VARCHAR(11) not null
    , third_set_score VARCHAR(11)
    , final_score CHAR(3) not null
    , match_duration TIME
    , primary key (dim_match_sk)
);



-- ========== dim_tournaments ========== --
-- DMART --
create table if not exists dmart.dim_tournaments (
    dim_tournament_sk CHAR(32) not null
    , tournament_hash_key CHAR(32) not null
    , row_load_dt TIMESTAMP not null
    , row_expired_dt TIMESTAMP
    , tournament_bk VARCHAR(100) not null
    , tournament_name VARCHAR(75) not null
    , country_name VARCHAR(50) not null
    , tournament_level VARCHAR(25) not null
    , surface VARCHAR(20)
    , tourn_start_date DATE not null
    , tourn_end_date DATE
    , primary key (dim_tournament_sk)
);



-- ========== fct_match_statistics ========== --
-- DMART --
create table if not exists dmart.fct_match_statistics (
    fct_match_statistics_sk CHAR(32) not null
    , match_statistics_hash_key CHAR(32) not null
    , row_load_dt TIMESTAMP not null
    , row_expired_dt TIMESTAMP
    , dim_match_sk CHAR(32) not null
    , dim_player1_sk CHAR(32) not null
    , dim_player2_sk CHAR(32) not null
    , dim_winner_sk CHAR(32) not null
    , dim_tournament_sk CHAR(32) not null
    , player1_aces SMALLINT not null
    , player2_aces SMALLINT not null
    , player1_double_faults SMALLINT not null
    , player2_double_faults SMALLINT not null
    , player1_break_points_converted_perc DECIMAL(4,3) not null
    , player2_break_points_converted_perc DECIMAL(4,3) not null
    , primary key (fct_match_statistics_sk)
);

create index if not exists ix_dim_players_hash_active on dmart.dim_players (player_hash_key) where row_expired_dt is null;
create index if not exists ix_dim_coaches_hash_active on dmart.dim_coaches (coach_hash_key) where row_expired_dt is null;
create index if not exists ix_dim_tournaments_hash_active on dmart.dim_tournaments (tournament_hash_key) where row_expired_dt is null;
create index if not exists ix_dim_matches_hash_active on dmart.dim_matches (match_hash_key) where row_expired_dt is null;
create index if not exists ix_fct_coaching_contracts_hash_active on dmart.fct_coaching_contracts (coaching_contract_hash_key) where row_expired_dt is null;
create index if not exists ix_fct_match_statistics_hash_active on dmart.fct_match_statistics (match_statistics_hash_key) where row_expired_dt is null;

--rollback drop index if exists dmart.ix_dim_players_hash_active, dmart.ix_dim_coaches_hash_active, dmart.ix_dim_tournaments_hash_active, dmart.ix_dim_matches_hash_active, dmart.ix_fct_coaching_contracts_hash_active, dmart.ix_fct_match_statistics_hash_active;
--rollback DROP TABLE IF EXISTS dmart.fct_match_statistics;
--rollback DROP TABLE IF EXISTS dmart.dim_tournaments;
--rollback DROP TABLE IF EXISTS dmart.dim_matches;
--rollback DROP TABLE IF EXISTS dmart.fct_coaching_contracts;
--rollback DROP TABLE IF EXISTS dmart.dim_coaches;
--rollback DROP TABLE IF EXISTS dmart.dim_players;
--rollback DROP TABLE IF EXISTS dmart.ref_country;
