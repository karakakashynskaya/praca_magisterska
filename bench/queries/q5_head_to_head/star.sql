-- Q5. Bilans bezpośrednich pojedynków dwóch zawodniczek (parametry: player_a, player_b)
select
    count(*) as matches
    , count(*) filter (where w.player_bk = %(player_a)s) as wins_a
    , count(*) filter (where w.player_bk = %(player_b)s) as wins_b
    , min(m.date_of_match) as first_meeting
    , max(m.date_of_match) as last_meeting
from star.fct_match_statistics as f
join star.dim_player as p1
    on p1.dim_player_sk = f.dim_player1_sk
join star.dim_player as p2
    on p2.dim_player_sk = f.dim_player2_sk
join star.dim_player as w
    on w.dim_player_sk = f.dim_winner_sk
join star.dim_match as m
    on m.dim_match_sk = f.dim_match_sk
where f.is_current
    and (p1.player_bk, p2.player_bk) in ((%(player_a)s, %(player_b)s), (%(player_b)s, %(player_a)s));
