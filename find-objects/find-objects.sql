create or alter function test.FindObjects(
    @contains varchar(max)
) returns table as 
    /*
      Created by Keith Townsend, long ago
      MIT License

      Searches for @contains in all searchable object definitions. 
      For convenience, it adds brackets for identifiers that need them, except for keywords but you really shouldn't do that anyway.
      Defined as a table function to make it more versatile in queries to join, filter, or exclude columns that aren't needed.
    */

    return
        select  x.[schema],
                x.[object],
                [name] = concat(x.[schema], '.', x.[object]), 
                [type] = o.type_desc,
                [definition] = trim(char(32) + char(13) + char(10) + char(9) from m.definition) --> I like it tidy
        FROM    sys.sql_modules m
                inner join sys.objects o 
                    on m.object_id = o.object_id
                inner join sys.schemas s 
                    on o.schema_id = s.schema_id
                outer apply (select
                    --> add brackets if identifiers need them (note, does not detect keywords that also require brackets)
                    --> detects identifiers starting with number or containing anything that isn't a number, letter or underscore
                    case when o.name like '%[^0-9a-z_]%' or o.name like '[0-9]%' then quotename(o.name) else o.name end,
                    case when s.name like '%[^0-9a-z_]%' or s.name like '[0-9]%' then quotename(s.name) else s.name end
                ) x([object], [schema])
        where   o.type in ('P', 'V', 'TR', 'FN', 'TF', 'IF') -- these other types don't have defs to examine: F, IT, D, SQ, UQ, U, TT, S, PK, SO, AF
                and m.definition like '%' + @contains + '%'
GO
