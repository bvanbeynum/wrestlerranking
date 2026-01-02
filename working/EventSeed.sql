
/*

getSeed = async bracket => {
	const response = await fetch(`https://prod-web-api.flowrestling.org/api/event-hub/14463842/brackets/${bracket.bracketId}`);
	const data = await response.json();
	const matches = Object.keys(data.data.matches).map(k => data.data.matches[k]);
	let wrestlers = matches.filter(m => m.bottomParticipant && m.bottomParticipant.seed).map(m => ({name: m.bottomParticipant.name, team: m.bottomParticipant.teamName, seed: m.bottomParticipant.seed}));

	wrestlers = wrestlers.concat(matches.filter(m => m.topParticipant && m.topParticipant.seed).map(m => ({name: m.topParticipant.name, team: m.topParticipant.teamName, seed: m.topParticipant.seed})));

	const sql = [...new Set(wrestlers.map(w => w.name))].map(n => wrestlers.filter(a => a.name == n).map(w => `(${bracket.text.replace(' lbs', '')}, '${w.name}','${w.team}',${w.seed})`).find(() => true)).join("\n, ");
	console.log(", " + sql);
}

*/


create table #EventSeed (
	WeightClass int
	, WrestlerName varchar(255)
	, TeamName varchar(255)
	, Seed int
)

insert #EventSeed (WeightClass, WrestlerName, TeamName, Seed)
values
(106, 'Andrew Avery','Hanahan',6)
, (106, 'James Hash','Marion',2)
, (106, 'Ethan Braswell','Effingham',5)
, (106, 'Nicholas Fontana','Hilton Head',8)
, (106, 'Truett Ellison','Catawba Ridge',7)
, (106, 'Kadence Badger','Effingham',4)
, (106, 'Grant Jeter','St James',3)
, (106, 'Stephano Calderon','May River',1)
, (113, 'RJ Bell','Fountain Inn',10)
, (113, 'Landon Phillips','Grovetown',1)
, (113, 'Wesley Lawton','Ashley Ridge',6)
, (113, 'Andreo Manlove','South Effingham',2)
, (113, 'Jacob McClure','Catawba Ridge',3)
, (113, 'Bentley Alcantara','Berkeley',7)
, (113, 'Liam Maguire','Myrtle Beach',8)
, (113, 'William Ashley','Lucy Beckham',9)
, (113, 'Bryce Butler','May River',5)
, (113, 'Chase LaFountain','John Paul II',4)
, (120, 'Rahiem Skyers','Ashley Ridge',4)
, (120, 'Tahrik Bailey','South Effingham',3)
, (120, 'Grant Lee','South Effingham B',6)
, (120, 'Liam Finney','St James',8)
, (120, 'DeMontae Holland','McIntosh',2)
, (120, 'Taylon Winker','Catawba Ridge',1)
, (120, 'Ryan Seman','May River',9)
, (120, 'Sullivan Silbiger','Lucy Beckham',5)
, (120, 'BRODY HARRIS','Fort Mill',7)
, (126, 'LUCAS VAN BEYNUM','Fort Mill',4)
, (126, 'Angel Acosta','Catawba Ridge',8)
, (126, 'Josiah Carranco','St James',6)
, (126, 'Jordyn White','Berkeley',2)
, (126, 'Camren Douberley','Effingham',5)
, (126, 'Aiden Simmons','Benedictine',3)
, (126, 'Adrian Galo','White Knoll',7)
, (126, 'Marcus Foulk','May River',1)
, (132, 'Liam Engblom','May River',4)
, (132, 'Luca Phillips','Ashley Ridge',9)
, (132, 'Ryan Ferrell','Fountain Inn',8)
, (132, 'Trey Holcombe','Hanahan',6)
, (132, 'Eric Jackson','McIntosh',2)
, (132, 'Noah Knowlton','South Effingham B',3)
, (132, 'Max Golliher','Marion',5)
, (132, 'Javaree Bartley','Whale Branch',7)
, (132, 'Mayson Young','South Effingham',1)
, (138, 'AJ  West','Benedictine',3)
, (138, 'Jase Reynolds','John Paul II',5)
, (138, 'Brendan Maguire','Myrtle Beach',8)
, (138, 'Grady Brewer','Ashley Ridge',7)
, (138, 'Tyler Mindala','St James',4)
, (138, 'Owen Miller','Hanahan',6)
, (138, 'Jacob Alfonzo','May River',2)
, (138, 'Gianni Bottone','Lucy Beckham',1)
, (144, 'James Kearney','St James',6)
, (144, 'Tanner Caster','Ashley Ridge',8)
, (144, 'Thomas Brough','May River',3)
, (144, 'Cole Sowers','Hilton Head',4)
, (144, 'Jayden Nguyen','Fort Mill',7)
, (144, 'Maddox Vasquez','South Effingham',9)
, (144, 'Gavin Maxwell','Socastee',5)
, (144, 'Matthew Spignardo','Lucy Beckham',1)
, (150, 'Aidan Hamilton','Ashley Ridge',5)
, (150, 'CJ Florencio','Hilton Head',4)
, (150, 'Archer Rozelle','Catawba Ridge',2)
, (150, 'Caleb Barksdale','St James',8)
, (150, 'Anthony Culick','Gilbert',6)
, (150, 'Jackson Stuckey','Hanahan',3)
, (150, 'Jeremiah Hobbs','South Effingham',7)
, (150, 'Lincoln Greene','Fort Mill',1)
, (157, 'Jaden Gerido','Effingham',4)
, (157, 'Victor Smith','Grovetown',2)
, (157, 'KEENAN COSTON','Fort Mill',5)
, (157, 'Ethan Webb','South Effingham',8)
, (157, 'Michael Kegler','Socastee',3)
, (157, 'Will Hair','Hanahan',6)
, (157, 'Alexander Miles','South Effingham B',7)
, (157, 'Blake Butler','May River',1)
, (165, 'Logan Isenhower','White Knoll',4)
, (165, 'BRODEN MITCHESON','Fort Mill',2)
, (165, 'Riley Atkins','South Effingham',1)
, (165, 'Finn Randall','Bishop England',6)
, (165, 'Sheldon Williams','Grovetown',8)
, (165, 'Rollins Dixon','St James',3)
, (165, 'Andre Cavalheiro','May River',7)
, (165, 'Jake Hope','McIntosh',5)
, (175, 'Gage Amaker','Berkeley',6)
, (175, 'Garrett Moore','Marion',4)
, (175, 'Kevin Summers','Bridges Prep',2)
, (175, 'Adrian Ellsworth','White Knoll',8)
, (175, 'William Patton','Grovetown',7)
, (175, 'Talon Campbell','Ashley Ridge',3)
, (175, 'Leandro Larranaga','May River',5)
, (175, 'Nathan Rose','St James',1)
, (190, 'Landon Bledsoe','Fountain Inn',1)
, (190, 'Henry Santiz','May River',4)
, (190, 'Jake Stroud','Gilbert',6)
, (190, 'Joshua Whalen','St James',5)
, (190, 'MAURICE LAWRENCE','Fort Mill',8)
, (190, 'George Campbell','McIntosh',2)
, (190, 'Elijah Sellers','Grovetown',3)
, (190, 'Caysen Fisher','South Effingham',7)
, (215, 'Sean Zadroga-McNulty','May River',6)
, (215, 'Malik Smith','St James',3)
, (215, 'Eric Light','Socastee',4)
, (215, 'TED ERNST','Fort Mill',2)
, (215, 'Uriah Puckett','Ashley Ridge',8)
, (215, 'Chase Lundy','Fountain Inn',7)
, (215, 'Cameron Spinks','Grovetown',5)
, (215, 'Colton Freeman','Beaufort',1)
, (285, 'Krystian Villatoro','Fort Mill',4)
, (285, 'Jaden Priester','Beaufort',6)
, (285, 'Javonte Cummings','McIntosh',3)
, (285, 'Devin Johnson','White Knoll',8)
, (285, 'Alex Johnson','Catawba Ridge',2)
, (285, 'Jayden Page','May River',7)
, (285, 'Jakob Antidormi','Socastee',5)
, (285, 'Kevin Steptoe','South Effingham',1)

