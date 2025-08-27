WITH MatchCounts AS (
	SELECT
		WrestlerID,
		COUNT(*) as MatchCount
	FROM EventWrestlerMatch
	GROUP BY WrestlerID
),
PotentialDuplicates AS (
	WITH WrestlerTeamHistory AS (
		SELECT DISTINCT
			WrestlerID,
			TeamName
		FROM
			EventWrestlerMatch
	)
	SELECT
		w1.ID as Wrestler1ID,
		w2.ID as Wrestler2ID,
		w1.Name AS Wrestler1Name,
		w2.Name AS Wrestler2Name,
		w1.InsertDate AS Wrestler1InsertDate,
		w2.InsertDate AS Wrestler2InsertDate,
		dbo.LEVENSHTEIN(w1.Name, w2.Name) as LevenshteinDistance,
		wth1.TeamName
	FROM
		WrestlerTeamHistory wth1
	JOIN
		WrestlerTeamHistory wth2 ON wth1.TeamName = wth2.TeamName AND wth1.WrestlerID <> wth2.WrestlerID
	JOIN Wrestler w1 ON wth1.WrestlerID = w1.ID
	JOIN Wrestler w2 ON wth2.WrestlerID = w2.ID
	WHERE dbo.LEVENSHTEIN(w1.Name, w2.Name) IN (1,2) OR SOUNDEX(w1.Name) = SOUNDEX(w2.Name)
)
SELECT 
	CASE
		WHEN mc1.MatchCount > mc2.MatchCount THEN pd.Wrestler1ID
		WHEN mc2.MatchCount > mc1.MatchCount THEN pd.Wrestler2ID
		WHEN pd.Wrestler1InsertDate < pd.Wrestler2InsertDate THEN pd.Wrestler1ID
		ELSE pd.Wrestler2ID
	END as SurvivorWrestlerID,
	CASE
		WHEN mc1.MatchCount > mc2.MatchCount THEN pd.Wrestler1Name
		WHEN mc2.MatchCount > mc1.MatchCount THEN pd.Wrestler2Name
		WHEN pd.Wrestler1InsertDate < pd.Wrestler2InsertDate THEN pd.Wrestler1Name
		ELSE pd.Wrestler2Name
	END as SurvivorWrestlerName,
	CASE
		WHEN mc1.MatchCount > mc2.MatchCount THEN pd.Wrestler2ID
		WHEN mc2.MatchCount > mc1.MatchCount THEN pd.Wrestler1ID
		WHEN pd.Wrestler1InsertDate < pd.Wrestler2InsertDate THEN pd.Wrestler2ID
		ELSE pd.Wrestler1ID
	END as DuplicateWrestlerID,
	CASE
		WHEN mc1.MatchCount > mc2.MatchCount THEN pd.Wrestler2Name
		WHEN mc2.MatchCount > mc1.MatchCount THEN pd.Wrestler1Name
		WHEN pd.Wrestler1InsertDate < pd.Wrestler2InsertDate THEN pd.Wrestler2Name
		ELSE pd.Wrestler1Name
	END as DuplicateWrestlerName
FROM PotentialDuplicates pd
JOIN MatchCounts mc1 ON pd.Wrestler1ID = mc1.WrestlerID
JOIN MatchCounts mc2 ON pd.Wrestler2ID = mc2.WrestlerID