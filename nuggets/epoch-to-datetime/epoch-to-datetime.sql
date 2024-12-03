create or alter function dbo.EpochToDateTime2(
  @epoch bigint
) returns datetime2 as
  if @epoch is null return null
  return dateadd(millisecond, @epoch % 1000, dateadd(second, @epoch / 1000, '1/1/1970'))
end
GO

create or alter function dbo.DateTime2AsEpoch(
  @dt2 datetime2
) returns bigint as begin
  if @dt2 is null return null
  return cast(datediff(second, '1/1/1970', @dt2) as bigint) * 1000 + datepart(millisecond, @dt2)
end
GO
