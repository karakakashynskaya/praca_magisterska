--liquibase formatted sql
--changeset kkakashynskaya:23-star-proc-facts splitStatements:false runOnChange:true

-- ========== fct_coaching_contracts ========== --
-- Wymaga wcześniej załadowanych star.dim_player i star.dim_coach.
create or replace procedure star.sp_load_star_fct_coaching_contracts(
    in f_run_id VARCHAR
    , in f_load_date TIMESTAMP
    , inout f_record_inserted INT
    , inout f_record_expired INT
    , inout f_error_num INT
    , inout f_error_message VARCHAR
)
language plpgsql
as $$
declare
    v_record_count INT;
    v_expired_count INT := 0;
begin
    create temp table tmp_fct_cc_candidate as
    select
        rcc.player_bk || ';' || rcc.coach_bk as contract_bk
        , dp.dim_player_sk
        , dc.dim_coach_sk
        , rcc.is_active
        , md5(upper(trim(coalesce(rcc.is_active::text, '')))) as attr_hash
    from stg.raw_coaching_contracts as rcc
    left join star.dim_player as dp
        on dp.player_bk = rcc.player_bk and dp.is_current
    left join star.dim_coach as dc
        on dc.coach_bk = rcc.coach_bk and dc.is_current;

    update star.fct_coaching_contracts as f
    set is_current = false, row_expiry_dt = f_load_date - interval '1 second'
    where f.is_current
        and not exists (
            select 1 from tmp_fct_cc_candidate as c
            where c.contract_bk = f.contract_bk
        );
    get diagnostics v_expired_count = row_count;

    update star.fct_coaching_contracts as f
    set is_current = false, row_expiry_dt = f_load_date - interval '1 second'
    where f.is_current
        and exists (
            select 1 from tmp_fct_cc_candidate as c
            where c.contract_bk = f.contract_bk
                and c.attr_hash != f.attr_hash
        );
    get diagnostics v_record_count = row_count;
    v_expired_count := v_expired_count + v_record_count;

    insert into star.fct_coaching_contracts (
        fct_coaching_contract_sk, contract_bk, row_effective_dt, row_expiry_dt, is_current,
        dim_player_sk, dim_coach_sk, is_active, attr_hash
    )
    select
        md5(c.contract_bk || ';' || upper(trim(coalesce(f_load_date::text, '')))) as fct_coaching_contract_sk
        , c.contract_bk
        , f_load_date
        , null::timestamp
        , true
        , coalesce(c.dim_player_sk, '-98')
        , coalesce(c.dim_coach_sk, '-98')
        , c.is_active
        , c.attr_hash
    from tmp_fct_cc_candidate as c
    where not exists (
        select 1 from star.fct_coaching_contracts as f
        where f.contract_bk = c.contract_bk
            and f.attr_hash = c.attr_hash
            and f.is_current
    );
    get diagnostics v_record_count = row_count;

    drop table if exists tmp_fct_cc_candidate;

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_star_fct_coaching_contracts', v_record_count, format('Inserted: %s, Expired: %s', v_record_count, v_expired_count));

    f_record_inserted = v_record_count;
    f_record_expired = v_expired_count;

    raise info 'star.fct_coaching_contracts loaded! Inserted=%, Expired=%', v_record_count, v_expired_count;

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_star_fct_coaching_contracts', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;



-- ========== fct_match_statistics ========== --
-- Wymaga wcześniej załadowanych star.dim_match, star.dim_player, star.dim_tournament.
-- Grain: jeden wiersz = jeden mecz (player1 vs player2), tak samo jak w dmart.
create or replace procedure star.sp_load_star_fct_match_statistics(
    in f_run_id VARCHAR
    , in f_load_date TIMESTAMP
    , inout f_record_inserted INT
    , inout f_record_expired INT
    , inout f_error_num INT
    , inout f_error_message VARCHAR
)
language plpgsql
as $$
declare
    v_record_count INT;
    v_expired_count INT := 0;
