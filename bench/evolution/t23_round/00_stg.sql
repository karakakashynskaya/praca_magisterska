-- T23 / krok wspólny: obszar tymczasowy dla nowego obiektu "runda" (round.json -> rounds.csv)
create table if not exists stg.buffer_rounds (
    round_id VARCHAR(10)
    , round_name VARCHAR(50)
);

create table if not exists stg.raw_rounds (
    round_sk CHAR(32) not null
    , round_bk VARCHAR(10) not null
    , round_name VARCHAR(50)
    , hash_diff CHAR(32) not null
    , rec_src VARCHAR(50) not null
    , load_dt TIMESTAMP not null
);

create or replace procedure stg.sp_load_rounds(in f_run_id VARCHAR, in f_load_date TIMESTAMP)
language plpgsql
as $$
declare
    v_record_count INT;
begin
    truncate table stg.buffer_rounds;
    copy stg.buffer_rounds
    from '/var/lib/postgresql/import/data_src/rounds.csv'
    with (format csv, header true, delimiter ',');

    truncate table stg.raw_rounds;
    insert into stg.raw_rounds (round_sk, round_bk, round_name, hash_diff, rec_src, load_dt)
    select distinct on (upper(trim(round_id)))
        md5(upper(trim(coalesce(round_id, ''))))
        , trim(round_id)
        , nullif(trim(round_name), '')
        , md5(upper(trim(coalesce(round_name, ''))))
        , 'wta_dwh_benchmark'
        , f_load_date
    from stg.buffer_rounds
    where nullif(trim(round_id), '') is not null
    order by upper(trim(round_id));
    get diagnostics v_record_count = row_count;

    analyze stg.raw_rounds;

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_rounds', v_record_count, 'Raw table loaded successfully');

exception when others then
    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_rounds', 0, 'Error: ' || substring(sqlerrm, 1, 200));
end;
$$;
