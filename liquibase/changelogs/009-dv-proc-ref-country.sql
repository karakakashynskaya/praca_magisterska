--liquibase formatted sql
--changeset kkakashynskaya:9-dv-proc-ref-country splitStatements:false runOnChange:true

-----------------------------------------------------------------------------
-- ====== REF_COUNTRY ====== --
/* Procedury do utworzenia:
    1. stg.sp_load_ref_country:
        a. stg.sp_truncate_buffer_ref_country
        b. stg.sp_load_buffer_ref_country
        c. stg.sp_truncate_raw_ref_country
        d. stg.sp_load_raw_ref_country
    2. dbo.sp_load_ref_country
*/

-- 1.a. stg.sp_truncate_buffer_ref_country
create or replace procedure stg.sp_truncate_buffer_ref_country(
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
    truncate table stg.buffer_ref_country;

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_truncate_buffer_ref_country', 0, 'Buffer truncated successfully');

    raise info 'Table buffer_ref_country truncated successfully!';

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_truncate_buffer_ref_country', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;



-- 1.b. stg.sp_load_buffer_ref_country
create or replace procedure stg.sp_load_buffer_ref_country(
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
    copy stg.buffer_ref_country
    from '/var/lib/postgresql/import/data_src/ref_country.csv'
    with (
        format csv,
        header true,
        delimiter ','
    );

    select count(*) into v_record_count from stg.buffer_ref_country;

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_buffer_ref_country', v_record_count, 'Buffer loaded successfully');

    f_record_inserted = v_record_count;

    raise info 'Table buffer_ref_country loaded successfully! Records inserted: %', f_record_inserted;

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_buffer_ref_country', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;



-- 1.c. stg.sp_truncate_raw_ref_country
create or replace procedure stg.sp_truncate_raw_ref_country(
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
    truncate table stg.raw_ref_country;

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_truncate_raw_ref_country', 0, 'Raw table truncated successfully');

    raise info 'Table raw_ref_country truncated successfully!';

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_truncate_raw_ref_country', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;



-- 1.d. stg.sp_load_raw_ref_country
create or replace procedure stg.sp_load_raw_ref_country(
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
    lock table stg.raw_ref_country;

    create temp table tmp_raw_ref_country (
        country_code_src VARCHAR
        , description_src VARCHAR
        , country_code CHAR(3)
        , description VARCHAR(50)
    );

    insert into tmp_raw_ref_country (
        country_code_src
        , description_src
        , country_code
        , description
    )
    select
        country_code
        , description
        , case when country_code is not null and length(trim(country_code)) = 3
            then country_code else null end
        , case when description is not null and length(trim(description)) <= 50
            then description else null end
    from stg.buffer_ref_country;

    -- WSTAWIANIE POPRAWNYCH REKORDÓW DO WARSTWY RAW --
    insert into stg.raw_ref_country (
        country_sk
        , country_code_bk
        , country_name
        , rec_src
        , load_dt
    )
    select
        md5(upper(trim(coalesce(country_code, '')))) as country_sk
        , upper(trim(coalesce(country_code, ''))) as country_code_bk
        , description as country_name
        , f_rec_src as rec_src
        , f_load_date as load_dt
    from tmp_raw_ref_country
    where 1=1
        and country_code is not null
        and length(trim(country_code)) > 0
        and description is not null;

    get diagnostics v_record_count = row_count;
    f_record_inserted = v_record_count;

    truncate table stg.buffer_ref_country_not_valid;

    -- WSTAWIANIE NIEPOPRAWNYCH REKORDÓW --
    insert into stg.buffer_ref_country_not_valid (
        country_code
        , description
        , run_id
        , error_description
    )
    select
        country_code
        , description
        , f_run_id as run_id
        , case
            when country_code_src is not null and country_code is null
                then '[country_code]: should contain 3 chars; '
            else ''
        end ||
        case
            when description_src is not null and description is null
                then '[description]: data would be truncated; '
            else ''
        end as error_description
    from tmp_raw_ref_country
    where 1=1
        and (country_code_src is not null and country_code is null)
        or (description_src is not null and description is null);

    drop table if exists tmp_raw_ref_country;

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_raw_ref_country', v_record_count, 'Raw table loaded successfully');

    raise info 'Table raw_ref_country loaded successfully! Records inserted: %', f_record_inserted;

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_raw_ref_country', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;



-- 1. stg.sp_load_ref_country
create or replace procedure stg.sp_load_ref_country(
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
        call stg.sp_truncate_buffer_ref_country(f_run_id, f_load_date, f_rec_src, f_record_inserted, f_error_num, f_error_message);
        call stg.sp_load_buffer_ref_country(f_run_id, f_load_date, f_rec_src, f_record_inserted, f_error_num, f_error_message);
        call stg.sp_truncate_raw_ref_country(f_run_id, f_load_date, f_rec_src, f_record_inserted, f_error_num, f_error_message);
        call stg.sp_load_raw_ref_country(f_run_id, f_load_date, f_rec_src, f_record_inserted, f_error_num, f_error_message);

        raise info 'The stored procedures (staging ref_country) finished successfully!';

    exception when others then
        f_error_num = -1;
        f_error_message = substring(sqlerrm, 1, 200);

        insert into stg.log_table (run_id, object_name, records_count, message)
        values (f_run_id, 'sp_load_ref_country', 0, 'Error: '|| f_error_message);

        raise info 'An exception occurred %', sqlerrm;
    end;
end;
$$;



-----------------------------------------------------------------------------
-- ===== POZIOM DBO ===== --
-- 2. dbo.sp_load_ref_country
create or replace procedure dbo.sp_load_ref_country(
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
    insert into dbo.ref_country (country_sk, country_code_bk, country_name, rec_src, load_dt)
    select
        country_sk
        , country_code_bk
        , country_name
        , rec_src
        , load_dt
    from stg.v_ref_country as vrc
    where not exists (
        select rc.country_sk
        from dbo.ref_country as rc
        where rc.country_sk = vrc.country_sk
    );

    get diagnostics v_record_count = row_count;

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_ref_country', v_record_count, 'Ref country loaded successfully');

    f_record_inserted = v_record_count;

    raise info 'Table ref_country loaded successfully! Records inserted: %', f_record_inserted;

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_ref_country', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;


--rollback DROP PROCEDURE IF EXISTS dbo.sp_load_ref_country;
--rollback DROP PROCEDURE IF EXISTS stg.sp_load_ref_country;
--rollback DROP PROCEDURE IF EXISTS stg.sp_load_raw_ref_country;
--rollback DROP PROCEDURE IF EXISTS stg.sp_truncate_raw_ref_country;
--rollback DROP PROCEDURE IF EXISTS stg.sp_load_buffer_ref_country;
--rollback DROP PROCEDURE IF EXISTS stg.sp_truncate_buffer_ref_country;
