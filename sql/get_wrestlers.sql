select	EventWrestler.ID
		,EventWrestler.WrestlerName
from	EventWrestler
join EventWrestlerMatch on
		EventWrestler.ID = EventWrestlerMatch.EventWrestlerID
group by
		EventWrestler.ID
		,EventWrestler.WrestlerName
having
		count(EventWrestlerMatch.ID) > 0;
