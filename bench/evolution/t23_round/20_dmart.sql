-- T23 / warstwa prezentacyjna DV: nowy wymiar + klucz obcy w istniejącej tabeli faktów.
create table if not exists dmart.dim_rounds (
    dim_round_sk CHAR(32) not null
    , round_hash_key CHAR(32) not null
    , row_load_dt TIMESTAMP not null
    , row_expired_dt TIMESTAMP
    , round_bk VARCHAR(10) not null
    , round_name VARCHAR(50)
    , primary key (dim_round_sk)
);
create index if not exists ix_dim_rounds_hash_active on dmart.dim_rounds (round_hash_key) where row_expired_dt is null;

alter table dmart.fct_match_statistics add column if not exists dim_round_sk CHAR(32);

create or replace procedure dmart.sp_load_rounds(in f_run_id VARCHAR, in f_load_date TIMESTAMP)
language plpgsql
as $$
declare
    v_dim INT;
    v_fct INT;
begin
    update dmart.dim_rounds as d
    set row_expired_dt = f_load_date - interval '1 second'
    where d.row_expired_dt is null
        and exists (
            select 1 from dbo.sat_round_details as s
            where s.round_sk = d.round_hash_key and s.load_end_dt is null and s.load_dt <> d.row_load_dt
        );

    insert into dmart.dim_rounds (dim_round_sk, round_hash_key, row_load_dt, row_expired_dt, round_bk, round_name)
    select
        md5(upper(trim(h.round_bk)) || ';' || upper(trim(coalesce(s.load_dt, h.load_dt)::text)))
        , h.round_sk
        , coalesce(s.load_dt, h.load_dt)
        , null
        , h.round_bk
        , s.round_name
    from dbo.hub_rounds as h
    left join dbo.sat_round_details as s
        on s.round_sk = h.round_sk and s.load_end_dt is null
    where not exists (
        select 1 from dmart.dim_rounds as d
        where d.round_hash_key = h.round_sk and d.row_expired_dt is null
    );
    get diagnostics v_dim = row_count;

    analyze dmart.dim_rounds;

    update dmart.fct_match_statistics as f
    set dim_round_sk = coalesce(d.dim_round_sk, '-98')
    from dmart.dim_matches as dm
    left join dbo.link_match_round as l
        on l.match_sk = dm.match_hash_key
    left join dmart.dim_rounds as d
        on d.round_hash_key = l.round_sk and d.row_expired_dt is null
    where f.dim_round_sk is null
        and dm.dim_match_sk = f.dim_match_sk;
    get diagnostics v_fct = row_count;

    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_rounds_dmart', v_dim + v_fct, format('dim: %s, fct updated: %s', v_dim, v_fct));

exception when others then
    insert into stg.log_table (run_id, object_name, records_count, message)
    values (f_run_id, 'sp_load_rounds_dmart', 0, 'Error: ' || substring(sqlerrm, 1, 200));
end;
$$;

create or replace procedure dbo.sp_load_all_dv_full(
    in f_run_id VARCHAR
    , in f_load_date TIMESTAMP
)
language plpgsql
as $$
begin
    call dbo.sp_load_all_dv(f_run_id, f_load_date);
    call stg.sp_load_rounds(f_run_id, f_load_date);
    call dbo.sp_load_rounds(f_run_id, f_load_date);
    call dmart.sp_load_dmart(f_run_id, f_load_date);
    call dmart.sp_load_rounds(f_run_id, f_load_date);
end;
$$;
