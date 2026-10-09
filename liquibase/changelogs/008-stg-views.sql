--liquibase formatted sql
--changeset kkakashynskaya:8-stg-views context:common splitStatements:false runOnChange:true

-- ========== ref_country ========== --
-- STG VIEWS --
create or replace view stg.v_ref_country as
select distinct
    country_sk
    , country_code_bk
    , country_name
    , rec_src
    , load_dt
from stg.raw_ref_country;



-- ========== dim_players ========== --
-- STG VIEWS --
create or replace view stg.v_hub_players as
select
    player_sk
    , rec_src
    , load_dt
    , player_bk
from stg.raw_players;

create or replace view stg.v_sat_player_date_of_birth as
select
    player_sk
    , rec_src
    , load_dt
    , sat_player_date_of_birth_hash_key as hash_diff
    , date_of_birth
from stg.raw_players;

create or replace view stg.v_sat_player_personal_info as
select
    player_sk
    , rec_src
    , load_dt
    , sat_player_personal_info_hash_key as hash_diff
    , first_name
    , second_name
    , country
    , titles_won
    , is_active
from stg.raw_players;

-- dane fizyczne gracza
create or replace view stg.v_sat_player_physical_details as
select
    player_sk
    , rec_src
    , load_dt
    , sat_player_physical_details_hash_key as hash_diff
    , height_cm
    , weight_kg
    , dominant_hand
from stg.raw_player_physical_details;



-- ========== dim_coaches ========== --
-- STG VIEWS --
create or replace view stg.v_hub_coaches as
select
    coach_sk
    , rec_src
    , load_dt
    , coach_bk
from stg.raw_coaches;

create or replace view stg.v_sat_coach_personal_info as
select
    coach_sk
    , rec_src
    , load_dt
    , sat_coach_personal_info_hash_key as hash_diff
    , first_name
    , second_name
    , career_start_date
    , career_end_date
from stg.raw_coaches;



-- ========== fct_coaching_contracts ========== --
-- STG VIEWS --
create or replace view stg.v_link_coaching_contracts as
select
    coaching_contract_sk
    , rec_src
    , load_dt
    , player_sk
    , coach_sk
from stg.raw_coaching_contracts;

create or replace view stg.v_sat_coaching_contract_details as
select
    coaching_contract_sk
    , rec_src
    , load_dt
    , sat_coaching_contract_details_hash_key as hash_diff
    , is_active
from stg.raw_coaching_contracts;



-- ========== dim_tournaments ========== --
-- STG VIEWS --
create or replace view stg.v_hub_tournaments as
select distinct
    tournament_sk
    , rec_src
    , load_dt
    , tournament_bk
from stg.raw_tournaments;

create or replace view stg.v_sat_tournament_details as
select distinct
    tournament_sk
    , rec_src
    , load_dt
    , sat_tournament_details_hash_key as hash_diff
    , tournament_name
    , country
    , tournament_level
    , surface
    , tourn_start_date
    , tourn_end_date
from stg.raw_tournaments;



-- ========== dim_matches ========== --
-- STG VIEWS --
create or replace view stg.v_hub_matches as
select distinct
    match_sk
    , rec_src
    , load_dt
    , match_bk
from stg.raw_matches;

create or replace view stg.v_sat_match_details as
select distinct
    match_sk
    , rec_src
    , load_dt
    , sat_match_details_hash_key as hash_diff
    , date_of_match
    , match_round
    , match_duration
from stg.raw_matches;

create or replace view stg.v_link_match_tournament as
select distinct
    match_tournament_sk
    , rec_src
    , load_dt
    , match_sk
    , tournament_sk
from stg.raw_matches;

create or replace view stg.v_link_match_player as
select
    match_player1_sk as match_player_sk
    , rec_src
    , load_dt
    , match_sk
    , player1_sk as player_sk
    , 1 as player_number
from stg.raw_matches
union all
select
    match_player2_sk as match_player_sk
    , rec_src
    , load_dt
    , match_sk
    , player2_sk as player_sk
    , 2 as player_number
from stg.raw_matches;

create or replace view stg.v_sat_match_player_result as
select
    match_player1_sk as match_player_sk
    , rec_src
    , load_dt
    , sat_match_player1_result_hash_key as hash_diff
    , player1_sk as player_sk
    , 1 as player_number
    , player1_first_set_score as first_set_score
    , player1_second_set_score as second_set_score
    , player1_third_set_score as third_set_score
    , player1_final_score as final_score
    , case when winner_sk = player1_sk then true else false end as is_winner
from stg.raw_matches
union all
select
    match_player2_sk as match_player_sk
    , rec_src
    , load_dt
    , sat_match_player2_result_hash_key as hash_diff
    , player2_sk as player_sk
    , 2 as player_number
    , player2_first_set_score as first_set_score
    , player2_second_set_score as second_set_score
    , player2_third_set_score as third_set_score
    , player2_final_score as final_score
    , case when winner_sk = player2_sk then true else false end as is_winner
from stg.raw_matches;



-- ========== fct_match_statistics ========== --
-- STG VIEWS --
create or replace view stg.v_link_match_statistics as
select distinct
    match_statistics_sk
    , rec_src
    , load_dt
    , match_sk
    , player_sk
from stg.raw_match_statistics;

create or replace view stg.v_sat_match_statistics_details as
select distinct
    match_statistics_sk
    , rec_src
    , load_dt
    , sat_match_statistics_details_hash_key as hash_diff
    , aces
    , double_faults
    , break_points_converted_perc
from stg.raw_match_statistics;


--rollback DROP VIEW IF EXISTS stg.v_sat_match_statistics_details;
--rollback DROP VIEW IF EXISTS stg.v_link_match_statistics;
--rollback DROP VIEW IF EXISTS stg.v_sat_match_player_result;
--rollback DROP VIEW IF EXISTS stg.v_link_match_player;
--rollback DROP VIEW IF EXISTS stg.v_link_match_tournament;
--rollback DROP VIEW IF EXISTS stg.v_sat_match_details;
--rollback DROP VIEW IF EXISTS stg.v_hub_matches;
--rollback DROP VIEW IF EXISTS stg.v_sat_tournament_details;
--rollback DROP VIEW IF EXISTS stg.v_hub_tournaments;
--rollback DROP VIEW IF EXISTS stg.v_sat_coaching_contract_details;
--rollback DROP VIEW IF EXISTS stg.v_link_coaching_contracts;
--rollback DROP VIEW IF EXISTS stg.v_sat_coach_personal_info;
--rollback DROP VIEW IF EXISTS stg.v_hub_coaches;
--rollback DROP VIEW IF EXISTS stg.v_sat_player_physical_details;
--rollback DROP VIEW IF EXISTS stg.v_sat_player_personal_info;
--rollback DROP VIEW IF EXISTS stg.v_sat_player_date_of_birth;
--rollback DROP VIEW IF EXISTS stg.v_hub_players;
--rollback DROP VIEW IF EXISTS stg.v_ref_country;
