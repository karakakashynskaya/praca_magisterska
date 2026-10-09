-- T21. Złożoność implementacji: liczba obiektów i wierszy kodu proceduralnego per warstwa.
with layer(nspname, architecture, layer) as (
    values ('stg', 'wspólne', 'stg'), ('dbo', 'DV', 'dbo (Data Vault)'), ('biz', 'DV', 'biz (widoki)'),
           ('dmart', 'DV', 'dmart (prezentacyjna)'), ('star', 'Star', 'star')
)
, rel as (
    select n.nspname
        , count(*) filter (where c.relkind = 'r') as tables
        , count(*) filter (where c.relkind = 'i') as indexes
        , count(*) filter (where c.relkind = 'v') as views
        , coalesce(sum(array_length(regexp_split_to_array(pg_get_viewdef(c.oid), E'\n'), 1))
                   filter (where c.relkind = 'v'), 0) as view_loc
    from pg_class as c
    join pg_namespace as n on n.oid = c.relnamespace
    group by n.nspname
)
, proc as (
    select n.nspname
        , count(*) as procedures
        , sum(array_length(regexp_split_to_array(pg_get_functiondef(p.oid), E'\n'), 1)) as procedure_loc
    from pg_proc as p
    join pg_namespace as n on n.oid = p.pronamespace
    where p.prokind in ('p', 'f')
    group by n.nspname
)
select l.architecture, l.layer
    , coalesce(r.tables, 0) as tables, coalesce(r.indexes, 0) as indexes, coalesce(r.views, 0) as views
    , coalesce(p.procedures, 0) as procedures
    , coalesce(p.procedure_loc, 0) + coalesce(r.view_loc, 0) as code_loc
from layer as l
left join rel as r using (nspname)
left join proc as p using (nspname)
order by l.architecture, l.layer;
