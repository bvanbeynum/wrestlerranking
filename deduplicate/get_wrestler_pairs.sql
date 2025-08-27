WITH WrestlerTeamHistory AS (
    SELECT DISTINCT
        WrestlerID,
        TeamName
    FROM
        EventWrestlerMatch
)
SELECT
    wth1.WrestlerID AS Wrestler1ID,
    wth2.WrestlerID AS Wrestler2ID,
    wth1.TeamName
FROM
    WrestlerTeamHistory wth1
JOIN
    WrestlerTeamHistory wth2 ON wth1.TeamName = wth2.TeamName AND wth1.WrestlerID <> wth2.WrestlerID;
