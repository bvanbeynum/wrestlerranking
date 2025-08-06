
import os
import pyodbc
import json
import glicko2
from datetime import datetime, timedelta

def executeQuery(connection, queryName, parameters=None):
	"""Executes a SQL query from the sqlQueries dictionary."""
	with connection.cursor() as cursor:
		if parameters:
			cursor.execute(sqlQueries[queryName], parameters)
		else:
			cursor.execute(sqlQueries[queryName])
		return cursor.fetchall()

# Load SQL queries from files into a dictionary for easy access.
sqlQueries = {}
for fileName in os.listdir("sql"):
	if fileName.endswith(".sql"):
		with open(os.path.join("sql", fileName), "r") as fileObject:
			sqlQueries[fileName.replace(".sql", "")] = fileObject.read()

# Load database configuration from an external JSON file.
with open("config.json", "r") as fileObject:
	config = json.load(fileObject)

# Construct the database connection string.
dbConfig = config["database"]
connectionString = f"DRIVER={{ODBC Driver 18 for SQL Server}};SERVER={dbConfig['server']};DATABASE={dbConfig['database']};UID={dbConfig['user']};PWD={dbConfig['password']}"

# Establish the database connection.
connection = pyodbc.connect(connectionString)

# Get the date range of all matches.
dateRangeResult = executeQuery(connection, "get_match_date_range")[0]
minDate = dateRangeResult.minDate
maxDate = dateRangeResult.maxDate

# To make the script restartable, get the last date that was processed.
lastProcessedDateResult = executeQuery(connection, "get_last_processed_date")
lastProcessedDate = lastProcessedDateResult[0][0] if lastProcessedDateResult and lastProcessedDateResult[0][0] else None

# Set the start date for processing.
currentDate = lastProcessedDate if lastProcessedDate else minDate

# Loop through each week from the start date to the max date.
while currentDate <= maxDate:
	weekEnd = currentDate + timedelta(days=6 - currentDate.weekday())

	print(f"{datetime.now()}: Processing matches for week ending {weekEnd.strftime('%Y-%m-%d')}")

	# Get all wrestlers and their latest ratings.
	wrestlers = executeQuery(connection, "get_wrestlers")
	players = {}
	latestRatings = executeQuery(connection, "get_latest_wrestler_ratings")
	for rating in latestRatings:
		players[rating.EventWrestlerID] = glicko2.Player(rating=rating.Rating, rd=rating.Deviation)

	# Initialize any new wrestlers with default ratings.
	for wrestler in wrestlers:
		if wrestler.ID not in players:
			players[wrestler.ID] = glicko2.Player(rating=1500, rd=500, vol=0.06)

	# Get the match outcomes for the current week.
	weeklyMatchOutcomes = executeQuery(connection, "get_weekly_match_outcomes", (currentDate, weekEnd))

	# Store the results for each player for the current week.
	playerResults = {playerId: [] for playerId in players.keys()}
	for outcome in weeklyMatchOutcomes:
		winnerId = outcome.WinnerID
		loserId = outcome.LoserID

		winner = players[winnerId]
		loser = players[loserId]

		# Append the opponent's rating, RD, and the outcome (1 for win, 0 for loss).
		playerResults[winnerId].append((loser.rating, loser.rd, 1))
		playerResults[loserId].append((winner.rating, winner.rd, 0))

	# Update the Glicko-2 ratings for all players for the week.
	for playerId, results in playerResults.items():
		if results:
			# If the player competed, update their rating based on the results.
			players[playerId].rate(results)
		else:
			# If the player was inactive, the glicko2 library handles the RD increase.
			players[playerId].update_rating_deviation()

		# Log the new rating to the database for historical tracking.
		executeQuery(connection, "insert_wrestler_rating", (playerId, weekEnd, players[playerId].rating, players[playerId].rd))

	# Update the wrestler's main rating in the EventWrestler table.
	for playerId, player in players.items():
		executeQuery(connection, "update_event_wrestler", (player.rating, player.rd, playerId))

	# Commit the changes for the week to the database.
	connection.commit()
	print(f"{datetime.now()}: Finished processing for week ending {weekEnd.strftime('%Y-%m-%d')}")

	# Move to the next week.
	currentDate = weekEnd + timedelta(days=1)

# Close the connection.
connection.close()

print(f"{datetime.now()}: Wrestler rating process completed.")

