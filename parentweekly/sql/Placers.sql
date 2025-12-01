select	EventRatings.Division
		, Place = case
			when (EventRatings.RoundName like '1st Place%' or EventRatings.RoundName = 'Finals') and EventRatings.IsWinner = 1 then '1st Place'
			when (EventRatings.RoundName like '1st Place%' or EventRatings.RoundName = 'Finals') and EventRatings.IsWinner = 0 then '2nd Place'
			when EventRatings.RoundName like '3rd Place%' and EventRatings.IsWinner = 1 then '3rd Place'
			when EventRatings.RoundName like '3rd Place%' and EventRatings.IsWinner = 0 then '4th Place'
			when EventRatings.RoundName like '5th Place%' and EventRatings.IsWinner = 1 then '5th Place'
			when EventRatings.RoundName like '5th Place%' and EventRatings.IsWinner = 0 then '6th Place'
			when EventRatings.RoundName like '7th Place%' and EventRatings.IsWinner = 1 then '7th Place'
			when EventRatings.RoundName like '7th Place%' and EventRatings.IsWinner = 0 then '8th Place'
			end
		, Wrestler = EventWrestler.WrestlerName
from	#EventRatings EventRatings
join	EventWrestler
on		EventRatings.EventWrestlerID = EventWrestler.ID
where	EventRatings.SchoolID = 71 -- Fort Mill
		and (EventRatings.RoundName like '% place%' or EventRatings.RoundName = 'Finals')
order by
		EventRatings.Division
		, Place
		, Wrestler
