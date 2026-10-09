--liquibase formatted sql
--changeset kkakashynskaya:24-star-orchestrator splitStatements:false runOnChange:true

-- Punkt wejścia dla PEŁNEGO pipeline'u Star (stg -> dims -> facts) w jednym wywołaniu.
-- Symetryczny do dbo.sp_load_all_dv_full — to jest procedura, którą będzie mierzył
-- harness benchmarkowy dla architektury Star Schema.
-- Uwaga: stg jest WSPÓLNY dla obu architektur (Extract identyczny) — wywołanie
-- tych samych stg.sp_load_* co w DV jest zamierzone, nie duplikacja przez pomyłkę.

create or replace procedure dbo.sp_analyze_schema(in f_schema TEXT)
language plpgsql
as $$
declare
    r record;
begin
    for r in select tablename from pg_tables where schemaname = f_schema loop
        execute format('analyze %I.%I', f_schema, r.tablename);
    end loop;
    -- wpis w logu wyodrębnia koszt odświeżania statystyk jako osobny etap (T2)
    insert into stg.log_table (object_name, records_count, message)
    values ('analyze_' || f_schema, 0, 'Statistics refreshed');
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

    -- statystyki dla tabel obszaru tymczasowego (symetrycznie do DV)
    call dbo.sp_analyze_schema('stg');

    -- ===== STAR: dims (niezależne od siebie) ===== --
    call star.sp_load_star_dim_player(f_run_id, f_load_date, v_record_inserted, v_record_expired, v_error_num, v_error_message);
    call star.sp_load_star_dim_coach(f_run_id, f_load_date, v_record_inserted, v_record_expired, v_error_num, v_error_message);
    call star.sp_load_star_dim_tournament(f_run_id, f_load_date, v_record_inserted, v_record_expired, v_error_num, v_error_message);
    call star.sp_load_star_dim_match(f_run_id, f_load_date, v_record_inserted, v_record_expired, v_error_num, v_error_message);

    -- statystyki dla wymiarów przed ładowaniem faktów (symetrycznie do dmart)
    call dbo.sp_analyze_schema('star');

    -- ===== STAR: facts (zależne od dims powyżej) ===== --
    call star.sp_load_star_fct_coaching_contracts(f_run_id, f_load_date, v_record_inserted, v_record_expired, v_error_num, v_error_message);
    call star.sp_load_star_fct_match_statistics(f_run_id, f_load_date, v_record_inserted, v_record_expired, v_error_num, v_error_message);

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


--rollback DROP PROCEDURE IF EXISTS star.sp_load_star_full;