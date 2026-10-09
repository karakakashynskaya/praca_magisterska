-- Q6. Forma krocząca zawodniczki — wariant DV
with player_match as (
    select
        smd.date_of_match
        , hm.match_bk
        , coalesce(smpr.is_winner, false)::int as won
        , coalesce(smsd.aces, 0) as aces
    from dbo.hub_players as hp
    join dbo.link_match_player as lmp
        on lmp.player_sk = hp.player_sk
    join dbo.hub_matches as hm
        on hm.match_sk = lmp.match_sk
    join dbo.sat_match_details as smd
        on smd.match_sk = lmp.match_sk
        and smd.load_end_dt is null
    left join dbo.sat_match_player_result as smpr
        on smpr.match_player_sk = lmp.match_player_sk
        and smpr.load_end_dt is null
    left join dbo.link_match_statistics as lms
        on lms.match_sk = lmp.match_sk
        and lms.player_sk = lmp.player_sk
    left join dbo.sat_match_statistics_details as smsd
        on smsd.match_statistics_sk = lms.match_statistics_sk
        and smsd.load_end_dt is null
    where hp.player_bk = %(player_a)s
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
select
    date_of_match
    , match_bk
    , won
    , round(avg(won) over w, 3) as win_rate_last_10
    , round(avg(aces) over w, 2) as avg_aces_last_10
from player_match
window w as (order by date_of_match, match_bk rows between 9 preceding and current row)
order by date_of_match, match_bk;
