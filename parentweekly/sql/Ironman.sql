select	Division
		-- , Rank
		, Wrestler = wrestlername
		, Matches
from	(
		select	Division = EventRatings.Division
				, Rank = rank() over (
					partition by EventRatings.Division 
					order by count(distinct EventRatings.MatchID) desc
					)
				, EventWrestler.WrestlerName
				, Matches = count(distinct EventRatings.MatchID)
		from	#EventRatings EventRatings
		join	EventWrestler
		on		EventRatings.EventWrestlerID = EventWrestler.ID
		where	EventRatings.SchoolID = 71 -- Fort Mill
		group by
				EventWrestler.WrestlerName
				, EventRatings.Division
		) TopMatches
where	Rank <= 5
order by
		Division desc
		, Rank
