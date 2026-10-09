--liquibase formatted sql
--changeset kkakashynskaya:11-dv-proc-coaches splitStatements:false runOnChange:true

-----------------------------------------------------------------------------
-- ====== COACHES ====== --

-- 1.a. stg.sp_truncate_buffer_coaches
create or replace procedure stg.sp_truncate_buffer_coaches(
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
    truncate table stg.buffer_coaches;

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_truncate_buffer_coaches', 0, 'Buffer truncated successfully');

    raise info 'Table buffer_coaches truncated successfully!';

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_truncate_buffer_coaches', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;



-- 1.b. stg.sp_load_buffer_coaches
create or replace procedure stg.sp_load_buffer_coaches(
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
    copy stg.buffer_coaches
    from '/var/lib/postgresql/import/data_src/coaches.csv'
    with (
        format csv,
        header true,
        delimiter ','
    );

    select count(*) into v_record_count from stg.buffer_coaches;

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_buffer_coaches', v_record_count, 'Buffer loaded successfully');

    f_record_inserted = v_record_count;

    raise info 'Table buffer_coaches loaded successfully! Records inserted: %', f_record_inserted;

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_buffer_coaches', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;



-- 1.c. stg.sp_truncate_raw_coaches
create or replace procedure stg.sp_truncate_raw_coaches(
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
    truncate table stg.raw_coaches;

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_truncate_raw_coaches', 0, 'Raw table truncated successfully');

    raise info 'Table raw_coaches truncated successfully!';

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_truncate_raw_coaches', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;



-- 1.d. stg.sp_load_raw_coaches
create or replace procedure stg.sp_load_raw_coaches(
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
    create temp table tmp_raw_coaches (
        id_src VARCHAR
        , first_name_src VARCHAR
        , second_name_src VARCHAR
        , career_start_date_src VARCHAR
        , career_end_date_src VARCHAR
        , id VARCHAR(100)
        , first_name VARCHAR(50)
        , second_name VARCHAR(100)
        , career_start_date DATE
        , career_end_date DATE
    );

    insert into tmp_raw_coaches (
        id_src, first_name_src, second_name_src, career_start_date_src, career_end_date_src,
        id, first_name, second_name, career_start_date, career_end_date
    )
    select
        id, first_name, second_name, career_start_date, career_end_date
        , case when id is not null and length(trim(id)) <= 100
            then id else null end
        , case when first_name is not null and length(trim(first_name)) <= 50
            then first_name else null end
        , case when second_name is not null and length(trim(second_name)) <= 100
            then second_name else null end
        , case when career_start_date is not null
            then cast(career_start_date as DATE) else null end
        , case
            when career_end_date is null then null
            when career_start_date is null
                then cast(career_end_date as DATE)
            when cast(career_end_date as DATE) > cast(career_start_date as DATE)
                then cast(career_end_date as DATE)
            else null
        end
    from stg.buffer_coaches;

    -- WSTAWIANIE POPRAWNYCH REKORDÓW DO WARSTWY RAW --
    insert into stg.raw_coaches (
        coach_sk
        , coach_bk
        , first_name
        , second_name
        , career_start_date
        , career_end_date
        , sat_coach_personal_info_hash_key
        , rec_src
        , load_dt
        , hash_diff
    )
    select distinct
        md5(upper(trim(coalesce(id, '')))) as coach_sk
        , upper(trim(coalesce(id, ''))) as coach_bk
        , first_name
        , second_name
        , career_start_date
        , career_end_date
        , md5(
            upper(trim(coalesce(id, ''))) || ';' ||
            upper(trim(coalesce(first_name, ''))) || ';' ||
            upper(trim(coalesce(second_name, ''))) || ';' ||
            upper(trim(coalesce(career_start_date::text, ''))) || ';' ||
            upper(trim(coalesce(career_end_date::text, '')))
        ) as sat_coach_personal_info_hash_key
        , f_rec_src as rec_src
        , f_load_date as load_dt
        , md5(
            upper(trim(coalesce(id, ''))) || ';' ||
            upper(trim(coalesce(first_name, ''))) || ';' ||
            upper(trim(coalesce(second_name, ''))) || ';' ||
            upper(trim(coalesce(career_start_date::text, ''))) || ';' ||
            upper(trim(coalesce(career_end_date::text, '')))
        ) as hash_diff
    from tmp_raw_coaches
    where 1=1
        and id is not null
        and length(trim(id)) > 0
        and first_name is not null
        and second_name is not null;

    get diagnostics v_record_count = row_count;
    f_record_inserted = v_record_count;

    truncate table stg.buffer_coaches_not_valid;

    -- WSTAWIANIE NIEPOPRAWNYCH REKORDÓW --
    insert into stg.buffer_coaches_not_valid (
        id
        , first_name
        , second_name
        , career_start_date
        , career_end_date
        , run_id
        , error_description
    )
    select
        id, first_name, second_name, career_start_date, career_end_date
        , f_run_id as run_id
        , case
            when id_src is not null and id is null
                then '[id]: data would be truncated; '
            else ''
        end ||
        case
            when first_name_src is not null and first_name is null
                then '[first_name]: data would be truncated; '
            else ''
        end ||
        case
            when second_name_src is not null and second_name is null
                then '[second_name]: data would be truncated; '
            else ''
        end ||
        case
            when id is null or length(trim(id)) = 0
                then '[id]: value should not be null; '
            else ''
        end ||
        case
            when first_name is null
                then '[first_name]: value should not be null; '
            else ''
        end ||
        case
            when second_name is null
                then '[second_name]: value should not be null; '
            else ''
        end ||
        case
            when career_end_date_src is not null
                and career_start_date is not null
                and career_end_date is null
                then '[career_end_date]: career_end_date should be later then [career_start_date]; '
            else ''
        end as error_description
    from tmp_raw_coaches
    where 1=1
        and (id_src is not null and id is null)
        or (first_name_src is not null and first_name is null)
        or (second_name_src is not null and second_name is null)
        or (id is null or length(trim(id)) = 0)
        or first_name is null
        or second_name is null
        or (career_end_date_src is not null and career_start_date is not null and career_end_date is null);

    drop table if exists tmp_raw_coaches;

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_raw_coaches', v_record_count, 'Raw table loaded successfully');

    raise info 'Table raw_coaches loaded successfully! Records inserted: %', f_record_inserted;

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_raw_coaches', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;



-- 1. stg.sp_load_coaches
create or replace procedure stg.sp_load_coaches(
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
        call stg.sp_truncate_buffer_coaches(f_run_id, f_load_date, f_rec_src, f_record_inserted, f_error_num, f_error_message);
        call stg.sp_load_buffer_coaches(f_run_id, f_load_date, f_rec_src, f_record_inserted, f_error_num, f_error_message);
        call stg.sp_truncate_raw_coaches(f_run_id, f_load_date, f_rec_src, f_record_inserted, f_error_num, f_error_message);
        call stg.sp_load_raw_coaches(f_run_id, f_load_date, f_rec_src, f_record_inserted, f_error_num, f_error_message);

        raise info 'The stored procedures (staging coaches) finished successfully!';

    exception when others then
        f_error_num = -1;
        f_error_message = substring(sqlerrm, 1, 200);

        insert into stg.log_table (run_id, object_name, records_count, message)
        values (f_run_id, 'sp_load_coaches', 0, 'Error: '|| f_error_message);

        raise info 'An exception occurred %', sqlerrm;
    end;
end;
$$;



-----------------------------------------------------------------------------
-- ===== POZIOM DBO ===== --
-- ===== SATELITA STATUSU (pełna logika CRUD) ===== --
create or replace procedure dbo.sp_load_sat_coach_status(
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
    insert into dbo.sat_coach_status (coach_sk, load_dt, load_end_dt, rec_src, status)
    select distinct
        hc.coach_sk
        , f_load_date
        , null::timestamp
        , f_rec_src
        , 'D'
    from dbo.hub_coaches as hc
    where exists (
            select scs.coach_sk
            from dbo.sat_coach_status as scs
            where 1=1
                and scs.coach_sk = hc.coach_sk
                and scs.status in ('C', 'U')
                and scs.load_end_dt is null
        )
        and not exists (
            select rc.coach_sk
            from stg.raw_coaches as rc
            where rc.coach_sk = hc.coach_sk
        )
        and not exists (
            select scs.coach_sk
            from dbo.sat_coach_status as scs
            where 1=1
                and scs.coach_sk = hc.coach_sk
                and scs.status = 'D'
                and scs.load_end_dt is null
        );

    get diagnostics v_delete_count = row_count;

    update dbo.sat_coach_status as old_sat
    set load_end_dt = f_load_date - interval '1 second'
    where old_sat.load_end_dt is null
        and old_sat.status in ('C', 'U')
        and old_sat.load_dt < f_load_date
        and exists (
            select new_sat.coach_sk
            from dbo.sat_coach_status as new_sat
            where 1=1
                and new_sat.coach_sk = old_sat.coach_sk
                and new_sat.status = 'D'
                and new_sat.load_dt = f_load_date
        );


    -- CRUD: Create, status = 'C' (nowy rekord, nigdy wcześniej w dbo)
    insert into dbo.sat_coach_status (coach_sk, load_dt, load_end_dt, rec_src, status)
    select distinct
        rc.coach_sk
        , f_load_date
        , null::timestamp
        , f_rec_src
        , 'C'
    from stg.raw_coaches as rc
    where not exists (
            select scs.coach_sk
            from dbo.sat_coach_status as scs
            where 1=1
                and scs.coach_sk = rc.coach_sk
        )
        and not exists (
            select scs.coach_sk
            from dbo.sat_coach_status as scs
            where 1=1
                and scs.coach_sk = rc.coach_sk
                and scs.load_dt = f_load_date
        );

    get diagnostics v_create_count = row_count;


    -- CRUD: Create, status = 'C' (rekord wraca po wcześniejszym usunięciu)
    insert into dbo.sat_coach_status (coach_sk, load_dt, load_end_dt, rec_src, status)
    select distinct
        rc.coach_sk
        , f_load_date
        , null::timestamp
        , f_rec_src
        , 'C'
    from stg.raw_coaches as rc
    where exists (
            select scs.coach_sk
            from dbo.sat_coach_status as scs
            where 1=1
                and scs.coach_sk = rc.coach_sk
                and scs.status = 'D'
                and scs.load_end_dt is null
        )
        and not exists (
            select scs.coach_sk
            from dbo.sat_coach_status as scs
            where 1=1
                and scs.coach_sk = rc.coach_sk
                and scs.load_dt = f_load_date
        );

    get diagnostics v_update_count = row_count;
    v_create_count := v_create_count + v_update_count;

    update dbo.sat_coach_status as old_sat
    set load_end_dt = f_load_date - interval '1 second'
    where old_sat.load_end_dt is null
        and old_sat.status = 'D'
        and old_sat.load_dt < f_load_date
        and exists (
            select new_sat.coach_sk
            from dbo.sat_coach_status as new_sat
            where 1=1
                and new_sat.coach_sk = old_sat.coach_sk
                and new_sat.status = 'C'
                and new_sat.load_dt = f_load_date
        );


    -- statystyki planera po wstawieniu wierszy 'C'/'D' w tej samej transakcji;
    -- bez tego planer zakłada pustą tabelę (rows=1) i wybiera Nested Loop O(n^2)
    analyze dbo.sat_coach_status;

    -- CRUD: Update, status = 'U' (dane rekordu się zmieniły)
    insert into dbo.sat_coach_status (coach_sk, load_dt, load_end_dt, rec_src, status)
    select distinct
        rc.coach_sk
        , f_load_date
        , null::timestamp
        , f_rec_src
        , 'U'
    from stg.raw_coaches as rc
    where exists (
            select scs.coach_sk
            from dbo.sat_coach_status as scs
            where 1=1
                and scs.coach_sk = rc.coach_sk
                and scs.status in ('C', 'U')
                and scs.load_dt < f_load_date
                and not exists (
                  select scs2.coach_sk
                  from dbo.sat_coach_status as scs2
                  where 1=1
                    and scs2.coach_sk = scs.coach_sk
                    and scs2.load_dt > scs.load_dt
              )
        )
        and exists
                (select scpi.coach_sk
                 from dbo.sat_coach_personal_info as scpi
                 where 1=1
                    and scpi.coach_sk = rc.coach_sk
                    and scpi.load_dt = f_load_date
        )
        and not exists (
            select scs.coach_sk
            from dbo.sat_coach_status as scs
            where 1=1
                and scs.coach_sk = rc.coach_sk
                and scs.load_dt = f_load_date
        );

    get diagnostics v_update_count = row_count;

    update dbo.sat_coach_status as old_sat
    set load_end_dt = f_load_date - interval '1 second'
    where old_sat.load_end_dt is null
        and old_sat.status in ('C', 'U')
        and old_sat.load_dt < f_load_date
        and exists (
            select new_sat.coach_sk
            from dbo.sat_coach_status as new_sat
            where 1=1
                and new_sat.coach_sk = old_sat.coach_sk
                and new_sat.status = 'U'
                and new_sat.load_dt = f_load_date
        );

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_sat_coach_status', v_create_count + v_delete_count + v_update_count,
            format('Created: %s, Deleted: %s, Updated: %s', v_create_count, v_delete_count, v_update_count));

    f_record_inserted = v_create_count + v_update_count;
    f_record_updated = v_delete_count;

    raise info 'Table sat_coach_status loaded successfully: Created=%, Deleted=%, Updated=%',
               v_create_count, v_delete_count, v_update_count;

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_sat_coach_status', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;



-- ===== HUB ===== --
-- 2.a. dbo.sp_load_hub_coaches
create or replace procedure dbo.sp_load_hub_coaches(
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
    insert into dbo.hub_coaches (coach_sk, rec_src, load_dt, coach_bk)
    select distinct
        coach_sk
        , rec_src
        , load_dt
        , coach_bk
    from stg.v_hub_coaches as vhc
    where not exists (
        select hc.coach_sk
        from dbo.hub_coaches as hc
        where hc.coach_sk = vhc.coach_sk
    );

    get diagnostics v_record_count = row_count;

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_hub_coaches', v_record_count, 'Hub loaded successfully');

    f_record_inserted = v_record_count;

    raise info 'Table hub_coaches loaded successfully! Records inserted: %', f_record_inserted;

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_hub_coaches', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;



-- ===== SATELITA ===== --
-- 3. dbo.sp_load_sat_coach_personal_info
create or replace procedure dbo.sp_load_sat_coach_personal_info(
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
    update dbo.sat_coach_personal_info as old_sat
    set load_end_dt = f_load_date - interval '1 second'
    where old_sat.load_end_dt is null
        and exists (
            select new_sat.coach_sk
            from stg.v_sat_coach_personal_info as new_sat
            where 1=1
                and new_sat.coach_sk = old_sat.coach_sk
                and new_sat.hash_diff != old_sat.hash_diff
        );

    get diagnostics v_updated_count = row_count;

    insert into dbo.sat_coach_personal_info (
        coach_sk, load_dt, rec_src, load_end_dt, hash_diff, first_name, second_name, career_start_date, career_end_date
    )
    select distinct
        coach_sk
        , load_dt
        , rec_src
        , null::timestamp as load_end_dt
        , hash_diff
        , first_name
        , second_name
        , career_start_date
        , career_end_date
    from stg.v_sat_coach_personal_info as vscpi
    where not exists (
        select scpi.coach_sk
        from dbo.sat_coach_personal_info as scpi
        where 1=1
            and scpi.coach_sk = vscpi.coach_sk
            and scpi.hash_diff = vscpi.hash_diff
            and scpi.load_end_dt is null
    );

    get diagnostics v_record_count = row_count;

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_sat_coach_personal_info', v_record_count, 'Satellite loaded successfully');

    f_record_inserted = v_record_count;
    f_record_updated = v_updated_count;

    raise info 'Table sat_coach_personal_info updated successfully! Records updated: %', f_record_updated;
    raise info 'Table sat_coach_personal_info loaded successfully! Records inserted: %', f_record_inserted;

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_sat_coach_personal_info', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;


--rollback DROP PROCEDURE IF EXISTS dbo.sp_load_sat_coach_personal_info;
--rollback DROP PROCEDURE IF EXISTS dbo.sp_load_hub_coaches;
--rollback DROP PROCEDURE IF EXISTS dbo.sp_load_sat_coach_status;
--rollback DROP PROCEDURE IF EXISTS stg.sp_load_coaches;
--rollback DROP PROCEDURE IF EXISTS stg.sp_load_raw_coaches;
--rollback DROP PROCEDURE IF EXISTS stg.sp_truncate_raw_coaches;
--rollback DROP PROCEDURE IF EXISTS stg.sp_load_buffer_coaches;
--rollback DROP PROCEDURE IF EXISTS stg.sp_truncate_buffer_coaches;