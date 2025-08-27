select
	WinnerID = Winner.EventWrestlerID
	, LoserID = Loser.EventWrestlerID
	, EventMatch.WinType
from
	EventWrestlerMatch
join EventWrestlerMatch as Winner
	on EventWrestlerMatch.EventMatchID = Winner.EventMatchID
		and Winner.IsWinner = 1
join EventWrestlerMatch as Loser
	on EventWrestlerMatch.EventMatchID = Loser.EventMatchID
		and Loser.IsWinner = 0
join EventMatch
	on EventWrestlerMatch.EventMatchID = EventMatch.ID
join Event
	on EventMatch.EventID = Event.ID
where
	Event.EventDate between ? and ?
	and EventMatch.WinType not in ('bye', 'for', 'nc');