--liquibase formatted sql
--changeset kkakashynskaya:18-biz-views context:common splitStatements:false runOnChange:true

-- ========== ref_country ========== --
-- BIZ --
create or replace view biz.v_ref_country as
select distinct
    rc.country_sk
    , rc.country_code_bk
    , rc.country_name
    , rc.load_dt
from dbo.ref_country rc
left join dbo.sat_ref_country_status srfs
    on rc.country_sk = srfs.country_sk
    and srfs.load_end_dt is null
where coalesce(srfs.status, 'C') <> 'D';



-- ========== dim_players ========== --
-- BIZ --
create or replace view biz.v_dim_players as
with tmp_dim_players as (
    select
        hp.player_sk as player_hash_key
        , greatest(
            hp.load_dt
            , coalesce(spdob.load_dt, hp.load_dt)
            , coalesce(sppi.load_dt, hp.load_dt)
            , coalesce(sppd.load_dt, hp.load_dt)
            , coalesce(rf.load_dt, hp.load_dt)
            , coalesce(sps.load_dt, hp.load_dt)
        ) as load_dt
        , hp.player_bk as player_bk
        , spdob.date_of_birth as date_of_birth
        , sppi.first_name as first_name
        , sppi.second_name as second_name
        , rf.country_name as country_name
        , sppi.titles_won as titles_won
        , sppi.is_active as is_active
        , sppd.height_cm as height_cm
        , sppd.weight_kg as weight_kg
        , sppd.dominant_hand as dominant_hand
    from dbo.hub_players as hp
    left join dbo.sat_player_date_of_birth as spdob
        on hp.player_sk = spdob.player_sk
        and spdob.load_end_dt is null
    left join dbo.sat_player_personal_info as sppi
        on hp.player_sk = sppi.player_sk
        and sppi.load_end_dt is null
    left join dbo.sat_player_physical_details as sppd
        on hp.player_sk = sppd.player_sk
        and sppd.load_end_dt is null
    left join dbo.ref_country as rf
        on sppi.country = rf.country_code_bk
    left join dbo.sat_player_status sps
        on hp.player_sk = sps.player_sk
        and sps.load_end_dt is null
    where coalesce(sps.status, 'C') <> 'D')
select
    md5(
        upper(trim(coalesce(player_bk, ''))) || ';' ||
        upper(trim(coalesce(load_dt::text, '')))
    ) as dim_player_sk
    , player_hash_key
    , load_dt
    , player_bk
    , date_of_birth
    , first_name
    , second_name
    , country_name
    , titles_won
    , is_active
    , height_cm
    , weight_kg
    , dominant_hand
from tmp_dim_players;



-- ========== dim_coaches ========== --
-- BIZ --
create or replace view biz.v_dim_coaches as
with tmp_dim_coaches as (
    select distinct
        hc.coach_sk as coach_hash_key
        , greatest(
            hc.load_dt
            , coalesce(scpi.load_dt, hc.load_dt)
            , coalesce(scs.load_dt, hc.load_dt)
        ) as load_dt
        , hc.coach_bk as coach_bk
        , scpi.first_name as first_name
        , scpi.second_name as second_name
        , scpi.career_start_date as career_start_date
        , scpi.career_end_date as career_end_date
    from dbo.hub_coaches as hc
    left join dbo.sat_coach_personal_info as scpi
        on 1=1
            and hc.coach_sk = scpi.coach_sk
            and scpi.load_end_dt is null
    left join dbo.sat_coach_status scs
        on hc.coach_sk = scs.coach_sk
        and scs.load_end_dt is null
    where coalesce(scs.status, 'C') <> 'D')
select
    md5(
        upper(trim(coalesce(coach_bk, ''))) || ';' ||
        upper(trim(coalesce(load_dt::text, '')))
    ) as dim_coach_sk
    , coach_hash_key
    , load_dt
    , coach_bk
    , first_name
    , second_name
    , career_start_date
    , career_end_date
from tmp_dim_coaches;



