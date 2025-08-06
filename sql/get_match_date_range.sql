select
	min(EventDate) as minDate,
	max(EventDate) as maxDate
from
	EventMatch;