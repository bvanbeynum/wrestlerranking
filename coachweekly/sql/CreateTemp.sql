set nocount on;

if object_id('tempdb..#WeekEvents') is not null drop table #WeekEvents;
if object_id('tempdb..#EventRatings') is not null drop table #EventRatings;

create table #WeekEvents (
	EventID int
	, EventDate date
	, EventName varchar(255)
	, SchoolID int
	, SchoolName varchar(255)
	, EventSchoolName varchar(255)
);

create table #EventRatings (
	EventID int
	, EventDate date
	, EventName varchar(255)
	, SchoolID int
	, MatchID int
	, Division varchar(255)
	, WeightClass varchar(255)
	, RoundName varchar(255)
	, WinType varchar(255)
	, WrestlerName varchar(255)
	, TeamName varchar(255)
	, IsWinner bit
	, EventWrestlerID int
	, Rating int
	, PeriodEndDate date
);

set nocount off;
