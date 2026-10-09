--liquibase formatted sql
--changeset kkakashynskaya:16-dv-orchestrator splitStatements:false runOnChange:true

-----------------------------------------------------------------------------
-- ===== DBO: WSZYSTKIE HUBY ===== --
create or replace procedure dbo.sp_load_all_hubs(
    in f_run_id VARCHAR
    , in f_load_date TIMESTAMP
    , inout f_rec_src VARCHAR
    , inout f_record_inserted INT
    , inout f_error_num INT
    , inout f_error_message VARCHAR
)
language plpgsql
as $$
begin
    f_error_num = 0;
    f_error_message = '';

    begin
        call dbo.sp_load_hub_players(f_run_id, f_load_date, f_rec_src, f_record_inserted, f_error_num, f_error_message);
        call dbo.sp_load_ref_country(f_run_id, f_load_date, f_rec_src, f_record_inserted, f_error_num, f_error_message);
        call dbo.sp_load_hub_coaches(f_run_id, f_load_date, f_rec_src, f_record_inserted, f_error_num, f_error_message);
        call dbo.sp_load_hub_tournaments(f_run_id, f_load_date, f_rec_src, f_record_inserted, f_error_num, f_error_message);
        call dbo.sp_load_hub_matches(f_run_id, f_load_date, f_rec_src, f_record_inserted, f_error_num, f_error_message);

        raise info 'The stored procedures (dbo load_all_hubs) finished successfully!';

    exception when others then
        f_error_num = -1;
        f_error_message = substring(sqlerrm, 1, 200);

        insert into stg.log_table (run_id, object_name, records_count, message)
        values (f_run_id, 'sp_load_all_hubs', 0, 'Error: '|| f_error_message);

        raise info 'An exception occurred %', sqlerrm;
    end;
end;
$$;



-----------------------------------------------------------------------------
-- ===== DBO: WSZYSTKIE LINKI ===== --
-- (zależą od hubów — wywoływane po sp_load_all_hubs)
create or replace procedure dbo.sp_load_all_links(
    in f_run_id VARCHAR
    , in f_load_date TIMESTAMP
    , inout f_rec_src VARCHAR
    , inout f_record_inserted INT
    , inout f_error_num INT
    , inout f_error_message VARCHAR
)
language plpgsql
as $$
begin
    f_error_num = 0;
    f_error_message = '';

    begin
        call dbo.sp_load_link_coaching_contracts(f_run_id, f_load_date, f_rec_src, f_record_inserted, f_error_num, f_error_message);
        call dbo.sp_load_link_match_tournament(f_run_id, f_load_date, f_rec_src, f_record_inserted, f_error_num, f_error_message);
        call dbo.sp_load_link_match_player(f_run_id, f_load_date, f_rec_src, f_record_inserted, f_error_num, f_error_message);
        call dbo.sp_load_link_match_statistics(f_run_id, f_load_date, f_rec_src, f_record_inserted, f_error_num, f_error_message);

        raise info 'The stored procedures (dbo load_all_links) finished successfully!';

    exception when others then
        f_error_num = -1;
        f_error_message = substring(sqlerrm, 1, 200);

        insert into stg.log_table (run_id, object_name, records_count, message)
        values (f_run_id, 'sp_load_all_links', 0, 'Error: '|| f_error_message);

        raise info 'An exception occurred %', sqlerrm;
    end;
end;
$$;



