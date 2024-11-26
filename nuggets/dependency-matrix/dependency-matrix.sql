create or alter proc dbo.DependencyMatrix
    @origins varchar(max),          -- one or more objects with basically the same columns (i.e., DWSTG.ServiceNowApplication and DWSTG.ServiceNowApplication_bak)
    @excludes varchar(max) = null   -- dependencies to skip column check becuase they fail schema validation
as 
    /*  Keith Townsend, 7/21/2021
        MIT License

        Find objects with dependencies.
        Be aware that some objects won't report column dependencies. Broken objects of course, but some that aren't 
        broken still don't report column dependencies. I read someplace that use in temp tables aren't tracked.
    */

    drop table if exists #data
    ;with origins as (
        select  [identifier] = o.value,
                [schema] = parsename(o.value, 2),
                [object] = parsename(o.value, 1)
        from    (select trim(value) from string_split(@origins, ',')) o(value)
    ), excludes as (
        select  [schema] = parsename(o.value, 2),
                [object] = parsename(o.value, 1)
        from    (select trim(value) from string_split(@excludes, ',')) o(value)    
    ), all_deps as (
        -- this is all the discovered dependency objects; can be duplicated if same object references multiple origins
        select  o.*,
                [skip_lookup] = case when e.object is null then 0 else 1 end,
                type = so.type_desc,
                referencing = referencing_schema_name + '.' + referencing_entity_name
        from    origins o
                cross apply sys.dm_sql_referencing_entities(o.identifier, 'Object') x
                left join sys.objects so
                    on so.object_id = x.referencing_id
                left join excludes e
                    on e.[schema] = x.referencing_schema_name
                    and e.[object] = x.referencing_entity_name
    ), unique_deps as (
        -- consolidated dependencies when there are multiple origins
        select  referenced = case when count(distinct identifier) > 1 then '(multiple)' else string_agg(identifier, ', ') end, 
                referencing,
                type
        from    all_deps
        group by referencing, type
    ), cols as (
        -- column dependency info
        select  t.referencing,
                q.*
        from    all_deps t
                cross apply (
                    select  [column] = x.referenced_minor_name,
                            marker = case when 1 = x.is_selected then 'S' else '' end
                                + case when 1 = x.is_updated then 'U' else '' end
                                + case when 1 = x.is_ambiguous then 'A' else '' end
                                + case when 1 = x.is_select_all then '*' else '' end
                                + case when 1 = x.is_insert_all then 'I' else '' end
                                + case when 1 = x.is_incomplete then '-' else '' end
                    from    sys.dm_sql_referenced_entities(t.referencing, 'object') x 
                    where   x.referenced_schema_name = t.[schema]
                            and x.referenced_entity_name = t.object
                            and x.referenced_minor_name is not null
                ) q
        where   t.skip_lookup = 0
    ), counts as (
        -- number of origin columns referenced by each dependency
        select  referencing,
                count(distinct [column]) as columns
        from    cols
        group by referencing
    ), col_freq as (
        -- number of times each column is referenced by all dependencies
        select [column], count(*) as freq from cols group by [column]
    ), result as (
        -- final mash of discovered dependencies
        select  marker = coalesce(x.marker, c.marker),
                isnull(cast(n.columns as varchar(50)), 'unable to discover columns') as columns,
                t.referenced, 
                t.referencing, 
                t.type, 
                [column] = coalesce(x.[column], c.[column])
        from    unique_deps t 
                left join counts n
                    on n.referencing = t.referencing
                left join cols c 
                    on c.referencing = t.referencing
                --> this is solely to show ? for marker when unable to discover columns
                left join (select distinct [column], marker = '?' from cols) x
                    on n.columns is null
        union   
        select  cast(freq as varchar(5)),
                '',
                '',
                '',
                'Frequency',
                [column]
        from    col_freq
    )
        select * into #data from result

    -- auto-generate the pivot column names and the select column names based on what we found
    -- NOTE: in order to get varchar(max) out of string_agg, the input must be varchar(max)
    -- NOTE: if concatenating large strings you must cast all parts being concatenated as varchar(max) or the concatenation won't be varchar(max)
    declare @pcols varchar(max), @scols varchar(max)
    select  @pcols = string_agg(cast(quoted as varchar(max)), ',') within group (order by freq desc, quoted),
            @scols = string_agg(cast(blanked as varchar(max)), ',') within group (order by freq desc, quoted)
    from    (select quotename([column]), count(*) from #data where [column] is not null group by [column]) c(quoted, freq)
            outer apply (select concat(char(10), quoted, '=isnull(', quoted, ','''')')) b(blanked)

    -- dynamic pivot
    declare @sql nvarchar(max) = '
        select  referenced, referencing, type, columns, ' + isnull(@scols, '[no columns found]') + '
        from    #data
        pivot   (max(marker) for [column] in (' + isnull(@pcols, '[no columns found]') + ')) p
        order by 2'
    exec(@sql)
GO
