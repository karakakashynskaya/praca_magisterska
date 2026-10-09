-- Q4. Skuteczność zwycięstw w zależności od kraju zawodniczki i nawierzchni
select
    d.country_name
    , t.surface
    , count(*) as matches
    , count(*) filter (where p.dim_player_sk = f.dim_winner_sk) as wins
    , round(count(*) filter (where p.dim_player_sk = f.dim_winner_sk)::numeric / count(*), 4) as win_rate
from dmart.fct_match_statistics as f
cross join lateral (
    values (f.dim_player1_sk), (f.dim_player2_sk)
) as p (dim_player_sk)
join dmart.dim_players as d
    on d.dim_player_sk = p.dim_player_sk
join dmart.dim_tournaments as t
    on t.dim_tournament_sk = f.dim_tournament_sk
where f.row_expired_dt is null
group by d.country_name, t.surface
order by d.country_name, t.surface;
