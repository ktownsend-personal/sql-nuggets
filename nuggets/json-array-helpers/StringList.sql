/*
  supporting type for json_array_from_list function
*/

if type_id('dbo.StringList') is null
    create type dbo.StringList as table (Value varchar(max));
GO
