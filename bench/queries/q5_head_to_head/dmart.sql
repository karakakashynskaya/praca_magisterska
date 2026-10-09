-- Q5. Bilans bezpośrednich pojedynków dwóch zawodniczek (parametry: player_a, player_b)
select
    count(*) as matches
    , count(*) filter (where w.player_bk = %(player_a)s) as wins_a
    , count(*) filter (where w.player_bk = %(player_b)s) as wins_b
    , min(m.date_of_match) as first_meeting
    , max(m.date_of_match) as last_meeting
from dmart.fct_match_statistics as f
join dmart.dim_players as p1
    on p1.dim_player_sk = f.dim_player1_sk
join dmart.dim_players as p2
    on p2.dim_player_sk = f.dim_player2_sk
join dmart.dim_players as w
    on w.dim_player_sk = f.dim_winner_sk
join dmart.dim_matches as m
    on m.dim_match_sk = f.dim_match_sk
where f.row_expired_dt is null
    and (p1.player_bk, p2.player_bk) in ((%(player_a)s, %(player_b)s), (%(player_b)s, %(player_a)s));
