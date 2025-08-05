select	EventMatch.ID
		, EventMatch.EventID
		, EventMatch.Division
		, EventMatch.WeightClass
		, EventMatch.RoundName
		, EventMatch.WinType
from	EventMatch
join	EventWrestlerMatch
on		EventMatch.ID = EventWrestlerMatch.EventMatchID
where	EventMatch.Division not in ('MS', 'JV')
		and EventWrestlerMatch.IsWinner = 1;