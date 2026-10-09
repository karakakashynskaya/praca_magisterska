--liquibase formatted sql
--changeset kkakashynskaya:5-dv-hub-tables context:common splitStatements:false

-- ========== ref_country ========== --
-- DBO --
----- satelita statusu -------------------------------------------------------
create table if not exists dbo.sat_ref_country_status (
    country_sk CHAR(32) not null
    , load_dt TIMESTAMP not null
    , load_end_dt TIMESTAMP
    , rec_src VARCHAR(50) not null
    , status char(1) -- 'C'=Create, 'U'=Update, 'D'=Delete
    , primary key (country_sk, load_dt)
);
------------------------------------------------------------------------------
create table if not exists dbo.ref_country (
    country_sk CHAR(32) not null
    , country_code_bk CHAR(3) not null
    , country_name VARCHAR(50) not null
    , rec_src VARCHAR(50) not null
    , load_dt TIMESTAMP not null
    , primary key (country_sk)
);



-- ========== dim_players ========== --
-- DBO --
----- satelita statusu -------------------------------------------------------
create table if not exists dbo.sat_player_status (
    player_sk CHAR(32) not null
    , load_dt TIMESTAMP not null
    , load_end_dt TIMESTAMP
    , rec_src VARCHAR(50) not null
    , status char(1)
    , primary key (player_sk, load_dt)
);
------------------------------------------------------------------------------
create table if not exists dbo.hub_players (
    player_sk CHAR(32) not null
    , rec_src VARCHAR(50) not null
    , load_dt TIMESTAMP not null
    , player_bk VARCHAR(100) not null
    , primary key (player_sk)
);



-- ========== dim_coaches ========== --
-- DBO --
----- satelita statusu -------------------------------------------------------
create table if not exists dbo.sat_coach_status (
    coach_sk CHAR(32) not null
    , load_dt TIMESTAMP not null
    , load_end_dt TIMESTAMP
    , rec_src VARCHAR(50) not null
    , status char(1)
    , primary key (coach_sk, load_dt)
);
------------------------------------------------------------------------------
create table if not exists dbo.hub_coaches (
    coach_sk CHAR(32) not null
    , rec_src VARCHAR(50) not null
    , load_dt TIMESTAMP not null
    , coach_bk VARCHAR(100) not null
    , primary key (coach_sk)
);



-- ========== dim_tournaments ========== --
-- DBO --
----- satelita statusu -------------------------------------------------------
create table if not exists dbo.sat_tournament_status (
    tournament_sk CHAR(32) not null
    , load_dt TIMESTAMP not null
    , load_end_dt TIMESTAMP
    , rec_src VARCHAR(50) not null
    , status char(1)
    , primary key (tournament_sk, load_dt)
);
------------------------------------------------------------------------------
create table if not exists dbo.hub_tournaments (
    tournament_sk CHAR(32) not null
    , rec_src VARCHAR(50) not null
    , load_dt TIMESTAMP not null
    , tournament_bk VARCHAR(100) not null
    , primary key (tournament_sk)
);



-- ========== dim_matches ========== --
-- DBO --
----- satelita statusu -------------------------------------------------------
create table if not exists dbo.sat_match_status (
    match_sk CHAR(32) not null
    , load_dt TIMESTAMP not null
    , load_end_dt TIMESTAMP
    , rec_src VARCHAR(50) not null
    , status char(1)
    , primary key (match_sk, load_dt)
);
------------------------------------------------------------------------------
create table if not exists dbo.hub_matches (
    match_sk CHAR(32) not null
    , rec_src VARCHAR(50) not null
    , load_dt TIMESTAMP not null
    , match_bk VARCHAR(100) not null
    , primary key (match_sk)
);


--rollback DROP TABLE IF EXISTS dbo.hub_matches;
--rollback DROP TABLE IF EXISTS dbo.sat_match_status;
--rollback DROP TABLE IF EXISTS dbo.hub_tournaments;
--rollback DROP TABLE IF EXISTS dbo.sat_tournament_status;
--rollback DROP TABLE IF EXISTS dbo.hub_coaches;
--rollback DROP TABLE IF EXISTS dbo.sat_coach_status;
--rollback DROP TABLE IF EXISTS dbo.hub_players;
--rollback DROP TABLE IF EXISTS dbo.sat_player_status;
--rollback DROP TABLE IF EXISTS dbo.ref_country;
--rollback DROP TABLE IF EXISTS dbo.sat_ref_country_status;
