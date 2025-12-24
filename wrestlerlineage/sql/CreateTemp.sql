select	SchoolID = School.ID
		, School.SchoolName
		, EventWrestlerMatch.EventWrestlerID
		, EventWrestlerMatch.WrestlerName
		, EventWrestlerMatch.EventMatchID
		, EventWrestlerMatch.IsWinner
into	#AllMatches
from	School
join	EventSchool
on		School.ID = EventSchool.SchoolID
join	EventWrestlerMatch
on		EventSchool.EventSchoolName = EventWrestlerMatch.TeamName
join	EventWrestler
on		EventWrestlerMatch.EventWrestlerID = EventWrestler.ID
join	EventMatch
on		EventWrestlerMatch.EventMatchID = EventMatch.ID
join	Event
on		EventMatch.EventID = event.ID
where	School.Classification is not null
		and School.SchoolState = 'sc'
		and School.SchoolName <> 'fort mill'
		and (
			(
				getdate() > cast(cast(year(getdate()) as varchar(max)) + '-12-01' as date) -- If the current date is past december
				and event.EventDate >= cast(cast(year(getdate()) - 1 as varchar(max)) + '-9-01' as date) -- Use current year and last year
			)
			or event.EventDate >= cast(cast(year(getdate()) - 2 as varchar(max)) + '-9-01' as date) -- Use previous 2 years if in the new year
		)
group by
		School.ID
		, School.SchoolName
		, EventWrestlerMatch.EventWrestlerID
		, EventWrestlerMatch.WrestlerName
		, EventWrestlerMatch.EventMatchID
		, EventWrestlerMatch.IsWinner