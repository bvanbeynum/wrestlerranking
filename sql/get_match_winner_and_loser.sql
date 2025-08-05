select	Winner.EventWrestlerID as WinnerID
		,Loser.EventWrestlerID as LoserID
		,ewm.EventMatchID
from	EventWrestlerMatch as ewm
join EventWrestlerMatch as Winner on
		ewm.EventMatchID = Winner.EventMatchID and Winner.IsWinner = 1
join EventWrestlerMatch as Loser on
		ewm.EventMatchID = Loser.EventMatchID and Loser.IsWinner = 0
