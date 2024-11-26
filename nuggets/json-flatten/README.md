# json-flatten

This function originated as a tool to easily access all child values at a particular depth for a particular property across all objects. For example, in a JSON like below it could be handy to get a complete list of the child property `addresses` for all parents.

```JSON
[
  {
    "name": "user1",
    "addresses": ["10.0.0.1", "10.0.0.2"]
  },
  {
    "name": "user2",
    "addresses": ["192.168.0.1", "192.168.1.1"]
  }
]
```

```SQL
declare @json varchar(max) = '...same json as above...'
select value from dbo.json_flatten(@json) where stub = '$[].addresses[]' 
```

||value|
|---|---|
|1|192.168.0.1|
|2|192.168.1.1|
|3|10.0.0.1|
|4|10.0.0.2|

If you examine the raw output of the function you can see how it organizes the results:

```SQL
select * from dbo.json_flatten(@json)
```

>Not shown in this example, but I used my [json-minify](/nuggets/json-minify/) function on @json to remove line breaks and make the results easier to view.

- `path` is the same syntax as what JSON functions would use to access the element
- `stub` is similar to `path`, but the array indexes are omitted to make it easier to filter a nested array across all objects
- `key` is either the property name or the index of an array element
- `value` is the value at that depth
- `typenum` is the type as reported by openjson()
- `typename` is the human readable form of `typenum`
- `intermediate` is true if the value has children, which is useful to exclude if wanting just the end-value elements
- `depth` is the depth level

||path|stub|key|value|typenum|typename|intermediate|depth|
|---|---|---|---|---|---|---|---|---|
|1|$|$|$|[{&quot;name&quot;:&quot;user1&quot;,&quot;addresses&quot;:[&quot;10.0.0.1&quot;,&quot;10.0.0.2&quot;]},{&quot;name&quot;:&quot;user2&quot;,&quot;addresses&quot;:[&quot;192.168.0.1&quot;,&quot;192.168.1.1&quot;]}]|4|array|1|0|
|2|$[0]|$[]|0|{&quot;name&quot;:&quot;user1&quot;,&quot;addresses&quot;:[&quot;10.0.0.1&quot;,&quot;10.0.0.2&quot;]}|5|object|1|1|
|3|$[1]|$[]|1|{&quot;name&quot;:&quot;user2&quot;,&quot;addresses&quot;:[&quot;192.168.0.1&quot;,&quot;192.168.1.1&quot;]}|5|object|1|1|
|4|$[1].name|$[].name|name|user2|1|string|0|2|
|5|$[1].addresses|$[].addresses|addresses|[&quot;192.168.0.1&quot;,&quot;192.168.1.1&quot;]|4|array|1|2|
|6|$[1].addresses[0]|$[].addresses[]|0|192.168.0.1|1|string|0|3|
|7|$[1].addresses[1]|$[].addresses[]|1|192.168.1.1|1|string|0|3|
|8|$[0].name|$[].name|name|user1|1|string|0|2|
|9|$[0].addresses|$[].addresses|addresses|[&quot;10.0.0.1&quot;,&quot;10.0.0.2&quot;]|4|array|1|2|
|10|$[0].addresses[0]|$[].addresses[]|0|10.0.0.1|1|string|0|3|
|11|$[0].addresses[1]|$[].addresses[]|1|10.0.0.2|1|string|0|3|
