
import os
import pyodbc
import json
import glicko2
from datetime import datetime, timedelta

def executeQuery(connection, queryName, parameters=None, many=False):
	"""Executes a SQL query from the sqlQueries dictionary, with optional batch execution."""
	with connection.cursor() as cursor:
		if many:
			cursor.executemany(sqlQueries[queryName], parameters)
		elif parameters:
			cursor.execute(sqlQueries[queryName], parameters)
		else:
			cursor.execute(sqlQueries[queryName])
		if cursor.description:
			return cursor.fetchall()
		return None

# Load SQL queries from files into a dictionary for easy access.
sqlQueries = {}
for fileName in os.listdir("rankwrestlers/sql"):
	if fileName.endswith(".sql"):
		with open(os.path.join("rankwrestlers/sql", fileName), "r") as fileObject:
			sqlQueries[fileName.replace(".sql", "")] = fileObject.read()

# Load database configuration from an external JSON file.
with open("config.json", "r") as fileObject:
	config = json.load(fileObject)

# Construct the database connection string.
dbConfig = config["database"]
connectionString = f"DRIVER={{ODBC Driver 18 for SQL Server}};SERVER={dbConfig['server']};DATABASE={dbConfig['database']};UID={dbConfig['user']};PWD={dbConfig['password']};ENCRYPT=no"

# Establish the database connection.
connection = pyodbc.connect(connectionString, autocommit=True)

# Get the date range of all matches.
dateRangeResult = executeQuery(connection, "get_match_date_range")[0]
minDate = dateRangeResult.minDate
maxDate = dateRangeResult.maxDate

# To make the script restartable, get the last date that was processed.
lastProcessedDateResult = executeQuery(connection, "get_last_processed_date")
lastProcessedDate = lastProcessedDateResult[0][0] if lastProcessedDateResult and lastProcessedDateResult[0][0] else None

# Set the start date for processing.
currentDate = lastProcessedDate + timedelta(days=1) if lastProcessedDate else minDate

# Loop through each week from the start date to the max date.
while currentDate <= maxDate:
	weekEnd = currentDate + timedelta(days=6 - currentDate.weekday())
	activityStartDate = currentDate - timedelta(days=365)

	if weekEnd > datetime.date.today():
		# Weeks not complete, so ranking is finished
		break

	print(f"{datetime.now()}: Processing matches for week ending {weekEnd.strftime('%Y-%m-%d')}")

	# Get the set of active wrestlers for the current week.
	activeWrestlerRows = executeQuery(connection, "get_active_wrestlers_for_period", (weekEnd, activityStartDate))
	activeWrestlers = {row.EventWrestlerID for row in activeWrestlerRows}

	# Get the latest ratings for the active wrestlers.
	players = {}
	latestRatings = executeQuery(connection, "get_latest_wrestler_ratings")
	for rating in latestRatings:
		if rating.EventWrestlerID in activeWrestlers:
			players[rating.EventWrestlerID] = glicko2.Player(rating=float(rating.Rating), rd=float(rating.Deviation))

	# Initialize any new active wrestlers with default ratings.
	for wrestlerId in activeWrestlers:
		if wrestlerId not in players:
			players[wrestlerId] = glicko2.Player(rating=1500, rd=500, vol=0.06)

	# Get the match outcomes for the current week.
	weeklyMatchOutcomes = executeQuery(connection, "get_weekly_match_outcomes", (currentDate, weekEnd))

	# Store the results for each player for the current week.
	playerResults = {playerId: [] for playerId in players.keys()}
	for outcome in weeklyMatchOutcomes:
		winnerId = outcome.WinnerID
		loserId = outcome.LoserID

		if winnerId in activeWrestlers and loserId in activeWrestlers:
			winner = players[winnerId]
			loser = players[loserId]

			winType = outcome.WinType.lower()
			if "fall" in winType or "f" == winType:
				scoreRank = 1.0
			elif "tf" in winType:
				scoreRank = 1.0
			else:
				scoreRank = 0.7
			
			# Append the opponent's rating, RD, and the outcome.
			playerResults[winnerId].append((loser.rating, loser.rd, scoreRank))
			playerResults[loserId].append((winner.rating, winner.rd, 1 - scoreRank))

	# Update the Glicko-2 ratings for all active players for the week.
	for playerId, player in players.items():
		# Adjust RD for inactivity before processing games
		player._preRatingRD()

	for playerId, results in playerResults.items():
		if results:
			# If the player competed, update their rating based on the results.
			ratings, rds, outcomes = zip(*results)
			players[playerId].update_player(ratings, rds, outcomes)

	# Prepare batch inserts for wrestler ratings and updates for event wrestlers.
	insert_wrestler_rating_params = []
	update_event_wrestler_params = []
	for playerId, player in players.items():
		insert_wrestler_rating_params.append((playerId, weekEnd, player.rating, player.rd))
		update_event_wrestler_params.append((player.rating, player.rd, playerId))

	# Execute batch inserts and updates.
	executeQuery(connection, "insert_wrestler_rating", insert_wrestler_rating_params, many=True)
	executeQuery(connection, "update_event_wrestler", update_event_wrestler_params, many=True)

	print(f"{datetime.now()}: Finished processing for week ending {weekEnd.strftime('%Y-%m-%d')}")

	# Move to the next week.
	currentDate = weekEnd + timedelta(days=1)

# Close the connection.
connection.close()

print(f"{datetime.now()}: Wrestler rating process completed.")

