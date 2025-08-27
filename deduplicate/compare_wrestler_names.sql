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

WITH WrestlerTeamHistory AS (
    SELECT DISTINCT
        WrestlerID,
        TeamName
    FROM
        EventWrestlerMatch
)
SELECT
    w1.Name AS Wrestler1Name,
	w2.Name AS Wrestler2Name,
	dbo.LEVENSHTEIN(w1.Name, w2.Name) as LevenshteinDistance,
    wth1.TeamName
FROM
    WrestlerTeamHistory wth1
JOIN
    WrestlerTeamHistory wth2 ON wth1.TeamName = wth2.TeamName AND wth1.WrestlerID <> wth2.WrestlerID
JOIN Wrestler w1 ON wth1.WrestlerID = w1.ID
JOIN Wrestler w2 ON wth2.WrestlerID = w2.ID
WHERE dbo.LEVENSHTEIN(w1.Name, w2.Name) IN (1,2) OR SOUNDEX(w1.Name) = SOUNDEX(w2.Name)