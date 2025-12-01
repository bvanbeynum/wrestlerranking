
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

	if weekEnd > datetime.now().date():
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
			players[rating.EventWrestlerID] = {
				"varsity": glicko2.Player(rating=float(rating.Rating), rd=float(rating.Deviation)),
				"jv": glicko2.Player(rating=float(rating.JVRating), rd=float(rating.JVDeviation)) if rating.JVRating and rating.JVDeviation else glicko2.Player(rating=1500, rd=500, vol=0.06),
				"ms": glicko2.Player(rating=float(rating.MSRating), rd=float(rating.MSDeviation)) if rating.MSRating and rating.MSDeviation else glicko2.Player(rating=1500, rd=500, vol=0.06),
				"girls": glicko2.Player(rating=float(rating.GirlsRating), rd=float(rating.GirlsDeviation)) if rating.GirlsRating and rating.GirlsDeviation else glicko2.Player(rating=1500, rd=500, vol=0.06),
			}

	# Initialize any new active wrestlers with default ratings.
	for wrestlerId in activeWrestlers:
		if wrestlerId not in players:
			players[wrestlerId] = {
				"varsity": glicko2.Player(rating=1500, rd=500, vol=0.06),
				"jv": glicko2.Player(rating=1500, rd=500, vol=0.06),
				"ms": glicko2.Player(rating=1500, rd=500, vol=0.06),
				"girls": glicko2.Player(rating=1500, rd=500, vol=0.06)
			}
			
	# Get the match outcomes for the current week.
	weeklyMatchOutcomes = executeQuery(connection, "get_weekly_match_outcomes", (currentDate, weekEnd))

	# Store the results for each player for the current week.
	playerResults = {playerId: { "varsity": [], "jv": [], "ms": [], "girls": [] } for playerId in players.keys()}
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
			if outcome.Division == "HS":
				playerResults[winnerId]["varsity"].append((loser["varsity"].rating, loser["varsity"].rd, scoreRank))
				playerResults[loserId]["varsity"].append((winner["varsity"].rating, winner["varsity"].rd, 1 - scoreRank))
			elif outcome.Division == "JV":
				playerResults[winnerId]["jv"].append((loser["jv"].rating, loser["jv"].rd, scoreRank))
				playerResults[loserId]["jv"].append((winner["jv"].rating, winner["jv"].rd, 1 - scoreRank))
			elif outcome.Division == "MS":
				playerResults[winnerId]["ms"].append((loser["ms"].rating, loser["ms"].rd, scoreRank))
				playerResults[loserId]["ms"].append((winner["ms"].rating, winner["ms"].rd, 1 - scoreRank))
			elif outcome.Division == "Girls":
				playerResults[winnerId]["girls"].append((loser["girls"].rating, loser["girls"].rd, scoreRank))
				playerResults[loserId]["girls"].append((winner["girls"].rating, winner["girls"].rd, 1 - scoreRank))
				
	# Update the Glicko-2 ratings for all active players for the week.
	for playerId, player in players.items():
		# Adjust RD for inactivity before processing games
		player["varsity"]._preRatingRD()
		player["jv"]._preRatingRD()
		player["ms"]._preRatingRD()
		player["girls"]._preRatingRD()

	for playerId, resultType in playerResults.items():
		if resultType["varsity"] and len(resultType["varsity"]) > 0:
			ratings, rds, outcomes = zip(*resultType["varsity"])
			players[playerId]["varsity"].update_player(ratings, rds, outcomes)
		
		if resultType["jv"] and len(resultType["jv"]) > 0:
			ratings, rds, outcomes = zip(*resultType["jv"])
			players[playerId]["jv"].update_player(ratings, rds, outcomes)

		if resultType["ms"] and len(resultType["ms"]) > 0:
			ratings, rds, outcomes = zip(*resultType["ms"])
			players[playerId]["ms"].update_player(ratings, rds, outcomes)

		if resultType["girls"] and len(resultType["girls"]) > 0:
			ratings, rds, outcomes = zip(*resultType["girls"])
			players[playerId]["girls"].update_player(ratings, rds, outcomes)

	# Prepare batch inserts for wrestler ratings and updates for event wrestlers.
	insert_wrestler_rating_params = []
	update_event_wrestler_params = []
	for playerId, player in players.items():
		insert_wrestler_rating_params.append((
			playerId, 
			weekEnd, 
			player["varsity"].rating, 
			player["varsity"].rd,
			player["jv"].rating,
			player["jv"].rd,
			player["ms"].rating,
			player["ms"].rd,
			player["girls"].rating,
			player["girls"].rd
			))

		update_event_wrestler_params.append((
			player["varsity"].rating, 
			player["varsity"].rd, 
			player["jv"].rating, 
			player["jv"].rd, 
			player["ms"].rating, 
			player["ms"].rd, 
			player["girls"].rating, 
			player["girls"].rd,
			playerId))

	# Execute batch inserts and updates.
	executeQuery(connection, "insert_wrestler_rating", insert_wrestler_rating_params, many=True)
	executeQuery(connection, "update_event_wrestler", update_event_wrestler_params, many=True)

	print(f"{datetime.now()}: Finished processing for week ending {weekEnd.strftime('%Y-%m-%d')}")

	# Move to the next week.
	currentDate = weekEnd + timedelta(days=1)

# Close the connection.
connection.close()

print(f"{datetime.now()}: Wrestler rating process completed.")

