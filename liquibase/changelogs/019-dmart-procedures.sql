--liquibase formatted sql
--changeset kkakashynskaya:19-dmart-procedures splitStatements:false runOnChange:true

-- ========== ref_country ========== --
-- DMART --
create or replace procedure dmart.sp_load_ref_country(
    in f_run_id VARCHAR
    , in f_load_date TIMESTAMP
    , inout f_rec_src VARCHAR
    , inout f_record_inserted INT
    , inout f_error_num INT
    , inout f_error_message VARCHAR
)
language plpgsql
as $$
declare
    v_record_count INT;
begin
    insert into dmart.ref_country (
        country_sk
        , row_load_dt
        , country_code_bk
        , country_name
    )
    select
        country_sk
        , load_dt as row_load_dt
        , country_code_bk
        , country_name
    from biz.v_ref_country as vrc
    where not exists (
        select drc.country_sk
        from dmart.ref_country as drc
        where drc.country_sk = vrc.country_sk
    );

    get diagnostics v_record_count = row_count;

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_ref_country', v_record_count, 'Dimension loaded successfully');

    f_record_inserted = v_record_count;

    raise info 'Table ref_country loaded successfully! Records inserted: %', f_record_inserted;

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_ref_country', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;



-- ========== dim_players ========== --
-- DMART --
create or replace procedure dmart.sp_load_dim_players(
    in f_run_id VARCHAR
    , in f_load_date TIMESTAMP
    , inout f_rec_src VARCHAR
    , inout f_record_inserted INT
    , inout f_record_updated INT
    , inout f_error_num INT
    , inout f_error_message VARCHAR
)
language plpgsql
as $$
declare
    v_record_count INT;
    v_updated_count INT;
    v_deleted_count INT;
begin
    lock table dmart.dim_players;

    -- ustawia row_expired_dt dla usuniętych graczy
    update dmart.dim_players as old_dim
    set row_expired_dt = f_load_date - interval '1 second'
    where 1=1
        and old_dim.row_expired_dt is null
        and not exists (
            select new_dim.player_hash_key
            from biz.v_dim_players as new_dim
            where new_dim.player_hash_key = old_dim.player_hash_key
        );

    get diagnostics v_deleted_count = row_count;

    update dmart.dim_players as old_dim
    set row_expired_dt = f_load_date - interval '1 second'
    where 1=1
        and old_dim.row_expired_dt is null
        and exists (
            select new_dim.player_hash_key
            from biz.v_dim_players as new_dim
            where 1=1
                and new_dim.player_hash_key = old_dim.player_hash_key
                and new_dim.dim_player_sk != old_dim.dim_player_sk
            );

    get diagnostics v_updated_count = row_count;

    insert into dmart.dim_players (
        dim_player_sk
        , player_hash_key
        , row_load_dt
        , row_expired_dt
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
    )
    select distinct
        dim_player_sk
        , player_hash_key
        , load_dt as row_load_dt
        , null::timestamp as row_expired_dt
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
    from biz.v_dim_players as vdp
    where not exists (
        select dp.player_hash_key
        from dmart.dim_players as dp
        where 1=1
            and dp.player_hash_key = vdp.player_hash_key
            and dp.dim_player_sk = vdp.dim_player_sk
            and dp.row_expired_dt is null
        );

    get diagnostics v_record_count = row_count;

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_dim_players', v_record_count, 'Dimension loaded successfully');

    f_record_inserted = v_record_count;
    f_record_updated = v_updated_count;

    raise info 'Table dim_players loaded successfully! Records inserted: %. Records updated: %', f_record_inserted, f_record_updated;

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_dim_players', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;



-- ========== dim_coaches ========== --
-- DMART --
create or replace procedure dmart.sp_load_dim_coaches(
    in f_run_id VARCHAR
    , in f_load_date TIMESTAMP
    , inout f_rec_src VARCHAR
    , inout f_record_inserted INT
    , inout f_record_updated INT
    , inout f_error_num INT
    , inout f_error_message VARCHAR
)
language plpgsql
as $$
declare
    v_record_count INT;
    v_updated_count INT;
    v_deleted_count INT;
