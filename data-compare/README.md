# Data Compare

Often I find myself wanting to quickly compare data, usually some before and after results from a view or a table when I am making changes to something.
Not often enough to justify the cost of a dedicated tool, so I found myself writing custom compare queries unique to each situation and then discarding them when the task is done.
One day I had a little extra time and an insatiable desire to make a universal data compare tool. 
I had attempted this with SQL a few times over the years, and even created a tool in C# that worked well, but I always felt like the real solution could be better and fully native to SQL Server.
Finally I had an epiphany and realized I could use JSON functions to slice and dice the data in a dynamically comparable way. 
