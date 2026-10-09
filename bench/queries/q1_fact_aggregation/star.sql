-- Q1. Agregacja na tabeli faktów (bez złączeń)
select
    count(*) as matches
    , sum(f.player1_aces + f.player2_aces) as aces
    , sum(f.player1_double_faults + f.player2_double_faults) as double_faults
    , round(avg((f.player1_break_points_converted_perc + f.player2_break_points_converted_perc) / 2), 4) as avg_bp_converted
from star.fct_match_statistics as f
where f.is_current;
