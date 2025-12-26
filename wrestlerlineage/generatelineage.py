import os
import sys
import json
import re
import datetime
import requests
import sqlalchemy
from urllib.parse import quote_plus

with open("./config.json", "r") as reader:
	config = json.load(reader)

def logMessage(message):
	logTime = datetime.datetime.strftime(datetime.datetime.now(), "%Y-%m-%d %H:%M:%S")
	print(f"{logTime} - {message}")

def errorLogging(errorMessage):
	logMessage(errorMessage)
	try:
		logPayload = {
			"log": {
				"logTime": datetime.datetime.now().isoformat(),
				"lotTypeId": "69496309ae6d81224f22409a",
				"message": errorMessage
			}
		}
		requests.post(f"{ config['apiServer'] }/sys/api/addlog", json=logPayload)
	except Exception as apiError:
		logMessage(f"Failed to log error to API: {apiError}")

def loadSQL():
	sql = {}
	sqlPath = "./wrestlerlineage/sql"

	if os.path.exists(sqlPath):
		for file in os.listdir(sqlPath):
			with open(f"{ sqlPath }/{ file }", "r") as fileReader:
				sql[os.path.splitext(file)[0]] = fileReader.read()
	
	return sql

def getOpponents(wrestler, tier, WinType):
	
	try:
		dbResult = cn.execute(sqlalchemy.text(sql["OpponentsGet"]), {"WrestlerID": wrestler["WrestlerID"], "IsWinner": WinType})
		opponents = dbResult.mappings().all()

	except Exception as error:
		errorMessage = f"Error getting opponents: {error}"
		errorLogging(errorMessage)
		errorCount += 1
		return []
	
	wrestlerLineage = []
	for opponent in opponents:
		if tier < 3 or re.search("fort mill", opponent["TeamName"], re.IGNORECASE):
			packet = {
				"wrestler1SqlId": wrestler["WrestlerID"],
				"wrestler1Name": wrestler["WrestlerName"],
				"wrestler1Team": wrestler["TeamName"],
				"wrestler2SqlId": opponent["WrestlerID"],
				"wrestler2Name": opponent["WrestlerName"],
				"wrestler2Team": opponent["TeamName"],
				"isWinner": opponent["IsWinner"],
				"sort": tier,
				"eventDate": opponent["EventDate"]
			}
		
		if re.search("fort mill", opponent["TeamName"], re.IGNORECASE):
			wrestlerLineage.append([packet])
		
		elif tier < 3 and len(wrestlerLineage) < 50:
			subLineages = getOpponents(opponent, tier + 1, opponent["IsWinner"])
			for lineage in subLineages:
				lineage.insert(0, packet)
				wrestlerLineage.append(lineage)

	if len(wrestlerLineage) > 0:
		return wrestlerLineage
	else:
		return []


logMessage(f"------------- Setup")

sql = loadSQL()

logMessage(f"Connecting to DB")

try:
	db = sqlalchemy.create_engine(f"mssql+pyodbc://{config['database']['user']}:{config['database']['password']}@{config['database']['server']}/{config['database']['database']}?driver={quote_plus('ODBC Driver 18 for SQL Server')}&encrypt=no", isolation_level="AUTOCOMMIT")	
	cn = db.connect()

except Exception as error:
	errorMessage = f"Error connecting to database: {error}"
	errorLogging(errorMessage)
	sys.exit(1)

logMessage(f"------------- Processing")

try:
	logMessage(f"Get Schools")
	dbResult = cn.execute(sqlalchemy.text(sql["SchoolsGet"]))
	schools = dbResult.mappings().all()
	
except Exception as error:
	errorMessage = f"Error getting schools: {error}"
	errorLogging(errorMessage)
	sys.exit(1)

errorCount = 0
wrestlerLineage = []
for school in schools:
	logMessage(f"Process school { school['SchoolName'] } ************************")
	
	try:
		dbResult = cn.execute(sqlalchemy.text(sql["WrestlersGet"]), {"SchoolID": school["SchoolID"]})
		wrestlers = dbResult.mappings().all()

	except Exception as error:
		errorLogging(f"Error getting wrestlers: {error}")
		errorCount += 1
		
		if errorCount > 10:
			break
		else:
			continue
	
	for wrestler in wrestlers:
		logMessage(f"Process wrestler { wrestler['WrestlerName'] }")

		response = requests.get(f"{ config['millServer'] }/data/wrestler?sqlid={ wrestler['WrestlerID'] }")
		if response.status_code >= 400:
			errorLogging(f"Error getting wrestler: {response.text}")
			continue
		
		millWrestlers = json.loads(response.text)["wrestlers"]
		if len(millWrestlers) == 0:
			logMessage(f"Skipping { wrestler['WrestlerName'] } ({wrestler['WrestlerID']})")
			continue

		millWrestler = millWrestlers[0]

		try:
			dbResult = cn.execute(sqlalchemy.text(sql["OpponentsGet"]), {"WrestlerID": wrestler["WrestlerID"], "IsWinner": None})
			opponents = dbResult.mappings().all()

		except Exception as error:
			errorLogging(f"Error getting opponents: {error}")
			continue
		
		millWrestler["lineage"] = []
		allLineages = []
		for opponent in opponents:
			packet = {
					"wrestler1SqlId": wrestler["WrestlerID"],
					"wrestler1Name": wrestler["WrestlerName"],
					"wrestler1Team": wrestler["TeamName"],
					"wrestler2SqlId": opponent["WrestlerID"],
					"wrestler2Name": opponent["WrestlerName"],
					"wrestler2Team": opponent["TeamName"],
					"isWinner": opponent["IsWinner"],
					"sort": 0,
					"eventDate": opponent["EventDate"]
				}
			
			if re.search("fort mill", opponent["TeamName"], re.IGNORECASE):
				allLineages.append([packet])
			
			elif len(allLineages) < 100:
				subLineages = getOpponents(opponent, 0, opponent["IsWinner"])
				for lineage in subLineages:
					lineage.insert(0, packet)
					allLineages.append(lineage)
			else:
				continue

		if allLineages:
			shortestLineages = {}
			for path in allLineages:
				lastWrestler = path[-1]
				fortMillWrestlerId = lastWrestler["wrestler2SqlId"]

				if fortMillWrestlerId not in shortestLineages or len(path) < len(shortestLineages[fortMillWrestlerId]):
					shortestLineages[fortMillWrestlerId] = path
			
			lineageDistinct = list(shortestLineages.values())

			if lineageDistinct:
				lineagesForSorting = []
				for path in lineageDistinct:
					# Calculate average event date for each lineage path
					timestamps = [datetime.datetime.strptime(match["eventDate"], "%Y-%m-%d").timestamp() for match in path]
					if timestamps:
						avgTimestamp = sum(timestamps) / len(timestamps)
						lineagesForSorting.append((len(path), avgTimestamp, path))

				# Sort by shortest path (ascending), then by most recent average date (descending)
				lineagesForSorting.sort(key=lambda item: (item[0], -item[1]))
				
				# Keep only the top 10
				millWrestler["lineage"] = [item[2] for item in lineagesForSorting[:10]]		

		if len(millWrestler["lineage"]) > 0:
			logMessage(f"Saving wrestler. {len(millWrestler['lineage'])} Lineages")
			response = requests.post(f"{ config['millServer'] }/data/wrestler", json={ "wrestler": millWrestler })

			if response.status_code >= 400:
				errorLogging(f"Error updating wrestler: {response.text}")

logMessage(f"------------- Complete")
