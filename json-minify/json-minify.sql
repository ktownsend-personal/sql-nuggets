create or alter function [dbo].[json_minify](
    @value varchar(max)
) returns varchar(max) as begin

    /*
        Created by Keith Townsend on 4/22/2024
        MIT License

        Minifies JSON by stripping out excess whitespace (space, tab, newline, carriage return).
        Magnitudes faster than the original version that tried to be clever with charindex and 
        json_flatten function but that wasn't fast enough for the loop. This one does in 142ms
        what it was taking the original version 2 minutes to do. 
    */

    if nullif(trim(@value), '') is null return @value   --> short circuit blanks & nulls
    if 0 = isjson(@value) return @value                 --> short circuit non-json value

    declare @minified varchar(max)
    declare @pos int = 1
    declare @len int = len(@value)
    declare @insideQuotes bit = 0
    declare @escaped bit = 0

    while @pos <= @len
    begin
        declare @char char(1) = substring(@value, @pos, 1)

        set @insideQuotes = case 
            when @insideQuotes = 0 and @char = '"' then 1 
            when @insideQuotes = 1 and @escaped = 0 and @char = '"' then 0 
            else @insideQuotes 
        end

        set @escaped = case @char when '\' then 1 else 0 end

        if 1 = case 
            when @insideQuotes = 1 then 1
            when @char in (char(32), char(13), char(9), char(10)) then 0
            else 1
        end
            set @minified = concat(@minified, @char)

        set @pos = @pos + 1
    end

    return @minified
end
GO
