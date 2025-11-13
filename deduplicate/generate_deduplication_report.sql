/*
	Levenshtein Distance Function
	Calculates the minimum number of single-character edits (insertions, deletions or substitutions) required to change one word into another.
*/
CREATE FUNCTION dbo.MIN3 (@a INT, @b INT, @c INT)
RETURNS INT
AS
BEGIN
  IF @a < @b AND @a < @c RETURN @a
  IF @b < @a AND @b < @c RETURN @b
  RETURN @c
END
GO

CREATE FUNCTION [dbo].[LEVENSHTEIN]( @s NVARCHAR(MAX), @t NVARCHAR(MAX) )
RETURNS INT
AS
BEGIN
  DECLARE @d NVARCHAR(MAX), @ld INT
  DECLARE @n INT, @m INT, @i INT, @j INT, @s_i NCHAR, @t_j NCHAR, @cost INT
  SET @n = LEN(@s)
  SET @m = LEN(@t)
  SET @d = REPLICATE(NCHAR(0), (@n+1)*(@m+1))
  IF @n = 0
  BEGIN
    SET @ld = @m
    GOTO done
  END
  IF @m = 0
  BEGIN
    SET @ld = @n
    GOTO done
  END
  SET @i = 0
  WHILE @i <= @n
  BEGIN
    SET @d = STUFF(@d, @i+1, 1, NCHAR(@i))
    SET @i = @i+1
  END
  SET @j = 0
  WHILE @j <= @m
  BEGIN
    SET @d = STUFF(@d, @j*(@n+1)+1, 1, NCHAR(@j))
    SET @j = @j+1
  END
  SET @i = 1
  WHILE @i <= @n
  BEGIN
    SET @s_i = SUBSTRING(@s, @i, 1)
    SET @j = 1
    WHILE @j <= @m
    BEGIN
      SET @t_j = SUBSTRING(@t, @j, 1)
      IF @s_i = @t_j
        SET @cost = 0
      ELSE
        SET @cost = 1
      SET @d = STUFF(@d, @j*(@n+1)+@i+1, 1, NCHAR(dbo.MIN3(
        UNICODE(SUBSTRING(@d, @j*(@n+1)+@i, 1))+1,
        UNICODE(SUBSTRING(@d, (@j-1)*(@n+1)+@i+1, 1))+1,
        UNICODE(SUBSTRING(@d, (@j-1)*(@n+1)+@i, 1))+@cost)))
      SET @j = @j+1
    END
    SET @i = @i+1
  END
  SET @ld = UNICODE(SUBSTRING(@d, @m*(@n+1)+@n+1, 1))
  done:
  RETURN @ld
END
GO

if object_id('tempdb..#WrestlerTeamHistory') is not null drop table #WrestlerTeamHistory
if object_id('tempdb..#MatchCounts') is not null drop table #MatchCounts
if object_id('tempdb..#WrestlerInfo') is not null drop table #WrestlerInfo
if object_id('tempdb..#SoundexDuplicates') is not null drop table #SoundexDuplicates
if object_id('tempdb..#LevenshteinDuplicates') is not null drop table #LevenshteinDuplicates
if object_id('tempdb..#potentialDuplicates') is not null drop table #potentialDuplicates

-- Create #WrestlerTeamHistory temp table
SELECT DISTINCT
	EventWrestlerID,
	TeamName
INTO #WrestlerTeamHistory
FROM EventWrestlerMatch;

CREATE INDEX idxWrestlerTeamHistory ON #WrestlerTeamHistory(TeamName, EventWrestlerID);

-- Create #MatchCounts temp table
SELECT
	EventWrestlerID,
	COUNT(*) as MatchCount
INTO #MatchCounts
FROM EventWrestlerMatch
GROUP BY EventWrestlerID;

CREATE INDEX idxMatchCounts ON #MatchCounts(EventWrestlerID);