-- ========== fct_coaching_contracts ========== --
-- BIZ --
-- Uwaga: zależy od dmart.dim_players i dmart.dim_coaches — muszą być
-- już załadowane, zanim ten widok zwróci sensowne dim_player_sk/dim_coach_sk.
create or replace view biz.v_fct_coaching_contracts as
with tmp_fct_coaching_contracts as (
    select
        lcc.coaching_contract_sk as coaching_contract_hash_key
        , greatest(
            lcc.load_dt
            , coalesce(sccd.load_dt, lcc.load_dt)
            , coalesce(sccs.load_dt, lcc.load_dt)
        ) as load_dt
        , lcc.player_sk as player_hash_key
        , lcc.coach_sk as coach_hash_key
        , coalesce(dp.dim_player_sk, '-98') as dim_player_sk
        , coalesce(dc.dim_coach_sk, '-98') as dim_coach_sk
        , sccd.is_active as is_active
    from dbo.link_coaching_contracts lcc
    left join dbo.sat_coaching_contract_details as sccd
        on 1=1
            and lcc.coaching_contract_sk = sccd.coaching_contract_sk
            and sccd.load_end_dt is null
    left join dmart.dim_players as dp
        on 1=1
            and dp.player_hash_key = lcc.player_sk
            and dp.row_expired_dt is null
    left join dmart.dim_coaches as dc
        on 1=1
            and dc.coach_hash_key = lcc.coach_sk
            and dc.row_expired_dt is null
    left join dbo.sat_coaching_contract_status sccs
        on lcc.coaching_contract_sk = sccs.coaching_contract_sk
        and sccs.load_end_dt is null
    where coalesce(sccs.status, 'C') <> 'D')
select
    md5(
        upper(trim(coalesce(player_hash_key, ''))) || ';' ||
        upper(trim(coalesce(coach_hash_key, ''))) || ';' ||
        upper(trim(coalesce(load_dt::text, '')))
    ) as fct_coaching_contract_sk
    , coaching_contract_hash_key
    , load_dt
    , dim_player_sk
    , dim_coach_sk
    , is_active
from tmp_fct_coaching_contracts;



-- ========== dim_matches ========== --
-- BIZ --
create or replace view biz.v_dim_matches as
with player_results as (
    select
        lmp.match_sk
        , lmp.player_number
        , smpr.load_dt
        , smpr.first_set_score
        , smpr.second_set_score
        , smpr.third_set_score
        , smpr.final_score
    from dbo.link_match_player lmp
    left join dbo.sat_match_player_result smpr
        on 1=1
        and lmp.match_player_sk = smpr.match_player_sk
        and smpr.load_end_dt is null
),
match_scores as (
    select
        match_sk
        , max(load_dt) as player_results_load_dt
        , concat(
            max(case when player_number = 1 then first_set_score end)
            , '-'
            , max(case when player_number = 2 then first_set_score end)
        ) as first_set_score
        , concat(
            max(case when player_number = 1 then second_set_score end)
            , '-'
            , max(case when player_number = 2 then second_set_score end)
        ) as second_set_score
        , case
            when max(case when player_number = 1 then third_set_score end) is not null
            then concat(
                max(case when player_number = 1 then third_set_score end)
                , '-'
                , max(case when player_number = 2 then third_set_score end)
            )
            else null
        end as third_set_score
        , concat(
            max(case when player_number = 1 then final_score end)
            , '-'
            , max(case when player_number = 2 then final_score end)
        ) as final_score
    from player_results
    group by match_sk
),
tmp_dim_matches as (
    select
        hm.match_sk as match_hash_key
        , greatest(
            hm.load_dt
            , coalesce(smd.load_dt, hm.load_dt)
            , coalesce(ms.player_results_load_dt, hm.load_dt)
            , coalesce(sms.load_dt, hm.load_dt)
        ) as load_dt
        , hm.match_bk
        , smd.date_of_match
        , smd.match_round
        , smd.match_duration
        , ms.first_set_score
        , ms.second_set_score
        , ms.third_set_score
        , ms.final_score
    from dbo.hub_matches as hm
    left join dbo.sat_match_details as smd
        on hm.match_sk = smd.match_sk
        and smd.load_end_dt is null
    left join match_scores as ms
        on hm.match_sk = ms.match_sk
    left join dbo.sat_match_status as sms
        on hm.match_sk = sms.match_sk
        and sms.load_end_dt is null
    where coalesce(sms.status, 'C') <> 'D'
)
select
    md5(
        upper(trim(coalesce(match_bk, ''))) || ';' ||
        upper(trim(coalesce(load_dt::text, '')))
    ) as dim_match_sk
    , match_hash_key
    , load_dt
    , match_bk
    , date_of_match
    , match_round
    , first_set_score
    , second_set_score
    , third_set_score
    , final_score
    , match_duration
from tmp_dim_matches;



