
if object_id('tempdb..#WeekEvents') is not null
	drop table #WeekEvents

if object_id('tempdb..#EventRatings') is not null
	drop table #EventRatings

declare @LoadDate date = cast('12/9/2024' as date)

select	EventID = Event.ID
		, Event.EventDate
		, Event.EventName
		, SchoolFilter.SchoolID
		, SchoolFilter.SchoolName
		, SchoolFilter.EventSchoolName
into	#WeekEvents
from	Event
cross apply (
		select	distinct 
				SchoolID = School.ID
				, School.SchoolName
				, EventSchool.EventSchoolName
		from	Event EventLookup
		join	EventMatch
		on		EventLookup.ID = EventMatch.EventID
		join	EventWrestlerMatch
		on		EventMatch.ID = EventWrestlerMatch.EventMatchID
		join	EventSchool
		on		EventWrestlerMatch.TeamName = EventSchool.EventSchoolName
		join	School
		on		EventSchool.SchoolID = School.ID
		where	EventLookup.ID = Event.ID
				and School.Classification like '5a%'
		) SchoolFilter
where	event.EventDate between dateadd(d, -6, @LoadDate) and @LoadDate
group by
		Event.ID
		, Event.EventDate
		, Event.EventName
		, SchoolFilter.SchoolID
		, SchoolFilter.SchoolName
		, SchoolFilter.EventSchoolName
order by
		Event.EventDate desc
		, Event.EventName;

-- Weekly Ratings

select	distinct WeekEvents.EventID
		, WeekEvents.EventName
		, Division = coalesce(EventMatch.Division, 'hs')
		, EventMatch.WeightClass
		, WrestlerRating.EventWrestlerID
		, WrestlerRating.Rating
into	#EventRatings
from	#WeekEvents WeekEvents
join	EventMatch
on		WeekEvents.EventID = EventMatch.EventID
join	EventWrestlerMatch
on		EventMatch.ID = EventWrestlerMatch.EventMatchID
join	WrestlerRating
on		EventWrestlerMatch.EventWrestlerID = WrestlerRating.EventWrestlerID
		and WeekEvents.EventDate between dateadd(day, -6, WrestlerRating.PeriodEndDate) and WrestlerRating.PeriodEndDate
where	coalesce(EventMatch.Division, 'hs') like 'hs%'
		or EventMatch.Division = 'jv'
		or EventMatch.Division like 'high school%';

-- Toughest tournament

; with PercentileRatings as (
	select	distinct EventID
			, EventPercentile = percentile_cont(0.9) within group (order by Rating) over (partition by EventID)
	from	#EventRatings
)
select	Event = EventRatings.EventName
		, Wrestlers = count(distinct EventRatings.EventWrestlerID)
		, [Top Rating] = cast(round(PercentileRatings.EventPercentile, 0) as int)
from	#EventRatings EventRatings
join	PercentileRatings
on		EventRatings.EventID = PercentileRatings.EventID
group by
		EventRatings.EventID
		, EventRatings.EventName
		, PercentileRatings.EventPercentile
order by
		PercentileRatings.EventPercentile desc

-- School Rivalry Tournaments

; with SchoolEvents as (
select	school.Region
		, School.SchoolName
		, WeekEvents.EventName
		, Wrestlers = count(distinct EventWrestlerMatch.EventWrestlerID)
from	#WeekEvents WeekEvents
join	School
on		WeekEvents.SchoolID = School.ID
join	EventMatch
on		WeekEvents.EventID = EventMatch.EventID
join	EventWrestlerMatch
on		EventMatch.ID = EventWrestlerMatch.EventMatchID
		and WeekEvents.EventSchoolName = EventWrestlerMatch.TeamName
where	school.Classification like '5a%'
group by
		School.SchoolName
		, school.Region
		, WeekEvents.EventName
)
select	Region
		, School = SchoolName
		, Events = string_agg(EventName + ' (' + cast(Wrestlers as varchar(max)) + ' wrestlers)', ', ') within group (order by Wrestlers desc)
from	SchoolEvents
group by
		Region
		, SchoolName
order by
		Region
		, SchoolName

