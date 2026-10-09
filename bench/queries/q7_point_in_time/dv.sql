-- Q7. Stan na chwilę T (parametr: as_of) — wariant DV.
with player_match as (
    select
        lmp.player_sk
        , coalesce(smpr.is_winner, false) as is_winner
    from dbo.link_match_player as lmp
    join dbo.hub_matches as hm
        on hm.match_sk = lmp.match_sk
        and hm.load_dt <= %(as_of)s::timestamp
    left join dbo.sat_match_player_result as smpr
        on smpr.match_player_sk = lmp.match_player_sk
        and %(as_of)s::timestamp between smpr.load_dt and coalesce(smpr.load_end_dt, 'infinity')
    where lmp.load_dt <= %(as_of)s::timestamp
        and not exists (
            select 1
            from dbo.sat_match_status as sms
            where sms.match_sk = lmp.match_sk
                and sms.status = 'D'
                and %(as_of)s::timestamp between sms.load_dt and coalesce(sms.load_end_dt, 'infinity')
        )
        and not exists (
            select 1
            from dbo.link_match_statistics as l
            join dbo.sat_match_statistics_status as s
                on s.match_statistics_sk = l.match_statistics_sk
                and s.status = 'D'
                and %(as_of)s::timestamp between s.load_dt and coalesce(s.load_end_dt, 'infinity')
            where l.match_sk = lmp.match_sk
        )
)
select
    rc.country_name
    , count(*) as matches
    , count(*) filter (where pm.is_winner) as wins
    , round(count(*) filter (where pm.is_winner)::numeric / count(*), 4) as win_rate
from player_match as pm
left join dbo.sat_player_personal_info as sppi
    on sppi.player_sk = pm.player_sk
    and %(as_of)s::timestamp between sppi.load_dt and coalesce(sppi.load_end_dt, 'infinity')
left join dbo.ref_country as rc
    on rc.country_code_bk = sppi.country
group by rc.country_name
order by rc.country_name;
