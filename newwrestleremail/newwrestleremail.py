import pyodbc
import datetime
import json
import requests
import os
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from email.mime.application import MIMEApplication
from difflib import SequenceMatcher

def logMessage(message):
	logTime = datetime.datetime.strftime(datetime.datetime.now(), "%Y-%m-%d %H:%M:%S")
	print(f"{logTime} - {message}")

def errorLogging(errorMessage):
	logMessage(errorMessage)
	try:
		logPayload = {
			"log": {
				"logTime": datetime.datetime.now().isoformat(),
				"lotTypeId": "691e351ab7de6ab54ed121ae",
				"message": errorMessage
			}
		}
		requests.post(f"{ config["apiServer"] }/sys/api/addlog", json=logPayload)
	except Exception as apiError:
		logMessage(f"Failed to log error to API: {apiError}")

def loadSql():
	sql = {}
	sqlPath = "./newwrestleremail/sql/"

	if os.path.exists(sqlPath):
		for file in os.listdir(sqlPath):
			with open(f"{ sqlPath }/{ file }", "r") as fileReader:
				sql[os.path.splitext(file)[0]] = fileReader.read()
	
	return sql

def getNameDiffHtml(string1, string2):
	string1 = string1.lower()
	string2 = string2.lower()
	
	matcher = SequenceMatcher(None, string1, string2)
	
	output1 = []
	output2 = []
	
	for tag, i1, i2, j1, j2 in matcher.get_opcodes():
		if tag == 'replace':
			output1.append(f'<span class="diff">{string1[i1:i2]}</span>')
			output2.append(f'<span class="diff">{string2[j1:j2]}</span>')
		elif tag == 'delete':
			output1.append(f'<span class="diff">{string1[i1:i2]}</span>')
		elif tag == 'insert':
			output2.append(f'<span class="diff">{string2[j1:j2]}</span>')
		elif tag == 'equal':
			output1.append(string1[i1:i2])
			output2.append(string2[j1:j2])
			
	return ''.join(output1), ''.join(output2)





# *************************** Script Start ***************************

logMessage(f"Starting FloWrestling scraper.")

with open("./config.json", "r") as reader:
	config = json.load(reader)

cn = pyodbc.connect(f"DRIVER={{ODBC Driver 18 for SQL Server}};SERVER={ config["database"]["server"] };DATABASE={ config["database"]["database"] };ENCRYPT=no;UID={ config["database"]["user"] };PWD={ config["database"]["password"] }", autocommit=True)
cur = cn.cursor()

sql = loadSql()

logMessage(f"Process Name Updates.")
cur.execute(sql["ProcessWrestlerNames"])

logMessage(f"Process Team Duplicates.")
cur.execute(sql["ProcessTeamDups"])

logMessage(f"Email new wrestlers.")

cur.execute(sql["NewWrestlerGet"])
newWrestlers = cur.fetchall()

if len(newWrestlers) > 0:

	with open("./newwrestleremail/newwrestlertemplate.html", "r") as reader:
		htmlTemplate = reader.read()

	rows = []
	wrestlerGroups = {}
	for wrestler in newWrestlers:
		if wrestler.MatchGroupID not in wrestlerGroups:
			wrestlerGroups[wrestler.MatchGroupID] = []
		wrestlerGroups[wrestler.MatchGroupID].append(wrestler)

	lastMatchGroupId = None
	groupCounter = 0
	for index, wrestler in enumerate(newWrestlers):
		
		if wrestler.MatchGroupID != lastMatchGroupId:
			groupCounter += 1
			lastMatchGroupId = wrestler.MatchGroupID

		rowClass = []
		if groupCounter % 2 != 0:
			rowClass.append("odd-group")
		
		# Check if the group has more than one wrestler
		if len(wrestlerGroups[wrestler.MatchGroupID]) > 1:
			rowClass.append("group-row")
			
		# Check if it's the last wrestler in the group
		isLastInGroup = (index == len(newWrestlers) - 1) or (newWrestlers[index+1].MatchGroupID != wrestler.MatchGroupID)
		if isLastInGroup:
			rowClass.append("group-end")

		classString = f'class="{" ".join(rowClass)}"' if rowClass else ""

		existingWrestlerHtml, newWrestlerHtml = getNameDiffHtml(wrestler.ExistingWrestler, wrestler.NewWrestler)
		
		addDateStr = wrestler.AddDate.strftime("%m/%d/%Y") if wrestler.AddDate else ""

		script = f"insert into #dedup (saveid, dupid) values({wrestler.ExistingID},{wrestler.NewID});"

		row = f"""
		<tr {classString}>
			<td><input type="checkbox" class="wrestler-checkbox"></td>
			<td>{wrestler.ExistingID}</td>
			<td>{wrestler.NewID}</td>
			<td>{existingWrestlerHtml}</td>
			<td>{newWrestlerHtml}</td>
			<td class="team-col">{wrestler.MatchedTeams}</td>
			<td>{addDateStr}</td>
			<td class="script-cell">{script}</td>
		</tr>
		"""
		rows.append(row)

	htmlBody = htmlTemplate.replace("<NewEmailData>", "\n".join(rows))

	msg = MIMEMultipart()
	msg["From"] = "wrestlingfortmill@gmail.com"
	msg["To"] = "maildrop444@gmail.com"
	msg["Subject"] = "New Wrestler Report - " + datetime.datetime.now().strftime("%Y-%m-%d")

	msg.attach(MIMEText("New wrestler report is attached.", "plain"))

	attachment = MIMEApplication(htmlBody, _subtype="html")
	attachment.add_header("Content-Disposition", "attachment", filename="newWrestlerReport.html")
	msg.attach(attachment)

	try:
		with smtplib.SMTP_SSL("smtp.gmail.com", 465) as smtp:
			smtp.login("wrestlingfortmill@gmail.com", config["googleAppPassword"])
			smtp.send_message(msg)

		logMessage(f"Email sent successfully.")
	except Exception as e:
		errorLogging(f"Failed to send email. Error: {e}")

else:
	logMessage(f"No new wrestlers found.")

logMessage(f"---------- Complete.")
