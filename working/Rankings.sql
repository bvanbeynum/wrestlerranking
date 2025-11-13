
select	top 100 
		EventWrestler.GlickoRating
		, EventWrestler.GlickoDeviation
		, EventWrestler.ID
		, LastMatch.WeightClass
		, EventWrestler.WrestlerName
		, Teams.TeamName
from	EventWrestler with (nolock)
cross apply (
		select	TeamName = string_agg(TeamName, ', ') within group (order by UniqueTeam.TeamName)
		from	(
				select	distinct EventWrestlerMatch.TeamName
				from	EventWrestlerMatch with (nolock)
				where	EventWrestler.ID = EventWrestlerMatch.EventWrestlerID
				) UniqueTeam
		) Teams
cross apply (
		select	top 1 EventMatch.WeightClass
		from	EventWrestlerMatch with (nolock)
		join	EventMatch with (nolock)
		on		EventWrestlerMatch.EventMatchID = EventMatch.ID
		join	Event with (nolock)
		on		EventMatch.EventID = Event.ID
		where	EventWrestler.ID = EventWrestlerMatch.EventWrestlerID
				and isnumeric(EventMatch.WeightClass) = 1
		group by
				EventMatch.WeightClass
				, event.EventDate
		order by 
				Event.EventDate desc
		) LastMatch
where	EventWrestler.ID in (
			select	distinct EventWrestler.ID
			from	EventWrestler with (nolock)
			join	EventWrestlerMatch with (nolock)
			on		EventWrestler.ID = EventWrestlerMatch.EventWrestlerID
			join	EventMatch with (nolock)
			on		EventWrestlerMatch.EventMatchID = EventMatch.ID
			join	Event with (nolock)
			on		EventMatch.EventID = Event.ID
			where	event.EventState = 'sc'
					and event.EventDate > '12/1/2024'
		)
		-- and LastMatch.WeightClass = '144'
		and WrestlerName like '%van beynum'
order by
		EventWrestler.GlickoRating desc

if object_id('tempdb..#WrestlerMatches') is not null
	drop table #WrestlerMatches
if object_id('tempdb..#WrestlerRatings') is not null
	drop table #WrestlerRatings


select	WrestlerID = EventWrestler.ID
		, event.EventDate
		, event.EventName
		, MatchID = EventMatch.ID
		, WrestlerMatchID = EventWrestlerMatch.ID
		, EventMatch.RoundName
		, Result = EventWrestlerMatch.IsWinner
		, EventMatch.WinType
		, Opponent = OtherMatch.WrestlerName
		, OpponentTeam = OtherMatch.TeamName
		, OpponentRating = OpponentRating.Rating
		, OpponentDeviation = OpponentRating.Deviation
		, EventMatch.Sort
into	#WrestlerMatches
from	EventWrestler with (nolock)
join	EventWrestlerMatch with (nolock)
on		EventWrestler.ID = EventWrestlerMatch.EventWrestlerID
join	EventWrestlerMatch OtherMatch with (nolock)
on		EventWrestlerMatch.EventMatchID = OtherMatch.EventMatchID
		and EventWrestlerMatch.EventWrestlerID <> OtherMatch.EventWrestlerID
join	EventMatch with (nolock)
on		EventWrestlerMatch.EventMatchID = EventMatch.ID
join	Event with (nolock)
on		EventMatch.EventID = Event.ID
outer apply (
		select	Rating
				, Deviation
		from	(
				select	WrestlerRating.PeriodEndDate
						, WrestlerRating.Rating
						, WrestlerRating.Deviation
						, PreviousDate = lag(WrestlerRating.PeriodEndDate) over (order by WrestlerRating.PeriodEndDate)
				from	WrestlerRating with (nolock)
				where	WrestlerRating.EventWrestlerID = OtherMatch.EventWrestlerID
				) Ratings
		where	event.EventDate between Ratings.PreviousDate and dateadd(d, -1, Ratings.PeriodEndDate)
		) OpponentRating
where	EventWrestler.ID = 125555
		-- and event.EventName = 'Pins in the Park - Carowinds 2025'
		-- and event.EventName = 'Honey Badger 2025'
order by
		EventMatch.ID

select	WrestlerID = EventWrestler.ID
		, WrestlerRating.PeriodEndDate
		, WrestlerRating.Rating
		, WrestlerRating.Deviation
		, PreviousPeriod = lag(WrestlerRating.PeriodEndDate) over (order by WrestlerRating.PeriodEndDate)
		, PreviousRating = lag(WrestlerRating.Rating) over (order by WrestlerRating.PeriodEndDate)
		, PreviousDeviation = lag(WrestlerRating.Deviation) over (order by WrestlerRating.PeriodEndDate)
into	#WrestlerRatings
from	EventWrestler with (nolock)
join	WrestlerRating with (nolock)
on		EventWrestler.ID = WrestlerRating.EventWrestlerID
where	EventWrestler.ID = 125555

select	Ratings.PeriodEndDate
		, Rating = cast(cast(round(Ratings.Rating, 0) as int) as varchar(max)) + ' (' + cast(cast(round(Ratings.Deviation, 0) as int) as varchar(max)) + ')'
		, Difference = cast(round(Ratings.Rating - Ratings.PreviousRating, 0) as int)
		, Event = convert(varchar(10), Matches.EventDate, 101) + ': ' + Matches.EventName
		, Result = case when Matches.Result = 1 then 'won by ' + Matches.WinType else 'lost by ' + Matches.WinType end
		, Matches.Opponent
		, Matches.OpponentTeam
		, OpponentRating = cast(cast(round(Matches.OpponentRating, 0) as int) as varchar(max)) + ' (' + cast(cast(round(Matches.OpponentDeviation, 0) as int) as varchar(max)) + ')'
		, Outcome = case when Matches.Result = 1 then 'Win' else 'Loss' end
		, ExpectedOutcome = case
			when matches.Result = 1 and ratings.Rating > Matches.OpponentRating then 'Expected'
			when matches.Result = 1 and ratings.Rating + ratings.Deviation > matches.OpponentRating - matches.OpponentDeviation then 'In-range'
			when matches.Result = 1 and ratings.Rating + ratings.Deviation < matches.OpponentRating - matches.OpponentDeviation then 'Unexpected'
			when matches.Result = 0 and ratings.Rating < Matches.OpponentRating then 'Expected'
			when matches.Result = 0 and ratings.Rating - ratings.Deviation < Matches.OpponentRating + matches.OpponentDeviation then 'In-range'
			when Matches.Result = 0 and ratings.Rating - ratings.Deviation > Matches.OpponentRating + matches.OpponentDeviation then 'Unexpected'
			end
from	#WrestlerRatings Ratings
left join	
		#WrestlerMatches Matches
on		Ratings.WrestlerID = Matches.WrestlerID
		and Matches.EventDate between ratings.PreviousPeriod and dateadd(d, -1, ratings.PeriodEndDate)
order by
		Ratings.PeriodEndDate desc
		, Matches.EventDate desc
		, Matches.Sort desc
