-- Create temporary tables
CREATE TABLE #Wrestler (
	ID INT,
	Name NVARCHAR(255),
	InsertDate DATETIME
);

CREATE TABLE #Team (
	ID INT,
	Name NVARCHAR(255)
);

CREATE TABLE #EventWrestlerMatch (
	WrestlerID INT,
	TeamName NVARCHAR(255)
);

-- Insert sample data
INSERT INTO #Wrestler (ID, Name, InsertDate) VALUES
(1, 'Jon Moxley', '2022-01-01'),
(2, 'Jon Moxly', '2022-01-02'),
(3, 'Bryan Danielson', '2022-01-03'),
(4, 'Brian Danielson', '2022-01-04'),
(5, 'Chris Jericho', '2022-01-05'),
(6, 'Chris Jerico', '2022-01-06');

INSERT INTO #Team (ID, Name) VALUES
(1, 'Blackpool Combat Club'),
(2, 'Jericho Appreciation Society');

INSERT INTO #EventWrestlerMatch (WrestlerID, TeamName) VALUES
(1, 'Blackpool Combat Club'),
(2, 'Blackpool Combat Club'),
(3, 'Blackpool Combat Club'),
(4, 'Blackpool Combat Club'),
(5, 'Jericho Appreciation Society'),
(6, 'Jericho Appreciation Society');

-- Execute the deduplication logic using the temporary tables
-- CTE to get the distinct team history for each wrestler
WITH WrestlerTeamHistory AS (
	SELECT DISTINCT
		WrestlerID,
		TeamName
	FROM
		#EventWrestlerMatch
),
-- CTE to get the match count for each wrestler
MatchCounts AS (
	SELECT
		WrestlerID,
		COUNT(*) as MatchCount
	FROM #EventWrestlerMatch
	GROUP BY WrestlerID
),
-- CTE to find potential duplicate wrestlers based on Levenshtein distance or Soundex
PotentialDuplicates AS (
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
	JOIN #Wrestler w1 ON wth1.WrestlerID = w1.ID
	JOIN #Wrestler w2 ON wth2.WrestlerID = w2.ID
	WHERE dbo.LEVENSHTEIN(w1.Name, w2.Name) IN (1,2) OR SOUNDEX(w1.Name) = SOUNDEX(w2.Name)
)
-- Final SELECT statement to generate the deduplication report
SELECT 
	-- Determine the survivor and duplicate wrestler IDs and names based on match count and insert date
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
	END as DuplicateWrestlerName,
	pd.TeamName,
	-- Determine the detection method (Levenshtein or Soundex)
	CASE
		WHEN pd.LevenshteinDistance <= 2 THEN 'Levenshtein'
		ELSE 'Soundex'
	END as DetectionMethod,
	-- The Levenshtein distance is used as the similarity score
	pd.LevenshteinDistance as SimilarityScore
INTO #Result
FROM PotentialDuplicates pd
JOIN MatchCounts mc1 ON pd.Wrestler1ID = mc1.WrestlerID
JOIN MatchCounts mc2 ON pd.Wrestler2ID = mc2.WrestlerID

-- Print the results
SELECT * FROM #Result;

-- Drop the temporary tables
DROP TABLE #Result;
DROP TABLE #Wrestler;
DROP TABLE #Team;
DROP TABLE #EventWrestlerMatch;
