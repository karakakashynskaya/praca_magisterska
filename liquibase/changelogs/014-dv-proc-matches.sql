--liquibase formatted sql
--changeset kkakashynskaya:14-dv-proc-matches splitStatements:false runOnChange:true
--liquibase formatted sql

-- ====== MATCHES ====== --
-- 1.1.a. truncate buffer matches --
create or replace procedure stg.sp_truncate_buffer_matches(
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
    truncate table stg.buffer_matches;

    insert into stg.log_table (object_name, records_count, message)
    values ('sp_truncate_buffer_matches', 0, 'Buffer truncated successfully');

    raise info 'Table buffer_matches truncated successfully!';

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (object_name, records_count, message)
    values ('sp_truncate_buffer_matches', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;



-- 1.1.b. load buffer matches --
create or replace procedure stg.sp_load_buffer_matches(
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
    copy stg.buffer_matches
    from '/var/lib/postgresql/import/data_src/matches.csv'
    with (
        format csv,
        header true,
        delimiter ','
    );

    select count(*) into v_record_count from stg.buffer_matches;

    insert into stg.log_table (object_name, records_count, message)
    values ('sp_load_buffer_matches', v_record_count, 'Buffer loaded successfully');

    f_record_inserted = v_record_count;

    raise info 'Table buffer_matches loaded successfully! Records inserted: %', f_record_inserted;

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (object_name, records_count, message)
    values ('sp_load_buffer_matches', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;



-- 1.1.c. truncate raw matches --
create or replace procedure stg.sp_truncate_raw_matches(
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
    truncate table stg.raw_matches;

    insert into stg.log_table (object_name, records_count, message)
    values ('sp_truncate_raw_matches', 0, 'Raw table truncated successfully');

    raise info 'Table raw_matches truncated successfully!';

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (object_name, records_count, message)
    values ('sp_truncate_raw_matches', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;



-- 1.1.d. load raw matches --
create or replace procedure stg.sp_load_raw_matches(
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

    create temp table tmp_raw_matches (
        id_src VARCHAR
        , tournament_id_src VARCHAR
        , player1_id_src VARCHAR
        , player2_id_src VARCHAR
        , winner_id_src VARCHAR
        , date_of_match_src VARCHAR
        , match_round_src VARCHAR
        , first_set_score_src VARCHAR
        , second_set_score_src VARCHAR
        , third_set_score_src VARCHAR
        , final_score_src VARCHAR
        , match_duration_src VARCHAR
        , id VARCHAR(100)
        , tournament_id VARCHAR(100)
        , player1_id VARCHAR(100)
        , player2_id VARCHAR(100)
        , winner_id VARCHAR(100)
        , date_of_match DATE
        , match_round VARCHAR(5)
        , first_set_score VARCHAR(11)
        , second_set_score VARCHAR(11)
        , third_set_score VARCHAR(11)
        , final_score CHAR(3)
        , match_duration TIME
    );

    insert into tmp_raw_matches (
        id_src, tournament_id_src, player1_id_src, player2_id_src, winner_id_src,
        date_of_match_src, match_round_src, first_set_score_src, second_set_score_src,
        third_set_score_src, final_score_src, match_duration_src,
        id, tournament_id, player1_id, player2_id, winner_id,
        date_of_match, match_round, first_set_score, second_set_score,
        third_set_score, final_score, match_duration
    )
    select
        id, tournament_id, player1_id, player2_id, winner_id,
        date_of_match, match_round, first_set_score, second_set_score,
        third_set_score, final_score, match_duration,
        case when id is not null and length(trim(id)) <= 100
            then id else null end,
        case when tournament_id is not null and length(trim(tournament_id)) <= 100
            then tournament_id else null end,
        case when player1_id is not null and length(trim(player1_id)) <= 100
            then player1_id else null end,
        case when player2_id is not null and length(trim(player2_id)) <= 100
            then player2_id else null end,
        case when winner_id is not null and length(trim(winner_id)) <= 100
            then winner_id else null end,
        case when date_of_match is not null
            then cast(date_of_match as DATE) else null end,
        case when match_round is not null and length(trim(match_round)) <= 5
            then match_round else null end,
        case when first_set_score is not null and length(trim(first_set_score)) <= 11
            then first_set_score else null end,
        case when second_set_score is not null and length(trim(second_set_score)) <= 11
            then second_set_score else null end,
        case when third_set_score is not null and length(trim(third_set_score)) <= 11
            then third_set_score else null end,
        case when final_score is not null and length(trim(final_score)) <= 3
            then final_score else null end,
        case when match_duration is not null
            then cast(match_duration as TIME) else null end
    from stg.buffer_matches;

    -- INSERTING VALID RECORDS TO RAW LAYER --
    insert into stg.raw_matches (
        match_sk
        , match_bk
        , tournament_sk
        , tournament_bk
        , player1_sk
        , player1_bk
        , player2_sk
        , player2_bk
        , winner_sk
        , winner_bk
        , date_of_match
        , match_round
        , first_set_score
        , second_set_score
        , third_set_score
        , final_score
        , match_duration
        , match_tournament_sk
        , match_player1_sk
        , match_player2_sk
        , player1_first_set_score
        , player2_first_set_score
        , player1_second_set_score
        , player2_second_set_score
        , player1_third_set_score
        , player2_third_set_score
        , player1_final_score
        , player2_final_score
        , sat_match_details_hash_key
        , sat_match_player1_result_hash_key
        , sat_match_player2_result_hash_key
        , rec_src
        , load_dt
        , hash_diff
    )
    with tmp_valid_matches as (
        select distinct
            md5(upper(trim(coalesce(id, '')))) as match_sk
            , upper(trim(coalesce(id, ''))) as match_bk
            , md5(upper(trim(coalesce(tournament_id, '')))) as tournament_sk
            , upper(trim(coalesce(tournament_id, ''))) as tournament_bk
            , md5(upper(trim(coalesce(player1_id, '')))) as player1_sk
            , upper(trim(coalesce(player1_id, ''))) as player1_bk
            , md5(upper(trim(coalesce(player2_id, '')))) as player2_sk
            , upper(trim(coalesce(player2_id, ''))) as player2_bk
            , md5(upper(trim(coalesce(winner_id, '')))) as winner_sk
            , upper(trim(coalesce(winner_id, ''))) as winner_bk
            , date_of_match
            , match_round
            , first_set_score
            , second_set_score
            , third_set_score
            , final_score
            , match_duration
            , cast(split_part(first_set_score, '-', 1) as INT) as player1_first_set_score
            , cast(split_part(first_set_score, '-', 2) as INT) as player2_first_set_score
            , cast(split_part(second_set_score, '-', 1) as INT) as player1_second_set_score
            , cast(split_part(second_set_score, '-', 2) as INT) as player2_second_set_score
            , case when third_set_score is not null
                then cast(split_part(third_set_score, '-', 1) as INT)
                else null end as player1_third_set_score
            , case when third_set_score is not null
                then cast(split_part(third_set_score, '-', 2) as INT)
                else null end as player2_third_set_score
            , cast(split_part(final_score, '-', 1) as INT) as player1_final_score
            , cast(split_part(final_score, '-', 2) as INT) as player2_final_score
            , md5(
                upper(trim(coalesce(id, ''))) || ';' ||
                upper(trim(coalesce(date_of_match::text, ''))) || ';' ||
                upper(trim(coalesce(match_round, ''))) || ';' ||
                upper(trim(coalesce(match_duration::text, '')))
            ) as sat_match_details_hash_key
            , md5(
                upper(trim(coalesce(player1_id, ''))) || ';' ||
                cast(split_part(first_set_score, '-', 1) as TEXT) || ';' ||
                cast(split_part(second_set_score, '-', 1) as TEXT) || ';' ||
                coalesce(cast(split_part(third_set_score, '-', 1) as TEXT), '') || ';' ||
                cast(split_part(final_score, '-', 1) as TEXT) || ';' ||
                case when winner_id = player1_id then 'T' else 'F' end
            ) as sat_match_player1_result_hash_key
            , md5(
                upper(trim(coalesce(player2_id, ''))) || ';' ||
                cast(split_part(first_set_score, '-', 2) as TEXT) || ';' ||
                cast(split_part(second_set_score, '-', 2) as TEXT) || ';' ||
                coalesce(cast(split_part(third_set_score, '-', 2) as TEXT), '') || ';' ||
                cast(split_part(final_score, '-', 2) as TEXT) || ';' ||
                case when winner_id = player2_id then 'T' else 'F' end
            ) as sat_match_player2_result_hash_key
            , md5(
                upper(trim(coalesce(id, ''))) || ';' ||
                upper(trim(coalesce(tournament_id, ''))) || ';' ||
                upper(trim(coalesce(player1_id, ''))) || ';' ||
                upper(trim(coalesce(player2_id, ''))) || ';' ||
                upper(trim(coalesce(winner_id, ''))) || ';' ||
                upper(trim(coalesce(date_of_match::text, ''))) || ';' ||
                upper(trim(coalesce(match_round, ''))) || ';' ||
                upper(trim(coalesce(first_set_score, ''))) || ';' ||
                upper(trim(coalesce(second_set_score, ''))) || ';' ||
                upper(trim(coalesce(third_set_score, ''))) || ';' ||
                upper(trim(coalesce(final_score, ''))) || ';' ||
                upper(trim(coalesce(match_duration::text, '')))
            ) as hash_diff
        from tmp_raw_matches
        where 1=1
            and id is not null
            and length(trim(id)) > 0
            and tournament_id is not null
            and player1_id is not null
            and player2_id is not null
            and winner_id is not null
            and date_of_match is not null
            and match_round is not null
            and first_set_score is not null
            and second_set_score is not null
            and final_score is not null
            and first_set_score ~ '^[0-9]+-[0-9]+$'
            and second_set_score ~ '^[0-9]+-[0-9]+$'
            and (third_set_score is null or third_set_score ~ '^[0-9]+-[0-9]+$')
            and final_score ~ '^[0-9]+-[0-9]+$'
    )
    select
        match_sk
        , match_bk
        , tournament_sk
        , tournament_bk
        , player1_sk
        , player1_bk
        , player2_sk
        , player2_bk
        , winner_sk
        , winner_bk
        , date_of_match
        , match_round
        , first_set_score
        , second_set_score
        , third_set_score
        , final_score
        , match_duration
        , md5(
            upper(trim(coalesce(match_sk, ''))) || ';' ||
            upper(trim(coalesce(tournament_sk, '')))
        ) as match_tournament_sk
        , md5(
            upper(trim(coalesce(match_sk, ''))) || ';' ||
            upper(trim(coalesce(player1_sk, ''))) || ';1'
        ) as match_player1_sk
        , md5(
            upper(trim(coalesce(match_sk, ''))) || ';' ||
            upper(trim(coalesce(player2_sk, ''))) || ';2'
        ) as match_player2_sk
        , player1_first_set_score
        , player2_first_set_score
        , player1_second_set_score
        , player2_second_set_score
        , player1_third_set_score
        , player2_third_set_score
        , player1_final_score
        , player2_final_score
        , sat_match_details_hash_key
        , sat_match_player1_result_hash_key
        , sat_match_player2_result_hash_key
        , f_rec_src as rec_src
        , f_load_date as load_dt
        , hash_diff
    from tmp_valid_matches;

    get diagnostics v_record_count = row_count;
    f_record_inserted = v_record_count;

    truncate table stg.buffer_matches_not_valid;

    -- INSERTING INVALID RECORDS --
    insert into stg.buffer_matches_not_valid (
        id, tournament_id, player1_id, player2_id, winner_id,
        date_of_match, match_round, first_set_score, second_set_score,
        third_set_score, final_score, match_duration, run_id, error_description
    )
    select
        id, tournament_id, player1_id, player2_id, winner_id,
        date_of_match, match_round, first_set_score, second_set_score,
        third_set_score, final_score, match_duration, f_run_id,
        case
            when id_src is not null and id is null
                then '[id]: data would be truncated; '
            else ''
        end ||
        case
            when tournament_id_src is not null and tournament_id is null
                then '[tournament_id]: data would be truncated; '
            else ''
        end ||
        case
            when player1_id_src is not null and player1_id is null
                then '[player1_id]: data would be truncated; '
            else ''
        end ||
        case
            when player2_id_src is not null and player2_id is null
                then '[player2_id]: data would be truncated; '
            else ''
        end ||
        case
            when winner_id_src is not null and winner_id is null
                then '[winner_id]: data would be truncated; '
            else ''
        end ||
        case
            when match_round_src is not null and match_round is null
                then '[match_round]: data would be truncated; '
            else ''
        end ||
        case
            when first_set_score_src is not null and first_set_score is null
                then '[first_set_score]: data would be truncated; '
            else ''
        end ||
        case
            when second_set_score_src is not null and second_set_score is null
                then '[second_set_score]: data would be truncated; '
            else ''
        end ||
        case
            when final_score_src is not null and final_score is null
                then '[final_score]: data would be truncated; '
            else ''
        end ||
        case
            when id is null or length(trim(id)) = 0
                then '[id]: value should not be null; '
            else ''
        end ||
        case
            when tournament_id is null
                then '[tournament_id]: value should not be null; '
            else ''
        end ||
        case
            when player1_id is null
                then '[player1_id]: value should not be null; '
            else ''
        end ||
        case
            when player2_id is null
                then '[player2_id]: value should not be null; '
            else ''
        end ||
        case
            when winner_id is null
                then '[winner_id]: value should not be null; '
            else ''
        end ||
        case
            when date_of_match is null
                then '[date_of_match]: value should not be null; '
            else ''
        end ||
        case
            when match_round is null
                then '[match_round]: value should not be null; '
            else ''
        end ||
        case
            when first_set_score is null
                then '[first_set_score]: value should not be null; '
            else ''
        end ||
        case
            when second_set_score is null
                then '[second_set_score]: value should not be null; '
            else ''
        end ||
        case
            when final_score is null
                then '[final_score]: value should not be null; '
            else ''
        end ||
        case
            when first_set_score is not null and first_set_score !~ '^[0-9]+-[0-9]+$'
                then '[first_set_score]: invalid format (expected N-N); '
            else ''
        end ||
        case
            when second_set_score is not null and second_set_score !~ '^[0-9]+-[0-9]+$'
                then '[second_set_score]: invalid format (expected N-N); '
            else ''
        end ||
        case
            when third_set_score is not null and third_set_score !~ '^[0-9]+-[0-9]+$'
                then '[third_set_score]: invalid format (expected N-N); '
            else ''
        end ||
        case
            when final_score is not null and final_score !~ '^[0-9]+-[0-9]+$'
                then '[final_score]: invalid format (expected N-N); '
            else ''
        end as error_description
    from tmp_raw_matches
    where 1=1
        and (
            (id_src is not null and id is null)
            or (tournament_id_src is not null and tournament_id is null)
            or (player1_id_src is not null and player1_id is null)
            or (player2_id_src is not null and player2_id is null)
            or (winner_id_src is not null and winner_id is null)
            or (match_round_src is not null and match_round is null)
            or (first_set_score_src is not null and first_set_score is null)
            or (second_set_score_src is not null and second_set_score is null)
            or (final_score_src is not null and final_score is null)
            or (id is null or length(trim(id)) = 0)
            or tournament_id is null
            or player1_id is null
            or player2_id is null
            or winner_id is null
            or date_of_match is null
            or match_round is null
            or first_set_score is null
            or second_set_score is null
            or final_score is null
            or (first_set_score is not null and first_set_score !~ '^[0-9]+-[0-9]+$')
            or (second_set_score is not null and second_set_score !~ '^[0-9]+-[0-9]+$')
            or (third_set_score is not null and third_set_score !~ '^[0-9]+-[0-9]+$')
            or (final_score is not null and final_score !~ '^[0-9]+-[0-9]+$')
        );

    drop table if exists tmp_raw_matches;

    insert into stg.log_table (object_name, records_count, message)
    values ('sp_load_raw_matches', v_record_count, 'Raw table loaded successfully');

    raise info 'Table raw_matches loaded successfully! Records inserted: %', f_record_inserted;

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (object_name, records_count, message)
    values ('sp_load_raw_matches', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;



-- 1.1. stg.sp_load_matches:
create or replace procedure stg.sp_load_matches(
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
        call stg.sp_truncate_buffer_matches(f_run_id, f_load_date, f_rec_src, f_record_inserted, f_error_num, f_error_message);
        call stg.sp_load_buffer_matches(f_run_id, f_load_date, f_rec_src, f_record_inserted, f_error_num, f_error_message);
        call stg.sp_truncate_raw_matches(f_run_id, f_load_date, f_rec_src, f_record_inserted, f_error_num, f_error_message);
        call stg.sp_load_raw_matches(f_run_id, f_load_date, f_rec_src, f_record_inserted, f_error_num, f_error_message);

        raise info 'The stored procedures (staging matches) finished successfully!';
        raise info '----------------------------------------------------------------';

    exception when others then
        f_error_num = -1;
        f_error_message = substring(sqlerrm, 1, 200);

        insert into stg.log_table (object_name, records_count, message)
        values ('sp_load_matches', 0, 'Error: '|| f_error_message);

        raise info 'An exception occurred %', sqlerrm;
    end;
end;
$$;




-----------------------------------------------------------------------------
-- ===== DBO LEVEL ===== --
-- ===== STATUS TRACKING SATELLITE ===== --
create or replace procedure dbo.sp_load_sat_match_status(
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

    -- CRUD: Delete, status = 'D' (when deleted row)
    insert into dbo.sat_match_status (match_sk, load_dt, load_end_dt, rec_src, status)
    select distinct
        hm.match_sk
        , f_load_date
        , null::timestamp
        , f_rec_src
        , 'D'
    from dbo.hub_matches as hm
    where exists (
            select sms.match_sk
            from dbo.sat_match_status as sms
            where 1=1
                and sms.match_sk = hm.match_sk
                and sms.status in ('C', 'U')
                and sms.load_end_dt is null
        )
        and not exists (
            select rm.match_sk
            from stg.raw_matches as rm
            where rm.match_sk = hm.match_sk
        )
        and not exists (
            select sms.match_sk
            from dbo.sat_match_status as sms
            where 1=1
                and sms.match_sk = hm.match_sk
                and sms.status = 'D'
                and sms.load_end_dt is null
        );

    get diagnostics v_delete_count = row_count;

    update dbo.sat_match_status as old_sat
    set load_end_dt = f_load_date - interval '1 second'
    where old_sat.load_end_dt is null
        and old_sat.status in ('C', 'U')
        and old_sat.load_dt < f_load_date
        and exists (
            select new_sat.match_sk
            from dbo.sat_match_status as new_sat
            where 1=1
                and new_sat.match_sk = old_sat.match_sk
                and new_sat.status = 'D'
                and new_sat.load_dt = f_load_date
        );


    -- CRUD: Create, status = 'C' (when new row, never in dbo before)
    insert into dbo.sat_match_status (match_sk, load_dt, load_end_dt, rec_src, status)
    select distinct
        rm.match_sk
        , f_load_date
        , null::timestamp
        , f_rec_src
        , 'C'
    from stg.raw_matches as rm
    where not exists (
            select sms.match_sk
            from dbo.sat_match_status as sms
            where 1=1
                and sms.match_sk = rm.match_sk
        )
        and not exists (
            select sms.match_sk
            from dbo.sat_match_status as sms
            where 1=1
                and sms.match_sk = rm.match_sk
                and sms.load_dt = f_load_date
        );

    get diagnostics v_create_count = row_count;


    -- CRUD: Create, status = 'C' (when new row, but was in dbo before (previously deleted))
    insert into dbo.sat_match_status (match_sk, load_dt, load_end_dt, rec_src, status)
    select distinct
        rm.match_sk
        , f_load_date
        , null::timestamp
        , f_rec_src
        , 'C'
    from stg.raw_matches as rm
    where exists (
            select sms.match_sk
            from dbo.sat_match_status as sms
            where 1=1
                and sms.match_sk = rm.match_sk
                and sms.status = 'D'
                and sms.load_end_dt is null
        )
        and not exists (
            select sms.match_sk
            from dbo.sat_match_status as sms
            where 1=1
                and sms.match_sk = rm.match_sk
                and sms.load_dt = f_load_date
        );

    get diagnostics v_update_count = row_count;
    v_create_count := v_create_count + v_update_count;

    update dbo.sat_match_status as old_sat
    set load_end_dt = f_load_date - interval '1 second'
    where old_sat.load_end_dt is null
        and old_sat.status = 'D'
        and old_sat.load_dt < f_load_date
        and exists (
            select new_sat.match_sk
            from dbo.sat_match_status as new_sat
            where 1=1
                and new_sat.match_sk = old_sat.match_sk
                and new_sat.status = 'C'
                and new_sat.load_dt = f_load_date
        );



    -- statystyki planera po wstawieniu wierszy 'C'/'D' w tej samej transakcji;
    -- bez tego planer zakłada pustą tabelę (rows=1) i wybiera Nested Loop O(n^2)
    analyze dbo.sat_match_status;

    -- CRUD: Update, status = 'U' (row's data has changed)
    insert into dbo.sat_match_status (match_sk, load_dt, load_end_dt, rec_src, status)
    select distinct
        rm.match_sk
        , f_load_date
        , null::timestamp
        , f_rec_src
        , 'U'
    from stg.raw_matches as rm
    where exists (
        select sms.match_sk
        from dbo.sat_match_status as sms
        where sms.match_sk = rm.match_sk
            and sms.status in ('C', 'U')
            and sms.load_end_dt is null
    )
    and (
        exists (
            select smd.match_sk
            from dbo.sat_match_details as smd
            where smd.match_sk = rm.match_sk
                and smd.load_dt = f_load_date
        )
        or
        exists (
            select lmp.match_sk
            from dbo.sat_match_player_result as smpr
            join dbo.link_match_player as lmp
                on lmp.match_player_sk = smpr.match_player_sk
            where lmp.match_sk = rm.match_sk
                and smpr.load_dt = f_load_date
        )
    )
    and not exists (
        select sms.match_sk
        from dbo.sat_match_status as sms
        where sms.match_sk = rm.match_sk
            and sms.load_dt = f_load_date
    );

    get diagnostics v_update_count = row_count;

    update dbo.sat_match_status as old_sat
    set load_end_dt = f_load_date - interval '1 second'
    where old_sat.load_end_dt is null
        and old_sat.status in ('C', 'U')
        and old_sat.load_dt < f_load_date
        and exists (
            select new_sat.match_sk
            from dbo.sat_match_status as new_sat
            where 1=1
                and new_sat.match_sk = old_sat.match_sk
                and new_sat.status = 'U'
                and new_sat.load_dt = f_load_date
        );

    insert into stg.log_table (object_name, records_count, message)
    values ('sp_load_sat_match_status', v_create_count + v_delete_count + v_update_count,
            format('Created: %s, Deleted: %s, Updated: %s', v_create_count, v_delete_count, v_update_count));

    f_record_inserted = v_create_count + v_update_count;
    f_record_updated = v_delete_count;

    raise info 'Table sat_match_status loaded successfully: Created=%, Deleted=%, Updated=%',
               v_create_count, v_delete_count, v_update_count;

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (object_name, records_count, message)
    values ('sp_load_sat_match_status', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;




-- ===== HUBS ===== --
-- 2.a. dbo.sp_load_hub_matches:
create or replace procedure dbo.sp_load_hub_matches(
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
    insert into dbo.hub_matches (match_sk, rec_src, load_dt, match_bk)
    select distinct
        match_sk
        , rec_src
        , load_dt
        , match_bk
    from stg.v_hub_matches as vhm
    where not exists (
        select hm.match_sk
        from dbo.hub_matches as hm
        where hm.match_sk = vhm.match_sk
    );

    get diagnostics v_record_count = row_count;

    insert into stg.log_table (object_name, records_count, message)
    values ('sp_load_hub_matches', v_record_count, 'Hub loaded successfully');

    f_record_inserted = v_record_count;

    raise info 'Table hub_matches loaded successfully! Records inserted: %', f_record_inserted;

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (object_name, records_count, message)
    values ('sp_load_hub_matches', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;


-- ===== LINKS ===== --
-- 3.a. dbo.sp_load_link_match_tournament:
create or replace procedure dbo.sp_load_link_match_tournament(
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
    insert into dbo.link_match_tournament (match_tournament_sk, rec_src, load_dt, match_sk, tournament_sk)
    select distinct
        match_tournament_sk
        , rec_src
        , load_dt
        , match_sk
        , tournament_sk
    from stg.v_link_match_tournament as vlmt
    where not exists (
        select lmt.match_tournament_sk
        from dbo.link_match_tournament as lmt
        where lmt.match_tournament_sk = vlmt.match_tournament_sk
    );

    get diagnostics v_record_count = row_count;

    insert into stg.log_table (object_name, records_count, message)
    values ('sp_load_link_match_tournament', v_record_count, 'Link loaded successfully');

    f_record_inserted = v_record_count;

    raise info 'Table link_match_tournament loaded successfully! Records inserted: %', f_record_inserted;

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (object_name, records_count, message)
    values ('sp_load_link_match_tournament', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;


-- 3.b. dbo.sp_load_link_match_players:
create or replace procedure dbo.sp_load_link_match_player(
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
    insert into dbo.link_match_player (match_player_sk, rec_src, load_dt, match_sk, player_sk, player_number)
    select distinct
        match_player_sk
        , rec_src
        , load_dt
        , match_sk
        , player_sk
        , player_number
    from stg.v_link_match_player as vlmp
    where not exists (
        select lmp.match_player_sk
        from dbo.link_match_player as lmp
        where lmp.match_player_sk = vlmp.match_player_sk
    );

    get diagnostics v_record_count = row_count;

    insert into stg.log_table (object_name, records_count, message)
    values ('sp_load_link_match_player', v_record_count, 'Link loaded successfully');

    f_record_inserted = v_record_count;

    raise info 'Table link_match_player loaded successfully! Records inserted: %', f_record_inserted;

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (object_name, records_count, message)
    values ('sp_load_link_match_player', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;


-- ===== SATELLITES ===== --
-- 4.a. dbo.sp_load_sat_match_details
create or replace procedure dbo.sp_load_sat_match_details(
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

    update dbo.sat_match_details as old_sat
    set load_end_dt = f_load_date - interval '1 second'
    where old_sat.load_end_dt is null
      and exists (
          select new_sat.match_sk
          from stg.v_sat_match_details as new_sat
          where 1=1
            and new_sat.match_sk = old_sat.match_sk
            and new_sat.hash_diff != old_sat.hash_diff
      );

    get diagnostics v_updated_count = row_count;

    insert into dbo.sat_match_details (
        match_sk, load_dt, rec_src, load_end_dt, hash_diff,
        date_of_match, match_round, match_duration
    )
    select distinct
        match_sk
        , load_dt
        , rec_src
        , null::timestamp as load_end_dt
        , hash_diff
        , date_of_match
        , match_round
        , match_duration
    from stg.v_sat_match_details as vsmd
    where not exists (
        select smd.match_sk
        from dbo.sat_match_details as smd
        where 1=1
            and smd.match_sk = vsmd.match_sk
            and smd.hash_diff = vsmd.hash_diff
            and smd.load_end_dt is null
    );

    get diagnostics v_record_count = row_count;

    insert into stg.log_table (object_name, records_count, message)
    values ('sp_load_sat_match_details', v_record_count, 'Satellite loaded successfully');

    f_record_inserted = v_record_count;
    f_record_updated = v_updated_count;

    raise info 'Table sat_match_details updated successfully! Records updated: %', f_record_updated;
    raise info 'Table sat_match_details loaded successfully! Records inserted: %', f_record_inserted;

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (object_name, records_count, message)
    values ('sp_load_sat_match_details', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;


-- 4.b. dbo.sp_load_sat_match_players_result
create or replace procedure dbo.sp_load_sat_match_player_result(
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

    update dbo.sat_match_player_result as old_sat
    set load_end_dt = f_load_date - interval '1 second'
    where old_sat.load_end_dt is null
      and exists (
          select new_sat.match_player_sk
          from stg.v_sat_match_player_result as new_sat
          where 1=1
            and new_sat.match_player_sk = old_sat.match_player_sk
            and new_sat.hash_diff != old_sat.hash_diff
      );

    get diagnostics v_updated_count = row_count;

    insert into dbo.sat_match_player_result (
        match_player_sk, load_dt, rec_src, load_end_dt, hash_diff,
        first_set_score, second_set_score, third_set_score, final_score, is_winner
    )
    select distinct
        match_player_sk
        , load_dt
        , rec_src
        , null::timestamp as load_end_dt
        , hash_diff
        , first_set_score
        , second_set_score
        , third_set_score
        , final_score
        , is_winner
    from stg.v_sat_match_player_result as vsmpr
    where not exists (
        select smpr.match_player_sk
        from dbo.sat_match_player_result as smpr
        where 1=1
            and smpr.match_player_sk = vsmpr.match_player_sk
            and smpr.hash_diff = vsmpr.hash_diff
            and smpr.load_end_dt is null
    );

    get diagnostics v_record_count = row_count;

    insert into stg.log_table (object_name, records_count, message)
    values ('sp_load_sat_match_player_result', v_record_count, 'Satellite loaded successfully');

    f_record_inserted = v_record_count;
    f_record_updated = v_updated_count;

    raise info 'Table sat_match_player_result updated successfully! Records updated: %', f_record_updated;
    raise info 'Table sat_match_player_result loaded successfully! Records inserted: %', f_record_inserted;

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (object_name, records_count, message)
    values ('sp_load_sat_match_player_result', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;




-----------------------------------------------------------------------------
-- ===== DMART LEVEL ===== --
create or replace procedure dmart.sp_load_dim_matches(
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
    v_deleted_count INT;
begin
    lock table dmart.dim_matches;

    -- Set row_expired_dt for deleted matches
    update dmart.dim_matches as old_dim
    set row_expired_dt = f_load_date - interval '1 second'
    where 1=1
        and old_dim.row_expired_dt is null
        and not exists (
            select new_dim.match_hash_key
            from biz.v_dim_matches as new_dim
            where new_dim.match_hash_key = old_dim.match_hash_key
        );

    get diagnostics v_deleted_count = row_count;

    update dmart.dim_matches as old_dim
    set row_expired_dt = f_load_date - interval '1 second'
    where 1=1
        and old_dim.row_expired_dt is null
        and exists (
            select new_dim.match_hash_key
            from biz.v_dim_matches as new_dim
            where 1=1
                and new_dim.match_hash_key = old_dim.match_hash_key
                and new_dim.dim_match_sk != old_dim.dim_match_sk
        );

    get diagnostics v_updated_count = row_count;

    insert into dmart.dim_matches (
        dim_match_sk
        , match_hash_key
        , row_load_dt
        , row_expired_dt
        , match_bk
        , date_of_match
        , match_round
        , first_set_score
        , second_set_score
        , third_set_score
        , final_score
        , match_duration
    )
    select distinct
        dim_match_sk
        , match_hash_key
        , load_dt as row_load_dt
        , null::timestamp as row_expired_dt
        , match_bk
        , date_of_match
        , match_round
        , first_set_score
        , second_set_score
        , third_set_score
        , final_score
        , match_duration
    from biz.v_dim_matches as vdm
    where not exists (
        select dm.match_hash_key
        from dmart.dim_matches as dm
        where 1=1
            and dm.match_hash_key = vdm.match_hash_key
            and dm.dim_match_sk = vdm.dim_match_sk
            and dm.row_expired_dt is null
    );

    get diagnostics v_record_count = row_count;

    insert into stg.log_table (object_name, records_count, message)
    values ('sp_load_dim_matches', v_record_count, 'Dimension loaded successfully');

    f_record_inserted = v_record_count;
    f_record_updated = v_updated_count;

    raise info 'Table dim_matches loaded successfully! Records inserted: %. Records updated: %', f_record_inserted, f_record_updated;

exception when others then
    f_error_num = -1;
    f_error_message = substring(sqlerrm, 1, 200);

    insert into stg.log_table (object_name, records_count, message)
    values ('sp_load_dim_matches', 0, 'Error: '|| f_error_message);

    raise info 'An exception occurred %', sqlerrm;
end;
$$;


--rollback DROP PROCEDURE IF EXISTS dbo.sp_load_sat_match_player_result;
--rollback DROP PROCEDURE IF EXISTS dbo.sp_load_sat_match_details;
--rollback DROP PROCEDURE IF EXISTS dbo.sp_load_link_match_player;
--rollback DROP PROCEDURE IF EXISTS dbo.sp_load_link_match_tournament;
--rollback DROP PROCEDURE IF EXISTS dbo.sp_load_hub_matches;
--rollback DROP PROCEDURE IF EXISTS dbo.sp_load_sat_match_status;
--rollback DROP PROCEDURE IF EXISTS stg.sp_load_matches;
--rollback DROP PROCEDURE IF EXISTS stg.sp_load_raw_matches;
--rollback DROP PROCEDURE IF EXISTS stg.sp_truncate_raw_matches;
--rollback DROP PROCEDURE IF EXISTS stg.sp_load_buffer_matches;
--rollback DROP PROCEDURE IF EXISTS stg.sp_truncate_buffer_matches;