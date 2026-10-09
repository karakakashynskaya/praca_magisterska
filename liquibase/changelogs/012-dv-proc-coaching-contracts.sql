--liquibase formatted sql
--changeset kkakashynskaya:12-dv-proc-coaching-contracts splitStatements:false runOnChange:true

-----------------------------------------------------------------------------
-- ====== COACHING_CONTRACTS ====== --

-- 1.a. stg.sp_truncate_buffer_coaching_contracts
create or replace procedure stg.sp_truncate_buffer_coaching_contracts(
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
    truncate table stg.buffer_coaching_contracts;

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_truncate_buffer_coaching_contracts', 0, 'Buffer truncated successfully');

    raise info 'Table buffer_coaching_contracts truncated successfully!';

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_truncate_buffer_coaching_contracts', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;



-- 1.b. stg.sp_load_buffer_coaching_contracts
create or replace procedure stg.sp_load_buffer_coaching_contracts(
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
    copy stg.buffer_coaching_contracts
    from '/var/lib/postgresql/import/data_src/coachingcontracts.csv'
    with (
        format csv,
        header true,
        delimiter ','
    );

    select count(*) into v_record_count from stg.buffer_coaching_contracts;

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_buffer_coaching_contracts', v_record_count, 'Buffer loaded successfully');

    f_record_inserted = v_record_count;

    raise info 'Table buffer_coaching_contracts loaded successfully! Records inserted: %', f_record_inserted;

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_buffer_coaching_contracts', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;



-- 1.c. stg.sp_truncate_raw_coaching_contracts
create or replace procedure stg.sp_truncate_raw_coaching_contracts(
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
    truncate table stg.raw_coaching_contracts;

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_truncate_raw_coaching_contracts', 0, 'Raw table truncated successfully');

    raise info 'Table raw_coaching_contracts truncated successfully!';

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_truncate_raw_coaching_contracts', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;



-- 1.d. stg.sp_load_raw_coaching_contracts
create or replace procedure stg.sp_load_raw_coaching_contracts(
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
    create temp table tmp_raw_coaching_contracts (
        player_id_src VARCHAR
        , coach_id_src VARCHAR
        , is_active_src VARCHAR
        , player_id VARCHAR(100)
        , coach_id VARCHAR(100)
        , is_active BOOLEAN
    );

    insert into tmp_raw_coaching_contracts (
        player_id_src, coach_id_src, is_active_src,
        player_id, coach_id, is_active
    )
    select
        player_id, coach_id, is_active
        , case when player_id is not null and length(trim(player_id)) <= 100
            then player_id else null end
        , case when coach_id is not null and length(trim(coach_id)) <= 100
            then coach_id else null end
        , case when is_active is not null
            then cast(is_active as boolean) else null end
    from stg.buffer_coaching_contracts;

    -- WSTAWIANIE POPRAWNYCH REKORDÓW DO WARSTWY RAW --
    insert into stg.raw_coaching_contracts (
        coaching_contract_sk
        , player_sk
        , player_bk
        , coach_sk
        , coach_bk
        , is_active
        , sat_coaching_contract_details_hash_key
        , rec_src
        , load_dt
        , hash_diff
    )
    with tmp_valid_contracts as (
        select distinct
            md5(upper(trim(coalesce(player_id, '')))) as player_sk
            , upper(trim(coalesce(player_id, ''))) as player_bk
            , md5(upper(trim(coalesce(coach_id, '')))) as coach_sk
            , upper(trim(coalesce(coach_id, ''))) as coach_bk
            , is_active
            , md5(
                upper(trim(coalesce(is_active::text, '')))
            ) as sat_coaching_contract_details_hash_key
            , f_rec_src as rec_src
            , f_load_date as load_dt
            , md5(
                upper(trim(coalesce(is_active::text, '')))
            ) as hash_diff
        from tmp_raw_coaching_contracts
        where 1=1
            and player_id is not null
            and length(trim(player_id)) > 0
            and coach_id is not null
            and length(trim(coach_id)) > 0
            and is_active is not null)
    select
        md5(
            upper(trim(coalesce(player_sk, ''))) || ';' ||
            upper(trim(coalesce(coach_sk, ''))) || ';' ||
            upper(trim(coalesce(is_active::text, '')))
        ) as coaching_contract_sk
        , player_sk
        , player_bk
        , coach_sk
        , coach_bk
        , is_active
        , sat_coaching_contract_details_hash_key
        , rec_src
        , load_dt
        , hash_diff
    from tmp_valid_contracts;

    get diagnostics v_record_count = row_count;
    f_record_inserted = v_record_count;

    truncate table stg.buffer_coaching_contracts_not_valid;

    -- WSTAWIANIE NIEPOPRAWNYCH REKORDÓW --
    insert into stg.buffer_coaching_contracts_not_valid (
        player_id
        , coach_id
        , is_active
        , run_id
        , error_description
    )
    select
        player_id, coach_id, is_active
        , f_run_id as run_id
        , case
            when player_id_src is not null and player_id is null
                then '[player_id]: data would be truncated; '
            else ''
        end ||
        case
            when coach_id_src is not null and coach_id is null
                then '[coach_id]: data would be truncated; '
            else ''
        end ||
        case
            when player_id is null
                then '[player_id]: value should not be null; '
            else ''
        end ||
        case
            when coach_id is null
                then '[coach_id]: value should not be null; '
            else ''
        end ||
        case
            when is_active is null
                then '[is_active]: value should not be null; '
            else ''
        end as error_description
    from tmp_raw_coaching_contracts
    where 1=1
        and (player_id_src is not null and player_id is null)
        or (coach_id_src is not null and coach_id is null)
        or (player_id is null or length(trim(player_id)) = 0)
        or (coach_id is null or length(trim(coach_id)) = 0)
        or is_active is null;

    drop table if exists tmp_raw_coaching_contracts;

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_raw_coaching_contracts', v_record_count, 'Raw table loaded successfully');

    raise info 'Table raw_coaching_contracts loaded successfully! Records inserted: %', f_record_inserted;

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_raw_coaching_contracts', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;



-- 1. stg.sp_load_coaching_contracts
create or replace procedure stg.sp_load_coaching_contracts(
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
    f_record_inserted = 0;
    f_error_num = 0;
    f_error_message = '';

    begin
        call stg.sp_truncate_buffer_coaching_contracts(f_run_id, f_load_date, f_rec_src, f_record_inserted, f_error_num, f_error_message);
        call stg.sp_load_buffer_coaching_contracts(f_run_id, f_load_date, f_rec_src, f_record_inserted, f_error_num, f_error_message);
        call stg.sp_truncate_raw_coaching_contracts(f_run_id, f_load_date, f_rec_src, f_record_inserted, f_error_num, f_error_message);
        call stg.sp_load_raw_coaching_contracts(f_run_id, f_load_date, f_rec_src, f_record_inserted, f_error_num, f_error_message);

        raise info 'The stored procedures (staging coaching_contracts) finished successfully!';

    exception when others then
        f_error_num = -1;
        f_error_message = substring(sqlerrm, 1, 200);

        insert into stg.log_table (run_id, object_name, records_count, message)
        values (f_run_id, 'sp_load_coaching_contracts', 0, 'Error: '|| f_error_message);

        raise info 'An exception occurred %', sqlerrm;
    end;
end;
$$;



-----------------------------------------------------------------------------
-- ===== POZIOM DBO ===== --
-- ===== SATELITA STATUSU (pełna logika CRUD) ===== --
create or replace procedure dbo.sp_load_sat_coaching_contract_status(
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
    v_create_count INT := 0;
    v_delete_count INT := 0;
    v_update_count INT := 0;
begin

    -- CRUD: Delete, status = 'D' (rekord zniknął ze źródła)
    insert into dbo.sat_coaching_contract_status (coaching_contract_sk, load_dt, load_end_dt, rec_src, status)
    select distinct
        lcc.coaching_contract_sk
        , f_load_date
        , null::timestamp
        , f_rec_src
        , 'D'
    from dbo.link_coaching_contracts as lcc
    where 1=1
        and exists (
            select sccs.coaching_contract_sk
            from dbo.sat_coaching_contract_status as sccs
            where sccs.coaching_contract_sk = lcc.coaching_contract_sk
                and sccs.status in ('C', 'U')
                and sccs.load_end_dt is null
        )
        and not exists (
            select rcc.coaching_contract_sk
            from stg.raw_coaching_contracts as rcc
            where rcc.coaching_contract_sk = lcc.coaching_contract_sk
        )
        and not exists (
            select sccs.coaching_contract_sk
            from dbo.sat_coaching_contract_status as sccs
            where sccs.coaching_contract_sk = lcc.coaching_contract_sk
                and sccs.status = 'D'
                and sccs.load_end_dt is null
    );

    get diagnostics v_delete_count = row_count;

    update dbo.sat_coaching_contract_status as old_sat
    set load_end_dt = f_load_date - interval '1 second'
    where old_sat.load_end_dt is null
        and old_sat.status in ('C', 'U')
        and old_sat.load_dt < f_load_date
        and exists (
            select new_sat.coaching_contract_sk
            from dbo.sat_coaching_contract_status as new_sat
            where 1=1
                and new_sat.coaching_contract_sk = old_sat.coaching_contract_sk
                and new_sat.status = 'D'
                and new_sat.load_dt = f_load_date
        );


    -- CRUD: Create, status = 'C' (nowy rekord, nigdy wcześniej w dbo)
    insert into dbo.sat_coaching_contract_status (coaching_contract_sk, load_dt, load_end_dt, rec_src, status)
    select distinct
        rcc.coaching_contract_sk
        , f_load_date
        , null::timestamp
        , f_rec_src
        , 'C'
    from stg.raw_coaching_contracts as rcc
    where not exists (
            select sccs.coaching_contract_sk
            from dbo.sat_coaching_contract_status as sccs
            where sccs.coaching_contract_sk = rcc.coaching_contract_sk
        )
        and not exists (
            select sccs.coaching_contract_sk
            from dbo.sat_coaching_contract_status as sccs
            where sccs.coaching_contract_sk = rcc.coaching_contract_sk
                and sccs.load_dt = f_load_date
        );

    get diagnostics v_create_count = row_count;


    -- CRUD: Create, status = 'C' (rekord wraca po wcześniejszym usunięciu)
    insert into dbo.sat_coaching_contract_status (coaching_contract_sk, load_dt, load_end_dt, rec_src, status)
    select distinct
        rcc.coaching_contract_sk
        , f_load_date
        , null::timestamp
        , f_rec_src
        , 'C'
    from stg.raw_coaching_contracts as rcc
    where exists (
            select sccs.coaching_contract_sk
            from dbo.sat_coaching_contract_status as sccs
            where 1=1
                and sccs.coaching_contract_sk = rcc.coaching_contract_sk
                and sccs.status = 'D'
                and sccs.load_end_dt is null
        )
        and not exists (
            select sccs.coaching_contract_sk
            from dbo.sat_coaching_contract_status as sccs
            where sccs.coaching_contract_sk = rcc.coaching_contract_sk
                and sccs.load_dt = f_load_date
        );

    get diagnostics v_update_count = row_count;
    v_create_count := v_create_count + v_update_count;

    update dbo.sat_coaching_contract_status as old_sat
    set load_end_dt = f_load_date - interval '1 second'
    where old_sat.load_end_dt is null
        and old_sat.status = 'D'
        and old_sat.load_dt < f_load_date
        and exists (
            select new_sat.coaching_contract_sk
            from dbo.sat_coaching_contract_status as new_sat
            where 1=1
                and new_sat.coaching_contract_sk = old_sat.coaching_contract_sk
                and new_sat.status = 'C'
                and new_sat.load_dt = f_load_date
        );


    -- statystyki planera po wstawieniu wierszy 'C'/'D' w tej samej transakcji;
    -- bez tego planer zakłada pustą tabelę (rows=1) i wybiera Nested Loop O(n^2)
    analyze dbo.sat_coaching_contract_status;

    -- CRUD: Update, status = 'U' (dane rekordu się zmieniły)
    insert into dbo.sat_coaching_contract_status (coaching_contract_sk, load_dt, load_end_dt, rec_src, status)
    select distinct
        rcc.coaching_contract_sk
        , f_load_date
        , null::timestamp
        , f_rec_src
        , 'U'
    from stg.raw_coaching_contracts as rcc
    where exists (
            select sccs.coaching_contract_sk
            from dbo.sat_coaching_contract_status as sccs
            where 1=1 and
                sccs.coaching_contract_sk = rcc.coaching_contract_sk
                and sccs.status in ('C', 'U')
                and sccs.load_dt < f_load_date
                and not exists (
                  select sccs2.coaching_contract_sk
                  from dbo.sat_coaching_contract_status as sccs2
                  where 1=1
                    and sccs2.coaching_contract_sk = sccs.coaching_contract_sk
                    and sccs2.load_dt > sccs.load_dt
              )
        )
        and exists (
            select sccd.coaching_contract_sk
            from dbo.sat_coaching_contract_details as sccd
            where 1=1
                and sccd.coaching_contract_sk = rcc.coaching_contract_sk
                and sccd.load_dt = f_load_date
        )
        and not exists (
            select sccs.coaching_contract_sk
            from dbo.sat_coaching_contract_status as sccs
            where sccs.coaching_contract_sk = rcc.coaching_contract_sk
                and sccs.load_dt = f_load_date
        );

    get diagnostics v_update_count = row_count;

    update dbo.sat_coaching_contract_status as old_sat
    set load_end_dt = f_load_date - interval '1 second'
    where old_sat.load_end_dt is null
        and old_sat.status in ('C', 'U')
        and old_sat.load_dt < f_load_date
        and exists (
            select new_sat.coaching_contract_sk
            from dbo.sat_coaching_contract_status as new_sat
            where 1=1
                and new_sat.coaching_contract_sk = old_sat.coaching_contract_sk
                and new_sat.status = 'U'
                and new_sat.load_dt = f_load_date
        );

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_sat_coaching_contract_status', v_create_count + v_delete_count + v_update_count,
            format('Created: %s, Deleted: %s, Updated: %s', v_create_count, v_delete_count, v_update_count));

    f_record_inserted = v_create_count + v_update_count;
    f_record_updated = v_delete_count;

    raise info 'Table sat_coaching_contract_status loaded successfully: Created=%, Deleted=%, Updated=%',
               v_create_count, v_delete_count, v_update_count;

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_sat_coaching_contract_status', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;



-- ===== LINK ===== --
-- 2.a. dbo.sp_load_link_coaching_contracts
create or replace procedure dbo.sp_load_link_coaching_contracts(
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
    insert into dbo.link_coaching_contracts (
        coaching_contract_sk, rec_src, load_dt, player_sk, coach_sk
    )
    select distinct
        coaching_contract_sk
        , rec_src
        , load_dt
        , player_sk
        , coach_sk
    from stg.v_link_coaching_contracts as vlcc
    where not exists (
        select lcc.coaching_contract_sk
        from dbo.link_coaching_contracts as lcc
        where lcc.coaching_contract_sk = vlcc.coaching_contract_sk
    );

    get diagnostics v_record_count = row_count;

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_link_coaching_contracts', v_record_count, 'Link loaded successfully');

    f_record_inserted = v_record_count;

    raise info 'Table link_coaching_contracts loaded successfully! Records inserted: %', f_record_inserted;

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_link_coaching_contracts', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;



-- ===== SATELITA ===== --
-- 3. dbo.sp_load_sat_coaching_contract_details
create or replace procedure dbo.sp_load_sat_coaching_contract_details(
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
    update dbo.sat_coaching_contract_details as old_sat
    set load_end_dt = f_load_date - interval '1 second'
    where old_sat.load_end_dt is null
      and exists (
          select new_sat.coaching_contract_sk
          from stg.v_sat_coaching_contract_details as new_sat
          where 1=1
            and new_sat.coaching_contract_sk = old_sat.coaching_contract_sk
            and new_sat.hash_diff != old_sat.hash_diff
      );

    get diagnostics v_updated_count = row_count;

    insert into dbo.sat_coaching_contract_details (
        coaching_contract_sk, load_dt, rec_src, load_end_dt, hash_diff, is_active
    )
    select distinct
        coaching_contract_sk
        , load_dt
        , rec_src
        , null::timestamp as load_end_dt
        , hash_diff
        , is_active
    from stg.v_sat_coaching_contract_details as vsccd
    where not exists (
        select sccd.coaching_contract_sk
        from dbo.sat_coaching_contract_details as sccd
        where 1=1
            and sccd.coaching_contract_sk = vsccd.coaching_contract_sk
            and sccd.hash_diff = vsccd.hash_diff
            and sccd.load_end_dt is null
    );

    get diagnostics v_record_count = row_count;

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_sat_coaching_contract_details', v_record_count, 'Satellite loaded successfully');

    f_record_inserted = v_record_count;
    f_record_updated = v_updated_count;

    raise info 'Table sat_coaching_contract_details updated successfully! Records updated: %', f_record_updated;
    raise info 'Table sat_coaching_contract_details loaded successfully! Records inserted: %', f_record_inserted;

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_sat_coaching_contract_details', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;


--rollback DROP PROCEDURE IF EXISTS dbo.sp_load_sat_coaching_contract_details;
--rollback DROP PROCEDURE IF EXISTS dbo.sp_load_link_coaching_contracts;
--rollback DROP PROCEDURE IF EXISTS dbo.sp_load_sat_coaching_contract_status;
--rollback DROP PROCEDURE IF EXISTS stg.sp_load_coaching_contracts;
--rollback DROP PROCEDURE IF EXISTS stg.sp_load_raw_coaching_contracts;
--rollback DROP PROCEDURE IF EXISTS stg.sp_truncate_raw_coaching_contracts;
--rollback DROP PROCEDURE IF EXISTS stg.sp_load_buffer_coaching_contracts;
--rollback DROP PROCEDURE IF EXISTS stg.sp_truncate_buffer_coaching_contracts;