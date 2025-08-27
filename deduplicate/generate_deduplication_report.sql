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

-- CTE to get the distinct team history for each wrestler
WITH WrestlerTeamHistory AS (
	SELECT DISTINCT
		WrestlerID,
		TeamName
	FROM
		EventWrestlerMatch
),
-- CTE to get the match count for each wrestler
MatchCounts AS (
	SELECT
		WrestlerID,
		COUNT(*) as MatchCount
	FROM EventWrestlerMatch
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
	JOIN Wrestler w1 ON wth1.WrestlerID = w1.ID
	JOIN Wrestler w2 ON wth2.WrestlerID = w2.ID
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
FROM PotentialDuplicates pd
JOIN MatchCounts mc1 ON pd.Wrestler1ID = mc1.WrestlerID
JOIN MatchCounts mc2 ON pd.Wrestler2ID = mc2.WrestlerID