if object_id('tempdb..#wrestlers') is not null
	drop table #wrestlers

if object_id('tempdb..#MatchWrestlers') is not null
	drop table #MatchWrestlers

if object_id('tempdb..#WrestlerLineage') is not null
	drop table #WrestlerLineage

select	EventWrestlerID
		, WrestlerName
		, TeamName
into	#Wrestlers
from	(
		select	EventWrestlerID = EventWrestler.ID
				, EventWrestler.WrestlerName
				, TeamRank.TeamName
				, TeamRankFilter = row_number() over (partition by EventWrestler.ID order by Event.eventDate desc, EventWrestlerMatch.ID desc)
		from	TeamRank
		join	EventWrestlerMatch
		on		TeamRank.TeamName = EventWrestlerMatch.TeamName
		join	EventWrestler
		on		EventWrestlerMatch.EventWrestlerID = EventWrestler.ID
		join	EventMatch
		on		EventWrestlerMatch.EventMatchID = EventMatch.ID
		join	Event
		on		EventMatch.EventID = Event.ID
		where	Event.EventDate > getdate() - 720
		) WrestlerTeam
where	TeamRankFilter = 1

select	EventMatchID
		, EventWrestlerID
		, IsWinner
		, EventDate
		, WrestlerName
		, TeamName
into 	#MatchWrestlers
from	(
		select	EventWrestlerMatch.EventMatchID
				, EventWrestlerMatch.EventWrestlerID
				, EventWrestlerMatch.IsWinner
				, Event.EventDate
				, Wrestlers.WrestlerName
				, Wrestlers.TeamName
				, MatchCountFilter = count(EventWrestlerMatch.EventWrestlerID) over (partition by EventWrestlerMatch.EventMatchID)
		from	EventWrestlerMatch
		join	EventMatch
		on		EventWrestlerMatch.EventMatchID = EventMatch.ID
		join	Event
		on		EventMatch.EventID = Event.ID
		join	#Wrestlers Wrestlers
		on		EventWrestlerMatch.EventWrestlerID = Wrestlers.EventWrestlerID
		where	Event.EventDate > getdate() - 720
		) MatchWrestler
where	MatchCountFilter > 1

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
		, Wrestler2Team = OtherWrestler.TeamName
		, Packet = cast(
			'{' +
			'"wrestler1SqlId": ' + coalesce(cast(WrestlerMatches.EventWrestlerID as varchar(max)), 'null') + ',' +
			'"wrestler1Name": "' + WrestlerMatches.WrestlerName + '",' +
			'"wrestler1Team": "' + WrestlerMatches.TeamName + '",' +
			'"wrestler2SqlId": ' + coalesce(cast(OtherWrestler.EventWrestlerID as varchar(max)), 'null') + ',' +
			'"wrestler2Name": "' + OtherWrestler.WrestlerName + '",' +
			'"wrestler2Team": "' + OtherWrestler.TeamName + '",' +
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
		, Wrestler2Team = OtherWrestler.TeamName
		, Packet = EventWrestlerLineage.Packet +
			',{' +
			'"wrestler1SqlId": ' + coalesce(cast(WrestlerMatches.EventWrestlerID as varchar(max)), 'null') + ',' +
			'"wrestler1Name": "' + WrestlerMatches.WrestlerName + '",' +
			'"wrestler1Team": "' + WrestlerMatches.TeamName + '",' +
			'"wrestler2SqlId": ' + coalesce(cast(OtherWrestler.EventWrestlerID as varchar(max)), 'null') + ',' +
			'"wrestler2Name": "' + OtherWrestler.WrestlerName + '",' +
			'"wrestler2Team": "' + OtherWrestler.TeamName + '",' +
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

select	top 1000 *
from	EventWrestlerLineage


select	InitialFloID
		, Tier
		, Wrestler2FloID
		, FirstRecord = min(ID)
into	#DupRecords
from	EventWrestlerLineage
group by
		InitialFloID
		, Tier
		, Wrestler2FloID
having	count(0) > 1

select	EventWrestlerLineage.InitialFloID
		, EventWrestlerLineage.Wrestler2FloID
		, FirstTier = min(Tier)
		, LastTier = max(Tier)
into	#LineageTier
from	EventWrestlerLineage
where	EventWrestlerLineage.Wrestler2Team = 'fort mill'
group by
		EventWrestlerLineage.InitialFloID
		, EventWrestlerLineage.Wrestler2FloID

begin transaction

delete
from	EventWrestlerLineage
from	EventWrestlerLineage
join	#LineageTier LineageTier
on		EventWrestlerLineage.InitialFloID = LineageTier.InitialFloID
		and EventWrestlerLineage.Wrestler2FloID = LineageTier.Wrestler2FloID
		and EventWrestlerLineage.Tier > LineageTier.FirstTier

commit

select	EventWrestlerLineage.InitialEventWrestlerID
		, Tier = EventWrestlerLineage.Tier + 1
		, WrestlerMatches.IsWinner
		, Wrestler2ID = OtherWrestler.EventWrestlerID
		, Wrestler2Team = OtherWrestler.TeamName
		, Packet = EventWrestlerLineage.Packet +
			',{' +
			'"wrestler1SqlId": ' + coalesce(cast(WrestlerMatches.FloWrestlerID as varchar(max)), 'null') + ',' +
			'"wrestler1Name": "' + WrestlerMatches.WrestlerName + '",' +
			'"wrestler1Team": "' + WrestlerMatches.TeamName + '",' +
			'"wrestler2SqlId": ' + coalesce(cast(OtherWrestler.FloWrestlerID as varchar(max)), 'null') + ',' +
			'"wrestler2Name": "' + OtherWrestler.WrestlerName + '",' +
			'"wrestler2Team": "' + OtherWrestler.TeamName + '",' +
			'"isWinner": ' + case when WrestlerMatches.IsWinner = 1 then 'true' else 'false' end + ',' +
			'"sort": ' + cast(EventWrestlerLineage.Tier + 1 as varchar(max)) + ',' +
			'"eventDate": "' + replace(convert(varchar(max), WrestlerMatches.EventDate, 111), '/', '-') + '"' +
			'}'
from	EventWrestlerLineage
join	#MatchWrestlers WrestlerMatches
on		EventWrestlerLineage.EventWrestler2ID = WrestlerMatches.EventWrestlerID
		and EventWrestlerLineage.IsWinner = WrestlerMatches.IsWinner
join	#MatchWrestlers OtherWrestler
on		WrestlerMatches.EventMatchID = OtherWrestler.EventMatchID
		and WrestlerMatches.EventWrestlerID <> OtherWrestler.EventWrestlerID
where	EventWrestlerLineage.EventWrestler2Team <> 'fort mill'

select	max(Tier)
from	EventWrestlerLineage
where	EventWrestlerLineage.wrestler2Team <> 'fort mill'
