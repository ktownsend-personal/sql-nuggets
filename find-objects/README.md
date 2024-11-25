# find-objects

I use this when I'm researching dependencies or patterns.

I chose to make it a function because it is easier to consume than a stored procedure. You can filter it, exclude columns you don't need (like the heavy `definition` column) or even do joins to something else.

Example:

```SQL
select name from test.FindObjects('select') where type = 'SQL_SCALAR_FUNCTION' order by name
```

Available fields:

|column       |description|
|---:|:---|
|`schema`     |bracketed or bare depending on characters present|
|`object`     |bracketed or bare depending on characters present|
|`name`       |combined schema.object format|
|`type`       |type of object|
|`definition` |the full object definition that was searched, in case you want it|

Notes:

- includes brackets around identifiers when they aren't "regular" identifiers that can be used bare (i.e., special characters)

- Searchable:

  |Code|Type|
  |:---:|:---|
  |FN|SQL_SCALAR_FUNCTION|
  |IF|SQL_INLINE_TABLE_VALUED_FUNCTION|
  |P |SQL_STORED_PROCEDURE|
  |TF|SQL_TABLE_VALUED_FUNCTION|
  |TR|SQL_TRIGGER|
  |V |VIEW|

- Not searchable:

  |Code|Type|
  |:---:|:---|
  |AF|AGGREGATE_FUNCTION|
  |D |DEFAULT_CONSTRAINT|
  |F |FOREIGN_KEY_CONSTRAINT|
  |IT|INTERNAL_TABLE|
  |PK|PRIMARY_KEY_CONSTRAINT|
  |S |SYSTEM_TABLE|
  |SO|SEQUENCE_OBJECT|
  |SQ|SERVICE_QUEUE|
  |TT|TYPE_TABLE|
  |U |USER_TABLE|
  |UQ|UNIQUE_CONSTRAINT|
