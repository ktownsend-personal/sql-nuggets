create or alter function dbo.json_array_normalize(
    @jsonArray varchar(max),
    @sort bit = 1,
    @unique bit = 1
)
returns varchar(max)
as begin
    /*
        Created by Keith Townsend, 6/13/2025
        MIT License

        Applies normalization to a json array.
        See dependency dbo.JsonArrayFromList for full feature description.
    */

    if @jsonArray is null or @jsonArray = '' or @jsonArray = '[]'
        return '[]';
    
    declare @values dbo.StringList;
    insert into @values select [value] from openjson(@jsonArray)
    return dbo.JsonArrayFromList(@values, @sort, @unique);
end;
GO
