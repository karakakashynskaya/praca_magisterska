--liquibase formatted sql
--changeset kkakashynskaya:25-bench-schema context:common splitStatements:false

-- Jeden wiersz = jeden pełny przebieg ETL (CALL dbo.sp_load_all_dv_full / star.sp_load_star_full)
-- dla konkretnej architektury, wolumenu i scenariusza (pełne / przyrostowe ładowanie).
create table if not exists bench.benchmark_runs (
    id SERIAL PRIMARY KEY
    , run_id VARCHAR(100) not null
    , architecture VARCHAR(10) not null   -- 'DV' / 'STAR'
    , scenario VARCHAR(20) not null       -- 'full' / 'incremental'
    , volume INT not null                 -- liczba meczów w tym przebiegu (1000/5000/10000)
    , duration_sec NUMERIC(10,3)
    , cpu_avg_pct NUMERIC(5,2)
    , cpu_peak_pct NUMERIC(5,2)
    , mem_avg_mb NUMERIC(10,2)
    , mem_peak_mb NUMERIC(10,2)
    , cache_hit_ratio NUMERIC(5,4)
    , temp_blks_written BIGINT
    , db_size_mb NUMERIC(10,2)
    , error_message TEXT
    , run_ts TIMESTAMP not null default current_timestamp
);
create index if not exists ix_benchmark_runs_arch_scenario_volume
    on bench.benchmark_runs (architecture, scenario, volume);



-- Jeden wiersz = wykonanie JEDNEGO zapytania z zestawu queries/ (rozdz. 7.3),
-- dla konkretnej architektury i wolumenu. Kilka wierszy na (query_name, architecture,
-- volume) — po jednym na powtórzenie (uśrednianie, pierwszy cold-cache odrzucany w analizie).
create table if not exists bench.query_runs (
    id SERIAL PRIMARY KEY
    , run_id VARCHAR(100) not null
    , query_name VARCHAR(100) not null    -- np. 'q1_simple_agg', 'q2_join', 'q3_point_in_time'
    , architecture VARCHAR(10) not null   -- 'DV' / 'STAR'
    , volume INT not null
    , repetition INT not null default 1
    , exec_time_ms NUMERIC(10,3)
    , shared_blks_hit BIGINT
    , shared_blks_read BIGINT
    , temp_blks_written BIGINT
    , run_ts TIMESTAMP not null default current_timestamp
);
create index if not exists ix_query_runs_query_arch_volume
    on bench.query_runs (query_name, architecture, volume);


--rollback DROP TABLE IF EXISTS bench.query_runs;
--rollback DROP TABLE IF EXISTS bench.benchmark_runs;
