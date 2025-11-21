
select	top 5
		CompletedCount
		, PeriodsRemaining
		, WrestlersLoaded = Wrestlers
		, WrestlersRemain
		, PeriodEndDate
		, Completed
		, LoadTime
		, TimeRemaining = cast(lag(LoadSeconds) over (order by PeriodEndDate) * PeriodsRemaining / 60 / 60 / 24 as varchar(255)) + 'D ' +
			cast((lag(LoadSeconds) over (order by PeriodEndDate) * PeriodsRemaining / 60 / 60) % 24 as varchar(255)) + 'h ' +
			cast((lag(LoadSeconds) over (order by PeriodEndDate) * PeriodsRemaining / 60) % 60 as varchar(255)) + 'm '
		, Ending = dateadd(second, lag(LoadSeconds) over (order by PeriodEndDate) * PeriodsRemaining, LastAdd)
from	(
		select	*
				, Completed = 
					right('00' + cast(datepart(hh, LastAdd) % 12 as varchar(255)), 2) + ':' + 
					right('00' + cast(datepart(minute, LastAdd) as varchar(255)), 2)
				, LoadSeconds = datediff(second, PreviousFinish, LastAdd)
				, LoadTime = cast(datediff(second, PreviousFinish, LastAdd) / 60 as varchar(255)) + 'm ' + cast(datediff(second, PreviousFinish, LastAdd) % 60 as varchar(255)) + 's'
				, WrestlersRemain  = Wrestlers - PreviousWrestlers
		from	(
				select	WrestlerRating.PeriodEndDate
						, CompletedCount = count(PeriodEndDate) over ()
						, LastAdd = max(WrestlerRating.InsertDate)
						, Wrestlers = count(distinct WrestlerRating.EventWrestlerID)
						, PreviousWrestlers = lag(count(distinct WrestlerRating.EventWrestlerID)) over (order by WrestlerRating.PeriodEndDate)
						, PreviousPeriod = lag(WrestlerRating.PeriodEndDate) over (order by WrestlerRating.PeriodEndDate)
						, PreviousFinish = lag(max(WrestlerRating.InsertDate)) over (order by WrestlerRating.PeriodEndDate)
						, PeriodsRemaining = datediff(week, WrestlerRating.PeriodEndDate, cast(dateadd(day, - (datepart(dw, getdate()) - 1) % 7, getdate()) as date))
				from	WrestlerRating with (nolock)
				group by
						WrestlerRating.PeriodEndDate
				) PeriodData
		) LoadTimes
order by
		PeriodEndDate desc
