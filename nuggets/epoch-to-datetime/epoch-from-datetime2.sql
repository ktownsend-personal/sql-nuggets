create or alter function dbo.EpochFromDateTime2(
    @dt2 datetime2,
    @precision varchar(11)
) returns bigint as begin
    /*
        Created by Keith Townsend, 12/3/2024

        Converts DateTime2 to unix timestamp (epoch time).
        Must specify desired precision of either second or millisecond.
    */

    if @dt2 is null return null
    if nullif(trim(@precision), '') is null set @precision = 'second'
    return case 
        when @precision in ('s',  'second')      then datediff(second, '1970-01-01', @dt2)
        when @precision in ('ms', 'millisecond') then cast(datediff(second, '1970-01-01', @dt2) as bigint) * 1000 + datepart(millisecond, @dt2)
        else 0
    end
end
GO