begin
    lock table dmart.dim_coaches;

    update dmart.dim_coaches as old_dim
    set row_expired_dt = f_load_date - interval '1 second'
    where 1=1
        and old_dim.row_expired_dt is null
        and not exists (
            select new_dim.coach_hash_key
            from biz.v_dim_coaches as new_dim
            where new_dim.coach_hash_key = old_dim.coach_hash_key
        );

    get diagnostics v_deleted_count = row_count;

    update dmart.dim_coaches as old_dim
    set row_expired_dt = f_load_date - interval '1 second'
    where 1=1
        and old_dim.row_expired_dt is null
        and exists (
            select new_dim.coach_hash_key
            from biz.v_dim_coaches as new_dim
            where 1=1
                and new_dim.coach_hash_key = old_dim.coach_hash_key
                and new_dim.dim_coach_sk != old_dim.dim_coach_sk
            );

    get diagnostics v_updated_count = row_count;

    insert into dmart.dim_coaches (
        dim_coach_sk
        , coach_hash_key
        , row_load_dt
        , row_expired_dt
        , coach_bk
        , first_name
        , second_name
        , career_start_date
        , career_end_date
    )
    select distinct
        dim_coach_sk
        , coach_hash_key
        , load_dt as row_load_dt
        , null::timestamp as row_expired_dt
        , coach_bk
        , first_name
        , second_name
        , career_start_date
        , career_end_date
    from biz.v_dim_coaches as vdc
    where not exists (
        select dc.coach_hash_key
        from dmart.dim_coaches as dc
        where 1=1
            and dc.coach_hash_key = vdc.coach_hash_key
            and dc.dim_coach_sk = vdc.dim_coach_sk
            and dc.row_expired_dt is null
    );

    get diagnostics v_record_count = row_count;

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_dim_coaches', v_record_count, 'Dimension loaded successfully');

    f_record_inserted = v_record_count;
    f_record_updated = v_updated_count;

    raise info 'Table dim_coaches loaded successfully! Records inserted: %. Records updated: %', f_record_inserted, f_record_updated;

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_dim_coaches', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;



-- ========== dim_tournaments ========== --
-- DMART --
create or replace procedure dmart.sp_load_dim_tournaments(
    in f_run_id VARCHAR
    , in f_load_date TIMESTAMP
    , inout f_rec_src VARCHAR
    , inout f_record_inserted INT
    , inout f_record_updated INT
    , inout f_error_num INT
    , inout f_error_message VARCHAR
)
language plpgsql
as $$
declare
    v_record_count INT;
    v_updated_count INT;
    v_deleted_count INT;
begin
    lock table dmart.dim_tournaments;

    update dmart.dim_tournaments as old_dim
    set row_expired_dt = f_load_date - interval '1 second'
    where 1=1
        and old_dim.row_expired_dt is null
        and not exists (
            select new_dim.tournament_hash_key
            from biz.v_dim_tournaments as new_dim
            where new_dim.tournament_hash_key = old_dim.tournament_hash_key
        );

    get diagnostics v_deleted_count = row_count;

    update dmart.dim_tournaments as old_dim
    set row_expired_dt = f_load_date - interval '1 second'
    where 1=1
        and old_dim.row_expired_dt is null
        and exists (
            select new_dim.tournament_hash_key
            from biz.v_dim_tournaments as new_dim
            where 1=1
                and new_dim.tournament_hash_key = old_dim.tournament_hash_key
                and new_dim.dim_tournament_sk != old_dim.dim_tournament_sk
            );

    get diagnostics v_updated_count = row_count;

    insert into dmart.dim_tournaments (
        dim_tournament_sk
        , tournament_hash_key
        , row_load_dt
        , row_expired_dt
        , tournament_bk
        , tournament_name
        , country_name
        , tournament_level
        , surface
        , tourn_start_date
        , tourn_end_date
    )
    select distinct
        dim_tournament_sk
        , tournament_hash_key
        , load_dt as row_load_dt
        , null::timestamp as row_expired_dt
        , tournament_bk
        , tournament_name
        , country_name
        , tournament_level
        , surface
        , tourn_start_date
        , tourn_end_date
    from biz.v_dim_tournaments as vdt
    where not exists (
        select dt.tournament_hash_key
        from dmart.dim_tournaments as dt
        where 1=1
            and dt.tournament_hash_key = vdt.tournament_hash_key
            and dt.dim_tournament_sk = vdt.dim_tournament_sk
            and dt.row_expired_dt is null
        );

    get diagnostics v_record_count = row_count;

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_dim_tournaments', v_record_count, 'Dimension loaded successfully');

    f_record_inserted = v_record_count;
    f_record_updated = v_updated_count;

    raise info 'Table dim_tournaments loaded successfully! Records inserted: %. Records updated: %', f_record_inserted, f_record_updated;

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_dim_tournaments', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;



