# json-minify

It shocks me every time I need to minify some JSON in a SQL query that it's not a built-in capability of SQL Server.

I have had a couple iterations of this, but finally it seems fast and stable enough to share.

## Usage

This is really easy to use. Give it JSON and it returns minified JSON. 

```SQL
select dbo.json_minify(x.jsonData) as minified from dbo.myTable x
```

## How It Works

This is basically just looping over all the chars in the string and building a new string. It detects when inside dobule-quotes so that it doesn't remove spaces from names and values, and it knows the difference of escaped double-quotes inside a value.

Whitespace handled: `space`, `tab`, `carriage return` and `line feed`.

Previous versions were more complicated and far slower. I'm very happy with this solution.
