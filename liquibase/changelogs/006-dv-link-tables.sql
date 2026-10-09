--liquibase formatted sql
--changeset kkakashynskaya:6-dv-link-tables context:common splitStatements:false

-- ========== fct_coaching_contracts ========== --
-- DBO --
----- satelita statusu -------------------------------------------------------
create table if not exists dbo.sat_coaching_contract_status (
    coaching_contract_sk CHAR(32) not null
    , load_dt TIMESTAMP not null
    , load_end_dt TIMESTAMP
    , rec_src VARCHAR(50) not null
    , status char(1)
    , primary key (coaching_contract_sk, load_dt)
);
------------------------------------------------------------------------------
create table if not exists dbo.link_coaching_contracts (
    coaching_contract_sk CHAR(32) not null
    , rec_src VARCHAR(50) not null
    , load_dt TIMESTAMP not null
    , player_sk CHAR(32) not null
    , coach_sk CHAR(32) not null
    , primary key (coaching_contract_sk)
);



-- ========== dim_matches: relacje ========== --
-- DBO --
create table if not exists dbo.link_match_tournament (
    match_tournament_sk CHAR(32) not null
    , rec_src VARCHAR(50) not null
    , load_dt TIMESTAMP not null
    , match_sk CHAR(32) not null
    , tournament_sk CHAR(32) not null
    , primary key (match_tournament_sk)
);

create table if not exists dbo.link_match_player (
    match_player_sk CHAR(32) not null
    , rec_src VARCHAR(50) not null
    , load_dt TIMESTAMP not null
    , match_sk CHAR(32) not null
    , player_sk CHAR(32) not null
    , player_number SMALLINT not null -- 1 lub 2, rola gracza w meczu
    , primary key (match_player_sk)
);



-- ========== fct_match_statistics ========== --
-- DBO --
----- satelita statusu -------------------------------------------------------
create table if not exists dbo.sat_match_statistics_status (
    match_statistics_sk CHAR(32) not null
    , load_dt TIMESTAMP not null
    , load_end_dt TIMESTAMP
    , rec_src VARCHAR(50) not null
    , status char(1)
    , primary key (match_statistics_sk, load_dt)
);
------------------------------------------------------------------------------
create table if not exists dbo.link_match_statistics (
    match_statistics_sk CHAR(32) not null
    , rec_src VARCHAR(50) not null
    , load_dt TIMESTAMP not null
    , match_sk CHAR(32) not null
    , player_sk CHAR(32) not null
    , primary key (match_statistics_sk)
);


--rollback DROP TABLE IF EXISTS dbo.link_match_statistics;
--rollback DROP TABLE IF EXISTS dbo.sat_match_statistics_status;
--rollback DROP TABLE IF EXISTS dbo.link_match_player;
--rollback DROP TABLE IF EXISTS dbo.link_match_tournament;
--rollback DROP TABLE IF EXISTS dbo.link_coaching_contracts;
--rollback DROP TABLE IF EXISTS dbo.sat_coaching_contract_status;
