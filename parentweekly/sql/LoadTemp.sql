set nocount on;

insert	#WeekEvents (
		EventID
		, EventDate
		, EventName
		, SchoolID
		, SchoolName
		, EventSchoolName
		)
select	EventID = Event.ID
		, Event.EventDate
		, Event.EventName
		, SchoolFilter.SchoolID
		, SchoolFilter.SchoolName
		, SchoolFilter.EventSchoolName
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
where	event.EventDate between dateadd(d, -6, :loadDate) and :loadDate
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

insert	#EventRatings (
		EventID
		, EventDate
		, EventName
		, SchoolID
		, MatchID
		, Division
		, WeightClass
		, RoundName
		, WinType
		, WrestlerName
		, TeamName
		, IsWinner
		, EventWrestlerID
		, Rating
		, PeriodEndDate
		)
select	EventID
		, EventDate
		, EventName
		, SchoolID
		, MatchID
		, Division
		, WeightClass
		, RoundName
		, WinType
		, WrestlerName
		, TeamName
		, IsWinner
		, EventWrestlerID
		, Rating
		, PeriodEndDate
from	(
		select	distinct WeekEvents.EventID
				, WeekEvents.EventDate
				, WeekEvents.EventName
				, WeekEvents.SchoolID
				, MatchID = EventMatch.ID
				, Division = case 
					when EventMatch.Division like 'jv%' or EventMatch.Division like '%junior%' then 'JV'
					when EventMatch.division like 'hs%'  then 'HS'
					when EventMatch.Division like '%varsity%'  then 'HS'
					when EventMatch.Division like '%high%' then 'HS'
					when EventMatch.division like '%ms%' or EventMatch.Division like '%middle%' then 'MS'
					when EventMatch.Division in ('10U', '8U', '12U', '14U') then 'MS'
					when EventMatch.Division like '%girl%' then 'Girls'
					when EventMatch.division in ('tot', 'bantam', 'midget', '6U', 'elem') then 'Youth'
					when nullif(EventMatch.Division, '') is not null then EventMatch.Division
					when EventMatch.Division is null and WeekEvents.EventName like '% middle%' then 'MS'
					when EventMatch.Division is null and WeekEvents.EventName like '% ms %' then 'MS'
					when EventMatch.Division is null and WeekEvents.EventName like '%/ms %' then 'MS'
					when EventMatch.Division is null and WeekEvents.EventName like '% ms/%' then 'MS'
					when EventMatch.Division is null and WeekEvents.EventName like '% jv %' then 'JV'
					when EventMatch.Division is null and WeekEvents.EventName like '% jv/%' then 'JV'
					when EventMatch.Division is null and WeekEvents.EventName like '%/jv%' then 'JV'
					when EventMatch.Division is null and WeekEvents.EventName like '% jv%' then 'JV'
					when EventMatch.Division is null and WeekEvents.EventName like 'jv %' then 'JV'
					when EventMatch.Division is null and WeekEvents.EventName like '%girl%' then 'Girls'
					when EventMatch.Division is null and WeekEvents.EventName like '%women%' then 'Girls'
					when EventMatch.Division is null and WeekEvents.EventName like '%woman%' then 'Girls'
					else 'HS'
					end
				, EventMatch.WeightClass
				, EventMatch.RoundName
				, EventMatch.WinType
				, WrestlerName = EventWrestler.WrestlerName
				, EventWrestlerMatch.TeamName
				, EventWrestlerMatch.IsWinner
				, WrestlerRating.EventWrestlerID
				, WrestlerRating.Rating
				, WrestlerRating.PeriodEndDate
		from	#WeekEvents WeekEvents
		join	EventMatch
		on		WeekEvents.EventID = EventMatch.EventID
		join	EventWrestlerMatch
		on		EventMatch.ID = EventWrestlerMatch.EventMatchID
				and WeekEvents.EventSchoolName = EventWrestlerMatch.TeamName
		join	EventWrestler
		on		EventWrestlerMatch.EventWrestlerID = EventWrestler.ID
		left join
				WrestlerRating
		on		EventWrestlerMatch.EventWrestlerID = WrestlerRating.EventWrestlerID
				and WeekEvents.EventDate between dateadd(day, -6, WrestlerRating.PeriodEndDate) and WrestlerRating.PeriodEndDate
		) EventData

set nocount off;