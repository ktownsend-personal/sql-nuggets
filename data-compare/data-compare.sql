create or alter proc [dbo].[data_compare] (
    @table1 varchar(max),        --> first table to compare; use schema and brackets if needed, or json array of data row objects
    @table2 varchar(max),        --> second table to compare; use schema and brackets if needed, or json array of data row objects
    @keycol varchar(max),        --> join columns: comma separated if same in both tables or json object defining how keys are matched like {"table1key1":"table2key1","table1key2":"table2key2"}
    @laxval bit = 0,             --> set 1 to treat blanks and nulls as equal; default 0
    @notcol varchar(max) = null, --> optional columns to ignore (comma-separated, no brackets)
    @notkey varchar(max) = null  --> optional key values to ignore (comma-separated)
) as

    /*
        Created by Keith Townsend, 5/16/2024
        Inspired by work done by Thato Mantai found at https://thitos.blogspot.com/2014/03/compare-data-from-two-tables.html
        Published my previous version as answer on StackOverflow: https://stackoverflow.com/a/78490999/18155330
        This version is different enough from the previous version to consider it a new solution. 

        - Compares all data between two tables by name or JSON object arrays for all columns that exist in both sets. 
        - Does not support nested JSON data. 
        - Supports compound join key, even if key column names are different between sets. 
        - The table inputs accept the identifier for a table, optionally with schema and/or brackets, or a JSON string of the entire data set to compare if 
            you want to extract your own data with "FOR JSON, INCLUDE_NULL_VALUES".
        - The casing of the key column can be different in each table as long as it's spelled the same. We do a lookup to get the right casing for each table.
        - Using Azure Data Studio to analyze results is convenient because it has abiility to filter rows by column value (similar to Excel column filters).

        Result sets:
            1. table stats: columns compared/ignored, counts of records, keys (all/null/good), lists of unmatched keys
            2. column stats: summary of compared columns with counts of differences, matches, blanks and nulls
            3. distinct differences with counts
            4. all values that do not match

        NOTES:
            - if using a query to generate the JSON you pass in, recommend using INCLUDE_NULL_VALUES in your FOR JSON statement to ensure they are compared correctly
            - While it would be more efficient to give dynamic SQL exact columns that exist in both tables, that isn't feasible if either of the table inputs is JSON so we are getting all columns.

        FUTURE: 
            - optional fieldname matching pairs? same json syntax as @keycol, specifying only cases that aren't same name (used as a matching lookup)
            - improve dynamic key sort on final query to account for compound keys; currently works only for single key column when not defined as json in @keycol
    */

    --> holds full json result for each table to compare
    declare @result table([table] varchar(max), json varchar(max))

    --> capture table1 json (treat table as empty json array if blank value provided)
    if 1 = isjson(isnull(nullif(trim(@table1), ''), '[]')) begin
        insert @result([table], json) values('table1 (json)', @table1)
        set @table1 = 'table1 (json)'
    end else 
        insert @result([table], json) execute('select [table] = ''' + @table1 + ''', JSON = (select * from ' + @table1 + ' with(nolock) for json path, INCLUDE_NULL_VALUES)')

    --> capture table2 json (treat table as empty json array if blank value provided)
    if 1 = isjson(isnull(nullif(trim(@table2), ''), '[]')) begin
        insert @result([table], json) values('table2 (json)', @table2)
        set @table2 = 'table2 (json)'
    end else 
        insert @result([table], json) execute('select [table] = ''' + @table2 + ''', JSON = (select * from ' + @table2 + ' with(nolock) for json path, INCLUDE_NULL_VALUES)')

    --> normalize a matching list for key columns
    declare @keycols table (t1 varchar(max), t2 varchar(max), ordinal int)
    if 1 = isjson(@keycol)
        insert @keycols(t1, t2, ordinal) select [key], value, row_number() over (order by (select 1)) from openjson(@keycol)
    else
        insert @keycols(t1, t2, ordinal) select trim(value), trim(value), row_number() over (order by (select 1)) from string_split(@keycol, ',')

    --> fix casing for key coumn names because paths in json functions are case sensitive
    --> we can get the true casing from the JSON we already captured
    --> using parsename to remove unnecessary brackets that would prevent matching bare names
    update  kc
    set     t1 = coalesce(jk1.[key], x.t1),
            t2 = coalesce(jk2.[key], x.t2)
    from    @keycols kc
            outer apply (select parsename(kc.t1, 1), parsename(kc.t2, 1)) x(t1,t2)
            outer apply (select json from @result where [table] = @table1) j1
            outer apply (select json from @result where [table] = @table2) j2
            outer apply (select [key] from openjson(j1.json, '$[0]') where lower([key]) = lower(x.t1)) jk1
            outer apply (select [key] from openjson(j2.json, '$[0]') where lower([key]) = lower(x.t2)) jk2

    --> unpivot all the values for analysis
    declare @everything table([table] varchar(500), [key] varchar(500), [column] varchar(500), [value] varchar(max), [type] int, index ixe clustered ([table], [key], [column]))
    insert  @everything
    select  r.[table],
            k.[key],
            [column] = x.[key],
            x.[value],
            x.[type]
    from    @result r
            outer apply openjson(r.json) j
            --> extract compound key value to ensure we have a matching key for every row
            outer apply (
                select  string_agg(v.value, '|') within group (order by ordinal) 
                from    @keycols kc 
                        --> NOTE: case-sensitive path in json_value()
                        outer apply (select isnull(json_value(j.value, '$.' + case r.[table] when @table1 then t1 else t2 end), '[NULL]')) v(value)
            ) k([key])
            --> unpivot all the values
            outer apply openjson(j.value) x
    where   k.[key] not in (select trim(value) from string_split(@notkey, ','))

    declare @keys_unmatched table ([table] varchar(max), [key] varchar(max))
    ;with keys as (
        select distinct [table], [key] from @everything
    ), keys_unmatched as (
        select  x.[table],
                x.[key]
        from    (select * from keys where [table] = @table1) a 
                full outer join (select * from keys where [table] = @table2) b 
                    on a.[key] = b.[key] 
                outer apply (select
                    coalesce(a.[table], b.[table]),
                    cast(coalesce(a.[key], b.[key]) as varchar(max))
                ) x([table], [key])
        where   a.[key] is null 
                or b.[key] is null
    )
        insert  @keys_unmatched
        select  [table], [key]
        from    keys_unmatched

    declare @column_info table ([table] varchar(max), [column] varchar(max), ignored bit)
    ;with ignore_list as (
        select name = trim(value) from string_split(@notcol, ',')
    ), columns as (
        select distinct [table], [column] from @everything
    ), column_info as (
        select  t.[table],
                x.[column],
                x.ignored
        from    (select * from columns where [table] = @table1) e1
                full outer join (select * from columns where [table] = @table2) e2 
                    on e2.[column] = e1.[column]
                outer apply (select
                    --> special handling of situation where @notcol needs to show on both tables but there is only one row, so we outer apply string_split on this column
                    case when e1.[table] is null then e2.[table] when e2.[table] is null then e1.[table] else concat(@table1, ', ', @table2) end,
                    cast(coalesce(e1.[column], e2.[column]) as varchar(max)),
                    case when e1.[column] is null or e2.[column] is null or coalesce(e1.[column], e2.[column]) in (select * from ignore_list) then 1 else 0 end
                ) x([table], [column], ignored)
                outer apply (select trim(value) from string_split(x.[table], ',')) t([table]) --> see special handling note in previous outer-apply
    )
        insert  @column_info
        select  [table], [column], ignored
        from    column_info

    --> show table compare stats
    ;with tables as (
        select * from (values (@table1), (@table2)) x([table])
    ), columns_compared as (
        select  [table],
                [columns compared] = string_agg([column], ', ') within group (order by [column])
        from    @column_info 
        where   ignored = 0
        group by [table]
    ), columns_ignored as (
        select  [table],
                [columns ignored] = string_agg([column], ', ') within group (order by [column])
        from    @column_info
        where   ignored = 1
        group by [table]
    ), keys_null as (
        select  [table], 
                [rows] = count(*),
                [null keys] = count(case when [key] is null or [key] = '[NULL]' then 1 end),
                [good keys] = count(case when [key] is not null and [key] != '[NULL]' then 1 end)
        from    @everything e
                left join @keycols kc
                    on e.[column] = case when e.[table] = @table1 then kc.t1 else kc.t2 end
        where   kc.ordinal is not null
        group by [table]
    ), keys_missing as (
        select  t.[table],
                [missing keys] = string_agg(x.[key], ', ') 
        from    tables t
                outer apply @keycols kc 
                outer apply (select
                    case t.[table] when @table1 then kc.t1 else kc.t2 end
                ) x([key])
        where   x.[key] not in (select distinct e.[column] from @everything e where e.[table] = t.[table])
        group by t.[table]
    ), keys_unmatched as (
        select  [table],
                [count unmatched] = count(*),
                [keys unmatched] = string_agg([key], ', ') within group (order by case when 1 = isnumeric([key]) then cast([key] as int) else [key] end)
        from    @keys_unmatched
        where   [key] != '[NULL]'
        group by [table]
    )
        select  t.[table],
                n.[rows],
                n.[good keys],
                n.[null keys],
                m.[missing keys],
                cc.[columns compared],
                ci.[columns ignored],
                k.[count unmatched],
                k.[keys unmatched]
        from    tables t
                left join columns_compared cc
                    on cc.[table] = t.[table]
                left join columns_ignored ci
                    on ci.[table] = t.[table]
                left join keys_unmatched k
                    on k.[table] = t.[table]
                left join keys_null n
                    on n.[table] = t.[table]
                left join keys_missing m
                    on m.[table] = t.[table]

    --> capture xref
    declare @xref table([key] varchar(max), [column] varchar(max), [table1] varchar(max), [table2] varchar(max), [unmatched] bit)
    insert  @xref
    select  x.[key],
            x.[column],
            [table1] = t1.[value],
            [table2] = t2.[value],
            unmatched = case when t1.[value] = t2.[value] then 0                                                    --> skip matches
                                when isnull(t1.[value], '{{null}}') = isnull(t2.[value], '{{null}}') then 0            --> nulls are equal
                                when 1 = @laxval and isnull(trim(t1.[value]),'') = isnull(trim(t2.[value]), '') then 0 --> laxval enabled, treat blank equal to null
                                else 1 end
    from    (select * from @everything where [table] = @table1) t1
            full outer join (select * from @everything where [table] = @table2) t2
                on t1.[key] = t2.[key]
                and t1.[column] = t2.[column]
            outer apply (select
                coalesce(t1.[key], t2.[key]),
                coalesce(t1.[column], t2.[column])
            ) x([key], [column])
    where   x.[key] not in (select [key] from @keys_unmatched)                      --> ignore unmatched rows
            and x.[column] in (select [column] from @column_info where ignored = 0) --> ignore unmatched columns

    if exists (select * from @xref)
        select  [column],
                [differences] = count(case when unmatched = 1 then 1 end),
                [matches] = count(case when unmatched = 0 then 1 end),
                [blanks table1] = count(case when trim(table1) = '' then 1 end),
                [nulls table1] = count(case when table1 is null then 1 end),
                [blanks table2] = count(case when trim(table2) = '' then 1 end),
                [nulls table2] = count(case when table2 is null then 1 end)
        from    @xref
        group by [column]
        order by [column]

    if exists (select * from @xref where unmatched = 1)
    begin
        --> show distinct differences with counts
        select [column], table1, table2, records = count(*) from @xref where unmatched = 1 group by [column], table1, table2 order by 4 desc, 1, 2, 3

        --> show all differences
        --> TODO: @keytype based on @keycol is no longer correct now that we have compound key support (still works for non-json single key @keycol, but not compound or json syntax)
        declare @keytype varchar(20) = (select type_name(system_type_id) from sys.columns where object_id = object_id(@table1) and name = @keycol)
        select * from @xref where unmatched = 1 order by 
            --> each sort has to be a single type, so to conditionally cast you have to have separate sorts and return null for disabled sorts
            case when @keytype = 'int' then cast([key] as int) end,         --> if key type is int, order by int cast
            case when @keytype = 'bigint' then cast([key] as bigint) end,   --> if key type is bigint, order by bigint cast
            case when @keytype not in ('int', 'bigint') then [key] end,     --> if key type is not int, order without cast
            [column]
    end
GO
