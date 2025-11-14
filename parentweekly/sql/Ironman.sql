select	Division
		, Rank
		, Wrestler = wrestlername
		, Matches
from	(
		select	Division = case 
					when coalesce(EventMatch.Division, 'hs') like 'hs%' or EventMatch.Division like '%high school%' then 'Varsity'
					when EventMatch.Division = 'MS' or EventMatch.Division like '%middle%' then 'MS'
					when EventMatch.Division like '%girl%' then 'Girls'
					else 'JV' end
				, Rank = rank() over (
					partition by 
						case 
							when coalesce(EventMatch.Division, 'hs') like 'hs%' or EventMatch.Division like '%high school%' then 'Varsity'
							when EventMatch.Division = 'MS' or EventMatch.Division like '%middle%' then 'MS'
							when EventMatch.Division like '%girl%' then 'Girls'
							else 'JV' end
					order by count(distinct EventMatch.ID) desc
					)
				, EventWrestler.WrestlerName
				, Matches = count(distinct EventMatch.ID)
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
				, case 
					when coalesce(EventMatch.Division, 'hs') like 'hs%' or EventMatch.Division like '%high school%' then 'Varsity'
					when EventMatch.Division = 'MS' or EventMatch.Division like '%middle%' then 'MS'
					when EventMatch.Division like '%girl%' then 'Girls'
					else 'JV' end
		) TopMatches
where	Rank <= 5
order by
		case 
			when Division = 'Varsity' then 1
			when Division = 'JV' then 2
			when Division = 'Girls' then 3
			else 4 end
		, Rank
