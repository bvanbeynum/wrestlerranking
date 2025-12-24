select	WrestlerID
		, WrestlerName
		, TeamName
		, IsWinner
		, EventDate
from	(
		select	WrestlerID = OtherWrestler.EventWrestlerID
				, OtherWrestler.WrestlerName
				, OtherWrestler.TeamName
				, EventWrestlerMatch.IsWinner
				, EventDate = replace(convert(varchar(max), Event.EventDate, 111), '/', '-')
				, OpponentVersion = row_number() over (partition by OtherWrestler.EventWrestlerID order by Event.EventDate desc)
		from	EventWrestlerMatch
		join	EventMatch
		on		EventWrestlerMatch.EventMatchID = EventMatch.ID
		join	Event
		on		EventMatch.EventID = Event.ID
		join	EventWrestlerMatch OtherWrestler
		on		EventWrestlerMatch.EventMatchID = OtherWrestler.EventMatchID
				and EventWrestlerMatch.EventWrestlerID <> OtherWrestler.EventWrestlerID
		where	EventWrestlerMatch.EventWrestlerID = :WrestlerID
				and (EventWrestlerMatch.IsWinner = :IsWinner or :IsWinner is null)
				and Event.EventDate > getdate() - 720
		group by
				EventWrestlerMatch.EventWrestlerID
				, EventWrestlerMatch.WrestlerName
				, EventWrestlerMatch.TeamName
				, OtherWrestler.EventWrestlerID
				, OtherWrestler.WrestlerName
				, OtherWrestler.TeamName
				, EventWrestlerMatch.IsWinner
				, Event.EventDate
		) WrestlerOpponents
where	WrestlerOpponents.OpponentVersion = 1
order by
		case when TeamName like '%fort mill%' then 1 else 2 end
		, EventDate desc;