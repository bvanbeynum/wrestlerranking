
select	School.ID
		, School.SchoolName
		, School.CleanName
		, EventSchool.*
from	School
left join
		EventSchool
on		School.ID = EventSchool.SchoolID
where	School.SchoolName like 'james is%'





if object_id('tempdb..#AllTeams') is not null
	drop table #AllTeams;

if object_id('tempdb..#AllTeamGroup') is not null
	drop table #AllTeamGroup;

if object_id('tempdb..#TeamGroup') is not null
	drop table #TeamGroup;

-- ****************** Build the team groups *****************

-- All teams
select	TeamName
		, EventWrestlerID
into	#AllTeams
from	(
		select	EventWrestlerMatch.TeamName
				, EventWrestlerMatch.EventWrestlerID
				, Wrestlers = count(0) over (partition by EventWrestlerMatch.TeamName)
		from	EventWrestlerMatch
		join	EventWrestler
		on		EventWrestlerMatch.EventWrestlerID = EventWrestler.ID
		where	len(EventWrestlerMatch.TeamName) > 2
				and len(trim(EventWrestler.WrestlerName)) > 0
		group by
				EventWrestlerMatch.TeamName
				, EventWrestlerMatch.EventWrestlerID
		) WrestlerTeam
where	Wrestlers < 500
order by
		Wrestlers desc;

-- Get the baseline for the teams
select	TeamID = row_number() over (order by TeamName)
		, TeamName
		, Iteration = cast(1 as int)
into	#AllTeamGroup
from	#AllTeams
group by
		TeamName;

-- Iterate to get N levels deep of teams

declare @Iteration int = 1;

while @Iteration <= 4
begin
	insert	#AllTeamGroup (
			TeamID
			, TeamName
			, Iteration
			)
	select	AllTeam.TeamID
			, NextTeam.TeamName
			, AllTeam.Iteration + 1
	from	#AllTeamGroup AllTeam
	join	#AllTeams Initial
	on		AllTeam.TeamName = Initial.TeamName
	join	#AllTeams NextTeam
	on		Initial.EventWrestlerID = NextTeam.EventWrestlerID
			and Initial.TeamName <> NextTeam.TeamName
	left join
			#AllTeamGroup Excluded
	on		NextTeam.TeamName = Excluded.TeamName
			and AllTeam.TeamID = Excluded.TeamID
	where	Excluded.TeamName is null
			and AllTeam.Iteration = @Iteration
	group by
			AllTeam.TeamID
			, NextTeam.TeamName
			, AllTeam.Iteration;

	set @Iteration = @Iteration + 1;
end

-- Create the group ID
select	GroupID = min(TeamID)
		, TeamName
into	#TeamGroup
from	#AllTeamGroup
group by
		TeamName;

select	top 1000 *
from	#TeamGroup
where	TeamName like '%james is%'

select	TeamName
		, replace(TeamName, ' ', '')
from	#TeamGroup
where	GroupID IN
(
    5054,
    5052,
    5053,
    5055,
    5056
)
