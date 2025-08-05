select	WinnerID = Winner.EventWrestlerID
		, LoserID = Loser.EventWrestlerID
		, ewm.EventMatchID
from	EventWrestlerMatch as ewm
join	EventWrestlerMatch as Winner
on		ewm.EventMatchID = Winner.EventMatchID
		and Winner.IsWinner = 1
join	EventWrestlerMatch as Loser
on		ewm.EventMatchID = Loser.EventMatchID
		and Loser.IsWinner = 0;