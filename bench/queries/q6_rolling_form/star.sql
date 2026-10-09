-- Q6. Forma krocząca zawodniczki: udział zwycięstw i średnia asów w 10 ostatnich meczach (parametr: player_a)
with player_match as (
    select
        m.date_of_match
        , m.match_bk
        , (p.dim_player_sk = f.dim_winner_sk)::int as won
        , p.aces
    from star.fct_match_statistics as f
    cross join lateral (
        values (f.dim_player1_sk, f.player1_aces), (f.dim_player2_sk, f.player2_aces)
    ) as p (dim_player_sk, aces)
    join star.dim_player as d
        on d.dim_player_sk = p.dim_player_sk
    join star.dim_match as m
        on m.dim_match_sk = f.dim_match_sk
    where f.is_current
        and d.player_bk = %(player_a)s
)
select
    date_of_match
    , match_bk
    , won
    , round(avg(won) over w, 3) as win_rate_last_10
    , round(avg(aces) over w, 2) as avg_aces_last_10
from player_match
window w as (order by date_of_match, match_bk rows between 9 preceding and current row)
order by date_of_match, match_bk;
