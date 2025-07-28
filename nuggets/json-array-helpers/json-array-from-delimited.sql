create or alter function dbo.json_array_from_delimited(
    @delimitedValues varchar(max),
    @delimiter char(1) = ',',
    @sort bit = 0,
    @unique bit = 0
)
returns varchar(max)
as begin
    /*
        Created by Keith Townsend, 6/13/2025
        MIT License

        Makes a json array from delimited string.
        See dependency dbo.JsonArrayFromList for full feature description.
    */

    declare @values dbo.StringList;
    
    insert into @values (Value)
    select trim(value)
    from string_split(@delimitedValues, @delimiter)
    where nullif(trim(value), '') is not null;
    
    return dbo.JsonArrayFromList(@values, @sort, @unique);
end;
GO