-----------------------------------------------------------------------------
-- ===== DBO: WSZYSTKIE SATELITY ===== --
-- Kolejność ma znaczenie: najpierw satelity biznesowe (żeby wykryć zmiany
-- danych w tym samym load_dt), dopiero potem satelity statusu (CRUD),
-- które sprawdzają, czy w danym load_dt pojawił się nowy wiersz w satelicie
-- biznesowym — patrz warunek "status = 'U'" w każdej sp_load_sat_*_status.
-- Między obiema grupami odświeżane są statystyki planera, bo satelity statusu
-- czytają świeżo załadowane satelity biznesowe (ta sama transakcja).
create or replace procedure dbo.sp_load_all_sat(
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
begin
    f_error_num = 0;
    f_error_message = '';

    begin
        -- satelity biznesowe --
        call dbo.sp_load_sat_player_date_of_birth(f_run_id, f_load_date, f_rec_src, f_record_inserted, f_record_updated, f_error_num, f_error_message);
        call dbo.sp_load_sat_player_personal_info(f_run_id, f_load_date, f_rec_src, f_record_inserted, f_record_updated, f_error_num, f_error_message);
        call dbo.sp_load_sat_player_physical_details(f_run_id, f_load_date, f_rec_src, f_record_inserted, f_record_updated, f_error_num, f_error_message);
        call dbo.sp_load_sat_coach_personal_info(f_run_id, f_load_date, f_rec_src, f_record_inserted, f_record_updated, f_error_num, f_error_message);
        call dbo.sp_load_sat_tournament_details(f_run_id, f_load_date, f_rec_src, f_record_inserted, f_record_updated, f_error_num, f_error_message);
        call dbo.sp_load_sat_coaching_contract_details(f_run_id, f_load_date, f_rec_src, f_record_inserted, f_record_updated, f_error_num, f_error_message);
        call dbo.sp_load_sat_match_details(f_run_id, f_load_date, f_rec_src, f_record_inserted, f_record_updated, f_error_num, f_error_message);
        call dbo.sp_load_sat_match_player_result(f_run_id, f_load_date, f_rec_src, f_record_inserted, f_record_updated, f_error_num, f_error_message);
        call dbo.sp_load_sat_match_statistics_details(f_run_id, f_load_date, f_rec_src, f_record_inserted, f_record_updated, f_error_num, f_error_message);

        -- statystyki dla satelitów biznesowych przed satelitami statusu --
        call dbo.sp_analyze_schema('dbo');

        -- satelity statusu (CRUD) --
        call dbo.sp_load_sat_player_status(f_run_id, f_load_date, f_rec_src, f_record_inserted, f_record_updated, f_error_num, f_error_message);
        call dbo.sp_load_sat_coach_status(f_run_id, f_load_date, f_rec_src, f_record_inserted, f_record_updated, f_error_num, f_error_message);
        call dbo.sp_load_sat_tournament_status(f_run_id, f_load_date, f_rec_src, f_record_inserted, f_record_updated, f_error_num, f_error_message);
        call dbo.sp_load_sat_match_status(f_run_id, f_load_date, f_rec_src, f_record_inserted, f_record_updated, f_error_num, f_error_message);
        call dbo.sp_load_sat_coaching_contract_status(f_run_id, f_load_date, f_rec_src, f_record_inserted, f_record_updated, f_error_num, f_error_message);
        call dbo.sp_load_sat_match_statistics_status(f_run_id, f_load_date, f_rec_src, f_record_inserted, f_record_updated, f_error_num, f_error_message);

        raise info 'The stored procedures (dbo load_all_sat) finished successfully!';

    exception when others then
        f_error_num = -1;
        f_error_message = substring(sqlerrm, 1, 200);

        insert into stg.log_table (run_id, object_name, records_count, message)
        values (f_run_id, 'sp_load_all_sat', 0, 'Error: '|| f_error_message);

        raise info 'An exception occurred %', sqlerrm;
    end;
end;
$$;



-----------------------------------------------------------------------------
-- ===== JEDEN PUNKT WEJŚCIA DLA CAŁEGO PIPELINE'U DV ===== --
-- Wywołanie z zewnątrz (harness benchmarkowy): CALL dbo.sp_load_all_dv('run_123', now());
-- Kolejność: STG (buffer -> raw, per encja) -> HUB -> LINK -> SAT (biznesowe, potem status).
-- Przed każdą warstwą czytającą dane poprzedniej warstwy odświeżane są statystyki planera.
create or replace procedure dbo.sp_load_all_dv(
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
    -- ===== STG ===== --
    call stg.sp_load_ref_country(f_run_id, f_load_date, v_rec_src, v_record_inserted, v_error_num, v_error_message);
    call stg.sp_load_players(f_run_id, f_load_date, v_rec_src, v_record_inserted, v_error_num, v_error_message);
    call stg.sp_load_player_physical_details(f_run_id, f_load_date, v_rec_src, v_record_inserted, v_error_num, v_error_message);
    call stg.sp_load_coaches(f_run_id, f_load_date, v_rec_src, v_record_inserted, v_error_num, v_error_message);
    call stg.sp_load_tournaments(f_run_id, f_load_date, v_rec_src, v_record_inserted, v_error_num, v_error_message);
    call stg.sp_load_matches(f_run_id, f_load_date, v_rec_src, v_record_inserted, v_error_num, v_error_message);
    call stg.sp_load_coaching_contracts(f_run_id, f_load_date, v_rec_src, v_record_inserted, v_error_num, v_error_message);
    call stg.sp_load_match_statistics(f_run_id, f_load_date, v_rec_src, v_record_inserted, v_error_num, v_error_message);

    call dbo.sp_analyze_schema('stg');

    -- ===== DBO ===== --
    call dbo.sp_load_all_hubs(f_run_id, f_load_date, v_rec_src, v_record_inserted, v_error_num, v_error_message);
    call dbo.sp_analyze_schema('dbo');

    call dbo.sp_load_all_links(f_run_id, f_load_date, v_rec_src, v_record_inserted, v_error_num, v_error_message);
    call dbo.sp_analyze_schema('dbo');

    call dbo.sp_load_all_sat(f_run_id, f_load_date, v_rec_src, v_record_inserted, v_record_updated, v_error_num, v_error_message);

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_all_dv', 0, 'Full DV pipeline finished successfully');

    raise info 'Full DV pipeline (sp_load_all_dv) finished successfully! run_id=%', f_run_id;

exception when others then
    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_all_dv', 0, 'Error: '|| substring(sqlerrm, 1, 200));

    raise info 'An exception occurred in sp_load_all_dv: %', sqlerrm;
    raise;
end;
$$;


--rollback DROP PROCEDURE IF EXISTS dbo.sp_load_all_dv;
--rollback DROP PROCEDURE IF EXISTS dbo.sp_load_all_sat;
--rollback DROP PROCEDURE IF EXISTS dbo.sp_load_all_links;
--rollback DROP PROCEDURE IF EXISTS dbo.sp_load_all_hubs;