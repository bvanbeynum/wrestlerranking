select	WrestlerID = EventWrestlerMatch.EventWrestlerID
		, EventWrestler.WrestlerName
		, TeamName = School.SchoolName
from	EventSchool
join	School
on		EventSchool.SchoolID = School.ID
join	EventWrestlerMatch
on		EventSchool.EventSchoolName = EventWrestlerMatch.TeamName
join	EventWrestler
on		EventWrestlerMatch.EventWrestlerID = EventWrestler.ID
join	eventmatch
on		EventWrestlerMatch.EventMatchID = EventMatch.ID
join	Event
on		EventMatch.EventID = Event.ID
where	EventSchool.SchoolID = :SchoolID
		and (
			(
				getdate() > cast(cast(year(getdate()) as varchar(max)) + '-12-01' as date) -- If the current date is past december
				and event.EventDate >= cast(cast(year(getdate()) as varchar(max)) + '-9-01' as date) -- Use current year and last year
			)
			or event.EventDate >= cast(cast(year(getdate()) - 1 as varchar(max)) + '-9-01' as date) -- Use previous 2 years if in the new year
		)
group by
		EventWrestlerMatch.EventWrestlerID
		, EventWrestler.WrestlerName
		, School.SchoolName
		, EventWrestler.GlickoRating
		, EventWrestler.JVRating
		, EventWrestler.MSRating
		, EventWrestler.GirlsRating
order by
		coalesce(EventWrestler.GlickoRating, EventWrestler.JVRating, EventWrestler.MSRating, EventWrestler.GirlsRating, 0) desc
		, max(Event.EventDate) desc