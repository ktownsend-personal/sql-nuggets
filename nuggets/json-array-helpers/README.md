# json-array-helpers

This folder contains helper functions for working with JSON arrays to work around features not natively available in SQL Server. These utilities make it easier to create, normalize, and manipulate JSON arrays from delimited strings, table types, or existing JSON arrays.

## Contents

- **StringList.sql**: Defines the `dbo.StringList` table type, used as input for other functions.
- **json-array-from-delimited.sql**: Function `dbo.json_array_from_delimited` splits a delimited string into a JSON array. Useful for quick conversion of CSV-style input. Relies on `dbo.json_array_from_list`.
- **json-array-normalize.sql**: Function `dbo.json_array_normalize` takes a JSON array and returns a normalized version (sorted, deduplicated, and consistently formatted). Uses `dbo.json_array_from_list` for processing.
- **json-array-from-list.sql**: Function `dbo.json_array_from_list` takes a `dbo.StringList` table and returns a JSON array. Supports sorting, removing duplicates, and proper quoting/escaping of values. Used by the other two helpers but can be used directly if desired.

## Usage Examples

```sql
-- json_array_from_delimited(@delimitedValues, @delimiter, @sort, @unique)
-- Create a JSON array from a delimited string
select dbo.json_array_from_delimited('a,b,c', ',', 1, 1)
-- Returns: ["a","b","c"]

-- json_array_normalize(@jsonArray, @sort, @unique)
-- Normalize a JSON array
select dbo.json_array_normalize('["b","a","a"]', 1, 1)
-- Returns: ["a","b"]

-- json_array_from_list(@values, @sort, @unique)
-- Create a JSON array from values in a table
declare @list dbo.StringList;
insert into @list select Name from sys.objects where type = 'U';
select dbo.json_array_from_list(@list, 1, 1)
-- Returns: ["Table1","Table2", ...]
```
