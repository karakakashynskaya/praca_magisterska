--liquibase formatted sql
--changeset kkakashynskaya:10-dv-proc-players splitStatements:false runOnChange:true

-----------------------------------------------------------------------------
-- ====== PLAYERS ====== --

-- 1.1.a. truncate buffer players --
create or replace procedure stg.sp_truncate_buffer_players(
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
    truncate table stg.buffer_players;

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_truncate_buffer_players', 0, 'Buffer truncated successfully');

    raise info 'Table buffer_players truncated successfully!';

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_truncate_buffer_players', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;



-- 1.1.b. load buffer players --
create or replace procedure stg.sp_load_buffer_players(
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
    copy stg.buffer_players
    from '/var/lib/postgresql/import/data_src/players.csv'
    with (
        format csv,
        header true,
        delimiter ','
    );

    select count(*) into v_record_count from stg.buffer_players;

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_buffer_players', v_record_count, 'Buffer loaded successfully');

    f_record_inserted = v_record_count;

    raise info 'Table buffer_players loaded successfully! Records inserted: %', f_record_inserted;

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_buffer_players', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;



-- 1.1.c. truncate raw players --
create or replace procedure stg.sp_truncate_raw_players(
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
    truncate table stg.raw_players;

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_truncate_raw_players', 0, 'Raw table truncated successfully');

    raise info 'Table raw_players truncated successfully!';

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_truncate_raw_players', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;



-- 1.1.d. load raw players --
create or replace procedure stg.sp_load_raw_players(
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
    create temp table tmp_raw_players (
        id_src VARCHAR
        , first_name_src VARCHAR
        , second_name_src VARCHAR
        , country_src VARCHAR
        , date_of_birth_src VARCHAR
        , titles_won_src VARCHAR
        , is_active_src VARCHAR
        , id VARCHAR(100)
        , first_name VARCHAR(50)
        , second_name VARCHAR(100)
        , country CHAR(3)
        , date_of_birth DATE
        , titles_won SMALLINT
        , is_active BOOLEAN
    );

    insert into tmp_raw_players (
        id_src, first_name_src, second_name_src, country_src,
        date_of_birth_src, titles_won_src, is_active_src,
        id, first_name, second_name, country, date_of_birth, titles_won, is_active
    )
    select
        id, first_name, second_name, country, date_of_birth, titles_won, is_active
        , case when id is not null and length(trim(id)) <= 100
            then id else null end
        , case when first_name is not null and length(trim(first_name)) <= 50
            then first_name else null end
        , case when second_name is not null and length(trim(second_name)) <= 100
            then second_name else null end
        , case when country is not null and length(trim(country)) <= 3
            then country else null end
        , case when date_of_birth is not null
            then cast(date_of_birth as DATE) else null end
        , case when titles_won is not null
            then cast(titles_won as SMALLINT) else null end
        , case when is_active is not null
                then cast(is_active as BOOLEAN) else null end
    from stg.buffer_players;

    -- WSTAWIANIE POPRAWNYCH REKORDÓW DO WARSTWY RAW --
    insert into stg.raw_players (
        player_sk
        , player_bk
        , first_name
        , second_name
        , country
        , date_of_birth
        , titles_won
        , is_active
        , sat_player_date_of_birth_hash_key
        , sat_player_personal_info_hash_key
        , rec_src
        , load_dt
        , hash_diff
    )
    select distinct
        md5(upper(trim(coalesce(id, '')))) as player_sk
        , upper(trim(coalesce(id, ''))) as player_bk
        , first_name
        , second_name
        , country
        , date_of_birth
        , coalesce(titles_won, 0) as titles_won
        , is_active
        , md5(
            upper(trim(coalesce(id, ''))) || ';' ||
            upper(trim(coalesce(date_of_birth::text, '')))
        ) as sat_player_date_of_birth_hash_key
        , md5(
            upper(trim(coalesce(id, ''))) || ';' ||
            upper(trim(coalesce(first_name, ''))) || ';' ||
            upper(trim(coalesce(second_name, ''))) || ';' ||
            upper(trim(coalesce(country, ''))) || ';' ||
            upper(trim(coalesce(titles_won::text, ''))) || ';' ||
            upper(trim(coalesce(is_active::text, '')))
        ) as sat_player_personal_info_hash_key
        , f_rec_src as rec_src
        , f_load_date as load_dt
        , md5(
            upper(trim(coalesce(id, ''))) || ';' ||
            upper(trim(coalesce(first_name, ''))) || ';' ||
            upper(trim(coalesce(second_name, ''))) || ';' ||
            upper(trim(coalesce(country, ''))) || ';' ||
            upper(trim(coalesce(date_of_birth::text, ''))) || ';' ||
            upper(trim(coalesce(titles_won::text, ''))) || ';' ||
            upper(trim(coalesce(is_active::text, '')))
        ) as hash_diff
    from tmp_raw_players
    where 1=1
        and id is not null
        and length(trim(id)) > 0
        and first_name is not null
        and second_name is not null
        and date_of_birth is not null
        and is_active is not null;

    get diagnostics v_record_count = row_count;
    f_record_inserted = v_record_count;

    truncate table stg.buffer_players_not_valid;

    -- WSTAWIANIE NIEPOPRAWNYCH REKORDÓW --
    insert into stg.buffer_players_not_valid (
        id, first_name, second_name, country,
        date_of_birth, titles_won, is_active, run_id, error_description
    )
    select
        id, first_name, second_name, country, date_of_birth, titles_won, is_active
        , f_run_id as run_id,
        case
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
            when date_of_birth is null
                then '[date_of_birth]: value should not be null; '
            else ''
        end ||
        case
            when is_active is null
                then '[is_active]: value should not be null; '
            else ''
        end as error_description
    from tmp_raw_players
    where 1=1
        and ((id_src is not null and id is null)
        or (first_name_src is not null and first_name is null)
        or (second_name_src is not null and second_name is null)
        or (id is null or length(trim(id)) = 0)
        or first_name is null
        or second_name is null
        or date_of_birth is null
        or is_active is null);

    drop table if exists tmp_raw_players;

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_raw_players', v_record_count, 'Raw table loaded successfully');

    raise info 'Table raw_players loaded successfully! Records inserted: %', f_record_inserted;

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_raw_players', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;



-- 1.1. stg.sp_load_players
create or replace procedure stg.sp_load_players(
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
        call stg.sp_truncate_buffer_players(f_run_id, f_load_date, f_rec_src, f_record_inserted, f_error_num, f_error_message);
        call stg.sp_load_buffer_players(f_run_id, f_load_date, f_rec_src, f_record_inserted, f_error_num, f_error_message);
        call stg.sp_truncate_raw_players(f_run_id, f_load_date, f_rec_src, f_record_inserted, f_error_num, f_error_message);
        call stg.sp_load_raw_players(f_run_id, f_load_date, f_rec_src, f_record_inserted, f_error_num, f_error_message);

        raise info 'The stored procedures (staging players) finished successfully!';

    exception when others then
        f_error_num = -1;
        f_error_message = substring(sqlerrm, 1, 200);

        insert into stg.log_table (run_id, object_name, records_count, message)
        values (f_run_id, 'sp_load_players', 0, 'Error: '|| f_error_message);

        raise info 'An exception occurred %', sqlerrm;
    end;
end;
$$;



-----------------------------------------------------------------------------
-- ====== PLAYER_PHYSICAL_DETAILS ====== --

-- 1.2.a. truncate buffer player_physical_details --
create or replace procedure stg.sp_truncate_buffer_player_physical_details(
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
    truncate table stg.buffer_player_physical_details;

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_truncate_buffer_player_physical_details', 0, 'Buffer truncated successfully');

    raise info 'Table buffer_player_physical_details truncated successfully!';

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_truncate_buffer_player_physical_details', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;



-- 1.2.b. load buffer player_physical_details --
create or replace procedure stg.sp_load_buffer_player_physical_details(
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
    copy stg.buffer_player_physical_details
    from '/var/lib/postgresql/import/data_src/playersphysicaldetails.csv'
    with (
        format csv,
        header true,
        delimiter ','
    );

    select count(*) into v_record_count from stg.buffer_player_physical_details;

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_buffer_player_physical_details', v_record_count, 'Buffer loaded successfully');

    f_record_inserted = v_record_count;

    raise info 'Table buffer_player_physical_details loaded successfully! Records inserted: %', f_record_inserted;

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_buffer_player_physical_details', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;



-- 1.2.c. truncate raw player_physical_details --
create or replace procedure stg.sp_truncate_raw_player_physical_details(
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
    truncate table stg.raw_player_physical_details;

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_truncate_raw_player_physical_details', 0, 'Raw table truncated successfully');

    raise info 'Table raw_player_physical_details truncated successfully!';

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_truncate_raw_player_physical_details', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;



-- 1.2.d. load raw player_physical_details --
create or replace procedure stg.sp_load_raw_player_physical_details(
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
    create temp table tmp_raw_player_physical_details (
        player_id_src VARCHAR
        , height_cm_src VARCHAR
        , weight_kg_src VARCHAR
        , dominant_hand_src VARCHAR
        , player_id VARCHAR(100)
        , height_cm SMALLINT
        , weight_kg SMALLINT
        , dominant_hand VARCHAR(50)
    );

    insert into tmp_raw_player_physical_details (
        player_id_src, height_cm_src, weight_kg_src, dominant_hand_src,
        player_id, height_cm, weight_kg, dominant_hand
    )
    select
        player_id, height_cm, weight_kg, dominant_hand,
        case when player_id is not null and length(trim(player_id)) <= 100
            then player_id else null end,
        case when height_cm is not null and cast(height_cm as int) between 0 and 250
            then cast(height_cm as SMALLINT) else null end,
        case when weight_kg is not null and cast(weight_kg as int) between 0 and 150
            then cast(weight_kg as SMALLINT) else null end,
        case when dominant_hand is not null and length(trim(dominant_hand)) <= 50
            then dominant_hand else null end
    from stg.buffer_player_physical_details;

    -- WSTAWIANIE POPRAWNYCH REKORDÓW DO WARSTWY RAW --
    insert into stg.raw_player_physical_details (
        player_sk
        , player_bk
        , height_cm
        , weight_kg
        , dominant_hand
        , sat_player_physical_details_hash_key
        , rec_src
        , load_dt
        , hash_diff
    )
    select distinct
        md5(upper(trim(coalesce(player_id, '')))) as player_sk
        , upper(trim(coalesce(player_id, ''))) as player_bk
        , height_cm
        , weight_kg
        , dominant_hand
        , md5(
            upper(trim(coalesce(player_id, ''))) || ';' ||
            upper(trim(coalesce(height_cm::text, ''))) || ';' ||
            upper(trim(coalesce(weight_kg::text, ''))) || ';' ||
            upper(trim(coalesce(dominant_hand, '')))
        ) as sat_player_physical_details_hash_key
        , f_rec_src as rec_src
        , f_load_date as load_dt
        , md5(
            upper(trim(coalesce(player_id, ''))) || ';' ||
            upper(trim(coalesce(height_cm::text, ''))) || ';' ||
            upper(trim(coalesce(weight_kg::text, ''))) || ';' ||
            upper(trim(coalesce(dominant_hand, '')))
        ) as hash_diff
    from tmp_raw_player_physical_details
    where 1=1
        and player_id is not null
        and length(trim(player_id)) > 0;

    get diagnostics v_record_count = row_count;
    f_record_inserted = v_record_count;

    truncate table stg.buffer_player_physical_details_not_valid;

    -- WSTAWIANIE NIEPOPRAWNYCH REKORDÓW --
    insert into stg.buffer_player_physical_details_not_valid (
        player_id, height_cm, weight_kg, dominant_hand,
        run_id, error_description
    )
    select
        player_id, height_cm::text, weight_kg::text, dominant_hand,
        f_run_id,
        case
            when player_id_src is not null and player_id is null
                then '[player_id]: data would be truncated; '
            else ''
        end ||
        case
            when height_cm_src is not null and height_cm is null
                then '[height_cm]: data would be truncated or invalid; '
            else ''
        end ||
        case
            when weight_kg_src is not null and weight_kg is null
                then '[weight_kg]: data would be truncated or invalid; '
            else ''
        end ||
        case
            when dominant_hand_src is not null and dominant_hand is null
                then '[dominant_hand]: data would be truncated; '
            else ''
        end ||
        case
            when player_id is null or length(trim(player_id)) = 0
                then '[player_id]: value should not be null; '
            else ''
        end as error_description
    from tmp_raw_player_physical_details
    where 1=1
        and (player_id_src is not null and player_id is null)
        or (height_cm_src is not null and height_cm is null)
        or (weight_kg_src is not null and weight_kg is null)
        or (dominant_hand_src is not null and dominant_hand is null)
        or (player_id is null or length(trim(player_id)) = 0);

    drop table if exists tmp_raw_player_physical_details;

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_raw_player_physical_details', v_record_count, 'Raw table loaded successfully');

    raise info 'Table raw_player_physical_details loaded successfully! Records inserted: %', f_record_inserted;

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_raw_player_physical_details', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;



-- 1.2. stg.sp_load_player_physical_details
create or replace procedure stg.sp_load_player_physical_details(
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
        call stg.sp_truncate_buffer_player_physical_details(f_run_id, f_load_date, f_rec_src, f_record_inserted, f_error_num, f_error_message);
        call stg.sp_load_buffer_player_physical_details(f_run_id, f_load_date, f_rec_src, f_record_inserted, f_error_num, f_error_message);
        call stg.sp_truncate_raw_player_physical_details(f_run_id, f_load_date, f_rec_src, f_record_inserted, f_error_num, f_error_message);
        call stg.sp_load_raw_player_physical_details(f_run_id, f_load_date, f_rec_src, f_record_inserted, f_error_num, f_error_message);

        raise info 'The stored procedures (staging player_physical_details) finished successfully!';

    exception when others then
        f_error_num = -1;
        f_error_message = substring(sqlerrm, 1, 200);

        insert into stg.log_table (run_id, object_name, records_count, message)
        values (f_run_id, 'sp_load_player_physical_details', 0, 'Error: '|| f_error_message);

        raise info 'An exception occurred %', sqlerrm;
    end;
end;
$$;



-----------------------------------------------------------------------------
-- ===== POZIOM DBO ===== --
-- ===== SATELITA STATUSU (pełna logika CRUD: Create/Update/Delete) ===== --
create or replace procedure dbo.sp_load_sat_player_status(
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
    insert into dbo.sat_player_status (player_sk, load_dt, load_end_dt, rec_src, status)
    select distinct
        hp.player_sk
        , f_load_date
        , null::timestamp
        , f_rec_src
        , 'D'
    from dbo.hub_players as hp
    where exists (
            select sps.player_sk
            from dbo.sat_player_status as sps
            where 1=1
                and sps.player_sk = hp.player_sk
                and sps.status in ('C', 'U')
                and sps.load_end_dt is null
        )
        and not exists (
            select rp.player_sk
            from stg.raw_players as rp
            where rp.player_sk = hp.player_sk
        )
        and not exists (
            select sps.player_sk
            from dbo.sat_player_status as sps
            where 1=1
                and sps.player_sk = hp.player_sk
                and sps.status = 'D'
                and sps.load_end_dt is null
        );

    get diagnostics v_delete_count = row_count;

    update dbo.sat_player_status as old_sat
    set load_end_dt = f_load_date - interval '1 second'
    where old_sat.load_end_dt is null
        and old_sat.status in ('C', 'U')
        and old_sat.load_dt < f_load_date
        and exists (
            select new_sat.player_sk
            from dbo.sat_player_status as new_sat
            where 1=1
                and new_sat.player_sk = old_sat.player_sk
                and new_sat.status = 'D'
                and new_sat.load_dt = f_load_date
        );


    -- CRUD: Create, status = 'C' (nowy rekord, nigdy wcześniej w dbo)
    insert into dbo.sat_player_status (player_sk, load_dt, load_end_dt, rec_src, status)
    select distinct
        rp.player_sk
        , f_load_date
        , null::timestamp
        , f_rec_src
        , 'C'
    from stg.raw_players as rp
    where not exists (
            select sps.player_sk
            from dbo.sat_player_status as sps
            where 1=1
                and sps.player_sk = rp.player_sk
                and sps.status is not null
        )
        and not exists (
            select sps.player_sk
            from dbo.sat_player_status as sps
            where 1=1
                and sps.player_sk = rp.player_sk
                and sps.load_dt = f_load_date
        );

    get diagnostics v_create_count = row_count;


    -- CRUD: Create, status = 'C' (rekord wraca po wcześniejszym usunięciu)
    insert into dbo.sat_player_status (player_sk, load_dt, load_end_dt, rec_src, status)
    select distinct
        rp.player_sk
        , f_load_date
        , null::timestamp
        , f_rec_src
        , 'C'
    from stg.raw_players as rp
    where exists (
            select sps.player_sk
            from dbo.sat_player_status as sps
            where 1=1
                and sps.player_sk = rp.player_sk
                and sps.status = 'D'
                and sps.load_end_dt is null
        )
        and not exists (
            select sps.player_sk
            from dbo.sat_player_status as sps
            where 1=1
                and sps.player_sk = rp.player_sk
                and sps.load_dt = f_load_date
        );

    get diagnostics v_update_count = row_count;
    v_create_count := v_create_count + v_update_count;

    update dbo.sat_player_status as old_sat
    set load_end_dt = f_load_date - interval '1 second'
    where old_sat.load_end_dt is null
        and old_sat.status = 'D'
        and old_sat.load_dt < f_load_date
        and exists (
            select new_sat.player_sk
            from dbo.sat_player_status as new_sat
            where 1=1
                and new_sat.player_sk = old_sat.player_sk
                and new_sat.status = 'C'
                and new_sat.load_dt = f_load_date
        );


    -- statystyki planera po wstawieniu wierszy 'C'/'D' w tej samej transakcji;
    -- bez tego planer zakłada pustą tabelę (rows=1) i wybiera Nested Loop O(n^2)
    analyze dbo.sat_player_status;

    -- CRUD: Update, status = 'U' (dane rekordu się zmieniły)
    insert into dbo.sat_player_status (player_sk, load_dt, load_end_dt, rec_src, status)
    select distinct
        rp.player_sk
        , f_load_date
        , null::timestamp
        , f_rec_src
        , 'U'
    from stg.raw_players as rp
    where exists (
            select sps.player_sk
            from dbo.sat_player_status as sps
            where 1=1 and
                sps.player_sk = rp.player_sk
                and sps.status in ('C', 'U')
                and sps.load_dt < f_load_date
                and not exists (
                  select sps2.player_sk
                  from dbo.sat_player_status as sps2
                  where sps2.player_sk = sps.player_sk
                    and sps2.load_dt > sps.load_dt
              )
        )
        and (
            exists
                (select sppi.player_sk
                 from dbo.sat_player_personal_info as sppi
                 where 1=1
                    and sppi.player_sk = rp.player_sk
                    and sppi.load_dt = f_load_date)

            or exists
                (select sppd.player_sk
                 from dbo.sat_player_physical_details as sppd
                 where 1=1
                    and sppd.player_sk = rp.player_sk
                    and sppd.load_dt = f_load_date)

            or exists
                (select spdob.player_sk
                 from dbo.sat_player_date_of_birth as spdob
                 where 1=1
                    and spdob.player_sk = rp.player_sk
                    and spdob.load_dt = f_load_date)
        )
        and not exists (
            select sps.player_sk
            from dbo.sat_player_status as sps
            where 1=1
                and sps.player_sk = rp.player_sk
                and sps.load_dt = f_load_date
        );

    get diagnostics v_update_count = row_count;

    update dbo.sat_player_status as old_sat
    set load_end_dt = f_load_date - interval '1 second'
    where old_sat.load_end_dt is null
        and old_sat.status in ('C', 'U')
        and old_sat.load_dt < f_load_date
        and exists (
            select new_sat.player_sk
            from dbo.sat_player_status as new_sat
            where 1=1
                and new_sat.player_sk = old_sat.player_sk
                and new_sat.status = 'U'
                and new_sat.load_dt = f_load_date
        );

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_sat_player_status', v_create_count + v_delete_count + v_update_count,
            format('Created: %s, Deleted: %s, Updated: %s', v_create_count, v_delete_count, v_update_count));

    f_record_inserted = v_create_count + v_update_count;
    f_record_updated = v_delete_count;

    raise info 'Table sat_player_status loaded successfully: Created=%, Deleted=%, Updated=%',
               v_create_count, v_delete_count, v_update_count;

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_sat_player_status', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;



-- ===== HUB ===== --
-- 2.a. dbo.sp_load_hub_players
create or replace procedure dbo.sp_load_hub_players(
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
    insert into dbo.hub_players (player_sk, rec_src, load_dt, player_bk)
    select distinct
        player_sk
        , rec_src
        , load_dt
        , player_bk
    from stg.v_hub_players as vhp
    where not exists (
        select hp.player_sk
        from dbo.hub_players as hp
        where hp.player_sk = vhp.player_sk
    );

    get diagnostics v_record_count = row_count;

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_hub_players', v_record_count, 'Hub loaded successfully');

    f_record_inserted = v_record_count;

    raise info 'Table hub_players loaded successfully! Records inserted: %', f_record_inserted;

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_hub_players', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;



-- ===== SATELITY ===== --
-- 3.a. dbo.sp_load_sat_player_date_of_birth
create or replace procedure dbo.sp_load_sat_player_date_of_birth(
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
    update dbo.sat_player_date_of_birth as old_sat
    set load_end_dt = f_load_date - interval '1 second'
    where old_sat.load_end_dt is null
      and exists (
          select new_sat.player_sk
          from stg.v_sat_player_date_of_birth as new_sat
          where 1=1
            and new_sat.player_sk = old_sat.player_sk
            and new_sat.hash_diff != old_sat.hash_diff
      );

    get diagnostics v_updated_count = row_count;

    insert into dbo.sat_player_date_of_birth (
        player_sk, load_dt, rec_src, load_end_dt, hash_diff, date_of_birth
    )
    select distinct
        player_sk
        , load_dt
        , rec_src
        , null::timestamp as load_end_dt
        , hash_diff
        , date_of_birth
    from stg.v_sat_player_date_of_birth as vspdob
    where not exists (
        select spdob.player_sk
        from dbo.sat_player_date_of_birth as spdob
        where 1=1
            and spdob.player_sk = vspdob.player_sk
            and spdob.hash_diff = vspdob.hash_diff
            and spdob.load_end_dt is null
    );

    get diagnostics v_record_count = row_count;

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_sat_player_date_of_birth', v_record_count, 'Satellite loaded successfully');

    f_record_inserted = v_record_count;
    f_record_updated = v_updated_count;

    raise info 'Table sat_player_date_of_birth updated successfully! Records updated: %', f_record_updated;
    raise info 'Table sat_player_date_of_birth loaded successfully! Records inserted: %', f_record_inserted;

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_sat_player_date_of_birth', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;



-- 3.b. dbo.sp_load_sat_player_personal_info
create or replace procedure dbo.sp_load_sat_player_personal_info(
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
    update dbo.sat_player_personal_info as old_sat
    set load_end_dt = f_load_date - interval '1 second'
    where old_sat.load_end_dt is null
      and exists (
          select new_sat.player_sk
          from stg.v_sat_player_personal_info as new_sat
          where 1=1
            and new_sat.player_sk = old_sat.player_sk
            and new_sat.hash_diff != old_sat.hash_diff
      );

    get diagnostics v_updated_count = row_count;

    insert into dbo.sat_player_personal_info (
        player_sk, load_dt, rec_src, load_end_dt, hash_diff, first_name, second_name, country, titles_won, is_active
    )
    select distinct
        player_sk
        , load_dt
        , rec_src
        , null::timestamp as load_end_dt
        , hash_diff
        , first_name
        , second_name
        , country
        , titles_won
        , is_active
    from stg.v_sat_player_personal_info as vsppi
    where not exists (
        select sppi.player_sk
        from dbo.sat_player_personal_info as sppi
        where 1=1
            and sppi.player_sk = vsppi.player_sk
            and sppi.hash_diff = vsppi.hash_diff
            and sppi.load_end_dt is null
    );

    get diagnostics v_record_count = row_count;

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_sat_player_personal_info', v_record_count, 'Satellite loaded successfully');

    f_record_inserted = v_record_count;
    f_record_updated = v_updated_count;

    raise info 'Table sat_player_personal_info updated successfully! Records updated: %', f_record_updated;
    raise info 'Table sat_player_personal_info loaded successfully! Records inserted: %', f_record_inserted;

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_sat_player_personal_info', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;



-- 3.c. dbo.sp_load_sat_player_physical_details
create or replace procedure dbo.sp_load_sat_player_physical_details(
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
    update dbo.sat_player_physical_details as old_sat
    set load_end_dt = f_load_date - interval '1 second'
    where old_sat.load_end_dt is null
      and exists (
          select new_sat.player_sk
          from stg.v_sat_player_physical_details as new_sat
          where 1=1
            and new_sat.player_sk = old_sat.player_sk
            and new_sat.hash_diff != old_sat.hash_diff
      );

    get diagnostics v_updated_count = row_count;

    insert into dbo.sat_player_physical_details (
        player_sk, load_dt, rec_src, load_end_dt, hash_diff,
        height_cm, weight_kg, dominant_hand
    )
    select distinct
        player_sk
        , load_dt
        , rec_src
        , null::timestamp as load_end_dt
        , hash_diff
        , height_cm
        , weight_kg
        , dominant_hand
    from stg.v_sat_player_physical_details as vsppd
    where not exists (
        select sppd.player_sk
        from dbo.sat_player_physical_details as sppd
        where 1=1
            and sppd.player_sk = vsppd.player_sk
            and sppd.hash_diff = vsppd.hash_diff
            and sppd.load_end_dt is null
    );

    get diagnostics v_record_count = row_count;

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_sat_player_physical_details', v_record_count, 'Satellite loaded successfully');

    f_record_inserted = v_record_count;
    f_record_updated = v_updated_count;

    raise info 'Table sat_player_physical_details updated successfully! Records updated: %', f_record_updated;
    raise info 'Table sat_player_physical_details loaded successfully! Records inserted: %', f_record_inserted;

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_sat_player_physical_details', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;


--rollback DROP PROCEDURE IF EXISTS dbo.sp_load_sat_player_physical_details;
--rollback DROP PROCEDURE IF EXISTS dbo.sp_load_sat_player_personal_info;
--rollback DROP PROCEDURE IF EXISTS dbo.sp_load_sat_player_date_of_birth;
--rollback DROP PROCEDURE IF EXISTS dbo.sp_load_hub_players;
--rollback DROP PROCEDURE IF EXISTS dbo.sp_load_sat_player_status;
--rollback DROP PROCEDURE IF EXISTS stg.sp_load_player_physical_details;
--rollback DROP PROCEDURE IF EXISTS stg.sp_load_raw_player_physical_details;
--rollback DROP PROCEDURE IF EXISTS stg.sp_truncate_raw_player_physical_details;
--rollback DROP PROCEDURE IF EXISTS stg.sp_load_buffer_player_physical_details;
--rollback DROP PROCEDURE IF EXISTS stg.sp_truncate_buffer_player_physical_details;
--rollback DROP PROCEDURE IF EXISTS stg.sp_load_players;
--rollback DROP PROCEDURE IF EXISTS stg.sp_load_raw_players;
--rollback DROP PROCEDURE IF EXISTS stg.sp_truncate_raw_players;
--rollback DROP PROCEDURE IF EXISTS stg.sp_load_buffer_players;
--rollback DROP PROCEDURE IF EXISTS stg.sp_truncate_buffer_players;
