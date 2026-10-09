-- Q7. Stan na chwilę T (parametr: as_of): skuteczność zwycięstw według kraju zawodniczki,
select
    pt.country_name
    , count(*) as matches
    , count(*) filter (where w.player_bk = pv.player_bk) as wins
    , round(count(*) filter (where w.player_bk = pv.player_bk)::numeric / count(*), 4) as win_rate
from dmart.fct_match_statistics as f
cross join lateral (
    values (f.dim_player1_sk), (f.dim_player2_sk)
) as p (dim_player_sk)
join dmart.dim_players as pv
    on pv.dim_player_sk = p.dim_player_sk
join dmart.dim_players as pt
    on pt.player_bk = pv.player_bk
    and %(as_of)s::timestamp between pt.row_load_dt and coalesce(pt.row_expired_dt, 'infinity')
join dmart.dim_players as w
    on w.dim_player_sk = f.dim_winner_sk
where %(as_of)s::timestamp between f.row_load_dt and coalesce(f.row_expired_dt, 'infinity')
group by pt.country_name
order by pt.country_name;
