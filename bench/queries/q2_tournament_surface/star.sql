-- Q2. Agregacja ze złączeniem wymiaru turnieju (kategoria, nawierzchnia)
select
    t.tournament_level
    , t.surface
    , count(*) as matches
    , round(avg(f.player1_aces + f.player2_aces), 3) as avg_aces_per_match
    , round(avg(f.player1_double_faults + f.player2_double_faults), 3) as avg_double_faults_per_match
from star.fct_match_statistics as f
join star.dim_tournament as t
    on t.dim_tournament_sk = f.dim_tournament_sk
where f.is_current
group by t.tournament_level, t.surface
order by t.tournament_level, t.surface;
