with OpponentSkill as (
select	Division = EventRatings.Division
		, Wrestler = EventWrestler.WrestlerName
		, IsWin = case when EventRatings.IsWinner = 1 then 'Beat ' else 'Lost to ' end
		, Opponent = OpponentMatch.WrestlerName
		, OpponentTeam = OpponentMatch.TeamName
		, OpponentRating = OpponentRating.Rating
		, OpponentRank = rank() over (
			partition by EventWrestler.WrestlerName
			order by OpponentRating.Rating desc
			)
		, MaxRating = max(OpponentRating.Rating) over (partition by EventWrestler.id)
		, OverRated = case when OpponentRating.Rating > percentile_cont(0.8) within group (order by OpponentRating.Rating) over (partition by EventWrestler.id) then 1 else 0 end
from	#EventRatings EventRatings
join	EventWrestlerMatch OpponentMatch
on		EventRatings.MatchID = OpponentMatch.EventMatchID
		and EventRatings.EventWrestlerID <> OpponentMatch.EventWrestlerID
join	WrestlerRating OpponentRating
on		OpponentMatch.EventWrestlerID = OpponentRating.EventWrestlerID
		and EventRatings.EventDate between dateadd(day, -6, OpponentRating.PeriodEndDate) and OpponentRating.PeriodEndDate
join	EventWrestler
on		EventRatings.EventWrestlerID = EventWrestler.ID
where	EventRatings.SchoolID = 71 -- Fort Mill
)
select	Division
		, Rank
		, Wrestler
		, Opponents
from	(
		select	Division
				, Rank = rank() over (partition by Division order by sum(OverRated) desc, max(MaxRating) desc)
				, Wrestler
				, Opponents = string_agg('* ' + IsWin + ' ' + Opponent + ' (' + OpponentTeam + ')', '\n') within group (order by OpponentRating desc)
		from	OpponentSkill
		where	OpponentRank <= 2
		group by
				Division
				, Wrestler
		) as RankedOpponents
where	Rank <= 5
order by
		Division desc
		, Rank
