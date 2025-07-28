# periods

I often need to generate a series of weekly or monthly periods for trend reports or dashboards. This function makes it easy to get a table of period numbers, labels, and start/end dates for either weeks or months, for a given year or a number of periods back from today.

## Features

- Generates weekly or monthly periods for a specific year, or N periods back
- Always includes the final period of the previous year as the origin for trend data
- Output includes period number, code, label, start and end dates

## Usage

```sql
-- weekly periods for the current year
select * from dbo.periods('week', null)

-- monthly periods for 2024
select * from dbo.periods('month', 2024)

-- last 12 weekly periods
select * from dbo.periods('week', 12)
```


## Example output


### Weekly periods (2025)

| number | period    | label     | periodstart | periodend   |
|--------|-----------|-----------|-------------|-------------|
| 1      | 2024-WK53 | 2024-WK53 | 2024-12-30  | 2025-01-05  |
| 2      | 2025-WK2  | 2025-WK2  | 2025-01-06  | 2025-01-12  |
| 3      | 2025-WK3  | 2025-WK3  | 2025-01-13  | 2025-01-19  |
| 4      | 2025-WK4  | 2025-WK4  | 2025-01-20  | 2025-01-26  |
| ...    | ...       | ...       | ...         | ...         |

### Monthly periods (2025)

| number | period   | label    | periodstart | periodend   |
|--------|----------|----------|-------------|-------------|
| 1      | 2024-12  | 2024-Dec | 2024-12-01  | 2024-12-31  |
| 2      | 2025-01  | 2025-Jan | 2025-01-01  | 2025-01-31  |
| 3      | 2025-02  | 2025-Feb | 2025-02-01  | 2025-02-28  |
| ...    | ...      | ...      | ...         | ...         |

See the SQL file for details and parameters.