-- ========== dim_tournaments ========== --
-- BIZ --
create or replace view biz.v_dim_tournaments as
with tmp_dim_tournaments as (
    select distinct
        ht.tournament_sk as tournament_hash_key
        , greatest(
            ht.load_dt
            , coalesce(std.load_dt, ht.load_dt)
            , coalesce(sts.load_dt, ht.load_dt)
        ) as load_dt
        , ht.tournament_bk as tournament_bk
        , std.tournament_name as tournament_name
        , std.country as country_name
        , std.tournament_level as tournament_level
        , std.surface as surface
        , std.tourn_start_date as tourn_start_date
        , std.tourn_end_date as tourn_end_date
    from dbo.hub_tournaments as ht
    left join dbo.sat_tournament_details as std
        on 1=1
            and ht.tournament_sk = std.tournament_sk
            and std.load_end_dt is null
    left join dbo.sat_tournament_status sts
        on ht.tournament_sk = sts.tournament_sk
        and sts.load_end_dt is null
    where coalesce(sts.status, 'C') <> 'D'
)
select
    md5(
        upper(trim(coalesce(tournament_bk, ''))) || ';' ||
        upper(trim(coalesce(load_dt::text, '')))
    ) as dim_tournament_sk
    , tournament_hash_key
    , load_dt
    , tournament_bk
    , tournament_name
    , country_name
    , tournament_level
    , surface
    , tourn_start_date
    , tourn_end_date
from tmp_dim_tournaments;



