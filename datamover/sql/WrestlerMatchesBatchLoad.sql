select	EventWrestlerID = EventWrestlerMatch.EventWrestlerID
		, EventID = event.ID
		, EventName = Event.EventName
		, EventDate = Event.EventDate
		, TeamName = EventWrestlerMatch.TeamName
		, EventState = Event.EventState
		, Division = EventMatch.Division
		, WeightClass = EventMatch.WeightClass
		, MatchRound = EventMatch.RoundName
		, MatchSort = EventMatch.Sort
		, OpponentName = Opponent.WrestlerName
		, OpponentTeamName = OpponentMatch.TeamName
		, OpponentID = OpponentMatch.EventWrestlerID
		, IsWinner = EventWrestlerMatch.IsWinner
		, WinType = EventMatch.WinType
from	EventWrestlerMatch
join	#WrestlerBatch Batch
on		EventWrestlerMatch.EventWrestlerID = Batch.WrestlerID
join	EventMatch
on		EventWrestlerMatch.EventMatchID = EventMatch.ID
join	Event
on
		EventMatch.EventID = Event.ID
left join
		EventWrestlerMatch OpponentMatch
on
		EventWrestlerMatch.EventMatchID = OpponentMatch.EventMatchID
		and OpponentMatch.EventWrestlerID <> EventWrestlerMatch.EventWrestlerID
left join
		EventWrestler Opponent
on		OpponentMatch.EventWrestlerID = Opponent.ID
order by	
		Event.EventDate desc
		, MatchSort