-- Showdowns

;with MatchDetails as (
	select	WeekEvents.EventID
			, WeekEvents.EventName
			, EventMatch.ID as MatchID
			, EventMatch.RoundName
			, EventMatch.WeightClass
			, WinnerName = WinnerMatch.WrestlerName
			, WinnerTeam = WinnerMatch.TeamName
			, WinnerRating = WinnerRanking.Rating
			, WinnerEventWrestlerID = WinnerMatch.EventWrestlerID
			, LoserName = LoserMatch.WrestlerName
			, LoserTeam = LoserMatch.TeamName
			, LoserRating = LoserRanking.Rating
			, LoserEventWrestlerID = LoserMatch.EventWrestlerID 
			, RatingSort = WinnerRanking.Rating + LoserRanking.Rating
			, RatingDiff = abs(WinnerRanking.Rating - LoserRanking.Rating)
	from	(
			select	EventID
					, EventName
			from	#WeekEvents
			group by
					EventID
					, EventName
			) WeekEvents
	join	EventMatch
	on		WeekEvents.EventID = EventMatch.EventID
	join	EventWrestlerMatch WinnerMatch
	on		EventMatch.ID = WinnerMatch.EventMatchID
			and WinnerMatch.IsWinner = 1
	join	EventWrestlerMatch LoserMatch
	on		EventMatch.ID = LoserMatch.EventMatchID
			and LoserMatch.IsWinner = 0
	join	#EventRatings WinnerRanking
	on		WinnerMatch.EventWrestlerID = WinnerRanking.EventWrestlerID
	join	#EventRatings LoserRanking
	on		LoserMatch.EventWrestlerID = LoserRanking.EventWrestlerID
	where	coalesce(EventMatch.Division, 'hs') like 'hs%'
			or EventMatch.Division = 'jv'
			or EventMatch.Division like 'high school%'
),
WrestlerMatchList as (
	select	WinnerEventWrestlerID as WrestlerID, MatchID, RatingDiff from MatchDetails
	union all
	select	LoserEventWrestlerID, MatchID, RatingDiff from MatchDetails
),
ToughestMatchRankings as (
	select	WrestlerID
			, MatchID
			, ToughestMatchRank = row_number() over (partition by WrestlerID order by RatingDiff asc)
	from	WrestlerMatchList
)
select	top 10 
		[Rank] = row_number() over (order by Details.RatingSort desc, Details.RatingDiff asc)
		, [Weight Class] = Details.WeightClass
		, Round = Details.RoundName
		, Winner = Details.WinnerName
		, Details.WinnerTeam
		, Loser = Details.LoserName
		, Details.LoserTeam
		, Event = Details.EventName
from	ToughestMatchRankings
join	MatchDetails as Details
on		ToughestMatchRankings.MatchID = Details.MatchID
where	ToughestMatchRankings.ToughestMatchRank = 1
group by Details.EventID
		, Details.EventName
		, Details.RoundName
		, Details.WeightClass
		, Details.WinnerName
		, Details.WinnerTeam
		, Details.WinnerRating
		, Details.LoserName
		, Details.LoserTeam
		, Details.LoserRating
		, Details.RatingSort
		, Details.RatingDiff
		, Details.MatchID
order by
		Details.RatingSort desc
		, Details.RatingDiff asc

-- Biggest upsets

