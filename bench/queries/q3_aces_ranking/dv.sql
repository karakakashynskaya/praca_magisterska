-- Q3. Ranking zawodniczek według liczby asów w sezonie (top 10) — wariant DV
with player_match as (
    select
        lmp.match_sk
        , lmp.player_sk
        , coalesce(smpr.is_winner, false) as is_winner
        , coalesce(smsd.aces, 0) as aces
        , coalesce(smsd.double_faults, 0) as double_faults
        , coalesce(smsd.break_points_converted_perc, 0) as break_points_converted_perc
    from dbo.link_match_player as lmp
    left join dbo.sat_match_player_result as smpr
        on smpr.match_player_sk = lmp.match_player_sk
        and smpr.load_end_dt is null
    left join dbo.link_match_statistics as lms
        on lms.match_sk = lmp.match_sk
        and lms.player_sk = lmp.player_sk
    left join dbo.sat_match_statistics_details as smsd
        on smsd.match_statistics_sk = lms.match_statistics_sk
        and smsd.load_end_dt is null
    where not exists (
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
, ranking as (
    select
        extract(year from smd.date_of_match)::int as season
        , hp.player_bk
        , sppi.first_name || ' ' || sppi.second_name as player_name
        , count(*) as matches
        , sum(pm.aces) as aces
        , rank() over (partition by extract(year from smd.date_of_match)::int order by sum(pm.aces) desc) as rnk
    from player_match as pm
    join dbo.sat_match_details as smd
        on smd.match_sk = pm.match_sk
        and smd.load_end_dt is null
    join dbo.hub_players as hp
        on hp.player_sk = pm.player_sk
    left join dbo.sat_player_personal_info as sppi
        on sppi.player_sk = pm.player_sk
        and sppi.load_end_dt is null
    group by extract(year from smd.date_of_match)::int, hp.player_bk, sppi.first_name, sppi.second_name
)
select season, rnk, player_bk, player_name, matches, aces
from ranking
where rnk <= 10
order by season, rnk, player_bk;
