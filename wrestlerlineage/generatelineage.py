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
				winning_lineages = []
				losing_lineages = []
				for path in lineageDistinct:
					if path and path[0]["isWinner"]:
						winning_lineages.append(path)
					else:
						losing_lineages.append(path)
				
				winningLineagesForSorting = []
				for path in winning_lineages:
					timestamps = [datetime.datetime.strptime(match["eventDate"], "%Y-%m-%d").timestamp() for match in path]
					if timestamps:
						avgTimestamp = sum(timestamps) / len(timestamps)
						winningLineagesForSorting.append((len(path), avgTimestamp, path))
				
				winningLineagesForSorting.sort(key=lambda item: (item[0], -item[1]))
				millWrestler["winningLineages"] = [item[2] for item in winningLineagesForSorting[:10]]

				losingLineagesForSorting = []
				for path in losing_lineages:
					timestamps = [datetime.datetime.strptime(match["eventDate"], "%Y-%m-%d").timestamp() for match in path]
					if timestamps:
						avgTimestamp = sum(timestamps) / len(timestamps)
						losingLineagesForSorting.append((len(path), avgTimestamp, path))

				losingLineagesForSorting.sort(key=lambda item: (item[0], -item[1]))
				millWrestler["losingLineages"] = [item[2] for item in losingLineagesForSorting[:10]]
				if "lineage" in millWrestler:
					del millWrestler["lineage"]

		if len(millWrestler.get("winningLineages", [])) > 0 or len(millWrestler.get("losingLineages", [])) > 0:
			logMessage(f"Saving wrestler. {len(millWrestler.get('winningLineages', []))} winning and {len(millWrestler.get('losingLineages', []))} losing Lineages")
			response = requests.post(f"{ config['millServer'] }/data/wrestler", json={ "wrestler": millWrestler })

			if response.status_code >= 400:
				errorLogging(f"Error updating wrestler: {response.text}")

logMessage(f"------------- Complete")
