--liquibase formatted sql
--changeset kkakashynskaya:15-dv-proc-match-statistics splitStatements:false runOnChange:true

-----------------------------------------------------------------------------
-- ====== MATCH_STATISTICS ====== --

-- 1.a. stg.sp_truncate_buffer_match_statistics
create or replace procedure stg.sp_truncate_buffer_match_statistics(
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
    truncate table stg.buffer_match_statistics;

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_truncate_buffer_match_statistics', 0, 'Buffer truncated successfully');

    raise info 'Table buffer_match_statistics truncated successfully!';

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_truncate_buffer_match_statistics', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;



-- 1.b. stg.sp_load_buffer_match_statistics
create or replace procedure stg.sp_load_buffer_match_statistics(
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
    copy stg.buffer_match_statistics
    from '/var/lib/postgresql/import/data_src/matchstatistics.csv'
    with (
        format csv,
        header true,
        delimiter ','
    );

    select count(*) into v_record_count from stg.buffer_match_statistics;

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_buffer_match_statistics', v_record_count, 'Buffer loaded successfully');

    f_record_inserted = v_record_count;

    raise info 'Table buffer_match_statistics loaded successfully! Records inserted: %', f_record_inserted;

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_buffer_match_statistics', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;



-- 1.c. stg.sp_truncate_raw_match_statistics
create or replace procedure stg.sp_truncate_raw_match_statistics(
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
    truncate table stg.raw_match_statistics;

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_truncate_raw_match_statistics', 0, 'Raw table truncated successfully');

    raise info 'Table raw_match_statistics truncated successfully!';

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_truncate_raw_match_statistics', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;



-- 1.d. stg.sp_load_raw_match_statistics
create or replace procedure stg.sp_load_raw_match_statistics(
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
    create temp table tmp_raw_match_statistics (
        match_id_src VARCHAR
        , player_id_src VARCHAR
        , aces_src VARCHAR
        , double_faults_src VARCHAR
        , break_points_converted_perc_src VARCHAR
        , match_id VARCHAR(100)
        , player_id VARCHAR(100)
        , aces SMALLINT
        , double_faults SMALLINT
        , break_points_converted_perc DECIMAL(4,3)
    );

    insert into tmp_raw_match_statistics (
        match_id_src, player_id_src, aces_src, double_faults_src, break_points_converted_perc_src,
        match_id, player_id, aces, double_faults, break_points_converted_perc
    )
    select
        match_id, player_id, aces, double_faults, break_points_converted_perc
        , case when match_id is not null and length(trim(match_id)) <= 100
            then match_id else null end
        , case when player_id is not null and length(trim(player_id)) <= 100
            then player_id else null end
        , case when aces is not null and aces::numeric >= 0 and aces::numeric <= 32767
            then aces::smallint else 0 end
        , case when double_faults is not null and double_faults::numeric >= 0 and double_faults::numeric <= 32767
            then double_faults::smallint else 0 end
        , case when break_points_converted_perc is not null
            and break_points_converted_perc::decimal(4,3) >= 0
            and break_points_converted_perc::decimal(4,3) <= 1
            then break_points_converted_perc::decimal(4,3) else 0 end
    from stg.buffer_match_statistics;

    -- WSTAWIANIE POPRAWNYCH REKORDÓW DO WARSTWY RAW --
    insert into stg.raw_match_statistics (
        match_statistics_sk
        , match_sk
        , match_bk
        , player_sk
        , player_bk
        , aces
        , double_faults
        , break_points_converted_perc
        , sat_match_statistics_details_hash_key
        , rec_src
        , load_dt
        , hash_diff
    )
    with tmp_valid_statistics as (
        select distinct
            md5(upper(trim(coalesce(match_id, '')))) as match_sk
            , upper(trim(coalesce(match_id, ''))) as match_bk
            , md5(upper(trim(coalesce(player_id, '')))) as player_sk
            , upper(trim(coalesce(player_id, ''))) as player_bk
            , aces
            , double_faults
            , break_points_converted_perc
            , md5(
                upper(trim(coalesce(aces::text, ''))) || ';' ||
                upper(trim(coalesce(double_faults::text, ''))) || ';' ||
                upper(trim(coalesce(break_points_converted_perc::text, '')))
            ) as sat_match_statistics_details_hash_key
            , f_rec_src as rec_src
            , f_load_date as load_dt
            , md5(
                upper(trim(coalesce(aces::text, ''))) || ';' ||
                upper(trim(coalesce(double_faults::text, ''))) || ';' ||
                upper(trim(coalesce(break_points_converted_perc::text, '')))
            ) as hash_diff
        from tmp_raw_match_statistics
        where 1=1
            and match_id is not null
            and length(trim(match_id)) > 0
            and player_id is not null
            and length(trim(player_id)) > 0)
    select
        md5(
            upper(trim(coalesce(match_sk, ''))) || ';' ||
            upper(trim(coalesce(player_sk, '')))
        ) as match_statistics_sk
        , match_sk
        , match_bk
        , player_sk
        , player_bk
        , aces
        , double_faults
        , break_points_converted_perc
        , sat_match_statistics_details_hash_key
        , rec_src
        , load_dt
        , hash_diff
    from tmp_valid_statistics;

    get diagnostics v_record_count = row_count;
    f_record_inserted = v_record_count;

    truncate table stg.buffer_match_statistics_not_valid;

    -- WSTAWIANIE NIEPOPRAWNYCH REKORDÓW --
    insert into stg.buffer_match_statistics_not_valid (
        match_id
        , player_id
        , aces
        , double_faults
        , break_points_converted_perc
        , run_id
        , error_description
    )
    select
        match_id, player_id, aces, double_faults, break_points_converted_perc
        , f_run_id as run_id
        , case
            when match_id_src is not null and match_id is null
                then '[match_id]: data would be truncated; '
            else ''
        end ||
        case
            when player_id_src is not null and player_id is null
                then '[player_id]: data would be truncated; '
            else ''
        end ||
        case
            when match_id is null
                then '[match_id]: value should not be null; '
            else ''
        end ||
        case
            when player_id is null
                then '[player_id]: value should not be null; '
            else ''
        end ||
        case
            when aces_src is not null and (aces_src::numeric < 0 or aces_src::numeric > 32767)
                then '[aces]: value should be between 0 and 32767; '
            else ''
        end ||
        case
            when double_faults_src is not null and (double_faults_src::numeric < 0 or double_faults_src::numeric > 32767)
                then '[double_faults]: value should be between 0 and 32767; '
            else ''
        end ||
        case
            when break_points_converted_perc_src is not null
                and (break_points_converted_perc_src::numeric < 0 or break_points_converted_perc_src::numeric > 1)
                then '[break_points_converted_perc]: value should be between 0 and 1; '
            else ''
        end as error_description
    from tmp_raw_match_statistics
    where 1=1
        and ((match_id_src is not null and match_id is null)
        or (player_id_src is not null and player_id is null)
        or (match_id is null or length(trim(match_id)) = 0)
        or (player_id is null or length(trim(player_id)) = 0)
        or (aces_src is not null and (aces_src::numeric < 0 or aces_src::numeric > 32767))
        or (double_faults_src is not null and (double_faults_src::numeric < 0 or double_faults_src::numeric > 32767))
        or (break_points_converted_perc_src is not null
            and (break_points_converted_perc_src::numeric < 0 or break_points_converted_perc_src::numeric > 1)));

    drop table if exists tmp_raw_match_statistics;

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_raw_match_statistics', v_record_count, 'Raw table loaded successfully');

    raise info 'Table raw_match_statistics loaded successfully! Records inserted: %', f_record_inserted;

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_raw_match_statistics', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;



-- 1. stg.sp_load_match_statistics
create or replace procedure stg.sp_load_match_statistics(
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
        call stg.sp_truncate_buffer_match_statistics(f_run_id, f_load_date, f_rec_src, f_record_inserted, f_error_num, f_error_message);
        call stg.sp_load_buffer_match_statistics(f_run_id, f_load_date, f_rec_src, f_record_inserted, f_error_num, f_error_message);
        call stg.sp_truncate_raw_match_statistics(f_run_id, f_load_date, f_rec_src, f_record_inserted, f_error_num, f_error_message);
        call stg.sp_load_raw_match_statistics(f_run_id, f_load_date, f_rec_src, f_record_inserted, f_error_num, f_error_message);

        raise info 'The stored procedures (staging match_statistics) finished successfully!';

    exception when others then
        f_error_num = -1;
        f_error_message = substring(sqlerrm, 1, 200);

        insert into stg.log_table (run_id, object_name, records_count, message)
        values (f_run_id, 'sp_load_match_statistics', 0, 'Error: '|| f_error_message);

        raise info 'An exception occurred %', sqlerrm;
    end;
end;
$$;



-----------------------------------------------------------------------------
-- ===== POZIOM DBO ===== --
-- ===== SATELITA STATUSU (pełna logika CRUD) ===== --
create or replace procedure dbo.sp_load_sat_match_statistics_status(
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
    insert into dbo.sat_match_statistics_status (match_statistics_sk, load_dt, load_end_dt, rec_src, status)
    select distinct
        lms.match_statistics_sk
        , f_load_date
        , null::timestamp
        , f_rec_src
        , 'D'
    from dbo.link_match_statistics as lms
    where 1=1
        and exists (
            select smss.match_statistics_sk
            from dbo.sat_match_statistics_status as smss
            where smss.match_statistics_sk = lms.match_statistics_sk
                and smss.status in ('C', 'U')
                and smss.load_end_dt is null
        )
        and not exists (
            select rms.match_statistics_sk
            from stg.raw_match_statistics as rms
            where rms.match_statistics_sk = lms.match_statistics_sk
        )
        and not exists (
            select smss.match_statistics_sk
            from dbo.sat_match_statistics_status as smss
            where smss.match_statistics_sk = lms.match_statistics_sk
                and smss.status = 'D'
                and smss.load_end_dt is null
    );

    get diagnostics v_delete_count = row_count;

    update dbo.sat_match_statistics_status as old_sat
    set load_end_dt = f_load_date - interval '1 second'
    where old_sat.load_end_dt is null
        and old_sat.status in ('C', 'U')
        and old_sat.load_dt < f_load_date
        and exists (
            select new_sat.match_statistics_sk
            from dbo.sat_match_statistics_status as new_sat
            where 1=1
                and new_sat.match_statistics_sk = old_sat.match_statistics_sk
                and new_sat.status = 'D'
                and new_sat.load_dt = f_load_date
        );


    -- CRUD: Create, status = 'C' (nowy rekord, nigdy wcześniej w dbo)
    insert into dbo.sat_match_statistics_status (match_statistics_sk, load_dt, load_end_dt, rec_src, status)
    select distinct
        rms.match_statistics_sk
        , f_load_date
        , null::timestamp
        , f_rec_src
        , 'C'
    from stg.raw_match_statistics as rms
    where not exists (
            select smss.match_statistics_sk
            from dbo.sat_match_statistics_status as smss
            where smss.match_statistics_sk = rms.match_statistics_sk
        )
        and not exists (
            select smss.match_statistics_sk
            from dbo.sat_match_statistics_status as smss
            where smss.match_statistics_sk = rms.match_statistics_sk
                and smss.load_dt = f_load_date
        );

    get diagnostics v_create_count = row_count;


    -- CRUD: Create, status = 'C' (rekord wraca po wcześniejszym usunięciu)
    insert into dbo.sat_match_statistics_status (match_statistics_sk, load_dt, load_end_dt, rec_src, status)
    select distinct
        rms.match_statistics_sk
        , f_load_date
        , null::timestamp
        , f_rec_src
        , 'C'
    from stg.raw_match_statistics as rms
    where exists (
            select smss.match_statistics_sk
            from dbo.sat_match_statistics_status as smss
            where 1=1
                and smss.match_statistics_sk = rms.match_statistics_sk
                and smss.status = 'D'
                and smss.load_end_dt is null
        )
        and not exists (
            select smss.match_statistics_sk
            from dbo.sat_match_statistics_status as smss
            where smss.match_statistics_sk = rms.match_statistics_sk
                and smss.load_dt = f_load_date
        );

    get diagnostics v_update_count = row_count;
    v_create_count := v_create_count + v_update_count;

    update dbo.sat_match_statistics_status as old_sat
    set load_end_dt = f_load_date - interval '1 second'
    where old_sat.load_end_dt is null
        and old_sat.status = 'D'
        and old_sat.load_dt < f_load_date
        and exists (
            select new_sat.match_statistics_sk
            from dbo.sat_match_statistics_status as new_sat
            where 1=1
                and new_sat.match_statistics_sk = old_sat.match_statistics_sk
                and new_sat.status = 'C'
                and new_sat.load_dt = f_load_date
        );


    -- statystyki planera po wstawieniu wierszy 'C'/'D' w tej samej transakcji;
    -- bez tego planer zakłada pustą tabelę (rows=1) i wybiera Nested Loop O(n^2)
    analyze dbo.sat_match_statistics_status;

    -- CRUD: Update, status = 'U' (dane rekordu się zmieniły)
    insert into dbo.sat_match_statistics_status (match_statistics_sk, load_dt, load_end_dt, rec_src, status)
    select distinct
        rms.match_statistics_sk
        , f_load_date
        , null::timestamp
        , f_rec_src
        , 'U'
    from stg.raw_match_statistics as rms
    where exists (
            select smss.match_statistics_sk
            from dbo.sat_match_statistics_status as smss
            where 1=1 and
                smss.match_statistics_sk = rms.match_statistics_sk
                and smss.status in ('C', 'U')
                and smss.load_dt < f_load_date
                and not exists (
                  select smss2.match_statistics_sk
                  from dbo.sat_match_statistics_status as smss2
                  where 1=1
                    and smss2.match_statistics_sk = smss.match_statistics_sk
                    and smss2.load_dt > smss.load_dt
              )
        )
        and exists (
            select smsd.match_statistics_sk
            from dbo.sat_match_statistics_details as smsd
            where 1=1
                and smsd.match_statistics_sk = rms.match_statistics_sk
                and smsd.load_dt = f_load_date
        )
        and not exists (
            select smss.match_statistics_sk
            from dbo.sat_match_statistics_status as smss
            where smss.match_statistics_sk = rms.match_statistics_sk
                and smss.load_dt = f_load_date
        );

    get diagnostics v_update_count = row_count;

    update dbo.sat_match_statistics_status as old_sat
    set load_end_dt = f_load_date - interval '1 second'
    where old_sat.load_end_dt is null
        and old_sat.status in ('C', 'U')
        and old_sat.load_dt < f_load_date
        and exists (
            select new_sat.match_statistics_sk
            from dbo.sat_match_statistics_status as new_sat
            where 1=1
                and new_sat.match_statistics_sk = old_sat.match_statistics_sk
                and new_sat.status = 'U'
                and new_sat.load_dt = f_load_date
        );

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_sat_match_statistics_status', v_create_count + v_delete_count + v_update_count,
            format('Created: %s, Deleted: %s, Updated: %s', v_create_count, v_delete_count, v_update_count));

    f_record_inserted = v_create_count + v_update_count;
    f_record_updated = v_delete_count;

    raise info 'Table sat_match_statistics_status loaded successfully: Created=%, Deleted=%, Updated=%',
               v_create_count, v_delete_count, v_update_count;

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_sat_match_statistics_status', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;



-- ===== LINK ===== --
-- 2.a. dbo.sp_load_link_match_statistics
create or replace procedure dbo.sp_load_link_match_statistics(
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
    insert into dbo.link_match_statistics (
        match_statistics_sk, rec_src, load_dt, match_sk, player_sk
    )
    select distinct
        match_statistics_sk
        , rec_src
        , load_dt
        , match_sk
        , player_sk
    from stg.v_link_match_statistics as vlms
    where not exists (
        select lms.match_statistics_sk
        from dbo.link_match_statistics as lms
        where lms.match_statistics_sk = vlms.match_statistics_sk
    );

    get diagnostics v_record_count = row_count;

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_link_match_statistics', v_record_count, 'Link loaded successfully');

    f_record_inserted = v_record_count;

    raise info 'Table link_match_statistics loaded successfully! Records inserted: %', f_record_inserted;

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_link_match_statistics', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;



-- ===== SATELITA ===== --
-- 3. dbo.sp_load_sat_match_statistics_details
create or replace procedure dbo.sp_load_sat_match_statistics_details(
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
    update dbo.sat_match_statistics_details as old_sat
    set load_end_dt = f_load_date - interval '1 second'
    where old_sat.load_end_dt is null
      and exists (
          select new_sat.match_statistics_sk
          from stg.v_sat_match_statistics_details as new_sat
          where 1=1
            and new_sat.match_statistics_sk = old_sat.match_statistics_sk
            and new_sat.hash_diff != old_sat.hash_diff
      );

    get diagnostics v_updated_count = row_count;

    insert into dbo.sat_match_statistics_details (
        match_statistics_sk, load_dt, rec_src, load_end_dt, hash_diff,
        aces, double_faults, break_points_converted_perc
    )
    select distinct
        match_statistics_sk
        , load_dt
        , rec_src
        , null::timestamp as load_end_dt
        , hash_diff
        , aces
        , double_faults
        , break_points_converted_perc
    from stg.v_sat_match_statistics_details as vsmsd
    where not exists (
        select smsd.match_statistics_sk
        from dbo.sat_match_statistics_details as smsd
        where 1=1
            and smsd.match_statistics_sk = vsmsd.match_statistics_sk
            and smsd.hash_diff = vsmsd.hash_diff
            and smsd.load_end_dt is null
    );

    get diagnostics v_record_count = row_count;

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_sat_match_statistics_details', v_record_count, 'Satellite loaded successfully');

    f_record_inserted = v_record_count;
    f_record_updated = v_updated_count;

    raise info 'Table sat_match_statistics_details updated successfully! Records updated: %', f_record_updated;
    raise info 'Table sat_match_statistics_details loaded successfully! Records inserted: %', f_record_inserted;

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_sat_match_statistics_details', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;


--rollback DROP PROCEDURE IF EXISTS dbo.sp_load_sat_match_statistics_details;
--rollback DROP PROCEDURE IF EXISTS dbo.sp_load_link_match_statistics;
--rollback DROP PROCEDURE IF EXISTS dbo.sp_load_sat_match_statistics_status;
--rollback DROP PROCEDURE IF EXISTS stg.sp_load_match_statistics;
--rollback DROP PROCEDURE IF EXISTS stg.sp_load_raw_match_statistics;
--rollback DROP PROCEDURE IF EXISTS stg.sp_truncate_raw_match_statistics;
--rollback DROP PROCEDURE IF EXISTS stg.sp_load_buffer_match_statistics;
--rollback DROP PROCEDURE IF EXISTS stg.sp_truncate_buffer_match_statistics;