begin
    create temp table tmp_fct_ms_candidate as
    select
        rm.match_bk
        , coalesce(dm.dim_match_sk, '-98') as dim_match_sk
        , coalesce(dp1.dim_player_sk, '-98') as dim_player1_sk
        , coalesce(dp2.dim_player_sk, '-98') as dim_player2_sk
        , coalesce(dw.dim_player_sk, '-98') as dim_winner_sk
        , coalesce(dt.dim_tournament_sk, '-98') as dim_tournament_sk
        , coalesce(rms1.aces, 0) as player1_aces
        , coalesce(rms2.aces, 0) as player2_aces
        , coalesce(rms1.double_faults, 0) as player1_double_faults
        , coalesce(rms2.double_faults, 0) as player2_double_faults
        , coalesce(rms1.break_points_converted_perc, 0) as player1_break_points_converted_perc
        , coalesce(rms2.break_points_converted_perc, 0) as player2_break_points_converted_perc
        , md5(
            upper(trim(coalesce(rms1.aces::text, ''))) || ';' ||
            upper(trim(coalesce(rms2.aces::text, ''))) || ';' ||
            upper(trim(coalesce(rms1.double_faults::text, ''))) || ';' ||
            upper(trim(coalesce(rms2.double_faults::text, ''))) || ';' ||
            upper(trim(coalesce(rms1.break_points_converted_perc::text, ''))) || ';' ||
            upper(trim(coalesce(rms2.break_points_converted_perc::text, '')))
        ) as attr_hash
    from stg.raw_matches as rm
    left join stg.raw_match_statistics as rms1
        on rms1.match_sk = rm.match_sk and rms1.player_sk = rm.player1_sk
    left join stg.raw_match_statistics as rms2
        on rms2.match_sk = rm.match_sk and rms2.player_sk = rm.player2_sk
    left join star.dim_match as dm
        on dm.match_bk = rm.match_bk and dm.is_current
    left join star.dim_player as dp1
        on dp1.player_bk = rm.player1_bk and dp1.is_current
    left join star.dim_player as dp2
        on dp2.player_bk = rm.player2_bk and dp2.is_current
    left join star.dim_player as dw
        on dw.player_bk = rm.winner_bk and dw.is_current
    left join star.dim_tournament as dt
        on dt.tournament_bk = rm.tournament_bk and dt.is_current;

    update star.fct_match_statistics as f
    set is_current = false, row_expiry_dt = f_load_date - interval '1 second'
    where f.is_current
        and not exists (
            select 1 from tmp_fct_ms_candidate as c
            where c.match_bk = f.match_bk
        );
    get diagnostics v_expired_count = row_count;

    update star.fct_match_statistics as f
    set is_current = false, row_expiry_dt = f_load_date - interval '1 second'
    where f.is_current
        and exists (
            select 1 from tmp_fct_ms_candidate as c
            where c.match_bk = f.match_bk
                and c.attr_hash != f.attr_hash
        );
    get diagnostics v_record_count = row_count;
    v_expired_count := v_expired_count + v_record_count;

    insert into star.fct_match_statistics (
        fct_match_statistics_sk, match_bk, row_effective_dt, row_expiry_dt, is_current,
        dim_match_sk, dim_player1_sk, dim_player2_sk, dim_winner_sk, dim_tournament_sk,
        player1_aces, player2_aces, player1_double_faults, player2_double_faults,
        player1_break_points_converted_perc, player2_break_points_converted_perc, attr_hash
    )
    select
        md5(c.match_bk || ';' || upper(trim(coalesce(f_load_date::text, '')))) as fct_match_statistics_sk
        , c.match_bk
        , f_load_date
        , null::timestamp
        , true
        , c.dim_match_sk
        , c.dim_player1_sk
        , c.dim_player2_sk
        , c.dim_winner_sk
        , c.dim_tournament_sk
        , c.player1_aces
        , c.player2_aces
        , c.player1_double_faults
        , c.player2_double_faults
        , c.player1_break_points_converted_perc
        , c.player2_break_points_converted_perc
        , c.attr_hash
    from tmp_fct_ms_candidate as c
    where not exists (
        select 1 from star.fct_match_statistics as f
        where f.match_bk = c.match_bk
            and f.attr_hash = c.attr_hash
            and f.is_current
    );
    get diagnostics v_record_count = row_count;

    drop table if exists tmp_fct_ms_candidate;

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_star_fct_match_statistics', v_record_count, format('Inserted: %s, Expired: %s', v_record_count, v_expired_count));

    f_record_inserted = v_record_count;
    f_record_expired = v_expired_count;

    raise info 'star.fct_match_statistics loaded! Inserted=%, Expired=%', v_record_count, v_expired_count;

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_star_fct_match_statistics', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;


--rollback DROP PROCEDURE IF EXISTS star.sp_load_star_fct_match_statistics;
--rollback DROP PROCEDURE IF EXISTS star.sp_load_star_fct_coaching_contracts;
