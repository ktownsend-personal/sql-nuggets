# dependency-matrix

This is a nice way to visualize what objects have dependencies on an object you plan to modify.

Basic usage:

```SQL
exec test.DependencyMatrix 'dbo.MyFlagsView'
```

|referenced|referencing|type|columns|FlagLevel|FlagReason|PID|ProcessId|FlagMeta|
|:---|:---|:---|---|---|---|---|---|---|
|||Frequency||3|3|3|3|2|
|dbo.MyFlagsView|dbo.spTest1|SQL_STORED_PROCEDURE|5|S|S|S|S|S|
|dbo.MyFlagsView|dbo.spTest2|SQL_STORED_PROCEDURE|5|S|S|S|S|S|
|dbo.MyFlagsView|dbo.vTest|VIEW|4|S|S|S|S||

- the first row shows how many objects reference each column (`type = Frequency`)
- `referenced` is the thing you were checking dependencies for
- `referencing` are the objects known to reference `referenced`
- `type` is the type of object referencing what you searched
- `columns` is a count of how many columns are referenced by the object
  - this will say `unable to discover columns` in some cases because discovery sometimes fails
- the rest of the columns are auto-discovered (in frequency order) and show a code indicating how the column is used
  - `S` select
  - `U` update
  - `A` ambiguous
  - `*` select-all
  - `I` insert-all
  - `-` incomplete
  - `?` unknown because columns failed to discover
  - `blank` if not used

## Notes

- you can specify more than one source object, but that only makes sense if they have basically the same columns
- you can specify a list of referencing objects to ignore
- the query can return error messages when discovery fails, and the query tool may show that instead of the results grid, so just switch to the grid manually after the query finishes
- I sometimes use [find-objects](/nuggets/find-objects) to double-check in case this might miss something, such as references inside sql strings that get executed
