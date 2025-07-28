create or alter function dbo.periods (
    @periodType nvarchar(10), -- 'week' or 'month'
    @targetYearOrPeriodCount int = null, -- null defaults to current year, 1754 is cutoff between year and period count
    @weekStartName nvarchar(10) = null -- name or abbreviation of weekday to start week periods; NULL or not found uses @@datefirst
) returns table as return
    /*
        Created by Keith Townsend on 8/28/2023

        Period generator for weekly or monthly periods.

        @periodType: 'week' or 'month'
        @targetYearOrPeriodCount:
            NULL will generate periods for the current year.
            Any value >= 1754 will be treated as a target year. 
            Any value < 1754 will be treated as a number of periods back in history, with a max of 100 periods returned.
                * we are using a recursive CTE, which has a limit of 100 iterations; besides, it would be unusual to query that many periods

        NOTES:
            For weekly periods, the first week may be labeled as WK53 of the previous year and WK1 may be skipped. This is due to SQL Server's 
            week numbering, which depends on the week containing January 1st and the chosen week start day. If the first week of the target year 
            does not start on January 1st, it may be considered the last week (WK53) of the previous year. The next week will be WK2, so WK1 may 
            not appear for some years/week start combinations.

            Special logic is implemented as CTE's because Inline Table-Valued Functions (ITVF) cannot use variables
    */

    with cte_params as (
        select
            100 as historyLimit,
            isnull(
                nullif(
                    (select min(i) from (values (1),(2),(3),(4),(5),(6),(7)) v(i)
                        where lower(datename(weekday, dateadd(day, v.i-1, '1900-01-01')))
                              like lower(isnull(@weekStartName, datename(weekday, dateadd(day, @@datefirst-1, '1900-01-01')))) + '%'),
                    0),
                @@datefirst) as datefirst,
            case when @targetYearOrPeriodCount is null then year(getutcdate())
                 when @targetYearOrPeriodCount >= 1754 then @targetYearOrPeriodCount
                 else null end as targetYear,
            case when @targetYearOrPeriodCount < 1754 then @targetYearOrPeriodCount else null end as periodsBack,
            case when lower(@periodType) = 'week' then 53 when lower(@periodType) = 'month' then 13 else 0 end as maxPeriods,
            case when lower(@periodType) = 'week' then 'yyyy-W\K'
                 when lower(@periodType) = 'month' then 'yyyy-MM'
                 else '' end as periodFormat,
            case when lower(@periodType) = 'week' then 'yyyy-W\K'
                 when lower(@periodType) = 'month' then 'yyyy-MMM'
                 else '' end as labelFormat
    ), cte_dates as (
        select *,
            case
                when periodsBack is not null and lower(@periodType) = 'week'
                    then dateadd(week, -periodsBack+1, cast(dateadd(day, 1-datefirst, getutcdate()) as date))
                when periodsBack is not null and lower(@periodType) = 'month'
                    then datefromparts(year(dateadd(month, -periodsBack+1, getutcdate())), month(dateadd(month, -periodsBack+1, getutcdate())), 1)
                when lower(@periodType) = 'week'
                    then dateadd(day, -((datepart(weekday, cast(cast(targetYear as varchar(4)) + '-01-01' as date)) - datefirst + 7) % 7), cast(cast(targetYear as varchar(4)) + '-01-01' as date))
                else cast(cast(targetYear as varchar(4)) + '-01-01' as date)
            end as startDate,
            case
                when periodsBack is not null and periodsBack < historyLimit then periodsBack
                when periodsBack is not null then historyLimit
                else maxPeriods end as iterations
        from cte_params
    ), periods_cte as (
        select 1 as iteration, startDate as period_start from cte_dates
        union all
        select iteration + 1,
            case when lower(@periodType) = 'week' then dateadd(week, iteration, startDate)
                 when lower(@periodType) = 'month' then dateadd(month, iteration, startDate)
            end
        from periods_cte
        cross join cte_dates
        where iteration < iterations
    )
        select  [number] = p.iteration,
                [period] = format(p.period_start, d.periodFormat) + x.suffix,
                [label] = format(p.period_start, d.labelFormat) + x.suffix,
                [periodstart] = p.period_start,
                [periodend] = x.periodend
        from    periods_cte p
        cross join cte_dates d
        outer apply (select 
            case when lower(@periodType) = 'week' then cast(datepart(week, p.period_start) as varchar(4)) else '' end,
            case when lower(@periodType) = 'week' then dateadd(day, 6, p.period_start)
                when lower(@periodType) = 'month' then eomonth(p.period_start)
            end
        ) x(suffix, periodend)
        where
            -- guard against invalid inputs
            lower(isnull(@periodType, '')) in ('week', 'month')
            and (@targetYearOrPeriodCount is null or @targetYearOrPeriodCount >= 1)
            -- if target year, filter by target year to ensure we don't get extra periods
            and (d.targetYear is null or d.targetYear in (year(p.period_start), year(x.periodend)))
GO
