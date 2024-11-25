create or alter function dbo.json_flatten(
    @json varchar(max)
) returns table as
    /*  
        Created by Keith Townsend on 3/19/2024
        MIT License

        Recursive CTE to flatten nested JSON up to depth 100

        - Intermediate column is useful for omitting rows that aren't the final property in a chain.
        - Path column is compatible with sql json functions that use path.
        - Stub column is useful for finding all array items at same property chain for aggregation.
        It is like path column but without any indexes inside the square brackets.

        DEV-TIP: you can see what data types & collations are returned by a query like this:
            select * from sys.dm_exec_describe_first_result_set(
                'query string goes here', 
                null, 
                0
            )
    */

    return 
        with data as (
            select  --> cast & collate required in anchor to match openjson() types in recursive part
                    path     = cast('$' as nvarchar(4000))  collate Latin1_General_BIN2, 
                    stub     = cast('$' as nvarchar(4000)) collate Latin1_General_BIN2,
                    [key]    = cast('$' as nvarchar(4000))  collate Latin1_General_BIN2, 
                    value    = cast(@json as nvarchar(max)) collate SQL_Latin1_General_CP1_CI_AS, 
                    typenum  = cast(typenum as tinyint),
                    depth    = 0
            from    (select case 
                        --> detect what type of JSON value we were given (match openjson type numbers)
                        when @json is null then 0
                        when len(@json) < 50 and 1 = isnumeric(@json) then 2    --> must check length to avoid truncation error from isnumeric()
                        when @json in ('true', 'false') then 3
                        when 1 = isjson(@json) and left(trim(@json), 1) = '[' then 4
                        when 1 = isjson(@json) and left(trim(@json), 1) = '{' then 5
                        else 1
                    end) x(typenum)
            union all
            select  case x.typenum
                        when 4 then concat(x.path, '[', j.[key], ']') --> array
                        else concat(x.path, '.', j.[key])             --> property
                    end, 
                    case x.typenum
                        when 4 then concat(x.[stub], '[]')           --> array
                        else concat(x.[stub], '.', j.[key])          --> property
                    end, 
                    j.[key], j.value, j.type,
                    x.depth + 1
            from    data x 
                    outer apply openjson(case when 1 = isjson(x.value) then x.value end) j 
            where   depth < 100
                    and j.type > 0
        ), types(id,name) as (
            -- order matters to align index with type numbers returned by openjson()
            select [key], value from openjson('["null","string","number","bool","array","object"]')
            --> NOTE: in SQL2022 and newer you can use string_split() with ordinal:
            --        select [key] = ordinal, value from string_split('null,string,number,bool,array,object', ',', 1)

        )
            select  d.path, d.stub, d.[key], d.value, d.typenum, 
                    typename = t.name,            --> readable json type
                    intermediate = isJson(value), --> caller can omit intermediate rows (typical)
                    d.depth
            from    data d 
                    left join types t 
                        on t.id = d.typenum
GO