-- ========== dim_matches ========== --
-- DMART --
create or replace procedure dmart.sp_load_dim_matches(
    in f_run_id VARCHAR
    , in f_load_date TIMESTAMP
    , inout f_rec_src VARCHAR
    , inout f_record_inserted INT
    , inout f_record_updated INT
    , inout f_error_num INT
    , inout f_error_message VARCHAR
)
language plpgsql
as $$
declare
    v_record_count INT;
    v_updated_count INT;
    v_deleted_count INT;
begin
    lock table dmart.dim_matches;

    update dmart.dim_matches as old_dim
    set row_expired_dt = f_load_date - interval '1 second'
    where 1=1
        and old_dim.row_expired_dt is null
        and not exists (
            select new_dim.match_hash_key
            from biz.v_dim_matches as new_dim
            where new_dim.match_hash_key = old_dim.match_hash_key
        );

    get diagnostics v_deleted_count = row_count;

    update dmart.dim_matches as old_dim
    set row_expired_dt = f_load_date - interval '1 second'
    where 1=1
        and old_dim.row_expired_dt is null
        and exists (
            select new_dim.match_hash_key
            from biz.v_dim_matches as new_dim
            where 1=1
                and new_dim.match_hash_key = old_dim.match_hash_key
                and new_dim.dim_match_sk != old_dim.dim_match_sk
        );

    get diagnostics v_updated_count = row_count;

    insert into dmart.dim_matches (
        dim_match_sk
        , match_hash_key
        , row_load_dt
        , row_expired_dt
        , match_bk
        , date_of_match
        , match_round
        , first_set_score
        , second_set_score
        , third_set_score
        , final_score
        , match_duration
    )
    select distinct
        dim_match_sk
        , match_hash_key
        , load_dt as row_load_dt
        , null::timestamp as row_expired_dt
        , match_bk
        , date_of_match
        , match_round
        , first_set_score
        , second_set_score
        , third_set_score
        , final_score
        , match_duration
    from biz.v_dim_matches as vdm
    where not exists (
        select dm.match_hash_key
        from dmart.dim_matches as dm
        where 1=1
            and dm.match_hash_key = vdm.match_hash_key
            and dm.dim_match_sk = vdm.dim_match_sk
            and dm.row_expired_dt is null
    );

    get diagnostics v_record_count = row_count;

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_dim_matches', v_record_count, 'Dimension loaded successfully');

    f_record_inserted = v_record_count;
    f_record_updated = v_updated_count;

    raise info 'Table dim_matches loaded successfully! Records inserted: %. Records updated: %', f_record_inserted, f_record_updated;

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_dim_matches', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;



-- ========== fct_coaching_contracts ========== --
-- DMART --
-- Wymaga wcześniej załadowanych dmart.dim_players i dmart.dim_coaches (patrz biz.v_fct_coaching_contracts).
create or replace procedure dmart.sp_load_fct_coaching_contracts(
    in f_run_id VARCHAR
    , in f_load_date TIMESTAMP
    , inout f_rec_src VARCHAR
    , inout f_record_inserted INT
    , inout f_record_updated INT
    , inout f_error_num INT
    , inout f_error_message VARCHAR
)
language plpgsql
as $$
declare
    v_record_count INT;
    v_updated_count INT;
