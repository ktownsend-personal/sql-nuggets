# data-compare

I often find myself needing to quickly compare data, usually before and after results from a view or a table when I am making changes to something. It wasn't often enough to justify the cost of a dedicated tool, so I found myself writing custom compare queries unique to each situation and then discarding them when the task was done. Tedious and boring. Not what a real developer would do. 

I long desired to make a universal data compare tool, and attempted it a few times over the years but was never satisfied with the result. Not flexible enough, too much string manipulation to make dynamic queries, verbose results to sift through. Finally, earlier this year (May 2024) I had an epiphany and realized I could use JSON functions to slice and dice the data in a dynamically comparable way.

## Features

- compares two sets of data, either by table/view name or JSON object array
  - named table or view can have schema and/or brackets
  - if querying your own JSON, using `INCLUDE_NULL_VALUES` is recommended to ensure columns where all rows are null are still compared appropriately
  - nested JSON not supported; just simple table JSON, like
    `select * from table for json path, include_null_values`
- supports compound join key, even if key column names are different in each set of data
  - case is not sensitive
  - join key can be comma separated string if names are the same between the data sets: `key1, key2`
  - join key can be json object defining how keys are matched when names are different between the data sets: `{"table1key1":"table2key1","table1key2":"table2key2"}`
- optional switch to treat blanks and nulls as equal; default not equal
- ignore columns you don't care about with a csv list of column names
  - automatically ignores columns only found in one of the sets
- ignore rows you don't care about with a csv list of row keys
  - compound key values need to be formatted as `key1val|key2val`
- outputs (*omitted if nothing to show):
  - table summary
  - *column summary
  - *column difference summary count of each distinct delta
  - *all values that don't match

## Usage

### Typical

This is a typical example of how I would use it in real life. I am testing a change to a view so I can compare beofre and after, and using a transaction around all of it so the change is only applied during the test.

```sql
begin tran
  --> capture JSON of the view before making changes
  declare @table1 varchar(max) = (select * from [dbo].[vWhatever] for json path, INCLUDE_NULL_VALUES)

  --> alter the view here...

  --> compare captured JSON to the updated view
  exec dbo.data_compare @table1, '[dbo].[vWhatever]', 'id'
rollback
```

### Advanced

We can compare output of stored procedures too, by leveraging the JSON input feature.

```sql
--> declare temp tables to capture "before" and "after"
--> NOTE: columns and types must match actual sproc output
create table #before(col1 int, col2 varchar(10))
select top 0 * into #after from #before --> easy table structure copy trick if columns are the same

--> capture "before"
insert #before exec dbo.MySproc 'input1'
declare @before varchar(max) = (select * from #before for json path, INCLUDE_NULL_VALUES)

begin tran
  --> alter sproc here ...

  --> capture "after"
  insert #after exec dbo.MySproc 'input1'
  declare @after varchar(max) = (select * from #after for json path, INCLUDE_NULL_VALUES)

  --> compare the two outputs
  exec dbo.data_compare @before, @after, 'id'
rollback
```

## How It Works

### The Magic

This solution leverages `openjson()` to extract every field name and value from both sets of data, along with table name and compound key for the row it came from. Having one row for every value allows us to use some fairly straightforward queries to do our comparisons and create meaningful summaries.

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

## Benefits

One of the things I love about this solution is that the only dynamic SQL we need is the initial JSON query if we are given a table or view name. That means nearly everything is visible to the query optimizer for greater efficiency. My previous attempts at this were nearly all dynamic SQL and were hard to debug and maintain.

Another benefit of using JSON functions is the source data can come from anywhere and be pasted into a variable. We are not limited to things we can query from the database. We can also capture stored procedure output into temp tables using `insert #temptable exec dbo.MySproc` and format that as JSON for comparison.
