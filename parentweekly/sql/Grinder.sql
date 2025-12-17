with ConsiWrestler as (
select	EventRatings.Division
		, Rank = rank() over (
			partition by EventRatings.Division
			order by sum(case 
				when EventRatings.RoundName like '3rd Place%' then 1 
				when EventRatings.RoundName like '%th Place%' then 1 
				when EventRatings.RoundName like 'cons%' then 1 
				else 0 end) desc
			)
		, Wrestler = EventWrestler.WrestlerName
		, ConsiMatches = sum(case 
			when EventRatings.RoundName like '3rd Place%' then 1 
			when EventRatings.RoundName like '%th Place%' then 1 
			when EventRatings.RoundName like 'cons%' then 1 
			else 0 end)
from	#EventRatings EventRatings
join	EventWrestler
on		EventRatings.EventWrestlerID = EventWrestler.ID
where	EventRatings.SchoolID = 71 -- Fort Mill
group by
		EventWrestler.WrestlerName
		, EventRatings.division
having	sum(case 
			when EventRatings.RoundName like '3rd Place%' then 1 
			when EventRatings.RoundName like '%th Place%' then 1 
			when EventRatings.RoundName like 'cons%' then 1 
			else 0 end) > 1
)
select	Division
		-- , [Rank]
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
