-- Q4. Skuteczność zwycięstw według kraju zawodniczki i nawierzchni — wariant DV
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
select
    rc.country_name
    , std.surface
    , count(*) as matches
    , count(*) filter (where pm.is_winner) as wins
    , round(count(*) filter (where pm.is_winner)::numeric / count(*), 4) as win_rate
from player_match as pm
left join dbo.sat_player_personal_info as sppi
    on sppi.player_sk = pm.player_sk
    and sppi.load_end_dt is null
left join dbo.ref_country as rc
    on rc.country_code_bk = sppi.country
join dbo.link_match_tournament as lmt
    on lmt.match_sk = pm.match_sk
join dbo.sat_tournament_details as std
    on std.tournament_sk = lmt.tournament_sk
    and std.load_end_dt is null
group by rc.country_name, std.surface
order by rc.country_name, std.surface;
