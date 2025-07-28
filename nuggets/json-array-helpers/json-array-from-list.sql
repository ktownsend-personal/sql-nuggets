create or alter function dbo.json_array_from_list(
    @values dbo.StringList readonly,
    @sort bit = 0,
    @unique bit = 0
)
returns varchar(max) 
as begin
    /*
        Created by Keith Townsend, 6/13/2025
        MIT License

        Makes a json array from dbo.StringList. 
        - Optionally sort or remove duplicates.
        - Automatically quotes strings and escapes special characters. Uses bare values for null/bool/number.
        - Automatically lowercases true/false/null.
        - Sorts by type first (null, bool, number, string), then within each type sorts appropriately (i.e. numerically vs. alphabetically)

        Can be used directly. Also used by dbo.JsonArrayFromDelimited and dbo.JsonArrayNormalize.

        To call this you need to first put your values into a list of type dbo.StringList.
            declare @list dbo.StringList
            insert @list select mycol from mytable
            declare @json varchar(max) = dbo.JsonArrayFromList(@list, 1, 1)

        In some cases you may find it easier to use dbo.JsonArrayFromDelimited or dbo.JsonArrayNormalize.

        TODO: 
            - This would be even better as a SQLCLR aggregate function, but that isn't an option for everyone.
            - Speed is unknown for very large arrays, so watch for that being an issue in the future.
    */

    declare @result varchar(max);

    --> capture original order and remove blank/null
    declare @scrubbed table (value varchar(max), row bigint)
    insert  @scrubbed
    select  value, 
            row = row_number() over (order by (select null))
    from    @values
    where   nullif(trim(value), '') is not null;
    
    -- remove duplicates if requested
    if @unique = 1
        delete @scrubbed where row not in (select min(row) from @scrubbed group by Value);

    --> escapes, transforms & quoted vs. bare value handling
    update  @scrubbed
    set     value = case 
                when lower(value) in ('true', 'false', 'null') then lower(value)            --> Booleans and null
                when try_cast(value as decimal(18,6)) is not null then value                --> Numbers
                when isjson(value) = 1 then value                                           --> Valid JSON objects/arrays
                else '"' + replace(replace(replace(replace(replace(replace(replace(replace( --> strings
                        value, 
                        '\',      '\\'), -- Backslash
                        '"',      '\"'), -- Quote
                        char(8),  '\b'), -- Backspace
                        char(9),  '\t'), -- Tab
                        char(10), '\n'), -- Line feed
                        char(12), '\f'), -- Form feed
                        char(13), '\r'), -- Carriage return
                        '/',      '\/')  -- Forward slash
                    + '"' 
            end;
    
    -- build json array with conditional sorting
    select  @result = '[' + string_agg(
                value, 
                ','
            ) within group (order by 
                case when @sort = 0 then row end,                                   --> original order if not sorting
                case when @sort = 1 then                                            --> sort types first
                    case
                        when value = 'null' then 1                                      -- null first
                        when value in ('true', 'false') then 2                          -- bool second
                        when try_cast(value as decimal(18,6)) is not null then 3        -- number third
                        else 4                                                          -- string/json last
                    end
                end,
                case when @sort = 1 and try_cast(value as decimal(18,6)) is not null --> numeric sort for numbers
                      then cast(value as decimal(18,6)) 
                end,
                case when @sort = 1 then value end                                  --> alphabetic sort strings/json
            ) + ']'
    from    @scrubbed;

    return isnull(@result, '[]');
end;
GO
