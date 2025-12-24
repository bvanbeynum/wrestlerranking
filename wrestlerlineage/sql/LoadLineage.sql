if object_id('tempdb..#MatchWrestlers') is not null
	drop table #MatchWrestlers;

select	SchoolID = School.ID
		, School.SchoolName
		, EventWrestlerMatch.EventWrestlerID
		, EventWrestlerMatch.WrestlerName
		, EventWrestlerMatch.EventMatchID
		, EventWrestlerMatch.IsWinner
		, event.EventDate
into	#MatchWrestlers
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
		, event.EventDate

create index idx_MatchWrestlers_WrestlerID on #MatchWrestlers (EventWrestlerID);
create index idx_MatchWrestlers_MatchID on #MatchWrestlers (EventMatchID);

-- Initial load

-- truncate table EventWrestlerLineage;

insert	EventWrestlerLineage (
		InitialEventWrestlerID
		, Tier
		, IsWinner
		, EventWrestler2ID
		, EventWrestler2Team
		, Packet
		, Lineage
		)
select	InitialEventWrestlerID = WrestlerMatches.EventWrestlerID
		, Tier = 1
		, WrestlerMatches.IsWinner
		, Wrestler2FloID = OtherWrestler.EventWrestlerID
		, Wrestler2Team = OtherWrestler.SchoolName
		, Packet = cast(
			'{' +
			'"wrestler1SqlId": ' + coalesce(cast(WrestlerMatches.EventWrestlerID as varchar(max)), 'null') + ',' +
			'"wrestler1Name": "' + WrestlerMatches.WrestlerName + '",' +
			'"wrestler1Team": "' + WrestlerMatches.SchoolName + '",' +
			'"wrestler2SqlId": ' + coalesce(cast(OtherWrestler.EventWrestlerID as varchar(max)), 'null') + ',' +
			'"wrestler2Name": "' + OtherWrestler.WrestlerName + '",' +
			'"wrestler2Team": "' + OtherWrestler.SchoolName + '",' +
			'"isWinner": ' + case when WrestlerMatches.IsWinner = 1 then 'true' else 'false' end + ',' +
			'"sort": 1,' +
			'"eventDate": "' + replace(convert(varchar(max), WrestlerMatches.EventDate, 111), '/', '-') + '"' +
			'}'
			as varchar(max))
		, Lineage = '/' + cast(WrestlerMatches.EventWrestlerID as varchar(max))
from	#MatchWrestlers WrestlerMatches
join	#MatchWrestlers OtherWrestler
on		WrestlerMatches.EventMatchID = OtherWrestler.EventMatchID
		and WrestlerMatches.EventWrestlerID <> OtherWrestler.EventWrestlerID


-- Loop

declare @Iteration int;
set @Iteration = 1;

while @Iteration < 6
begin

insert	EventWrestlerLineage (
		InitialEventWrestlerID
		, Tier
		, IsWinner
		, EventWrestler2ID
		, EventWrestler2Team
		, Packet
		, Lineage
		)
select	EventWrestlerLineage.InitialEventWrestlerID
		, Tier = EventWrestlerLineage.Tier + 1
		, WrestlerMatches.IsWinner
		, Wrestler2ID = OtherWrestler.EventWrestlerID
		, Wrestler2Team = OtherWrestler.SchoolName
		, Packet = EventWrestlerLineage.Packet +
			',{' +
			'"wrestler1SqlId": ' + coalesce(cast(WrestlerMatches.EventWrestlerID as varchar(max)), 'null') + ',' +
			'"wrestler1Name": "' + WrestlerMatches.WrestlerName + '",' +
			'"wrestler1Team": "' + WrestlerMatches.SchoolName + '",' +
			'"wrestler2SqlId": ' + coalesce(cast(OtherWrestler.EventWrestlerID as varchar(max)), 'null') + ',' +
			'"wrestler2Name": "' + OtherWrestler.WrestlerName + '",' +
			'"wrestler2Team": "' + OtherWrestler.SchoolName + '",' +
			'"isWinner": ' + case when WrestlerMatches.IsWinner = 1 then 'true' else 'false' end + ',' +
			'"sort": ' + cast(EventWrestlerLineage.Tier + 1 as varchar(max)) + ',' +
			'"eventDate": "' + replace(convert(varchar(max), WrestlerMatches.EventDate, 111), '/', '-') + '"' +
			'}'
		, Lineage = EventWrestlerLineage.Lineage + '/' + cast(EventWrestlerLineage.EventWrestler2ID as varchar(max))
from	EventWrestlerLineage
join	#MatchWrestlers WrestlerMatches
on		EventWrestlerLineage.EventWrestler2ID = WrestlerMatches.EventWrestlerID
		and EventWrestlerLineage.IsWinner = WrestlerMatches.IsWinner
join	#MatchWrestlers OtherWrestler
on		WrestlerMatches.EventMatchID = OtherWrestler.EventMatchID
		and WrestlerMatches.EventWrestlerID <> OtherWrestler.EventWrestlerID
where	EventWrestlerLineage.EventWrestler2Team <> 'fort mill'
		and EventWrestlerLineage.Tier = @Iteration
		and EventWrestlerLineage.Lineage not like '%/' + cast(OtherWrestler.EventWrestlerID as varchar(max)) + '%'

set @Iteration = @Iteration + 1

raiserror('Iteration %i', 10, 1, @Iteration) with nowait;

end
