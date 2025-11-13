
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

return;

if @@trancount = 0
	begin transaction
else
	throw 50000, 'Existing transaction', 16

declare @SaveID int = 142500;
declare @DupID int = 142735;

select	'Matches: ' + cast(count(0) as varchar(max))
from	EventWrestlerMatch
where	EventWrestlerMatch.EventWrestlerID = @DupID;

update	EventWrestlerMatch
set		EventWrestlerID = @SaveID
		, ModifiedDate = getdate()
from	EventWrestlerMatch
where	EventWrestlerMatch.EventWrestlerID = @DupID;

select	'Match update: ' + cast(@@rowcount as varchar(max));

select	'Wrestlers delete: ' + cast(count(0) as varchar(max))
from	EventWrestler
where	EventWrestler.ID = @DupID;

delete
from	EventWrestler
from	EventWrestler
where	EventWrestler.ID = @DupID;

select	'Wrestler deleted: ' + cast(@@rowcount as varchar(max));

update	EventWrestler
set		ModifiedDate = getdate()
where	EventWrestler.ID = @SaveID;

/*

commit;

rollback;

*/
