--liquibase formatted sql
--changeset kkakashynskaya:22-star-proc-dims splitStatements:false runOnChange:true

-- ========== dim_player ========== --
create or replace procedure star.sp_load_star_dim_player(
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
    create temp table tmp_dim_player_candidate as
    select
        rp.player_bk
        , rp.date_of_birth
        , rp.first_name
        , rp.second_name
        , rc.country_name
        , rp.titles_won
        , rp.is_active
        , rppd.height_cm
        , rppd.weight_kg
        , rppd.dominant_hand
        , md5(
            upper(trim(coalesce(rp.date_of_birth::text, ''))) || ';' ||
            upper(trim(coalesce(rp.first_name, ''))) || ';' ||
            upper(trim(coalesce(rp.second_name, ''))) || ';' ||
            upper(trim(coalesce(rc.country_name, ''))) || ';' ||
            upper(trim(coalesce(rp.titles_won::text, ''))) || ';' ||
            upper(trim(coalesce(rp.is_active::text, ''))) || ';' ||
            upper(trim(coalesce(rppd.height_cm::text, ''))) || ';' ||
            upper(trim(coalesce(rppd.weight_kg::text, ''))) || ';' ||
            upper(trim(coalesce(rppd.dominant_hand, '')))
            ) as attr_hash
    from stg.raw_players as rp
    left join stg.raw_ref_country as rc
        on rp.country = rc.country_code_bk
    left join stg.raw_player_physical_details as rppd
        on rp.player_sk = rppd.player_sk;

    -- soft-delete: gracz zniknął ze źródła
    update star.dim_player as d
    set is_current = false, row_expiry_dt = f_load_date - interval '1 second'
    where d.is_current
        and not exists (
            select 1 from tmp_dim_player_candidate as c
            where c.player_bk = d.player_bk
        );
    get diagnostics v_expired_count = row_count;

    -- expire zmienionej wersji
    update star.dim_player as d
    set is_current = false, row_expiry_dt = f_load_date - interval '1 second'
    where d.is_current
        and exists (
            select 1 from tmp_dim_player_candidate as c
            where c.player_bk = d.player_bk
                and c.attr_hash != d.attr_hash
        );
    get diagnostics v_record_count = row_count;
    v_expired_count := v_expired_count + v_record_count;

    -- insert nowej wersji (nowy bk, lub bk którego aktywna wersja właśnie wygasła)
    insert into star.dim_player (
        dim_player_sk, player_bk, row_effective_dt, row_expiry_dt, is_current,
        date_of_birth, first_name, second_name, country_name, titles_won, is_active,
        height_cm, weight_kg, dominant_hand, attr_hash
    )
    select
        md5(upper(trim(coalesce(c.player_bk, ''))) || ';' || upper(trim(coalesce(f_load_date::text, '')))) as dim_player_sk
        , c.player_bk
        , f_load_date
        , null::timestamp
        , true
        , c.date_of_birth
        , c.first_name
        , c.second_name
        , c.country_name
        , c.titles_won
        , c.is_active
        , c.height_cm
        , c.weight_kg
        , c.dominant_hand
        , c.attr_hash
    from tmp_dim_player_candidate as c
    where not exists (
        select 1 from star.dim_player as d
        where d.player_bk = c.player_bk
            and d.attr_hash = c.attr_hash
            and d.is_current
    );
    get diagnostics v_record_count = row_count;

    drop table if exists tmp_dim_player_candidate;

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_star_dim_player', v_record_count, format('Inserted: %s, Expired: %s', v_record_count, v_expired_count));

    f_record_inserted = v_record_count;
    f_record_expired = v_expired_count;

    raise info 'star.dim_player loaded! Inserted=%, Expired=%', v_record_count, v_expired_count;

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_star_dim_player', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;



-- ========== dim_coach ========== --
create or replace procedure star.sp_load_star_dim_coach(
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
    create temp table tmp_dim_coach_candidate as
    select
        rc.coach_bk
        , rc.first_name
        , rc.second_name
        , rc.career_start_date
        , rc.career_end_date
        , md5(
            upper(trim(coalesce(rc.first_name, ''))) || ';' ||
            upper(trim(coalesce(rc.second_name, ''))) || ';' ||
            upper(trim(coalesce(rc.career_start_date::text, ''))) || ';' ||
            upper(trim(coalesce(rc.career_end_date::text, '')))
        ) as attr_hash
    from stg.raw_coaches as rc;

    update star.dim_coach as d
    set is_current = false, row_expiry_dt = f_load_date - interval '1 second'
    where d.is_current
        and not exists (
            select 1 from tmp_dim_coach_candidate as c
            where c.coach_bk = d.coach_bk
        );
    get diagnostics v_expired_count = row_count;

    update star.dim_coach as d
    set is_current = false, row_expiry_dt = f_load_date - interval '1 second'
    where d.is_current
        and exists (
            select 1 from tmp_dim_coach_candidate as c
            where c.coach_bk = d.coach_bk
                and c.attr_hash != d.attr_hash
        );
    get diagnostics v_record_count = row_count;
    v_expired_count := v_expired_count + v_record_count;

    insert into star.dim_coach (
        dim_coach_sk, coach_bk, row_effective_dt, row_expiry_dt, is_current,
        first_name, second_name, career_start_date, career_end_date, attr_hash
    )
    select
        md5(upper(trim(coalesce(c.coach_bk, ''))) || ';' || upper(trim(coalesce(f_load_date::text, '')))) as dim_coach_sk
        , c.coach_bk
        , f_load_date
        , null::timestamp
        , true
        , c.first_name
        , c.second_name
        , c.career_start_date
        , c.career_end_date
        , c.attr_hash
    from tmp_dim_coach_candidate as c
    where not exists (
        select 1 from star.dim_coach as d
        where d.coach_bk = c.coach_bk
            and d.attr_hash = c.attr_hash
            and d.is_current
    );
    get diagnostics v_record_count = row_count;

    drop table if exists tmp_dim_coach_candidate;

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_star_dim_coach', v_record_count, format('Inserted: %s, Expired: %s', v_record_count, v_expired_count));

    f_record_inserted = v_record_count;
    f_record_expired = v_expired_count;

    raise info 'star.dim_coach loaded! Inserted=%, Expired=%', v_record_count, v_expired_count;

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_star_dim_coach', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;



-- ========== dim_tournament ========== --
create or replace procedure star.sp_load_star_dim_tournament(
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
    create temp table tmp_dim_tournament_candidate as
    select
        rt.tournament_bk
        , rt.tournament_name
        , rt.country as country_name
        , rt.tournament_level
        , rt.surface
        , rt.tourn_start_date
        , rt.tourn_end_date
        , md5(
            upper(trim(coalesce(rt.tournament_name, ''))) || ';' ||
            upper(trim(coalesce(rt.country, ''))) || ';' ||
            upper(trim(coalesce(rt.tournament_level, ''))) || ';' ||
            upper(trim(coalesce(rt.surface, ''))) || ';' ||
            upper(trim(coalesce(rt.tourn_start_date::text, ''))) || ';' ||
            upper(trim(coalesce(rt.tourn_end_date::text, '')))
        ) as attr_hash
    from stg.raw_tournaments as rt;

    update star.dim_tournament as d
    set is_current = false, row_expiry_dt = f_load_date - interval '1 second'
    where d.is_current
        and not exists (
            select 1 from tmp_dim_tournament_candidate as c
            where c.tournament_bk = d.tournament_bk
        );
    get diagnostics v_expired_count = row_count;

    update star.dim_tournament as d
    set is_current = false, row_expiry_dt = f_load_date - interval '1 second'
    where d.is_current
        and exists (
            select 1 from tmp_dim_tournament_candidate as c
            where c.tournament_bk = d.tournament_bk
                and c.attr_hash != d.attr_hash
        );
    get diagnostics v_record_count = row_count;
    v_expired_count := v_expired_count + v_record_count;

    insert into star.dim_tournament (
        dim_tournament_sk, tournament_bk, row_effective_dt, row_expiry_dt, is_current,
        tournament_name, country_name, tournament_level, surface,
        tourn_start_date, tourn_end_date, attr_hash
    )
    select
        md5(upper(trim(coalesce(c.tournament_bk, ''))) || ';' || upper(trim(coalesce(f_load_date::text, '')))) as dim_tournament_sk
        , c.tournament_bk
        , f_load_date
        , null::timestamp
        , true
        , c.tournament_name
        , c.country_name
        , c.tournament_level
        , c.surface
        , c.tourn_start_date
        , c.tourn_end_date
        , c.attr_hash
    from tmp_dim_tournament_candidate as c
    where not exists (
        select 1 from star.dim_tournament as d
        where d.tournament_bk = c.tournament_bk
            and d.attr_hash = c.attr_hash
            and d.is_current
    );
    get diagnostics v_record_count = row_count;

    drop table if exists tmp_dim_tournament_candidate;

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_star_dim_tournament', v_record_count, format('Inserted: %s, Expired: %s', v_record_count, v_expired_count));

    f_record_inserted = v_record_count;
    f_record_expired = v_expired_count;

    raise info 'star.dim_tournament loaded! Inserted=%, Expired=%', v_record_count, v_expired_count;

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_star_dim_tournament', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;



-- ========== dim_match ========== --
create or replace procedure star.sp_load_star_dim_match(
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
    create temp table tmp_dim_match_candidate as
    select
        rm.match_bk
        , rm.date_of_match
        , rm.match_round
        , rm.first_set_score
        , rm.second_set_score
        , rm.third_set_score
        , rm.final_score
        , rm.match_duration
        , md5(
            upper(trim(coalesce(rm.date_of_match::text, ''))) || ';' ||
            upper(trim(coalesce(rm.match_round, ''))) || ';' ||
            upper(trim(coalesce(rm.first_set_score, ''))) || ';' ||
            upper(trim(coalesce(rm.second_set_score, ''))) || ';' ||
            upper(trim(coalesce(rm.third_set_score, ''))) || ';' ||
            upper(trim(coalesce(rm.final_score, ''))) || ';' ||
            upper(trim(coalesce(rm.match_duration::text, '')))
        ) as attr_hash
    from stg.raw_matches as rm;

    update star.dim_match as d
    set is_current = false, row_expiry_dt = f_load_date - interval '1 second'
    where d.is_current
        and not exists (
            select 1 from tmp_dim_match_candidate as c
            where c.match_bk = d.match_bk
        );
    get diagnostics v_expired_count = row_count;

    update star.dim_match as d
    set is_current = false, row_expiry_dt = f_load_date - interval '1 second'
    where d.is_current
        and exists (
            select 1 from tmp_dim_match_candidate as c
            where c.match_bk = d.match_bk
                and c.attr_hash != d.attr_hash
        );
    get diagnostics v_record_count = row_count;
    v_expired_count := v_expired_count + v_record_count;

    insert into star.dim_match (
        dim_match_sk, match_bk, row_effective_dt, row_expiry_dt, is_current,
        date_of_match, match_round, first_set_score, second_set_score,
        third_set_score, final_score, match_duration, attr_hash
    )
    select
        md5(upper(trim(coalesce(c.match_bk, ''))) || ';' || upper(trim(coalesce(f_load_date::text, '')))) as dim_match_sk
        , c.match_bk
        , f_load_date
        , null::timestamp
        , true
        , c.date_of_match
        , c.match_round
        , c.first_set_score
        , c.second_set_score
        , c.third_set_score
        , c.final_score
        , c.match_duration
        , c.attr_hash
    from tmp_dim_match_candidate as c
    where not exists (
        select 1 from star.dim_match as d
        where d.match_bk = c.match_bk
            and d.attr_hash = c.attr_hash
            and d.is_current
    );
    get diagnostics v_record_count = row_count;

    drop table if exists tmp_dim_match_candidate;

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_star_dim_match', v_record_count, format('Inserted: %s, Expired: %s', v_record_count, v_expired_count));

    f_record_inserted = v_record_count;
    f_record_expired = v_expired_count;

    raise info 'star.dim_match loaded! Inserted=%, Expired=%', v_record_count, v_expired_count;

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_star_dim_match', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;


--rollback DROP PROCEDURE IF EXISTS star.sp_load_star_dim_match;
--rollback DROP PROCEDURE IF EXISTS star.sp_load_star_dim_tournament;
--rollback DROP PROCEDURE IF EXISTS star.sp_load_star_dim_coach;
--rollback DROP PROCEDURE IF EXISTS star.sp_load_star_dim_player;
