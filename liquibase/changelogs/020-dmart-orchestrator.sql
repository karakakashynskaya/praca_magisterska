--liquibase formatted sql
--changeset kkakashynskaya:20-dmart-orchestrator splitStatements:false runOnChange:true

-- Wywołanie z zewnątrz: CALL dmart.sp_load_dmart('run_123', now());
-- To jest DRUGA połowa pełnego pipeline'u DV — wołana PO dbo.sp_load_all_dv,
-- nie zamiast niej (dmart czyta z biz-views, które czytają z dbo).
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

create or replace procedure dmart.sp_load_dmart(
    in f_run_id VARCHAR
    , in f_load_date TIMESTAMP
)
language plpgsql
as $$
declare
    v_rec_src VARCHAR := 'wta_dwh_benchmark';
    v_record_inserted INT := 0;
    v_record_updated INT := 0;
    v_error_num INT := 0;
    v_error_message VARCHAR := '';
begin
    call dbo.sp_analyze_schema('dbo');
    -- niezależne dimensiony --
    call dmart.sp_load_ref_country(f_run_id, f_load_date, v_rec_src, v_record_inserted, v_error_num, v_error_message);
    call dmart.sp_load_dim_players(f_run_id, f_load_date, v_rec_src, v_record_inserted, v_record_updated, v_error_num, v_error_message);
    call dmart.sp_load_dim_coaches(f_run_id, f_load_date, v_rec_src, v_record_inserted, v_record_updated, v_error_num, v_error_message);
    call dmart.sp_load_dim_tournaments(f_run_id, f_load_date, v_rec_src, v_record_inserted, v_record_updated, v_error_num, v_error_message);
    call dmart.sp_load_dim_matches(f_run_id, f_load_date, v_rec_src, v_record_inserted, v_record_updated, v_error_num, v_error_message);

    call dbo.sp_analyze_schema('dmart');

    -- fakty, zależne od już załadowanych dimensionów powyżej --
    call dmart.sp_load_fct_coaching_contracts(f_run_id, f_load_date, v_rec_src, v_record_inserted, v_record_updated, v_error_num, v_error_message);
    call dmart.sp_load_fct_match_statistics(f_run_id, f_load_date, v_rec_src, v_record_inserted, v_record_updated, v_error_num, v_error_message);

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_dmart', 0, 'Full dmart pipeline finished successfully');

    raise info 'Full dmart pipeline (sp_load_dmart) finished successfully! run_id=%', f_run_id;

exception when others then
    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_dmart', 0, 'Error: '|| substring(sqlerrm, 1, 200));

    raise info 'An exception occurred in sp_load_dmart: %', sqlerrm;
    raise;
end;
$$;


-- Punkt wejścia dla PEŁNEGO pipeline'u DV (stg -> dbo -> dmart) w jednym wywołaniu.
-- To jest procedura, którą będzie mierzył harness benchmarkowy dla architektury Data Vault.
create or replace procedure dbo.sp_load_all_dv_full(
    in f_run_id VARCHAR
    , in f_load_date TIMESTAMP
)
language plpgsql
as $$
begin
    call dbo.sp_load_all_dv(f_run_id, f_load_date);
    call dmart.sp_load_dmart(f_run_id, f_load_date);
end;
$$;


--rollback DROP PROCEDURE IF EXISTS dbo.sp_load_all_dv_full;
--rollback DROP PROCEDURE IF EXISTS dmart.sp_load_dmart;
