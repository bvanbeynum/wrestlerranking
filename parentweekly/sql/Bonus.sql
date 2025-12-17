;with WrestlerBonus as (
select	EventRatings.Division
		, Rank = rank() over (
			partition by EventRatings.Division
			order by sum(case 
				when EventRatings.WinType = 'f' or EventRatings.WinType like '%fall%' or EventRatings.WinType like '%for%' then 2
				when EventRatings.WinType = '%tf%'then 1.5
				when EventRatings.WinType = '%md%' or EventRatings.WinType like 'maj%' then 1.5
				end) desc
			)
		, Wrestler = EventRatings.WrestlerName
		, [Bonus Points] = sum(case 
			when EventRatings.WinType = 'f' or EventRatings.WinType like '%fall%' or EventRatings.WinType like '%for%' then 2
			when EventRatings.WinType = '%tf%'then 1.5
			when EventRatings.WinType = '%md%' or EventRatings.WinType like 'maj%' then 1.5
			end)
from	#EventRatings EventRatings
where	EventRatings.SchoolID = 71 -- Fort Mill
		and EventRatings.IsWinner = 1
group by
		EventRatings.WrestlerName
		, EventRatings.Division
)
select	Division
		-- , [Rank]
		, Wrestler
		, [Bonus Points]
from	WrestlerBonus
where	Rank <= 5
order by
		Division desc
		, [Rank]
		, Wrestler;
