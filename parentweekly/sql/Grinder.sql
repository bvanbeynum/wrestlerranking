with ConsiWrestler as (
select	Division = case 
			when coalesce(EventMatch.Division, 'hs') like 'hs%' or EventMatch.Division like '%high school%' then 'Varsity'
			when EventMatch.Division = 'MS' or EventMatch.Division like '%middle%' then 'MS'
			when EventMatch.Division like '%girl%' then 'Girls'
			else 'JV' end
		, Rank = rank() over (
			partition by case 
				when coalesce(EventMatch.Division, 'hs') like 'hs%' or EventMatch.Division like '%high school%' then 'Varsity'
				when EventMatch.Division = 'MS' or EventMatch.Division like '%middle%' then 'MS'
				when EventMatch.Division like '%girl%' then 'Girls'
				else 'JV' end
			order by sum(case 
				when EventMatch.RoundName like '3rd Place%' then 1 
				when EventMatch.RoundName like '%th Place%' then 1 
				when EventMatch.RoundName like 'cons%' then 1 
				else 0 end) desc
			)
		, Wrestler = EventWrestler.WrestlerName
		, ConsiMatches = sum(case 
			when EventMatch.RoundName like '3rd Place%' then 1 
			when EventMatch.RoundName like '%th Place%' then 1 
			when EventMatch.RoundName like 'cons%' then 1 
			else 0 end)
from	#WeekEvents WeekEvents
join	EventMatch
on		WeekEvents.EventID = EventMatch.EventID
join	EventWrestlerMatch
on		EventMatch.ID = EventWrestlerMatch.EventMatchID
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
having	sum(case 
			when EventMatch.RoundName like '3rd Place%' then 1 
			when EventMatch.RoundName like '%th Place%' then 1 
			when EventMatch.RoundName like 'cons%' then 1 
			else 0 end) > 1
)
select	Division
		, [Rank]
		, Wrestler
		, [Consi Matches] = ConsiMatches
from	ConsiWrestler
where	Rank <= 10
order by
		case 
			when Division = 'Varsity' then 1
			when Division = 'JV' then 2
			when Division = 'Girls' then 3
			else 4 end
		, [Rank]
