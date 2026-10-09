-- T23 / Data Vault: nowy hub, satelita i link. Żaden istniejący obiekt dbo nie jest zmieniany.
create table if not exists dbo.hub_rounds (
    round_sk CHAR(32) not null
    , rec_src VARCHAR(50) not null
    , load_dt TIMESTAMP not null
    , round_bk VARCHAR(10) not null
    , primary key (round_sk)
);

create table if not exists dbo.sat_round_details (
    round_sk CHAR(32) not null
    , load_dt TIMESTAMP not null
    , rec_src VARCHAR(50) not null
    , load_end_dt TIMESTAMP
    , hash_diff CHAR(32) not null
    , round_name VARCHAR(50)
    , primary key (round_sk, load_dt)
);

create table if not exists dbo.link_match_round (
    match_round_sk CHAR(32) not null
    , rec_src VARCHAR(50) not null
    , load_dt TIMESTAMP not null
    , match_sk CHAR(32) not null
    , round_sk CHAR(32) not null
    , primary key (match_round_sk)
);
create index if not exists ix_link_match_round_match on dbo.link_match_round (match_sk);

create or replace procedure dbo.sp_load_rounds(in f_run_id VARCHAR, in f_load_date TIMESTAMP)
language plpgsql
as $$
declare
    v_hub INT;
    v_sat INT;
    v_link INT;
begin
    insert into dbo.hub_rounds (round_sk, rec_src, load_dt, round_bk)
    select rr.round_sk, rr.rec_src, f_load_date, rr.round_bk
    from stg.raw_rounds as rr
    where not exists (select 1 from dbo.hub_rounds as h where h.round_sk = rr.round_sk);
    get diagnostics v_hub = row_count;

    update dbo.sat_round_details as s
    set load_end_dt = f_load_date - interval '1 second'
    where s.load_end_dt is null
        and exists (
            select 1 from stg.raw_rounds as rr
            where rr.round_sk = s.round_sk and rr.hash_diff <> s.hash_diff
        );

    insert into dbo.sat_round_details (round_sk, load_dt, rec_src, load_end_dt, hash_diff, round_name)
    select rr.round_sk, f_load_date, rr.rec_src, null, rr.hash_diff, rr.round_name
    from stg.raw_rounds as rr
    where not exists (
        select 1 from dbo.sat_round_details as s
        where s.round_sk = rr.round_sk and s.load_end_dt is null
    );
    get diagnostics v_sat = row_count;

    analyze dbo.hub_rounds;

    insert into dbo.link_match_round (match_round_sk, rec_src, load_dt, match_sk, round_sk)
    select distinct
        md5(upper(trim(coalesce(rm.match_sk, ''))) || ';' || upper(trim(coalesce(h.round_sk, ''))))
        , 'wta_dwh_benchmark'
        , f_load_date
        , rm.match_sk
        , h.round_sk
    from stg.raw_matches as rm
    join dbo.hub_rounds as h
        on h.round_bk = trim(rm.match_round)
    where not exists (
        select 1 from dbo.link_match_round as l
        where l.match_round_sk = md5(upper(trim(coalesce(rm.match_sk, ''))) || ';' || upper(trim(coalesce(h.round_sk, ''))))
    );
    get diagnostics v_link = row_count;

    analyze dbo.sat_round_details;
    analyze dbo.link_match_round;

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_rounds_dv', v_hub + v_sat + v_link,
            format('hub: %s, sat: %s, link: %s', v_hub, v_sat, v_link));

exception when others then
    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_rounds_dv', 0, 'Error: ' || substring(sqlerrm, 1, 200));
end;
$$;