begin
    lock table dmart.fct_coaching_contracts;

    update dmart.fct_coaching_contracts as old_fct
    set row_expired_dt = f_load_date - interval '1 second'
    where 1=1
        and old_fct.row_expired_dt is null
        and not exists (
            select new_fct.coaching_contract_hash_key
            from biz.v_fct_coaching_contracts as new_fct
            where new_fct.coaching_contract_hash_key = old_fct.coaching_contract_hash_key
        );

    update dmart.fct_coaching_contracts old_fct
    set row_expired_dt = f_load_date - interval '1 second'
    where old_fct.row_expired_dt is null
      and exists (
          select new_fct.coaching_contract_hash_key
          from biz.v_fct_coaching_contracts new_fct
          where 1=1
            and new_fct.coaching_contract_hash_key = old_fct.coaching_contract_hash_key
            and new_fct.fct_coaching_contract_sk != old_fct.fct_coaching_contract_sk
      );

    get diagnostics v_updated_count = row_count;

    insert into dmart.fct_coaching_contracts (
        fct_coaching_contract_sk
        , coaching_contract_hash_key
        , row_load_dt
        , row_expired_dt
        , dim_player_sk
        , dim_coach_sk
        , is_active
    )
    select distinct
        fct_coaching_contract_sk
        , coaching_contract_hash_key
        , load_dt as row_load_dt
        , null::timestamp as row_expired_dt
        , dim_player_sk
        , dim_coach_sk
        , is_active
    from biz.v_fct_coaching_contracts as vfcc
    where not exists (
        select 1
        from dmart.fct_coaching_contracts as fcc
        where 1=1
            and fcc.coaching_contract_hash_key = vfcc.coaching_contract_hash_key
            and fcc.fct_coaching_contract_sk = vfcc.fct_coaching_contract_sk
            and fcc.row_expired_dt is null
    );

    get diagnostics v_record_count = row_count;

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_fct_coaching_contracts', v_record_count, 'Fact table loaded successfully');

    f_record_inserted = v_record_count;
    f_record_updated = v_updated_count;

    raise info 'Table fct_coaching_contracts loaded successfully! Records inserted: %. Records updated: %', f_record_inserted, f_record_updated;

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_fct_coaching_contracts', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;



-- ========== fct_match_statistics ========== --
-- DMART --
-- Wymaga wcześniej załadowanych dmart.dim_matches, dmart.dim_players, dmart.dim_tournaments.
create or replace procedure dmart.sp_load_fct_match_statistics(
    in f_run_id VARCHAR
    , in f_load_date TIMESTAMP
    , inout f_rec_src VARCHAR
    , inout f_record_inserted INT
    , inout f_record_updated INT
    , inout f_error_num INT
    , inout f_error_message VARCHAR
)
language plpgsql
as $$
declare
    v_record_count INT;
    v_updated_count INT;
begin
    lock table dmart.fct_match_statistics;

    update dmart.fct_match_statistics as old_fct
    set row_expired_dt = f_load_date - interval '1 second'
    where 1=1
        and old_fct.row_expired_dt is null
        and not exists (
            select new_fct.match_statistics_hash_key
            from biz.v_fct_match_statistics as new_fct
            where new_fct.match_statistics_hash_key = old_fct.match_statistics_hash_key
        );

    update dmart.fct_match_statistics old_fct
    set row_expired_dt = f_load_date - interval '1 second'
    where old_fct.row_expired_dt is null
      and exists (
          select new_fct.match_statistics_hash_key
          from biz.v_fct_match_statistics new_fct
          where 1=1
            and new_fct.match_statistics_hash_key = old_fct.match_statistics_hash_key
            and new_fct.fct_match_statistics_sk != old_fct.fct_match_statistics_sk
      );

    get diagnostics v_updated_count = row_count;

    insert into dmart.fct_match_statistics (
        fct_match_statistics_sk
        , match_statistics_hash_key
        , row_load_dt
        , row_expired_dt
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
    )
    select distinct
        fct_match_statistics_sk
        , match_statistics_hash_key
        , load_dt as row_load_dt
        , null::timestamp as row_expired_dt
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
    from biz.v_fct_match_statistics as vfms
    where not exists (
        select fms.match_statistics_hash_key
        from dmart.fct_match_statistics as fms
        where 1=1
            and fms.match_statistics_hash_key = vfms.match_statistics_hash_key
            and fms.fct_match_statistics_sk = vfms.fct_match_statistics_sk
            and fms.row_expired_dt is null
    );

    get diagnostics v_record_count = row_count;

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_fct_match_statistics', v_record_count, 'Fact table loaded successfully');

    f_record_inserted = v_record_count;
    f_record_updated = v_updated_count;

    raise info 'Table fct_match_statistics loaded successfully! Records inserted: %. Records updated: %', f_record_inserted, f_record_updated;

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_fct_match_statistics', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;


--rollback DROP PROCEDURE IF EXISTS dmart.sp_load_fct_match_statistics;
--rollback DROP PROCEDURE IF EXISTS dmart.sp_load_fct_coaching_contracts;
--rollback DROP PROCEDURE IF EXISTS dmart.sp_load_dim_matches;
--rollback DROP PROCEDURE IF EXISTS dmart.sp_load_dim_tournaments;
--rollback DROP PROCEDURE IF EXISTS dmart.sp_load_dim_coaches;
--rollback DROP PROCEDURE IF EXISTS dmart.sp_load_dim_players;
--rollback DROP PROCEDURE IF EXISTS dmart.sp_load_ref_country;
