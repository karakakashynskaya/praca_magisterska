--liquibase formatted sql
--changeset kkakashynskaya:21-star-tables context:common splitStatements:false

-- Uwaga architektoniczna: Star nie rozbija atrybutów na osobne satelity wg
-- częstotliwości zmian (jak DV, patrz rozdz. 2.5.3/3.4 teorii) — jedna zmiana
-- dowolnego atrybutu = nowa wersja CAŁEGO wiersza wymiaru. To jest właśnie
-- różnica testowana w kryterium "utrzymywanie historii danych" (rozdz. 2.6.4).
-- attr_hash = hash WSZYSTKICH atrybutów opisowych wiersza (odpowiednik hash_diff w DV,
-- ale jeden na cały wymiar, nie po jednym na satelitę).

-- ========== dim_player ========== --
create table if not exists star.dim_player (
    dim_player_sk CHAR(32) not null
    , player_bk VARCHAR(100) not null
    , row_effective_dt TIMESTAMP not null
    , row_expiry_dt TIMESTAMP
    , is_current BOOLEAN not null default true
    , date_of_birth DATE
    , first_name VARCHAR(50)
    , second_name VARCHAR(100)
    , country_name VARCHAR(50)
    , titles_won SMALLINT default 0
    , is_active BOOLEAN not null
    , height_cm SMALLINT
    , weight_kg SMALLINT
    , dominant_hand VARCHAR(50)
    , attr_hash CHAR(32) not null
    , primary key (dim_player_sk)
);
create index if not exists ix_dim_player_bk_current on star.dim_player (player_bk) where is_current;



-- ========== dim_coach ========== --
create table if not exists star.dim_coach (
    dim_coach_sk CHAR(32) not null
    , coach_bk VARCHAR(100) not null
    , row_effective_dt TIMESTAMP not null
    , row_expiry_dt TIMESTAMP
    , is_current BOOLEAN not null default true
    , first_name VARCHAR(50)
    , second_name VARCHAR(100)
    , career_start_date DATE
    , career_end_date DATE
    , attr_hash CHAR(32) not null
    , primary key (dim_coach_sk)
);
create index if not exists ix_dim_coach_bk_current on star.dim_coach (coach_bk) where is_current;



-- ========== dim_tournament ========== --
create table if not exists star.dim_tournament (
    dim_tournament_sk CHAR(32) not null
    , tournament_bk VARCHAR(100) not null
    , row_effective_dt TIMESTAMP not null
    , row_expiry_dt TIMESTAMP
    , is_current BOOLEAN not null default true
    , tournament_name VARCHAR(75)
    , country_name VARCHAR(50)
    , tournament_level VARCHAR(25)
    , surface VARCHAR(20)
    , tourn_start_date DATE
    , tourn_end_date DATE
    , attr_hash CHAR(32) not null
    , primary key (dim_tournament_sk)
);
create index if not exists ix_dim_tournament_bk_current on star.dim_tournament (tournament_bk) where is_current;



-- ========== dim_match ========== --
-- Modelowane jako dimension (jak dmart.dim_matches) — symetrycznie do DV,
-- właściwe miary są w fct_match_statistics.
create table if not exists star.dim_match (
    dim_match_sk CHAR(32) not null
    , match_bk VARCHAR(100) not null
    , row_effective_dt TIMESTAMP not null
    , row_expiry_dt TIMESTAMP
    , is_current BOOLEAN not null default true
    , date_of_match DATE
    , match_round VARCHAR(5)
    , first_set_score VARCHAR(11)
    , second_set_score VARCHAR(11)
    , third_set_score VARCHAR(11)
    , final_score CHAR(3)
    , match_duration TIME
    , attr_hash CHAR(32) not null
    , primary key (dim_match_sk)
);
create index if not exists ix_dim_match_bk_current on star.dim_match (match_bk) where is_current;



-- ========== fct_coaching_contracts ========== --
create table if not exists star.fct_coaching_contracts (
    fct_coaching_contract_sk CHAR(32) not null
    , contract_bk VARCHAR(210) not null
    , row_effective_dt TIMESTAMP not null
    , row_expiry_dt TIMESTAMP
    , is_current BOOLEAN not null default true
    , dim_player_sk CHAR(32) not null
    , dim_coach_sk CHAR(32) not null
    , is_active BOOLEAN not null
    , attr_hash CHAR(32) not null
    , primary key (fct_coaching_contract_sk)
);
create index if not exists ix_fct_coaching_contract_bk_current on star.fct_coaching_contracts (contract_bk) where is_current;



-- ========== fct_match_statistics ========== --
create table if not exists star.fct_match_statistics (
    fct_match_statistics_sk CHAR(32) not null
    , match_bk VARCHAR(100) not null
    , row_effective_dt TIMESTAMP not null
    , row_expiry_dt TIMESTAMP
    , is_current BOOLEAN not null default true
    , dim_match_sk CHAR(32) not null
    , dim_player1_sk CHAR(32) not null
    , dim_player2_sk CHAR(32) not null
    , dim_winner_sk CHAR(32) not null
    , dim_tournament_sk CHAR(32) not null
    , player1_aces SMALLINT not null default 0
    , player2_aces SMALLINT not null default 0
    , player1_double_faults SMALLINT not null default 0
    , player2_double_faults SMALLINT not null default 0
    , player1_break_points_converted_perc DECIMAL(4,3) default 0
    , player2_break_points_converted_perc DECIMAL(4,3) default 0
    , attr_hash CHAR(32) not null
    , primary key (fct_match_statistics_sk)
);
create index if not exists ix_fct_match_statistics_bk_current on star.fct_match_statistics (match_bk) where is_current;


--rollback DROP TABLE IF EXISTS star.fct_match_statistics;
--rollback DROP TABLE IF EXISTS star.fct_coaching_contracts;
--rollback DROP TABLE IF EXISTS star.dim_match;
--rollback DROP TABLE IF EXISTS star.dim_tournament;
--rollback DROP TABLE IF EXISTS star.dim_coach;
--rollback DROP TABLE IF EXISTS star.dim_player;
