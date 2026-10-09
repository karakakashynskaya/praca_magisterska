-- Q3. Ranking zawodniczek według liczby asów w sezonie (top 10 w każdym sezonie)
with player_match as (
    select
        extract(year from m.date_of_match)::int as season
        , p.dim_player_sk
        , p.aces
    from star.fct_match_statistics as f
    join star.dim_match as m
        on m.dim_match_sk = f.dim_match_sk
    cross join lateral (
        values (f.dim_player1_sk, f.player1_aces), (f.dim_player2_sk, f.player2_aces)
    ) as p (dim_player_sk, aces)
    where f.is_current
)
, ranking as (
    select
        pm.season
        , d.player_bk
        , d.first_name || ' ' || d.second_name as player_name
        , count(*) as matches
        , sum(pm.aces) as aces
        , rank() over (partition by pm.season order by sum(pm.aces) desc) as rnk
    from player_match as pm
    join star.dim_player as d
        on d.dim_player_sk = pm.dim_player_sk
    group by pm.season, d.player_bk, d.first_name, d.second_name
)
select season, rnk, player_bk, player_name, matches, aces
from ranking
where rnk <= 10
order by season, rnk, player_bk;