-- ========== fct_match_statistics ========== --
-- BIZ --
-- Uwaga: zależy od dmart.dim_matches, dmart.dim_players, dmart.dim_tournaments —
-- muszą być już załadowane. Grain: jeden mecz = jedna strona player1 vs player2.
create or replace view biz.v_fct_match_statistics as
with match_stats_combined as (
    select
        lmp1.match_sk as match_sk
        , lmp1.player_sk as player1_sk
        , lmp2.player_sk as player2_sk
        , lmp1.match_sk as match_players_sk
        , lms1.match_statistics_sk as player1_match_statistics_sk
        , lms1.load_dt as player1_lms_load_dt
        , smsd1.load_dt as player1_smsd_load_dt
        , smsd1.aces as player1_aces
        , smsd1.double_faults as player1_double_faults
        , smsd1.break_points_converted_perc as player1_break_points_converted_perc
        , sms1.load_dt as player1_sms_load_dt
        , sms1.status as player1_status
        , lms2.match_statistics_sk as player2_match_statistics_sk
        , lms2.load_dt as player2_lms_load_dt
        , smsd2.load_dt as player2_smsd_load_dt
        , smsd2.aces as player2_aces
        , smsd2.double_faults as player2_double_faults
        , smsd2.break_points_converted_perc as player2_break_points_converted_perc
        , sms2.load_dt as player2_sms_load_dt
        , sms2.status as player2_status
    from dbo.link_match_player as lmp1
    inner join dbo.link_match_player as lmp2
        on lmp1.match_sk = lmp2.match_sk
        and lmp1.player_number = 1
        and lmp2.player_number = 2
    left join dbo.link_match_statistics as lms1
        on lms1.match_sk = lmp1.match_sk
        and lms1.player_sk = lmp1.player_sk
    left join dbo.sat_match_statistics_details as smsd1
        on lms1.match_statistics_sk = smsd1.match_statistics_sk
        and smsd1.load_end_dt is null
    left join dbo.sat_match_statistics_status as sms1
        on lms1.match_statistics_sk = sms1.match_statistics_sk
        and sms1.load_end_dt is null
    left join dbo.link_match_statistics as lms2
        on lms2.match_sk = lmp2.match_sk
        and lms2.player_sk = lmp2.player_sk
    left join dbo.sat_match_statistics_details as smsd2
        on lms2.match_statistics_sk = smsd2.match_statistics_sk
        and smsd2.load_end_dt is null
    left join dbo.sat_match_statistics_status as sms2
        on lms2.match_statistics_sk = sms2.match_statistics_sk
        and sms2.load_end_dt is null
),
tmp_fct_match_statistics as (
    select distinct
        msc.match_sk as match_statistics_hash_key
        -- Wersja faktu (Kimball, symetrycznie do star.fct_match_statistics.attr_hash):
        -- nowa wersja powstaje wyłącznie przy zmianie miar (satelity statystyk) albo przy
        -- ponownym utworzeniu meczu po usunięciu (ostatni status 'C'). Zmiany atrybutów
        -- meczu, wyniku czy wymiarów NIE wersjonują faktu — fakt wskazuje wersję wymiaru
        -- z chwili swojego załadowania ("as was").
        , greatest(
            lmp1.load_dt
            , lmp2.load_dt
            , coalesce(msc.player1_lms_load_dt, lmp1.load_dt)
            , coalesce(msc.player1_smsd_load_dt, lmp1.load_dt)
            , coalesce(msc.player1_sms_load_dt, lmp1.load_dt)
            , coalesce(msc.player2_lms_load_dt, lmp1.load_dt)
            , coalesce(msc.player2_smsd_load_dt, lmp1.load_dt)
            , coalesce(msc.player2_sms_load_dt, lmp1.load_dt)
            , coalesce(lmt.load_dt, lmp1.load_dt)
            , coalesce((
                select max(c.load_dt)
                from dbo.sat_match_status as c
                where c.match_sk = lmp1.match_sk
                    and c.status = 'C'
            ), lmp1.load_dt)
        ) as load_dt
        , msc.match_sk as match_hash_key
        , msc.player1_sk as player1_hash_key
        , msc.player2_sk as player2_hash_key
        , case when smpr1.is_winner then msc.player1_sk else msc.player2_sk end as winner_hash_key
        , lmt.tournament_sk as tournament_hash_key
        , coalesce(dm.dim_match_sk, '-98') as dim_match_sk
        , coalesce(dp1.dim_player_sk, '-98') as dim_player1_sk
        , coalesce(dp2.dim_player_sk, '-98') as dim_player2_sk
        , coalesce(dw.dim_player_sk, '-98') as dim_winner_sk
        , coalesce(dt.dim_tournament_sk, '-98') as dim_tournament_sk
        , coalesce(msc.player1_aces, 0) as player1_aces
        , coalesce(msc.player1_double_faults, 0) as player1_double_faults
        , coalesce(msc.player1_break_points_converted_perc, 0) as player1_break_points_converted_perc
        , coalesce(msc.player2_aces, 0) as player2_aces
        , coalesce(msc.player2_double_faults, 0) as player2_double_faults
        , coalesce(msc.player2_break_points_converted_perc, 0) as player2_break_points_converted_perc
    from dbo.link_match_player as lmp1
    inner join dbo.link_match_player as lmp2
        on lmp1.match_sk = lmp2.match_sk
        and lmp1.player_number = 1
        and lmp2.player_number = 2

    left join match_stats_combined as msc
        on msc.match_sk = lmp1.match_sk

    left join dbo.sat_match_player_result as smpr1
        on lmp1.match_player_sk = smpr1.match_player_sk
        and smpr1.load_end_dt is null

    left join dbo.sat_match_player_result as smpr2
        on lmp2.match_player_sk = smpr2.match_player_sk
        and smpr2.load_end_dt is null

    left join dbo.link_match_tournament as lmt
        on lmp1.match_sk = lmt.match_sk

    left join dmart.dim_matches as dm
        on dm.match_hash_key = lmp1.match_sk
        and dm.row_expired_dt is null

    left join dmart.dim_players as dp1
        on dp1.player_hash_key = lmp1.player_sk
        and dp1.row_expired_dt is null

    left join dmart.dim_players as dp2
        on dp2.player_hash_key = lmp2.player_sk
        and dp2.row_expired_dt is null

    left join dmart.dim_players as dw
        on dw.player_hash_key = case when smpr1.is_winner then lmp1.player_sk else lmp2.player_sk end
        and dw.row_expired_dt is null

    left join dmart.dim_tournaments as dt
        on dt.tournament_hash_key = lmt.tournament_sk
        and dt.row_expired_dt is null

    left join dbo.sat_match_status as sms
        on lmp1.match_sk = sms.match_sk
        and sms.load_end_dt is null

    where coalesce(sms.status, 'C') <> 'D'
        and not (
            coalesce(msc.player1_status, 'C') = 'D'
            or coalesce(msc.player2_status, 'C') = 'D'
        )
)
select distinct
    md5(
        upper(trim(coalesce(match_hash_key, ''))) || ';' ||
        upper(trim(coalesce(player1_hash_key, ''))) || ';' ||
        upper(trim(coalesce(player2_hash_key, ''))) || ';' ||
        upper(trim(coalesce(load_dt::text, '')))
    ) as fct_match_statistics_sk
    , match_statistics_hash_key
    , load_dt
    , dim_match_sk
    , dim_player1_sk
    , dim_player2_sk
    , dim_winner_sk
    , dim_tournament_sk
    , player1_aces
    , player2_aces
    , player1_double_faults
    , player2_double_faults
    , player1_break_points_converted_perc
    , player2_break_points_converted_perc
from tmp_fct_match_statistics;


--rollback DROP VIEW IF EXISTS biz.v_fct_match_statistics;
--rollback DROP VIEW IF EXISTS biz.v_dim_tournaments;
--rollback DROP VIEW IF EXISTS biz.v_dim_matches;
--rollback DROP VIEW IF EXISTS biz.v_fct_coaching_contracts;
--rollback DROP VIEW IF EXISTS biz.v_dim_coaches;
--rollback DROP VIEW IF EXISTS biz.v_dim_players;
--rollback DROP VIEW IF EXISTS biz.v_ref_country;