;with MatchDetails as (
	select	WeekEvents.EventID
			, WeekEvents.EventName
			, EventMatch.ID as MatchID
			, EventMatch.RoundName
			, EventMatch.WeightClass
			, WinnerName = WinnerMatch.WrestlerName
			, WinnerTeam = WinnerMatch.TeamName
			, WinnerRating = WinnerRanking.Rating
			, WinnerEventWrestlerID = WinnerMatch.EventWrestlerID
			, LoserName = LoserMatch.WrestlerName
			, LoserTeam = LoserMatch.TeamName
			, LoserRating = LoserRanking.Rating
			, LoserEventWrestlerID = LoserMatch.EventWrestlerID 
			, RatingDiff = LoserRanking.Rating - WinnerRanking.Rating
	from	(
			select	EventID
					, EventName
			from	#WeekEvents
			group by
					EventID
					, EventName
			) WeekEvents
	join	EventMatch
	on		WeekEvents.EventID = EventMatch.EventID
	join	EventWrestlerMatch WinnerMatch
	on		EventMatch.ID = WinnerMatch.EventMatchID
			and WinnerMatch.IsWinner = 1
	join	EventWrestlerMatch LoserMatch
	on		EventMatch.ID = LoserMatch.EventMatchID
			and LoserMatch.IsWinner = 0
	join	#EventRatings WinnerRanking
	on		WinnerMatch.EventWrestlerID = WinnerRanking.EventWrestlerID
	join	#EventRatings LoserRanking
	on		LoserMatch.EventWrestlerID = LoserRanking.EventWrestlerID
	where	coalesce(EventMatch.Division, 'hs') like 'hs%'
			or EventMatch.Division = 'jv'
			or EventMatch.Division like 'high school%'
),
UpsetMatches as (
	select * from MatchDetails where RatingDiff > 0
),
BiggestUpsetLosses as (
	select	*
			, BiggestUpsetRank = row_number() over (partition by LoserEventWrestlerID order by RatingDiff desc)
	from UpsetMatches
)
select	top 10 
		[Rank] = row_number() over (order by BiggestUpsetLosses.LoserRating desc)
		, [Weight Class] = BiggestUpsetLosses.WeightClass
		, Round = BiggestUpsetLosses.RoundName
		, Winner = BiggestUpsetLosses.WinnerName
		, [Winner Team] = BiggestUpsetLosses.WinnerTeam
		, Loser = BiggestUpsetLosses.LoserName
		, [Loser Team] = BiggestUpsetLosses.LoserTeam
		, Event = BiggestUpsetLosses.EventName
from	BiggestUpsetLosses
where	BiggestUpsetRank = 1
order by
		BiggestUpsetLosses.LoserRating desc

-- Weight Class heat map

; with PercentileRatings as (
	select	distinct WeightClass
			, EventPercentile = percentile_cont(0.8) within group (order by Rating) over (partition by WeightClass)
	from	#EventRatings
)
select	[Weight Class] = EventRatings.WeightClass
		, Wrestlers = count(distinct EventRatings.EventWrestlerID)
		, [Top Rating] = cast(round(PercentileRatings.EventPercentile, 0) as int)
from	#EventRatings EventRatings
join	PercentileRatings
on		EventRatings.WeightClass = PercentileRatings.WeightClass
where	EventRatings.WeightClass in ('106', '113', '120', '126', '132', '138', '144', '150', '157', '165', '175', '190', '215', '285')
		and (
			coalesce(EventRatings.Division, 'hs') like 'hs%'
			or EventRatings.Division = 'jv'
			or EventRatings.Division like 'high school%'
		)
group by
		EventRatings.WeightClass
		, PercentileRatings.EventPercentile
order by
		PercentileRatings.EventPercentile desc




-- Iron Man (most matches)

select	top 10 Rank = rank() over (order by Matches desc)
		, Matches
		, Wrestler = wrestlername
		, Event = EventName
from	(
		select	EventWrestler.WrestlerName
				, weekevents.EventName
				, Matches = count(distinct EventMatch.ID)
				, MatchRank = rank() over (order by count(distinct EventMatch.ID) desc)
		from	#WeekEvents WeekEvents
		join	eventmatch
		on		WeekEvents.EventID = eventmatch.EventID
		join	EventWrestlerMatch
		on		eventmatch.ID = EventWrestlerMatch.EventMatchID
				and WeekEvents.EventSchoolName = EventWrestlerMatch.TeamName
		join	EventWrestler
		on		EventWrestlerMatch.EventWrestlerID = EventWrestler.ID
		where	WeekEvents.SchoolID = 71 -- Fort Mill
		group by
				EventWrestler.WrestlerName
				, weekevents.EventName
		) TopMatches
order by
		TopMatches.MatchRank
		, TopMatches.WrestlerName

-- Bonus Points

