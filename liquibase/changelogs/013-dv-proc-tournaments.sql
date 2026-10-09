--liquibase formatted sql
--changeset kkakashynskaya:13-dv-proc-tournaments splitStatements:false runOnChange:true

-----------------------------------------------------------------------------
-- ====== TOURNAMENTS ====== --

-- 1.a. truncate buffer tournaments
create or replace procedure stg.sp_truncate_buffer_tournaments(
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
    truncate table stg.buffer_tournaments;

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_truncate_buffer_tournaments', 0, 'Buffer truncated successfully');

    raise info 'Table buffer_tournaments truncated successfully!';

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_truncate_buffer_tournaments', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;



-- 1.b. load buffer tournaments
create or replace procedure stg.sp_load_buffer_tournaments(
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
    copy stg.buffer_tournaments
    from '/var/lib/postgresql/import/data_src/tournaments.csv'
    with (
        format csv,
        header true,
        delimiter ','
    );

    select count(*) into v_record_count from stg.buffer_tournaments;

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_buffer_tournaments', v_record_count, 'Buffer loaded successfully');

    f_record_inserted = v_record_count;

    raise info 'Table buffer_tournaments loaded successfully! Records inserted: %', f_record_inserted;

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_buffer_tournaments', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;



-- 1.c. truncate raw tournaments
create or replace procedure stg.sp_truncate_raw_tournaments(
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
    truncate table stg.raw_tournaments;

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_truncate_raw_tournaments', 0, 'Raw table truncated successfully');

    raise info 'Table raw_tournaments truncated successfully!';

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_truncate_raw_tournaments', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;



-- 1.d. load raw tournaments
create or replace procedure stg.sp_load_raw_tournaments(
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
    create temp table tmp_raw_tournaments (
        id_src VARCHAR
        , tournament_name_src VARCHAR
        , country_src VARCHAR
        , tournament_level_src VARCHAR
        , surface_src VARCHAR
        , tourn_start_date_src VARCHAR
        , tourn_end_date_src VARCHAR
        , id VARCHAR(100)
        , tournament_name VARCHAR(75)
        , country VARCHAR(50)
        , tournament_level VARCHAR(25)
        , surface VARCHAR(20)
        , tourn_start_date DATE
        , tourn_end_date DATE
    );

    insert into tmp_raw_tournaments (
        id_src, tournament_name_src, country_src, tournament_level_src,
        surface_src, tourn_start_date_src, tourn_end_date_src,
        id, tournament_name, country, tournament_level, surface,
        tourn_start_date, tourn_end_date
    )
    select
        id, tournament_name, country, tournament_level, surface,
        tourn_start_date, tourn_end_date
        , case when id is not null and length(trim(id)) <= 100
            then id else null end
        , case when tournament_name is not null and length(trim(tournament_name)) <= 75
            then tournament_name else null end
        , case when country is not null and length(trim(country)) <= 50
            then country else null end
        , case when tournament_level is not null and length(trim(tournament_level)) <= 25
            then tournament_level else null end
        , case when surface is not null and length(trim(surface)) <= 20
            then surface else null end
        , case when tourn_start_date is not null
            then cast(tourn_start_date as DATE) else null end
        , case when tourn_end_date is not null
            then cast(tourn_end_date as DATE) else null end
    from stg.buffer_tournaments;

    -- WSTAWIANIE POPRAWNYCH REKORDÓW DO WARSTWY RAW --
    insert into stg.raw_tournaments (
        tournament_sk
        , tournament_bk
        , tournament_name
        , country
        , tournament_level
        , surface
        , tourn_start_date
        , tourn_end_date
        , sat_tournament_details_hash_key
        , rec_src
        , load_dt
        , hash_diff
    )
    select distinct
        md5(upper(trim(coalesce(id, '')))) as tournament_sk
        , upper(trim(coalesce(id, ''))) as tournament_bk
        , tournament_name
        , country
        , tournament_level
        , surface
        , tourn_start_date
        , tourn_end_date
        , md5(
            upper(trim(coalesce(id, ''))) || ';' ||
            upper(trim(coalesce(tournament_name, ''))) || ';' ||
            upper(trim(coalesce(country, ''))) || ';' ||
            upper(trim(coalesce(tournament_level, ''))) || ';' ||
            upper(trim(coalesce(surface, ''))) || ';' ||
            upper(trim(coalesce(tourn_start_date::text, ''))) || ';' ||
            upper(trim(coalesce(tourn_end_date::text, '')))
        ) as sat_tournament_details_hash_key
        , f_rec_src as rec_src
        , f_load_date as load_dt
        , md5(
            upper(trim(coalesce(id, ''))) || ';' ||
            upper(trim(coalesce(tournament_name, ''))) || ';' ||
            upper(trim(coalesce(country, ''))) || ';' ||
            upper(trim(coalesce(tournament_level, ''))) || ';' ||
            upper(trim(coalesce(surface, ''))) || ';' ||
            upper(trim(coalesce(tourn_start_date::text, ''))) || ';' ||
            upper(trim(coalesce(tourn_end_date::text, '')))
        ) as hash_diff
    from tmp_raw_tournaments
    where 1=1
        and id is not null
        and length(trim(id)) > 0
        and tournament_name is not null
        and country is not null
        and tournament_level is not null
        and tourn_start_date is not null
        and tourn_end_date is not null;

    get diagnostics v_record_count = row_count;
    f_record_inserted = v_record_count;

    truncate table stg.buffer_tournaments_not_valid;

    -- WSTAWIANIE NIEPOPRAWNYCH REKORDÓW --
    insert into stg.buffer_tournaments_not_valid (
        id, tournament_name, country, tournament_level, surface,
        tourn_start_date, tourn_end_date, run_id, error_description
    )
    select
        id, tournament_name, country, tournament_level, surface,
        tourn_start_date, tourn_end_date
        , f_run_id as run_id,
        case
            when id_src is not null and id is null
                then '[id]: data would be truncated; '
            else ''
        end ||
        case
            when tournament_name_src is not null and tournament_name is null
                then '[tournament_name]: data would be truncated; '
            else ''
        end ||
        case
            when country_src is not null and country is null
                then '[country]: data would be truncated; '
            else ''
        end ||
        case
            when tournament_level_src is not null and tournament_level is null
                then '[tournament_level]: data would be truncated; '
            else ''
        end ||
        case
            when surface_src is not null and surface is null
                then '[surface]: data would be truncated; '
            else ''
        end ||
        case
            when id is null or length(trim(id)) = 0
                then '[id]: value should not be null; '
            else ''
        end ||
        case
            when tournament_name is null
                then '[tournament_name]: value should not be null; '
            else ''
        end ||
        case
            when country is null
                then '[country]: value should not be null; '
            else ''
        end ||
        case
            when tournament_level is null
                then '[tournament_level]: value should not be null; '
            else ''
        end ||
        case
            when tourn_start_date is null
                then '[tourn_start_date]: value should not be null; '
            else ''
        end ||
        case
            when tourn_end_date is null
                then '[tourn_end_date]: value should not be null; '
            else ''
        end as error_description
    from tmp_raw_tournaments
    where 1=1
        and (id_src is not null and id is null)
        or (tournament_name_src is not null and tournament_name is null)
        or (country_src is not null and country is null)
        or (tournament_level_src is not null and tournament_level is null)
        or (surface_src is not null and surface is null)
        or (id is null or length(trim(id)) = 0)
        or tournament_name is null
        or country is null
        or tournament_level is null
        or tourn_start_date is null
        or tourn_end_date is null;

    drop table if exists tmp_raw_tournaments;

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_raw_tournaments', v_record_count, 'Raw table loaded successfully');

    raise info 'Table raw_tournaments loaded successfully! Records inserted: %', f_record_inserted;

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_raw_tournaments', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;



-- 1. stg.sp_load_tournaments
create or replace procedure stg.sp_load_tournaments(
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
        call stg.sp_truncate_buffer_tournaments(f_run_id, f_load_date, f_rec_src, f_record_inserted, f_error_num, f_error_message);
        call stg.sp_load_buffer_tournaments(f_run_id, f_load_date, f_rec_src, f_record_inserted, f_error_num, f_error_message);
        call stg.sp_truncate_raw_tournaments(f_run_id, f_load_date, f_rec_src, f_record_inserted, f_error_num, f_error_message);
        call stg.sp_load_raw_tournaments(f_run_id, f_load_date, f_rec_src, f_record_inserted, f_error_num, f_error_message);

        raise info 'The stored procedures (staging tournaments) finished successfully!';

    exception when others then
        f_error_num = -1;
        f_error_message = substring(sqlerrm, 1, 200);

        insert into stg.log_table (run_id, object_name, records_count, message)
        values (f_run_id, 'sp_load_tournaments', 0, 'Error: '|| f_error_message);

        raise info 'An exception occurred %', sqlerrm;
    end;
end;
$$;



-----------------------------------------------------------------------------
-- ===== POZIOM DBO ===== --
-- ===== SATELITA STATUSU (pełna logika CRUD) ===== --
create or replace procedure dbo.sp_load_sat_tournament_status(
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
    insert into dbo.sat_tournament_status (tournament_sk, load_dt, load_end_dt, rec_src, status)
    select distinct
        ht.tournament_sk
        , f_load_date
        , null::timestamp
        , f_rec_src
        , 'D'
    from dbo.hub_tournaments as ht
    where exists (
            select sts.tournament_sk
            from dbo.sat_tournament_status as sts
            where 1=1
                and sts.tournament_sk = ht.tournament_sk
                and sts.status in ('C', 'U')
                and sts.load_end_dt is null
        )
        and not exists (
            select rt.tournament_sk
            from stg.raw_tournaments as rt
            where rt.tournament_sk = ht.tournament_sk
        )
        and not exists (
            select sts.tournament_sk
            from dbo.sat_tournament_status as sts
            where 1=1
                and sts.tournament_sk = ht.tournament_sk
                and sts.status = 'D'
                and sts.load_end_dt is null
        );

    get diagnostics v_delete_count = row_count;

    update dbo.sat_tournament_status as old_sat
    set load_end_dt = f_load_date - interval '1 second'
    where old_sat.load_end_dt is null
        and old_sat.status in ('C', 'U')
        and old_sat.load_dt < f_load_date
        and exists (
            select new_sat.tournament_sk
            from dbo.sat_tournament_status as new_sat
            where 1=1
                and new_sat.tournament_sk = old_sat.tournament_sk
                and new_sat.status = 'D'
                and new_sat.load_dt = f_load_date
        );


    -- CRUD: Create, status = 'C' (nowy rekord, nigdy wcześniej w dbo)
    insert into dbo.sat_tournament_status (tournament_sk, load_dt, load_end_dt, rec_src, status)
    select distinct
        rt.tournament_sk
        , f_load_date
        , null::timestamp
        , f_rec_src
        , 'C'
    from stg.raw_tournaments as rt
    where not exists (
            select sts.tournament_sk
            from dbo.sat_tournament_status as sts
            where 1=1
                and sts.tournament_sk = rt.tournament_sk
                and sts.status is not null
        )
        and not exists (
            select sts.tournament_sk
            from dbo.sat_tournament_status as sts
            where 1=1
                and sts.tournament_sk = rt.tournament_sk
                and sts.load_dt = f_load_date
        );

    get diagnostics v_create_count = row_count;


    -- CRUD: Create, status = 'C' (rekord wraca po wcześniejszym usunięciu)
    insert into dbo.sat_tournament_status (tournament_sk, load_dt, load_end_dt, rec_src, status)
    select distinct
        rt.tournament_sk
        , f_load_date
        , null::timestamp
        , f_rec_src
        , 'C'
    from stg.raw_tournaments as rt
    where exists (
            select sts.tournament_sk
            from dbo.sat_tournament_status as sts
            where 1=1
                and sts.tournament_sk = rt.tournament_sk
                and sts.status = 'D'
                and sts.load_end_dt is null
        )
        and not exists (
            select sts.tournament_sk
            from dbo.sat_tournament_status as sts
            where 1=1
                and sts.tournament_sk = rt.tournament_sk
                and sts.load_dt = f_load_date
        );

    get diagnostics v_update_count = row_count;
    v_create_count := v_create_count + v_update_count;

    update dbo.sat_tournament_status as old_sat
    set load_end_dt = f_load_date - interval '1 second'
    where old_sat.load_end_dt is null
        and old_sat.status = 'D'
        and old_sat.load_dt < f_load_date
        and exists (
            select new_sat.tournament_sk
            from dbo.sat_tournament_status as new_sat
            where 1=1
                and new_sat.tournament_sk = old_sat.tournament_sk
                and new_sat.status = 'C'
                and new_sat.load_dt = f_load_date
        );


    -- statystyki planera po wstawieniu wierszy 'C'/'D' w tej samej transakcji;
    -- bez tego planer zakłada pustą tabelę (rows=1) i wybiera Nested Loop O(n^2)
    analyze dbo.sat_tournament_status;

    -- CRUD: Update, status = 'U' (dane rekordu się zmieniły)
    insert into dbo.sat_tournament_status (tournament_sk, load_dt, load_end_dt, rec_src, status)
    select distinct
        rt.tournament_sk
        , f_load_date
        , null::timestamp
        , f_rec_src
        , 'U'
    from stg.raw_tournaments as rt
    where exists (
            select sts.tournament_sk
            from dbo.sat_tournament_status as sts
            where 1=1 and
                sts.tournament_sk = rt.tournament_sk
                and sts.status in ('C', 'U')
                and sts.load_dt < f_load_date
                and not exists (
                  select sts2.tournament_sk
                  from dbo.sat_tournament_status as sts2
                  where sts2.tournament_sk = sts.tournament_sk
                    and sts2.load_dt > sts.load_dt
              )
        )
        and (
            exists
                (select std.tournament_sk
                 from dbo.sat_tournament_details as std
                 where 1=1
                    and std.tournament_sk = rt.tournament_sk
                    and std.load_dt = f_load_date)
        )
        and not exists (
            select sts.tournament_sk
            from dbo.sat_tournament_status as sts
            where 1=1
                and sts.tournament_sk = rt.tournament_sk
                and sts.load_dt = f_load_date
        );

    get diagnostics v_update_count = row_count;

    update dbo.sat_tournament_status as old_sat
    set load_end_dt = f_load_date - interval '1 second'
    where old_sat.load_end_dt is null
        and old_sat.status in ('C', 'U')
        and old_sat.load_dt < f_load_date
        and exists (
            select new_sat.tournament_sk
            from dbo.sat_tournament_status as new_sat
            where 1=1
                and new_sat.tournament_sk = old_sat.tournament_sk
                and new_sat.status = 'U'
                and new_sat.load_dt = f_load_date
        );

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_sat_tournament_status', v_create_count + v_delete_count + v_update_count,
            format('Created: %s, Deleted: %s, Updated: %s', v_create_count, v_delete_count, v_update_count));

    f_record_inserted = v_create_count + v_update_count;
    f_record_updated = v_delete_count;

    raise info 'Table sat_tournament_status loaded successfully: Created=%, Deleted=%, Updated=%',
               v_create_count, v_delete_count, v_update_count;

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_sat_tournament_status', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;



-- ===== HUB ===== --
-- 2.a. dbo.sp_load_hub_tournaments
create or replace procedure dbo.sp_load_hub_tournaments(
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
    insert into dbo.hub_tournaments (tournament_sk, rec_src, load_dt, tournament_bk)
    select distinct
        tournament_sk
        , rec_src
        , load_dt
        , tournament_bk
    from stg.v_hub_tournaments as vht
    where not exists (
        select ht.tournament_sk
        from dbo.hub_tournaments as ht
        where ht.tournament_sk = vht.tournament_sk
    );

    get diagnostics v_record_count = row_count;

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_hub_tournaments', v_record_count, 'Hub loaded successfully');

    f_record_inserted = v_record_count;

    raise info 'Table hub_tournaments loaded successfully! Records inserted: %', f_record_inserted;

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_hub_tournaments', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;



-- ===== SATELITY ===== --
-- 3.a. dbo.sp_load_sat_tournament_details
create or replace procedure dbo.sp_load_sat_tournament_details(
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
    update dbo.sat_tournament_details as old_sat
    set load_end_dt = f_load_date - interval '1 second'
    where old_sat.load_end_dt is null
      and exists (
          select new_sat.tournament_sk
          from stg.v_sat_tournament_details as new_sat
          where 1=1
            and new_sat.tournament_sk = old_sat.tournament_sk
            and new_sat.hash_diff != old_sat.hash_diff
      );

    get diagnostics v_updated_count = row_count;

    insert into dbo.sat_tournament_details (
        tournament_sk, load_dt, rec_src, load_end_dt, hash_diff,
        tournament_name, country, tournament_level, surface,
        tourn_start_date, tourn_end_date
    )
    select distinct
        tournament_sk
        , load_dt
        , rec_src
        , null::timestamp as load_end_dt
        , hash_diff
        , tournament_name
        , country
        , tournament_level
        , surface
        , tourn_start_date
        , tourn_end_date
    from stg.v_sat_tournament_details as vstd
    where not exists (
        select std.tournament_sk
        from dbo.sat_tournament_details as std
        where 1=1
            and std.tournament_sk = vstd.tournament_sk
            and std.hash_diff = vstd.hash_diff
            and std.load_end_dt is null
    );

    get diagnostics v_record_count = row_count;

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_sat_tournament_details', v_record_count, 'Satellite loaded successfully');

    f_record_inserted = v_record_count;
    f_record_updated = v_updated_count;

    raise info 'Table sat_tournament_details updated successfully! Records updated: %', f_record_updated;
    raise info 'Table sat_tournament_details loaded successfully! Records inserted: %', f_record_inserted;

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_sat_tournament_details', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;


--rollback DROP PROCEDURE IF EXISTS dbo.sp_load_sat_tournament_details;
--rollback DROP PROCEDURE IF EXISTS dbo.sp_load_hub_tournaments;
--rollback DROP PROCEDURE IF EXISTS dbo.sp_load_sat_tournament_status;
--rollback DROP PROCEDURE IF EXISTS stg.sp_load_tournaments;
--rollback DROP PROCEDURE IF EXISTS stg.sp_load_raw_tournaments;
--rollback DROP PROCEDURE IF EXISTS stg.sp_truncate_raw_tournaments;
--rollback DROP PROCEDURE IF EXISTS stg.sp_load_buffer_tournaments;
--rollback DROP PROCEDURE IF EXISTS stg.sp_truncate_buffer_tournaments;