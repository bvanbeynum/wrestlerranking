with WrestlerImprovement as (
select	Division = EventRatings.Division
		, Rank = rank() over (
			partition by EventRatings.Division
			order by EventRatings.Rating - PreviousRating.PreviousRating desc
			)
		, Wrestler = EventRatings.WrestlerName
		, [Key Wins] = replace(trim(string_agg(
			case when EventRatings.IsWinner = 1 then
				concat(
					'- Defeated '
					, OpponentMatch.WrestlerName
					, ' ('
					, OpponentMatch.TeamName
					, ')'
				)
			else ''
			end
			, '\n') within group (order by EventRatings.MatchID)), '\n\n', '\n')
		, Improvement = EventRatings.Rating - PreviousRating.PreviousRating
from	#EventRatings EventRatings
join	EventWrestlerMatch OpponentMatch
on		EventRatings.MatchID = OpponentMatch.EventMatchID
		and EventRatings.EventWrestlerID <> OpponentMatch.EventWrestlerID
cross apply (
		select	top 1
				PreviousRating = WrestlerPreviousRating.Rating
		from	WrestlerRating WrestlerPreviousRating
		where	WrestlerPreviousRating.EventWrestlerID = EventRatings.EventWrestlerID
				and WrestlerPreviousRating.PeriodEndDate < EventRatings.PeriodEndDate
		order by
				WrestlerPreviousRating.PeriodEndDate desc
		) PreviousRating
where	EventRatings.SchoolID = 71 -- Fort Mill
group by
		EventRatings.Division
		, EventRatings.WrestlerName
		, EventRatings.Rating
		, PreviousRating.PreviousRating
having	EventRatings.Rating - PreviousRating.PreviousRating > 10
)
select	Division
		-- , [Rank]
		, Wrestler
		, [Key Wins]
from	WrestlerImprovement
where	Rank <= 5
order by
		Division desc
		, [Rank]
