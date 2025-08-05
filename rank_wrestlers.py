
import os
import pyodbc
import json
import glicko2
from datetime import timedelta

def execute_query(connection, queryName, parameters=None):
	with connection.cursor() as cursor:
		if parameters:
			cursor.execute(sqlQueries[queryName], parameters)
		else:
			cursor.execute(sqlQueries[queryName])
		return cursor.fetchall()

sqlQueries = {}
for fileName in os.listdir("sql"):
	if fileName.endswith(".sql"):
		with open(os.path.join("sql", fileName), "r") as fileObject:
			sqlQueries[fileName.replace(".sql", "")] = fileObject.read()

with open("config.json", "r") as fileObject:
	config = json.load(fileObject)

db_config = config["database"]
conn_str = f"DRIVER={{ODBC Driver 18 for SQL Server}};SERVER={db_config['server']};DATABASE={db_config['database']};UID={db_config['user']};PWD={db_config['password']}"
connection = pyodbc.connect(conn_str)

# 1. Get all wrestlers
wrestlers = execute_query(connection, "get_wrestlers")

# 2. Get all matches
matches = execute_query(connection, "get_matches")

# 3. Get match winner and loser
matchResults = execute_query(connection, "get_match_winner_and_loser")

# 4. Glicko-2 calculation
# Initialize wrestlers with default ratings
players = {row.ID: glicko2.Player(rating=1500, rd=500, vol=0.06) for row in wrestlers}

# Group matches by week
matchesByWeek = {}
for match in matches:
	eventDate = match.EventDate
	weekEnd = eventDate + timedelta(days=6 - eventDate.weekday())
	if weekEnd not in matchesByWeek:
		matchesByWeek[weekEnd] = []
	matchesByWeek[weekEnd].append(match)

# Process matches week by week
for weekEnd in sorted(matchesByWeek.keys()):
	# Create a list of match results for each player for the current week
	playerResults = {playerID: [] for playerID in players.keys()}
	for match in matchesByWeek[weekEnd]:
		winnerID = [result.WinnerID for result in matchResults if result.EventMatchID == match.ID][0]
		loserID = [result.LoserID for result in matchResults if result.EventMatchID == match.ID][0]

		winner = players[winnerID]
		loser = players[loserID]

		playerResults[winnerID].append((loser.rating, loser.rd, 1))
		playerResults[loserID].append((winner.rating, winner.rd, 0))

	# Update ratings for the week
	for playerID, results in playerResults.items():
		if results:
			players[playerID].rate(results)
			# Log the rating change
			execute_query(connection, "insert_wrestler_rating", (playerID, weekEnd, players[playerID].rating, players[playerID].rd))

# 5. Update wrestler ratings
for playerID, player in players.items():
	execute_query(connection, "update_event_wrestler", (player.rating, player.rd, playerID))

connection.close()

