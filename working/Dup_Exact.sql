
if object_id('tempdb..#dups') is not null
	drop table #dups

if object_id('tempdb..#dedup') is not null
	drop table #dedup

select	GroupID
		, Priority
		, WrestlerID
		, WrestlerName
		, GlickoRating
		, WrestlerTeams.Teams
into	#Dups
from	(
		select	GroupID = rank() over (order by EventWrestler.WrestlerName, EventWrestlerMatch.TeamName)
				, Priority = row_number() over (partition by EventWrestler.WrestlerName, EventWrestlerMatch.TeamName order by EventWrestler.GlickoRating desc)
				, WrestlerID = EventWrestler.ID
				, EventWrestler.WrestlerName
				, EventWrestlerMatch.TeamName
				, EventWrestler.GlickoRating
				, Wrestlers = count(0) over (partition by EventWrestler.WrestlerName, EventWrestlerMatch.TeamName)
		from	EventWrestler
		join	EventWrestlerMatch
		on		EventWrestler.ID = EventWrestlerMatch.EventWrestlerID
		-- where	EventWrestler.WrestlerName = 'lucas van beynum'
		group by
				EventWrestler.ID
				, EventWrestler.WrestlerName
				, EventWrestlerMatch.TeamName
				, EventWrestler.GlickoRating
		) DupWrestlers
cross apply (
		select	Teams = string_agg(TeamName, ', ')
		from	(
				select	distinct EventWrestlerMatch.TeamName
				from	EventWrestlerMatch
				where	DupWrestlers.WrestlerID = EventWrestlerMatch.EventWrestlerID
				) WrestlerTeamsGroup
		) WrestlerTeams
where	Wrestlers > 1
order by
		GroupID
		, WrestlerID
		, WrestlerName
		, TeamName

select	SaveID = PrimaryWrestler.WrestlerID
		, DupID = Duplicate.WrestlerID
into	#dedup
from	#Dups PrimaryWrestler
join	#Dups Duplicate
on		PrimaryWrestler.GroupID = Duplicate.GroupID
		and Duplicate.Priority > 1
where	PrimaryWrestler.Priority = 1;

select	Dups = (select count(0) from #dedup)
		, Matches = (select count(distinct EventWrestlerMatch.ID) from EventWrestlerMatch join #dedup dedup on EventWrestlerMatch.EventWrestlerID = dedup.DupID)

select	*
from	#Dups
order by
		GroupID
		, Priority

return; 

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
set		ModifiedDate = getdate()
where	EventWrestler.ID in (
			select	distinct SaveID
			from	#dedup
		);

/*

commit;

rollback;

*/