-- select * from #EventSeed
-- select * from Event where EventName like '%may river%' order by EventDate desc

select	distinct Wrestler.EventWrestlerID
		, EventSeed.Seed
into	#WrestlerSeed
from	#EventSeed EventSeed
cross apply (
		select	EventWrestlerMatch.EventWrestlerID
		from	EventWrestlerMatch
		join	EventMatch
		on		EventWrestlerMatch.EventMatchID = EventMatch.ID
		where	EventSeed.WrestlerName = EventWrestlerMatch.WrestlerName
				and EventSeed.TeamName = EventWrestlerMatch.TeamName
				and EventMatch.EventID = 25587
		) Wrestler

select	Difference = (10 - coalesce(LoserSeed.Seed, 10)) - (10 - coalesce(WinnerSeed.Seed, 10))
		, Winner = case when WinnerSeed.seed is not null then cast(WinnerSeed.Seed as varchar(max)) + ' ' + WinnerMatch.WrestlerName else WinnerMatch.WrestlerName end
		, WinnerTeam = WinnerMatch.TeamName
		, Winner = case when LoserSeed.seed is not null then cast(LoserSeed.Seed as varchar(max)) + ' ' + LoserMatch.WrestlerName else null end
		, LoserTeam = LoserMatch.TeamName
		, EventMatch.WeightClass
		, EventMatch.RoundName
		-- , Expectation = case
		-- 	when coalesce(winner.GlickoRating, 1500.0) > coalesce(loser.GlickoRating, 1500.0) then 'Expected'
		-- 	when coalesce(winner.GlickoRating, 1500.0) + coalesce(winner.GlickoDeviation, 500.0) > coalesce(loser.GlickoRating, 1500.0) - coalesce(loser.GlickoDeviation, 500.0) then 'In Range'
		-- 	when coalesce(winner.GlickoRating, 1500.0) + coalesce(Winner.GlickoDeviation, 500.0) < coalesce(loser.GlickoRating, 1500.0) - coalesce(loser.GlickoDeviation, 500.0) then 'Unexpected'
		-- 	end
from	EventMatch
join	EventWrestlerMatch WinnerMatch
on		EventMatch.ID = WinnerMatch.EventMatchID
		and WinnerMatch.IsWinner = 1
join	EventWrestler Winner
on		WinnerMatch.EventWrestlerID = Winner.ID
left join
		#WrestlerSeed WinnerSeed
on		WinnerMatch.EventWrestlerID = WinnerSeed.EventWrestlerID
join	EventWrestlerMatch LoserMatch
on		EventMatch.ID = LoserMatch.EventMatchID
		and LoserMatch.IsWinner = 0
join	EventWrestler Loser
on		LoserMatch.EventWrestlerID = Loser.ID
left join
		#WrestlerSeed LoserSeed
on		LoserMatch.EventWrestlerID = LoserSeed.EventWrestlerID
where	EventMatch.EventID = 25587
		and (
			coalesce(WinnerSeed.Seed, 10) > coalesce(LoserSeed.Seed, 10)
		)
order by
		(10 - coalesce(LoserSeed.Seed, 10)) - (10 - coalesce(WinnerSeed.Seed, 10)) desc
		, LoserTeam
		, WeightClass
