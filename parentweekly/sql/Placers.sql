select	Division = case when EventMatch.Division is not null then EventMatch.Division
			when EventMatch.Division is null and WeekEvents.EventName like '% middle%' then 'MS'
			when EventMatch.Division is null and WeekEvents.EventName like '% ms %' then 'MS'
			when EventMatch.Division is null and WeekEvents.EventName like '%/ms %' then 'MS'
			when EventMatch.Division is null and WeekEvents.EventName like '% ms/%' then 'MS'
			when EventMatch.Division is null and WeekEvents.EventName like '% jv %' then 'JV'
			when EventMatch.Division is null and WeekEvents.EventName like '% jv/%' then 'JV'
			when EventMatch.Division is null and WeekEvents.EventName like '%/jv%' then 'JV'
			else 'HS' end
		, Place = case
			when (EventMatch.RoundName like '1st Place%' or EventMatch.RoundName = 'Finals') and EventWrestlerMatch.IsWinner = 1 then '1st Place'
			when (EventMatch.RoundName like '1st Place%' or EventMatch.RoundName = 'Finals') and EventWrestlerMatch.IsWinner = 0 then '2nd Place'
			when EventMatch.RoundName like '3rd Place%' and EventWrestlerMatch.IsWinner = 1 then '3rd Place'
			when EventMatch.RoundName like '3rd Place%' and EventWrestlerMatch.IsWinner = 0 then '4th Place'
			when EventMatch.RoundName like '5th Place%' and EventWrestlerMatch.IsWinner = 1 then '5th Place'
			when EventMatch.RoundName like '5th Place%' and EventWrestlerMatch.IsWinner = 0 then '6th Place'
			when EventMatch.RoundName like '7th Place%' and EventWrestlerMatch.IsWinner = 1 then '7th Place'
			when EventMatch.RoundName like '7th Place%' and EventWrestlerMatch.IsWinner = 0 then '8th Place'
			end
		, Wrestler = EventWrestler.WrestlerName
from	#WeekEvents WeekEvents
join	EventMatch
on		WeekEvents.EventID = EventMatch.EventID
join	EventWrestlerMatch
on		EventMatch.ID = EventWrestlerMatch.EventMatchID
		and WeekEvents.EventSchoolName = EventWrestlerMatch.TeamName
join	EventWrestler
on		EventWrestlerMatch.EventWrestlerID = EventWrestler.ID
where	WeekEvents.SchoolID = 71 -- Fort Mill
		and (EventMatch.RoundName like '% place%' or EventMatch.RoundName = 'Finals')
order by
		case when EventMatch.Division is not null then EventMatch.Division
			when EventMatch.Division is null and WeekEvents.EventName like '% middle%' then 'MS'
			when EventMatch.Division is null and WeekEvents.EventName like '% ms %' then 'MS'
			when EventMatch.Division is null and WeekEvents.EventName like '%/ms %' then 'MS'
			when EventMatch.Division is null and WeekEvents.EventName like '% ms/%' then 'MS'
			when EventMatch.Division is null and WeekEvents.EventName like '% jv %' then 'JV'
			when EventMatch.Division is null and WeekEvents.EventName like '% jv/%' then 'JV'
			when EventMatch.Division is null and WeekEvents.EventName like '%/jv%' then 'JV'
			else 'HS' end
		, Place
		, Wrestler