-- Step 1: Handle Soundex matches
-- Pre-calculate soundex for all wrestlers to optimize the join.
SELECT
	ID,
	WrestlerName,
	LEN(WrestlerName) as NameLength,
	InsertDate,
	SOUNDEX(WrestlerName) as SoundexValue
INTO #WrestlerInfo
FROM EventWrestler;

-- Index the temp table
CREATE INDEX idx_WrestlerInfo_Soundex ON #WrestlerInfo(SoundexValue, ID);
CREATE INDEX idx_WrestlerInfo_ID ON #WrestlerInfo(ID);


-- Find pairs with same soundex who have been on the same team
SELECT
	w1.ID as Wrestler1ID,
	w2.ID as Wrestler2ID,
	w1.WrestlerName AS Wrestler1Name,
	w2.WrestlerName AS Wrestler2Name,
	w1.InsertDate AS Wrestler1InsertDate,
	w2.InsertDate AS Wrestler2InsertDate,
	NULL as LevenshteinDistance,
	wth1.TeamName
INTO #SoundexDuplicates
FROM #WrestlerTeamHistory wth1
JOIN #WrestlerTeamHistory wth2 ON wth1.TeamName = wth2.TeamName AND wth1.EventWrestlerID < wth2.EventWrestlerID
JOIN #WrestlerInfo w1 ON wth1.EventWrestlerID = w1.ID
JOIN #WrestlerInfo w2 ON wth2.EventWrestlerID = w2.ID
WHERE w1.SoundexValue = w2.SoundexValue AND w1.WrestlerName <> w2.WrestlerName;


-- Step 2: Handle Levenshtein matches
-- This is still expensive, but we pre-filter by name length to reduce comparisons.
SELECT
	w1.ID as Wrestler1ID,
	w2.ID as Wrestler2ID,
	w1.WrestlerName AS Wrestler1Name,
	w2.WrestlerName AS Wrestler2Name,
	w1.InsertDate AS Wrestler1InsertDate,
	w2.InsertDate AS Wrestler2InsertDate,
	dbo.LEVENSHTEIN(w1.WrestlerName, w2.WrestlerName) as LevenshteinDistance,
	wth1.TeamName
INTO #LevenshteinDuplicates
FROM
	#WrestlerTeamHistory wth1
JOIN #WrestlerTeamHistory wth2 ON wth1.TeamName = wth2.TeamName AND wth1.EventWrestlerID < wth2.EventWrestlerID
JOIN #WrestlerInfo w1 ON wth1.EventWrestlerID = w1.ID
JOIN #WrestlerInfo w2 ON wth2.EventWrestlerID = w2.ID
WHERE ABS(w1.NameLength - w2.NameLength) <= 2
  AND dbo.LEVENSHTEIN(w1.WrestlerName, w2.WrestlerName) IN (1,2);


-- Step 3: Combine the results
SELECT *
INTO #PotentialDuplicates
FROM #SoundexDuplicates

UNION

SELECT *
FROM #LevenshteinDuplicates;

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
		WHEN pd.LevenshteinDistance IS NOT NULL AND pd.LevenshteinDistance <= 2 THEN 'Levenshtein'
		ELSE 'Soundex'
	END as DetectionMethod,
	-- The Levenshtein distance is used as the similarity score
	pd.LevenshteinDistance as SimilarityScore
FROM #PotentialDuplicates pd
JOIN #MatchCounts mc1 ON pd.Wrestler1ID = mc1.EventWrestlerID
JOIN #MatchCounts mc2 ON pd.Wrestler2ID = mc2.EventWrestlerID;

-- Clean up temp tables
DROP TABLE #WrestlerInfo;
DROP TABLE #SoundexDuplicates;
DROP TABLE #LevenshteinDuplicates;
DROP TABLE #PotentialDuplicates;
DROP TABLE #WrestlerTeamHistory;
DROP TABLE #MatchCounts;
