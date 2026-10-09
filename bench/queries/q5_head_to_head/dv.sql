-- Q5. Bilans bezpośrednich pojedynków dwóch zawodniczek — wariant DV
with ab as (
    select
        lmp.match_sk
        , hp.player_bk
        , coalesce(smpr.is_winner, false) as is_winner
    from dbo.hub_players as hp
    join dbo.link_match_player as lmp
        on lmp.player_sk = hp.player_sk
    left join dbo.sat_match_player_result as smpr
        on smpr.match_player_sk = lmp.match_player_sk
        and smpr.load_end_dt is null
    where hp.player_bk in (%(player_a)s, %(player_b)s)
        and not exists (
            select 1
            from dbo.sat_match_status as sms
            where sms.match_sk = lmp.match_sk
                and sms.load_end_dt is null
                and sms.status = 'D'
        )
        and not exists (
            select 1
            from dbo.link_match_statistics as l
            join dbo.sat_match_statistics_status as s
                on s.match_statistics_sk = l.match_statistics_sk
                and s.load_end_dt is null
                and s.status = 'D'
            where l.match_sk = lmp.match_sk
        )
)
, h2h as (
    select
        match_sk
        , bool_or(player_bk = %(player_a)s and is_winner) as won_a
        , bool_or(player_bk = %(player_b)s and is_winner) as won_b
    from ab
    group by match_sk
    having count(*) = 2
)
select
    count(*) as matches
    , count(*) filter (where h.won_a) as wins_a
    , count(*) filter (where h.won_b) as wins_b
    , min(smd.date_of_match) as first_meeting
    , max(smd.date_of_match) as last_meeting
from h2h as h
join dbo.sat_match_details as smd
    on smd.match_sk = h.match_sk
    and smd.load_end_dt is null;
