
select	distinct WrestlerID = EventWrestler.ID
		, EventWrestler.WrestlerName
		, EventWrestlerMatch.WrestlerName
		, EventWrestlerMatch.TeamName
from	EventWrestler
join	EventWrestlerMatch
on		EventWrestler.ID = EventWrestlerMatch.EventWrestlerID
where	EventWrestler.wrestlername like 't% ernst'
		and EventWrestlerMatch.TeamName = 'fort mill'
order by
		EventWrestler.wrestlername
		, EventWrestlerMatch.WrestlerName
		, EventWrestlerMatch.TeamName


select	distinct EventWrestler.ID
		, EventWrestler.WrestlerName
		, EventWrestlerMatch.WrestlerName
		, EventWrestlerMatch.TeamName
from	EventWrestler
left join
		EventWrestlerMatch
on		EventWrestler.ID = EventWrestlerMatch.EventWrestlerID
where	EventWrestler.id in (152097, 152096)
order by
		EventWrestler.id
		, EventWrestlerMatch.WrestlerName
		, EventWrestlerMatch.TeamName;

return;

if @@trancount = 0
	begin transaction
else
	throw 50000, 'Existing transaction', 16

if object_id('tempdb..#dedup') is not null
	drop table #dedup;

select	SaveID = 152096
		, DupID = EventWrestler.ID
into	#dedup
from	EventWrestler
where	EventWrestler.ID in (152097)
order by
		EventWrestler.ID;

select	Dups = (select count(0) from #dedup)
		, Matches = (select count(distinct EventWrestlerMatch.ID) from EventWrestlerMatch join #dedup dedup on EventWrestlerMatch.EventWrestlerID = dedup.DupID)

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
