select	Division = case 
			when coalesce(EventMatch.Division, 'hs') like 'hs%' or EventMatch.Division like '%high school%' then 'Varsity'
			when EventMatch.Division = 'MS' or EventMatch.Division like '%middle%' then 'MS'
			when EventMatch.Division like '%girl%' then 'Girls'
			else 'JV' end
		, Place = case
			when EventMatch.RoundName like '1st Place%' and EventWrestlerMatch.IsWinner = 1 then '1st Place'
			when EventMatch.RoundName like '1st Place%' and EventWrestlerMatch.IsWinner = 0 then '2nd Place'
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
		and EventMatch.RoundName like '% place%'
order by
		case 
			when coalesce(EventMatch.Division, 'hs') like 'hs%' or EventMatch.Division like '%high school%' then 1
			when EventMatch.Division = 'MS' or EventMatch.Division like '%middle%' then 4
			when EventMatch.Division like '%girl%' then 3
			else 2 end
		, Place
		, Wrestler
