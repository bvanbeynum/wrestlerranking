select	minDate = min(Event.EventDate)
		, maxDate = max(Event.EventDate)
from 	Event
join 	EventMatch
on		Event.ID = EventMatch.EventID
where	Event.EventDate < getdate();