# Data Compare

Often I find myself wanting to quickly compare data, usually some before and after results from a view or a table when I am making changes to something. It wasn't often enough to justify the cost of a dedicated tool, so I found myself writing custom compare queries unique to each situation and then discarding them when the task is done. One day I had a little extra time and an insatiable desire to make a universal data compare tool. I had attempted this with SQL a few times over the years, and even created a tool in C# that worked well, but I always felt like the real solution could be better and fully native to SQL Server. Finally, earlier this year (May 2024) I had an epiphany and realized I could use JSON functions to slice and dice the data in a dynamically comparable way.

## Features

- compares all data between two tables by name or JSON object arrays
  - named table can have schema and/or brackets
  - if querying your own JSON, using `FOR JSON PATH, INCLUDE_NULL_VALUES` is recommended to ensure null columns are compared
  - but not nested JSON; just simple table JSON, like
    `select * from table for json path, include_null_values`
- supports compound join key, even if key column names are different in each set of data
  - case is not sensitive because we have special handling for getting the correct casing of key column names independently for each set of data, which is important because json functions are case sensitive
  - join key can be comma separated string if names are the same between the data sets: `key1, key2`
  - join key can be json object defining how keys are matched when names are different between the data sets: `{"table1key1":"table2key1","table1key2":"table2key2"}`
- optional switch to treat blanks and nulls as equal; defaults to not equal
- explicit columns to ignore can be provided, such as coluns that aren't important for the comparison and you want to eliminate the noise from the results
  - columns only found in one of the sets will automatically be ignored
- explicit key values to ignore can be provided, such as when you have records that are expected to not match and don't care to see them in the results
- outputs:
  - table comparison summary
  - column comparison summary, if something to report
  - distinct differences with counts, if something to report
  - all values that don't match, if something to report

## Usage

This is a typical example of how I would use it in real life. I am testing a change to a view so I can compare beofre and after, and using a transaction so the change isn't permanent.

```sql
begin tran
  --> capture JSON of the view before making changes
  declare @table1 varchar(max) = (select * from dbo.vWhatever for json path, INCLUDE_NULL_VALUES)

  --> alter the view here...

  --> compare captured JSON to the updated view
  exec dbo.table_compare @table1, 'dbo.vWhatever', 'id', 0, 'RallyYear'
rollback
```

## How It Works

### The Magic

We are able to use `openjson()` to extract every field name and value from both sets of data, along with table name and compound key for the row it came from. Having one row for every value allows us to use some fairly straightforward queries to do our comparisons.

### Steps

1. capture json of each set into `@result` table
    - if provided a table or view name we query the full JSON of the table using dynamic SQL
1. normalize matching list for key columns into `@keycols` table
    - provided join key pairs are extracted into a table
    - JSON data is examined to determine correct casing of the key column names
1. all field names and values for all rows are unpivoted into `@everything` table
    - this is where `openjson()` provides the magic we need to compare everything dynamically
    - a special combined key value is generated here as well
1. unmatched key values between the sets are captured into `@keys_unmatched` table
1. unique column names are captured into `@column_info` table, identifying which table and whether ignored
1. output table comparison summary
1. capture cross-reference of field data between the two sets into `@xref` table
1. output summary of `@xref`, if it has any rows
1. output summary of row deltas from `@xref`, if there are any
1. output all row deltas from `@xref`, if there are any

## Notes

One of my favorite features of this approach is that it avoids a lot of dynamic SQL. We do have some dynamic SQL to get the JSON if given a table or view name, but otherwise everything is direct SQL and is visible to the query optimizer.
