
select	Position = row_number() over (order by WeightClass)
		, WeightClass
		, Alias = case when WeightClass = '285' then 'HWT' else WeightClass end
into	#WeightClass
from	(values ('106'), ('113'), ('120'), ('126'), ('132'), ('138'), ('144'), ('150'), ('157'), ('165'), ('175'), ('190'), ('215'), ('285')) as WeightClass (WeightClass)

select	EventWrestlerMatch.EventWrestlerID
		, EventWrestler.WrestlerName
		, EventWrestlerMatch.TeamName
		, EventWrestler.GlickoRating
		, EventWrestler.GlickoDeviation
into	#WrestlerTeamCTE
from	EventWrestlerMatch
join	EventWrestler
on		EventWrestlerMatch.EventWrestlerID = EventWrestler.ID
where	EventWrestlerMatch.TeamName in ('Boiling Springs', 'fort mill')
group by
		EventWrestlerMatch.EventWrestlerID
		, EventWrestler.WrestlerName
		, EventWrestlerMatch.TeamName
		, EventWrestler.GlickoRating
		, EventWrestler.GlickoDeviation

select	WrestlerTeamCTE.EventWrestlerID
		, EventMatch.Division
		, EventMatch.WeightClass
		, LastDate = Event.EventDate
		, LastDateRank = row_number() over (partition by WrestlerTeamCTE.EventWrestlerID order by Event.EventDate desc)
into	#WrestlerWeightCTE
from	#WrestlerTeamCTE WrestlerTeamCTE
join	EventWrestlerMatch
on		WrestlerTeamCTE.EventWrestlerID = EventWrestlerMatch.EventWrestlerID
		and WrestlerTeamCTE.TeamName = EventWrestlerMatch.TeamName
join	EventMatch
on		EventWrestlerMatch.EventMatchID = EventMatch.ID
join	Event
on		EventMatch.EventID = Event.ID
		and Event.EventDate > '11/1/2024'
group by
		WrestlerTeamCTE.EventWrestlerID
		, EventMatch.Division
		, EventMatch.WeightClass
		, event.EventDate

select	WrestlerTeamCTE.EventWrestlerID
		, WrestlerTeamCTE.WrestlerName
		, WrestlerTeamCTE.TeamName
		, WrestlerTeamCTE.GlickoRating
		, WrestlerTeamCTE.GlickoDeviation
		, WrestlerWeightCTE.Division
		, WrestlerWeightCTE.WeightClass
		, WrestlerWeightCTE.LastDate
into	#WrestlerCTE
from	#WrestlerTeamCTE WrestlerTeamCTE
join	#WrestlerWeightCTE WrestlerWeightCTE
on		WrestlerTeamCTE.EventWrestlerID = WrestlerWeightCTE.EventWrestlerID
		and WrestlerWeightCTE.LastDateRank = 1

select	WeightClass.WeightClass
		, WeightClass.[Position]
		, WrestlerCTE.TeamName
		, Pick = row_number() over (partition by WeightClass.WeightClass, WrestlerCTE.TeamName order by WrestlerCTE.GlickoRating desc)
		, WrestlerCTE.WrestlerName
		, WrestlerCTE.GlickoRating
		, WrestlerCTE.GlickoDeviation
		, WrestlerCTE.LastDate
		, WrestlerCTE.Division
into	#WrestlerRankCTE
from	#WeightClass WeightClass
left join
		#WrestlerCTE WrestlerCTE
on		WrestlerCTE.WeightClass in (WeightClass.WeightClass, WeightClass.Alias)


