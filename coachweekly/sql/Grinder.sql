with ConsiWrestler as (
select	Division = EventRatings.Division
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
		, EventRatings.Division
having	sum(case 
			when EventRatings.RoundName like '3rd Place%' then 1 
			when EventRatings.RoundName like '%th Place%' then 1 
			when EventRatings.RoundName like 'cons%' then 1 
			else 0 end) > 1
)
select	Division
		, [Rank]
		, Wrestler
		, [Consi Matches] = ConsiMatches
from	ConsiWrestler
where	Rank <= 10
order by
		Division desc
		, [Rank]
