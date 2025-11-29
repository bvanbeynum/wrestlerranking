;with MatchDetails as (
	select	WinnerMatch.EventID
			, WinnerMatch.EventName
			, WinnerMatch.MatchID
			, WinnerMatch.RoundName
			, WinnerMatch.WeightClass
			, WinnerName = WinnerMatch.WrestlerName
			, WinnerTeam = WinnerMatch.TeamName
			, WinnerRating = WinnerMatch.Rating
			, WinnerEventWrestlerID = WinnerMatch.EventWrestlerID
			, LoserName = LoserMatch.WrestlerName
			, LoserTeam = LoserMatch.TeamName
			, LoserRating = LoserRanking.Rating
			, LoserEventWrestlerID = LoserMatch.EventWrestlerID 
			, RatingDiff = LoserRanking.Rating - WinnerMatch.Rating
	from	#EventRatings WinnerMatch
	join	EventWrestlerMatch LoserMatch
	on		WinnerMatch.MatchID = LoserMatch.EventMatchID
			and LoserMatch.IsWinner = 0
	join	#EventRatings LoserRanking
	on		LoserMatch.EventWrestlerID = LoserRanking.EventWrestlerID
	cross apply (
			select	distinct School.SchoolName
			from	School
			join	EventSchool
			on		School.ID = EventSchool.SchoolID
			where	(EventSchool.EventSchoolName = WinnerMatch.TeamName or EventSchool.EventSchoolName = LoserMatch.TeamName)
					and School.Classification like '5a%'
			) SchoolFilter
	where	WinnerMatch.Division in ('hs', 'jv')
			and WinnerMatch.IsWinner = 1
),
UpsetMatches as (
	select * from MatchDetails where RatingDiff > 0
),
BiggestUpsetLosses as (
	select	*
			, BiggestUpsetRank = row_number() over (partition by LoserEventWrestlerID order by RatingDiff desc)
	from UpsetMatches
)
select	top 10 
		[Rank] = row_number() over (order by BiggestUpsetLosses.LoserRating desc)
		, [Weight Class] = BiggestUpsetLosses.WeightClass
		, Round = BiggestUpsetLosses.RoundName
		, Winner = BiggestUpsetLosses.WinnerName
		, [Winner Team] = BiggestUpsetLosses.WinnerTeam
		, Loser = BiggestUpsetLosses.LoserName
		, [Loser Team] = BiggestUpsetLosses.LoserTeam
		, Event = BiggestUpsetLosses.EventName
from	BiggestUpsetLosses
where	BiggestUpsetRank = 1
order by
		BiggestUpsetLosses.LoserRating desc;