WITH WeightClassWithPosition AS (
	SELECT
		WeightClass,
		Position = row_number() OVER (ORDER BY WeightClass)
	FROM #WeightClass
),
BoilingSpringsLineup AS (
	SELECT
		BS.WeightClass,
		BS.WrestlerName,
		BS.GlickoRating
	FROM (
		SELECT
			wc.WeightClass,
			w.WrestlerName,
			w.GlickoRating,
			RowNumber = row_number() OVER (PARTITION BY wc.WeightClass ORDER BY w.GlickoRating DESC)
		FROM WeightClassWithPosition AS wc
		JOIN #WrestlerRankCTE AS w
		ON wc.WeightClass = w.WeightClass
		WHERE w.TeamName = 'Boiling Springs'
	) AS BS
	WHERE BS.RowNumber = 1
),
FortMillWrestlersWithPosition AS (
	SELECT
		w.WrestlerName,
		w.GlickoRating,
		wp.Position,
		w.WeightClass
	FROM #WrestlerRankCTE AS w
	JOIN WeightClassWithPosition AS wp
	ON w.WeightClass = wp.WeightClass
	WHERE w.TeamName = 'Fort Mill'
),
FortMillOptions AS (
	SELECT
		wcp.WeightClass AS CompetingWeightClass,
		fm.WrestlerName,
		fm.GlickoRating,
		fm.WeightClass AS OriginalWeightClass
	FROM WeightClassWithPosition AS wcp
	JOIN FortMillWrestlersWithPosition AS fm
	ON abs(fm.Position - wcp.Position) <= 1
),
MatchupPotential AS (
	SELECT
		FortMillOptions.CompetingWeightClass,
		FortMillOptions.WrestlerName AS FortMillWrestler,
		FortMillOptions.GlickoRating AS FortMillGlicko,
		BoilingSpringsLineup.WrestlerName AS BoilingSpringsWrestler,
		BoilingSpringsLineup.GlickoRating AS BoilingSpringsGlicko,
		IsWin = CASE
			WHEN FortMillOptions.GlickoRating > BoilingSpringsLineup.GlickoRating THEN 1
			ELSE 0
		END
	FROM FortMillOptions
	JOIN BoilingSpringsLineup
	ON FortMillOptions.CompetingWeightClass = BoilingSpringsLineup.WeightClass
),
FortMillWrestlerWinningOptions AS (
	SELECT
		FortMillWrestler,
		WinningSlots = count(*)
	FROM MatchupPotential
	WHERE IsWin = 1
	GROUP BY FortMillWrestler
),
RankedAllChoices AS (
	SELECT
		mp.CompetingWeightClass,
		mp.FortMillWrestler,
		mp.FortMillGlicko,
		mp.BoilingSpringsWrestler,
		mp.BoilingSpringsGlicko,
		mp.IsWin,
		WinningSlots = coalesce(w.WinningSlots, 0),
		ChoiceRank = row_number() OVER (
			PARTITION BY
				mp.CompetingWeightClass
			ORDER BY
				mp.IsWin DESC,
				coalesce(w.WinningSlots, 0) ASC,
				mp.FortMillGlicko DESC
		)
	FROM MatchupPotential AS mp
	LEFT JOIN FortMillWrestlerWinningOptions AS w
	ON mp.FortMillWrestler = w.FortMillWrestler
),
FinalLineup AS (
	-- Anchor member: Start with each possible choice for the first weight class
	SELECT
		CompetingWeightClass = rac.CompetingWeightClass,
		FortMillWrestler = rac.FortMillWrestler,
		BoilingSpringsWrestler = rac.BoilingSpringsWrestler,
		FortMillGlicko = rac.FortMillGlicko,
		BoilingSpringsGlicko = rac.BoilingSpringsGlicko,
		IsWin = rac.IsWin,
		UsedWrestlers = cast(',' + rac.FortMillWrestler + ',' as varchar(max)),
		Level = 1,
		TotalWins = rac.IsWin,
		LineupPath = CAST(rac.CompetingWeightClass AS VARCHAR(MAX)) + ':' + rac.FortMillWrestler -- To reconstruct the path later
	FROM RankedAllChoices AS rac
	WHERE rac.CompetingWeightClass = (SELECT min(WeightClass) FROM WeightClassWithPosition)

	UNION ALL

	-- Recursive member: Extend each partial lineup with all valid next choices
	SELECT
		CompetingWeightClass = next_rac.CompetingWeightClass,
		FortMillWrestler = next_rac.FortMillWrestler,
		BoilingSpringsWrestler = next_rac.BoilingSpringsWrestler,
		FortMillGlicko = next_rac.FortMillGlicko,
		BoilingSpringsGlicko = next_rac.BoilingSpringsGlicko,
		IsWin = next_rac.IsWin,
		UsedWrestlers = cast(prev_lineup.UsedWrestlers + next_rac.FortMillWrestler + ',' as varchar(max)),
		Level = prev_lineup.Level + 1,
		TotalWins = prev_lineup.TotalWins + next_rac.IsWin,
		LineupPath = prev_lineup.LineupPath + ',' + CAST(next_rac.CompetingWeightClass AS VARCHAR(MAX)) + ':' + next_rac.FortMillWrestler
	FROM FinalLineup AS prev_lineup
	JOIN RankedAllChoices AS next_rac
		ON next_rac.CompetingWeightClass = (
			SELECT
				WeightClass
			FROM WeightClassWithPosition
			WHERE Position = prev_lineup.Level + 1
		)
	WHERE charindex(',' + next_rac.FortMillWrestler + ',', prev_lineup.UsedWrestlers) = 0
)
SELECT
	WeightClass = split.WeightClass,
	FortMillWrestler = split.FortMillWrestler,
	BoilingSpringsWrestler = (
		SELECT bsl.WrestlerName
		FROM BoilingSpringsLineup AS bsl
		WHERE bsl.WeightClass = split.WeightClass
	),
	Outcome = CASE
		WHEN (
			SELECT mp.IsWin
			FROM MatchupPotential AS mp
			WHERE mp.CompetingWeightClass = split.WeightClass
			AND mp.FortMillWrestler = split.FortMillWrestler
		) = 1 THEN 'Fort Mill Wins'
		ELSE 'Boiling Springs Wins'
	END
FROM (
	SELECT TOP 1
		LineupPath,
		TotalWins
	FROM FinalLineup AS fl
	WHERE fl.Level = (SELECT max(Position) FROM WeightClassWithPosition) -- Ensure all weight classes are filled
	ORDER BY
		fl.TotalWins DESC,
		fl.LineupPath ASC -- Tie-breaker for consistent results
) AS BestLineup
CROSS APPLY (
	SELECT
		WeightClass = CAST(SUBSTRING(value, 1, CHARINDEX(':', value) - 1) AS INT),
		FortMillWrestler = SUBSTRING(value, CHARINDEX(':', value) + 1, LEN(value))
	FROM STRING_SPLIT(BestLineup.LineupPath, ',')
) AS split
ORDER BY
	split.WeightClass;