select	top 10 Wrestler = EventWrestler.WrestlerName
		, [Bonus Points] = sum(case 
			when eventmatch.wintype = 'f' or eventmatch.WinType like 'fall%' or EventMatch.WinType like '%for%' then 2
			when eventmatch.wintype = 'tf' or eventmatch.WinType like 'tf%' then 1.5
			when eventmatch.wintype = 'md' or eventmatch.WinType like 'maj%' then 1.5
			end)
from	#WeekEvents WeekEvents
join	eventmatch
on		WeekEvents.EventID = eventmatch.EventID
join	EventWrestlerMatch
on		eventmatch.ID = EventWrestlerMatch.EventMatchID
		and WeekEvents.EventSchoolName = EventWrestlerMatch.TeamName
		and EventWrestlerMatch.IsWinner = 1
join	EventWrestler
on		EventWrestlerMatch.EventWrestlerID = EventWrestler.ID
where	WeekEvents.SchoolID = 71 -- Fort Mill
group by
		EventWrestler.WrestlerName
order by
		[Bonus Points] desc


-- Revenge Match

; with FirstEvent as (
select	EventDate = min(EventDate)
		, StartRange = dateadd(day, -365, min(EventDate))
		, EndRange = dateadd(day, -7, min(EventDate))
from	#WeekEvents
)
select	[Weight Class] = EventMatch.WeightClass
		, Event = WeekEvents.EventName
		, Round = EventMatch.RoundName
		, Winner = EventWrestlerMatch.WrestlerName
		, Loser = OpponentMatch.WrestlerName
		, [Prev Event Date] = PrevLoss.EventDate
		, [Prev Event] = PrevLoss.EventName
		, DateRank
from	#WeekEvents WeekEvents
join	eventmatch
on		WeekEvents.EventID = eventmatch.EventID
join	EventWrestlerMatch
on		eventmatch.ID = EventWrestlerMatch.EventMatchID
		and EventWrestlerMatch.IsWinner = 1
		and WeekEvents.EventSchoolName = EventWrestlerMatch.TeamName
join	EventWrestlerMatch OpponentMatch
on		EventWrestlerMatch.EventMatchID = OpponentMatch.EventMatchID
		and EventWrestlerMatch.EventWrestlerID <> OpponentMatch.EventWrestlerID
		and OpponentMatch.IsWinner = 0
cross apply (
		select	EventDate = PrevMatches.EventDate
				, EventName = PrevMatches.EventName
				, DateRank
		from	(
				select	PrevEvent.EventDate
						, PrevEvent.EventName
						, PrevWrestlerMatch.IsWinner
						, OpponentMatch.WrestlerName
						, DateRank = row_number() over (partition by PrevWrestlerMatch.EventWrestlerID order by PrevEvent.EventDate desc, PrevEventMatch.Sort desc)
				from	EventWrestlerMatch PrevWrestlerMatch
				join	EventWrestlerMatch PrevOpponentMatch
				on		PrevWrestlerMatch.EventMatchID = PrevOpponentMatch.EventMatchID
						and PrevWrestlerMatch.EventWrestlerID <> PrevOpponentMatch.EventWrestlerID
				join	EventMatch PrevEventMatch
				on		PrevWrestlerMatch.EventMatchID = PrevEventMatch.ID
				join	Event PrevEvent
				on		PrevEventMatch.EventID = PrevEvent.ID
				join	FirstEvent
				on		PrevEvent.EventDate between FirstEvent.StartRange and FirstEvent.EndRange
				where	EventWrestlerMatch.EventWrestlerID = PrevWrestlerMatch.EventWrestlerID
						and PrevOpponentMatch.EventWrestlerID = OpponentMatch.EventWrestlerID
				) PrevMatches
		where	PrevMatches.IsWinner = 0
				and PrevMatches.DateRank = 1
		) PrevLoss
where	WeekEvents.SchoolID = 71 -- Fort Mill
		and (
			EventMatch.Division like 'hs%'
			or EventMatch.Division = 'jv'
			or EventMatch.Division like 'high school'
			)
order by
		WeekEvents.EventDate desc
		, EventMatch.WeightClass
		, EventMatch.Sort
