-- T23 / Star: nowy wymiar + klucz obcy w istniejącej tabeli faktów + zmiana procedury nadrzędnej.
create table if not exists star.dim_round (
    dim_round_sk CHAR(32) not null
    , round_bk VARCHAR(10) not null
    , row_effective_dt TIMESTAMP not null
    , row_expiry_dt TIMESTAMP
    , is_current BOOLEAN not null default true
    , round_name VARCHAR(50)
    , attr_hash CHAR(32) not null
    , primary key (dim_round_sk)
);
create index if not exists ix_dim_round_bk_current on star.dim_round (round_bk) where is_current;

alter table star.fct_match_statistics add column if not exists dim_round_sk CHAR(32);

create or replace procedure star.sp_load_star_rounds(in f_run_id VARCHAR, in f_load_date TIMESTAMP)
language plpgsql
as $$
declare
    v_dim INT;
    v_fct INT;
begin
    update star.dim_round as d
    set is_current = false, row_expiry_dt = f_load_date - interval '1 second'
    where d.is_current
        and exists (
            select 1 from stg.raw_rounds as r
            where r.round_bk = d.round_bk and r.hash_diff <> d.attr_hash
        );

    insert into star.dim_round (dim_round_sk, round_bk, row_effective_dt, row_expiry_dt, is_current, round_name, attr_hash)
    select
        md5(upper(trim(r.round_bk)) || ';' || upper(trim(f_load_date::text)))
        , r.round_bk
        , f_load_date
        , null
        , true
        , r.round_name
        , r.hash_diff
    from stg.raw_rounds as r
    where not exists (
        select 1 from star.dim_round as d
        where d.round_bk = r.round_bk and d.is_current
    );
    get diagnostics v_dim = row_count;

    analyze star.dim_round;

    update star.fct_match_statistics as f
    set dim_round_sk = coalesce(d.dim_round_sk, '-98')
    from star.dim_match as dm
    left join star.dim_round as d
        on d.round_bk = trim(dm.match_round) and d.is_current
    where f.dim_round_sk is null
        and dm.dim_match_sk = f.dim_match_sk;
    get diagnostics v_fct = row_count;

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_star_rounds', v_dim + v_fct, format('dim: %s, fct updated: %s', v_dim, v_fct));

exception when others then
    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_star_rounds', 0, 'Error: ' || substring(sqlerrm, 1, 200));
end;
$$;

create or replace procedure star.sp_load_star_full(
    in f_run_id VARCHAR
    , in f_load_date TIMESTAMP
)
language plpgsql
as $$
declare
    v_rec_src VARCHAR := 'wta_dwh_benchmark';
    v_record_inserted INT := 0;
    v_record_expired INT := 0;
    v_error_num INT := 0;
    v_error_message VARCHAR := '';
begin
    -- ===== STG (wspólny z DV) ===== --

    call stg.sp_load_ref_country(f_run_id, f_load_date, v_rec_src, v_record_inserted, v_error_num, v_error_message);
    call stg.sp_load_players(f_run_id, f_load_date, v_rec_src, v_record_inserted, v_error_num, v_error_message);
    call stg.sp_load_player_physical_details(f_run_id, f_load_date, v_rec_src, v_record_inserted, v_error_num, v_error_message);
    call stg.sp_load_coaches(f_run_id, f_load_date, v_rec_src, v_record_inserted, v_error_num, v_error_message);
    call stg.sp_load_tournaments(f_run_id, f_load_date, v_rec_src, v_record_inserted, v_error_num, v_error_message);
    call stg.sp_load_matches(f_run_id, f_load_date, v_rec_src, v_record_inserted, v_error_num, v_error_message);
    call stg.sp_load_coaching_contracts(f_run_id, f_load_date, v_rec_src, v_record_inserted, v_error_num, v_error_message);
    call stg.sp_load_match_statistics(f_run_id, f_load_date, v_rec_src, v_record_inserted, v_error_num, v_error_message);
    call stg.sp_load_rounds(f_run_id, f_load_date);                        -- T23

    call dbo.sp_analyze_schema('stg');

    -- ===== STAR: dims (niezależne od siebie) ===== --
    call star.sp_load_star_dim_player(f_run_id, f_load_date, v_record_inserted, v_record_expired, v_error_num, v_error_message);
    call star.sp_load_star_dim_coach(f_run_id, f_load_date, v_record_inserted, v_record_expired, v_error_num, v_error_message);
    call star.sp_load_star_dim_tournament(f_run_id, f_load_date, v_record_inserted, v_record_expired, v_error_num, v_error_message);
    call star.sp_load_star_dim_match(f_run_id, f_load_date, v_record_inserted, v_record_expired, v_error_num, v_error_message);

    call dbo.sp_analyze_schema('star');

    -- ===== STAR: facts (zależne od dims powyżej) ===== --
    call star.sp_load_star_fct_coaching_contracts(f_run_id, f_load_date, v_record_inserted, v_record_expired, v_error_num, v_error_message);
    call star.sp_load_star_fct_match_statistics(f_run_id, f_load_date, v_record_inserted, v_record_expired, v_error_num, v_error_message);
    call star.sp_load_star_rounds(f_run_id, f_load_date);                  -- T23

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_star_full', 0, 'Full Star pipeline finished successfully');

    raise info 'Full Star pipeline (sp_load_star_full) finished successfully! run_id=%', f_run_id;

exception when others then
    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_star_full', 0, 'Error: '|| substring(sqlerrm, 1, 200));

    raise info 'An exception occurred in sp_load_star_full: %', sqlerrm;
    raise;
end;
$$;

