
if object_id('tempdb..#newwrestlers') is not null
	drop table #NewWrestlers;

if object_id('tempdb..#DupWrestlers') is not null
	drop table #DupWrestlers;

if object_id('tempdb..#PartialNameSameTeam') is not null
	drop table #PartialNameSameTeam;

select	WrestlerID = EventWrestler.ID
		, WrestlerName = EventWrestler.WrestlerName
		, FirstName = case when charindex(' ', EventWrestler.WrestlerName) > 0 then substring(EventWrestler.WrestlerName, 1, charindex(' ', EventWrestler.WrestlerName) - 1) else EventWrestler.WrestlerName end
		, FirstInitial = substring(EventWrestler.WrestlerName, 1, 1)
		, LastName = case when charindex(' ', EventWrestler.WrestlerName) > 0 then substring(EventWrestler.WrestlerName, charindex(' ', EventWrestler.WrestlerName) + 1, len(EventWrestler.WrestlerName)) else EventWrestler.WrestlerName end
		, LastInitial = case when charindex(' ', EventWrestler.WrestlerName) > 0 then substring(EventWrestler.WrestlerName, charindex(' ', EventWrestler.WrestlerName) + 1, 1) else EventWrestler.WrestlerName end
		, Teams = WrestlerTeams.Teams
into	#NewWrestlers
from	EventWrestler
cross apply (
		select	Teams = '|' + string_agg(TeamName, '|') + '|'
		from	(
				select	distinct EventWrestlerMatch.EventWrestlerID
						, EventWrestlerMatch.TeamName
				from	EventWrestlerMatch
				where	EventWrestler.ID = EventWrestlerMatch.EventWrestlerID
				) DistinctTeams
		) WrestlerTeams
where	EventWrestler.InsertDate > getdate() - 15

select	WrestlerID = DupWrestler.ID
		, WrestlerName = DupWrestler.WrestlerName
		, FirstName = case when charindex(' ', DupWrestler.WrestlerName) > 0 then substring(DupWrestler.WrestlerName, 1, charindex(' ', DupWrestler.WrestlerName) - 1) else DupWrestler.WrestlerName end
		, FirstInitial = substring(DupWrestler.WrestlerName, 1, 1)
		, LastName = case when charindex(' ', DupWrestler.WrestlerName) > 0 then substring(DupWrestler.WrestlerName, charindex(' ', DupWrestler.WrestlerName) + 1, len(DupWrestler.WrestlerName)) else DupWrestler.WrestlerName end
		, LastInitial = case when charindex(' ', DupWrestler.WrestlerName) > 0 then substring(DupWrestler.WrestlerName, charindex(' ', DupWrestler.WrestlerName) + 1, 1) else DupWrestler.WrestlerName end
		, Teams = WrestlerTeams.Teams
		, LastEvent = LastMatch.EventDate
into	#DupWrestlers
from	EventWrestler DupWrestler
cross apply (
		select	Teams = '|' + string_agg(TeamName, '|') + '|'
		from	(
				select	distinct EventWrestlerMatch.EventWrestlerID
						, EventWrestlerMatch.TeamName
				from	EventWrestlerMatch
				where	DupWrestler.ID = EventWrestlerMatch.EventWrestlerID
				) DistinctTeams
		) WrestlerTeams
cross apply (
		select	EventDate = max(cast(event.EventDate as date))
		from	EventWrestlerMatch LastMatch
		join	EventMatch
		on		LastMatch.EventMatchID = EventMatch.ID
		join	event
		on		EventMatch.EventID = event.ID
		where	DupWrestler.ID = LastMatch.EventWrestlerID
				and event.EventDate > getdate() - 545
		) LastMatch

create index idx_NewWrestlers_FirstNameLastInitial on #NewWrestlers (FirstName, LastInitial);
create index idx_NewWrestlers_LastNameFirstInitial on #NewWrestlers (LastName, FirstInitial);

create index idx_DupWrestlers_FirstNameLastInitial on #DupWrestlers (FirstName, LastInitial);
create index idx_DupWrestlers_LastNameFirstInitial on #DupWrestlers (LastName, FirstInitial);

select	distinct NewWrestlerID = NewWrestlers.WrestlerID
		, ExistingWrestlerID = DupWrestlers.WrestlerID
		, NewWrestler = NewWrestlers.WrestlerName
		, ExistingWrestler = DupWrestlers.WrestlerName
		, NewWrestlerTeam = NewWrestlers.Teams
		, LastEvent = DupWrestlers.LastEvent
into	#PartialNameSameTeam
from	#NewWrestlers NewWrestlers
join	#DupWrestlers DupWrestlers
on		(
			(NewWrestlers.FirstName = DupWrestlers.FirstName and NewWrestlers.LastInitial = DupWrestlers.LastInitial)
			or (NewWrestlers.LastName = DupWrestlers.LastName and NewWrestlers.FirstInitial = DupWrestlers.FirstInitial)
		)
		and NewWrestlers.WrestlerID <> DupWrestlers.WrestlerID

select	ExistingID = ExistingWrestlerID
		, NewID = NewWrestlerID
		, ExistingWrestler
		, NewWrestler
		, Team = replace(NewWrestlerTeam, '|', '')
		, LastEvent
from	#PartialNameSameTeam
order by
		NewWrestlerTeam
		, NewWrestler
		, ExistingWrestler

return;

if object_id('tempdb..#dedup') is not null
	drop table #dedup;

create table #dedup (
	SaveID int
	, DupID int
)

insert into #dedup (saveid, dupid) values(216934,294149);
insert into #dedup (saveid, dupid) values(219363,294170);

select	Dups = (select count(0) from #dedup)
		, Matches = (select count(distinct EventWrestlerMatch.ID) from EventWrestlerMatch join #dedup dedup on EventWrestlerMatch.EventWrestlerID = dedup.DupID)

if @@trancount = 0
	begin transaction
else
	throw 50000, 'Existing transaction', 16

update	EventWrestlerMatch
set		EventWrestlerID = dedup.SaveID
		, ModifiedDate = getdate()
from	EventWrestlerMatch
join	#dedup dedup
on		EventWrestlerMatch.EventWrestlerID = dedup.DupID;

delete
from	EventWrestler
from	EventWrestler
join	#dedup dedup
on		EventWrestler.ID = dedup.DupID;

update	EventWrestler
set		WrestlerName = TopWrestlerName.WrestlerName
		, ModifiedDate = getdate()
from	EventWrestler
cross apply (
		select	top 1 EventWrestlerMatch.WrestlerName
		from	EventWrestlerMatch
		join	EventMatch
		on		EventWrestlerMatch.EventMatchID = EventMatch.ID
		join	Event
		on		EventMatch.EventID = Event.ID
		where	EventWrestlerMatch.EventWrestlerID = EventWrestler.ID
		group by
				EventWrestlerMatch.WrestlerName
		order by
				count(distinct Event.ID) desc
				, min(Event.EventDate)
				, min(Event.ID)
		) TopWrestlerName
where	EventWrestler.ID in (
			select	distinct SaveID
			from	#dedup
		);

/*

commit;

rollback;

*/
