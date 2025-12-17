import json
import os
import time
import pandas as pd
from urllib.parse import quote_plus
import sqlalchemy
import requests
import sys
from datetime import datetime, timedelta, timezone
import premailer
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import smtplib
import imaplib
from google.oauth2 import service_account
from googleapiclient.discovery import build

def logMessage(message):
	logTime = datetime.strftime(datetime.now(), "%Y-%m-%d %H:%M:%S")
	print(f"{logTime} - {message}")

def errorLogging(errorMessage):
	logMessage(errorMessage)
	try:
		logPayload = {
			"log": {
				"logTime": datetime.now().isoformat(),
				"lotTypeId": "6915e9d862c8ac52d59ce88e",
				"message": errorMessage
			}
		}
		requests.post(f"{ config['apiServer'] }/sys/api/addlog", json=logPayload)
	except Exception as apiError:
		logMessage(f"Failed to log error to API: {apiError}")

def loadSQL():
	sql = {}
	sqlPath = "./parentweekly/sql"

	if os.path.exists(sqlPath):
		for file in os.listdir(sqlPath):
			with open(f"{ sqlPath }/{ file }", "r") as fileReader:
				sql[os.path.splitext(file)[0]] = fileReader.read()
	
	return sql

def loadVarsityDuals(dataDate, sheetsService):
	sheetId = "1-jIN_qDGDd9GC2FNQmfN8ysvddnOmu8-9Lwhnabv4a8"
	tabName = "2025-26 Duals" #"2024-2025 Duals"
	totalColumnIndex = None
	dualData = []

	result = sheetsService.spreadsheets().values().get(
		spreadsheetId=sheetId,
		range=tabName
	).execute()
	allrows = result.get('values', [])

	# Look for the total in the header
	for headerIndex in range(min(20, len(allrows))):
		row = allrows[headerIndex]
		for cellIndex, cell in enumerate(row):
			if cell.strip().lower() == "total":
				totalColumnIndex = cellIndex
				break
		
		if totalColumnIndex is not None:
			break
	
	if totalColumnIndex is None:
		raise Exception("Total column not found")
	
	eventDate = None
	opponentName = None
	fmScore = None
	oppScore = None
	sevenDaysBeforeLoad = dataDate + timedelta(days=-7)

	for row in allrows:
		# Skip empty rows
		if not any(row):
			continue

		if len(row) > totalColumnIndex and len(row) > 2:
			
			if row[0]:
				currentEventDateStr = row[0].strip()
				dateOfEvent = datetime.strptime(currentEventDateStr, "%m/%d/%Y").date()
				if dateOfEvent > dataDate.date() or dateOfEvent < sevenDaysBeforeLoad.date():
					continue
				eventDate = currentEventDateStr
			
			if row[1]:
				opponentName = row[1].strip()
		
			# Check for FM Pts in the 3rd column
			if row[2].strip().replace(".", "").lower() == "fm pts":
				try:
					fmScore = int(row[totalColumnIndex].strip())
				except (ValueError, IndexError):
					fmScore = None

			# Check for Opp Pts
			elif row[2].strip().replace(".", "").lower() == "opp pts":
				try:
					oppScore = int(row[totalColumnIndex].strip())
				except (ValueError, IndexError):
					oppScore = None

				if fmScore is not None and oppScore is not None and eventDate is not None:
					dualData.append({
						"team": "Varsity",
						"eventDate": eventDate,
						"opponentName": opponentName,
						"fmScore": fmScore,
						"oppScore": oppScore
					})
					
					eventDate = None
					opponentName = None
					fmScore = None
					oppScore = None

	logMessage(f"found { len(dualData)} records")

	if not dualData:
		return pd.DataFrame(columns=["team", "eventDate", "opponentName", "fmScore", "oppScore"])

	dualResults = pd.DataFrame(dualData)
	return dualResults

def loadOtherDuals(dataDate, sheetsService):
	sheetId = "1-9X-ZIf_AmOe6iVCIblmAor_qdnucEZW1awvV5-ubRE"
	tabName = "Results"
	dualData = []

	result = sheetsService.spreadsheets().values().get(
		spreadsheetId=sheetId,
		range=tabName
	).execute()
	allrows = result.get('values', [])

	if not allrows or len(allrows) < 1:
		return pd.DataFrame(columns=["team", "eventDate", "opponentName", "fmScore", "oppScore"])

	header = [h.strip().lower() for h in allrows[0]]
	try:
		dateCol = header.index("date")
		vsCol = header.index("vs")
		fmScoreCol = header.index("fm score")
		oppScoreCol = header.index("opponent score")
		teamCol = header.index("team")
	except ValueError as e:
		raise Exception(f"Missing required column in varsity duals sheet: {e}")

	sevenDaysBeforeLoad = dataDate + timedelta(days=-7)

	for row in allrows[1:]: # Skip header
		if not any(row):
			continue
		
		if len(row) <= teamCol:
			continue

		try:
			eventDateStr = row[dateCol].strip()
			dateOfEvent = datetime.strptime(eventDateStr, "%m/%d/%Y")
		except (ValueError, IndexError):
			continue

		if dateOfEvent.date() > dataDate.date() or dateOfEvent.date() < sevenDaysBeforeLoad.date():
			continue

		team = row[teamCol].strip() if len(row) > teamCol else None
		opponentName = row[vsCol].strip() if len(row) > vsCol else None
		fmScore = row[fmScoreCol].strip() if len(row) > fmScoreCol else None
		oppScore = row[oppScoreCol].strip() if len(row) > oppScoreCol else None

		if opponentName and fmScore and oppScore:
			try:
				dualData.append({
					"team": team if team else "",
					"eventDate": dateOfEvent.strftime("%m/%d/%Y"),
					"opponentName": opponentName,
					"fmScore": int(fmScore),
					"oppScore": int(oppScore)
				})
			except ValueError:
				continue

	if not dualData:
		return pd.DataFrame(columns=["team", "eventDate", "opponentName", "fmScore", "oppScore"])

	return pd.DataFrame(dualData)

def loadEvents(loadDate, sheetsService):
	sheetId = "1fbXj-36b1jvVe3rsdd4MgsBRimb-52VvhqlTzUgh_5c"
	calendars = {}

	result = sheetsService.spreadsheets().values().get(
		spreadsheetId=sheetId,
		range="Schedule!A2:H"
	).execute()
	allrows = result.get('values', [])

	sevenDaysFromLoad = loadDate + timedelta(days=7)

	varsityEvents = []
	jvEvents = []
	msEvents = []

	for row in allrows:
		# Skip empty rows
		if not any(row):
			continue
		
		try:
			eventDate = datetime.strptime(row[1], "%m/%d/%Y")
		except (ValueError, IndexError):
			continue

		if eventDate < loadDate:
			# Event is in the past
			continue

		elif eventDate > sevenDaysFromLoad:
			# Event is more than one week in the future
			break

		elif len(row) > 6 and row[0] == "Varsity":
			varsityEvents.append({
				"date": row[2],
				"time": row[3],
				"event": row[4],
				"location": row[5],
				"address": row[6]
			})

		elif len(row) > 6 and row[0] == "JV":
			jvEvents.append({
				"date": row[2],
				"time": row[3],
				"event": row[4],
				"location": row[5],
				"address": row[6]
			})

		elif len(row) > 6 and row[0] == "Middle":
			msEvents.append({
				"date": row[2],
				"time": row[3],
				"event": row[4],
				"location": row[5],
				"address": row[6]
			})
	
	logMessage(f"Varsity: {len(varsityEvents)}, JV: {len(jvEvents)}, Middle: {len(msEvents)}")

	calendars["varsity"] = pd.DataFrame(varsityEvents)
	calendars["jv"] = pd.DataFrame(jvEvents)
	calendars["ms"] = pd.DataFrame(msEvents)

	return calendars

def loadSQLData(loadDate):
	datasets = {}

	logMessage("Connect to database")

	db = sqlalchemy.create_engine(f"mssql+pyodbc://{config['database']['user']}:{config['database']['password']}@{config['database']['server']}/{config['database']['database']}?driver={quote_plus('ODBC Driver 18 for SQL Server')}&encrypt=no", isolation_level="AUTOCOMMIT")

	with db.connect() as cn:
		logMessage("Create temp tables")

		cn.execute(sqlalchemy.text(sql["CreateTemp"]))

		params = { "loadDate": loadDate }
		cn.execute(sqlalchemy.text(sql["LoadTemp"]), params)

		logMessage("Load Placers")
		datasets["placers"] = pd.read_sql_query(sqlalchemy.text(sql["Placers"]), cn)

		logMessage("Load Ironman")
		datasets["ironman"] = pd.read_sql_query(sqlalchemy.text(sql["Ironman"]), cn)

		logMessage("Load Forged Fire")
		datasets["forged"] = pd.read_sql_query(sqlalchemy.text(sql["ForgedFire"]), cn)

		logMessage("Load Grinder")
		datasets["grinder"] = pd.read_sql_query(sqlalchemy.text(sql["Grinder"]), cn)

		logMessage("Load Breakout")
		datasets["breakout"] = pd.read_sql_query(sqlalchemy.text(sql["Breakout"]), cn)

		logMessage("Load Bonus")
		datasets["bonus"] = pd.read_sql_query(sqlalchemy.text(sql["Bonus"]), cn)

	return datasets

def additionalPrompts():
	prompts = []

	prompts.append("""
Our apparal store is available at: https://stores.inksoft.com/FM_Wrestling/shop/products/all?page=1&fbclid=IwY2xjawNwwNRleHRuA2FlbQIxMQABHmQ1r3fxN_ZwHdX7byo4amL0T-AG-dSdkuIbtduEGyHfWV9tmQC-Vy4CFc4v_aem_61FmzRh56l4jJ9nPJUI07A
- Show Yellow Jacket pride at all events
- Great for gifts
- Fill the gym with blue and yellow
""")
	
	return prompts

def getParentEmails(sheetsService):
	spreadsheetId = "1Pfi643FJqtnOERCJf_xA4ug8FLVMhn-KvlHLxrVB5z4"
	sheetName = "Parent Emails"

	headerResponse = sheetsService.spreadsheets().values().get(
		spreadsheetId=spreadsheetId, 
		range=f"{sheetName}!A1:Z1"
	).execute()
	headerRow = headerResponse.get('values', [[]])[0]
	emailColumnIndex = headerRow.index("Email Address")
	emailColumn = chr(65 + emailColumnIndex)

	teamEmailResponse = sheetsService.spreadsheets().values().get(
		spreadsheetId=spreadsheetId, 
		range=f"{sheetName}!{emailColumn}2:{emailColumn}"
	).execute()
	parentEmails = [item for sublist in teamEmailResponse.get('values', []) for item in sublist]

	return parentEmails

# -------------------- Script Start ----------------- 

logMessage("---- Startup ----")

sql = loadSQL()
loadDate = datetime.now()
# loadDate = datetime(2025, 12, 15)

with open("./config.json", "r") as reader:
	config = json.load(reader)

try:
	creds = service_account.Credentials.from_service_account_file(
		'./credentials.json',
		scopes=[
			"https://www.googleapis.com/auth/spreadsheets.readonly"
		]
	)
	
	sheetsService = build('sheets', 'v4', credentials=creds)
	calendarService = build('calendar', 'v3', developerKey=config["calendarAPIKey"])

except Exception as error:
	errorMessage = f"Error loading service account credentials: {error}"
	errorLogging(errorMessage)
	sys.exit(1)

logMessage("---- Load Data ----")

logMessage("Load Dual Results")
try:
	dualResults = loadVarsityDuals(loadDate, sheetsService)

	logMessage("Load Other Team Duals")
	otherDuals = loadOtherDuals(loadDate, sheetsService)
	if not otherDuals.empty:
		dualResults = pd.concat([dualResults, otherDuals], ignore_index=True)

except Exception as error:
	errorMessage = f"Error loading dual results: {error}"
	errorLogging(errorMessage)
	sys.exit(1)

logMessage("Load Calendar")
try:
	calendarResults = loadEvents(loadDate, sheetsService)
except Exception as error:
	errorMessage = f"Error loading calendar data: {error}"
	errorLogging(errorMessage)
	sys.exit(1)

logMessage("Load SQL Data")
try:
	dataResults = loadSQLData(loadDate)
except Exception as error:
	errorMessage = f"Error data from SQL: {error}"
	errorLogging(errorMessage)
	sys.exit(1)

logMessage("Get Parent Emails")
try:
	parentEmails = getParentEmails(sheetsService)
except Exception as error:
	errorMessage = f"Error loading parent emails: {error}"
	errorLogging(errorMessage)
	sys.exit(1)

prompts = additionalPrompts()

logMessage("---- Email Generation and Send ----")

try:
	logMessage(f"AI Email Generation")
	
	with open("./parentweekly/parentweekly.css", "r") as reader:
		templateCSS = reader.read()

	url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={config['geminiAPIKey']}"

	prompt = f"""
You are a team parent with the fort mill high school wrestling team, the Fort Mill Yellow Jackets. Your task is to create a weekly email for { loadDate.strftime('%A, %B %d, %Y')} using the data provided that is clear and informative.

Here are your instructions:
- Create a well formatted email using HTML.
- The entire response should be a single HTML document.
- In the HTML <head>, you must include a <style> tag and copy the contents of the **Email CSS** section into it. This is critical for correct formatting.
- The HTML should be responsive for both mobile or desktop viewing. Use divs around tables to allow horizontal scrolling.
- Create a section for each dataset.
- Each section should build on each other.
- For the performance highlights, create a separate table for each division, and don't call them awards (this is not from the coach)
- Provide commentary for each section with highlights, and callouts.
- Make it fun by adding emoji
- Don't include a subject.

Email Structure
- Upcoming Events"""
	
	if len(dualResults) > 0:
		prompt += f"""
- Dual Results"""
		
	prompt += f"""
- Additional Information
"""
	
	if len(dataResults["placers"]) > 0 or len(dataResults["ironman"]) > 0 or len(dataResults["forged"]) > 0 or len(dataResults["grinder"]) > 0:
		prompt += f"""
- Performance Highlights
"""
	prompt += f"""
---

** Email CSS **

{templateCSS}

---

Upcoming Events

Varsity
{calendarResults["varsity"].to_html(index=False, classes="table")}

JV
{calendarResults["jv"].to_html(index=False, classes="table")}

Middle School
{calendarResults["ms"].to_html(index=False, classes="table")}
"""

	if len(dualResults) > 0:
		prompt += f"""
---

Dual Results
{dualResults.to_html(index=False, classes="table")}
"""

	if len(prompts) > 0:
		prompt += f"""
---

Additional Information 

{ "\n---\n".join(prompts) }
"""

	if len(dataResults["placers"]) > 0 or len(dataResults["ironman"]) > 0 or len(dataResults["forged"]) > 0 or len(dataResults["grinder"]) > 0:
		prompt += f"""
---

** Individual Performance Highlights **
"""
	
		if len(dataResults["placers"]) > 0:
			prompt += f"""
---
Placers
{dataResults["placers"].to_html(index=False, classes="table")}

---
"""

		if len(dataResults["ironman"]) > 0:
			prompt += f"""
---
Ironman
{dataResults["ironman"].to_html(index=False, classes="table")}
"""

		if len(dataResults["forged"]) > 0:
			prompt += f"""
---
Forged in Fire
{dataResults["forged"].to_html(index=False, classes="table")}
"""
	
		if len(dataResults["grinder"]) > 0:
			prompt += f"""
---
Grinder
{dataResults["grinder"].to_html(index=False, classes="table")}
---
"""

	requestBody = {"contents": [{"parts": [{"text": prompt}]}]}
	response = requests.post(url, json=requestBody, headers={"Content-Type": "application/json"})

	if response.status_code == 200:
		geminiResponse = response.json()['candidates'][0]['content']['parts'][0]['text']

		if geminiResponse[0:7] == "```html":
			geminiResponse = geminiResponse[7:]
		
		if geminiResponse[-3:] == "```":
			geminiResponse = geminiResponse[:-3]

	else:
		raise Exception(f"Error calling Gemini API. Status: {response.status_code}. Response: {response.text}")

except Exception as error:
	errorMessage = f"Error during AI generation: {error}"
	errorLogging(errorMessage)
	sys.exit(1)

try:
	logMessage(f"Inlining CSS")
	inlinedHtml = premailer.transform(geminiResponse)
	subject = f"FM Wrestling Weekly Email • {loadDate.strftime('%m/%d/%Y')}"
	batchSize = 40

	logMessage(f"Sending Email")

	# Send email to review
	mimeMessage = MIMEMultipart()
	mimeMessage['To'] = f'"Brett van Beynum" <maildrop444@gmail.com>'
	mimeMessage['Subject'] = subject
	mimeMessage.attach(MIMEText(inlinedHtml, 'html'))

	with smtplib.SMTP_SSL('smtp.gmail.com', 465) as smtp:
		smtp.login("wrestlingfortmill@gmail.com", config['googleAppPassword'])
		smtp.send_message(mimeMessage)

	# Create drafts
	imap = imaplib.IMAP4_SSL("imap.gmail.com")
	imap.login("wrestlingfortmill@gmail.com", config['googleAppPassword'])

	for emailIndex in range(0, len(parentEmails), batchSize):
		emailBatch = parentEmails[emailIndex:emailIndex+batchSize]
	
		mimeMessage = MIMEMultipart()
		mimeMessage['To'] = f'"Fort Mill Wrestling" <wrestlingfortmill@gmail.com>'
		mimeMessage['Bcc'] = ','.join(emailBatch)
		mimeMessage['Subject'] = subject
		mimeMessage.attach(MIMEText(inlinedHtml, 'html'))

		imap.append('[Gmail]/Drafts', '', imaplib.Time2Internaldate(time.time()), mimeMessage.as_bytes())
		logMessage(f"Created draft for batch {emailIndex//batchSize + 1}")
	
	mimeMessage = MIMEMultipart()
	mimeMessage['To'] = f'"Joelle Brotemarkle" <Brotemarkle.joelle@gmail.com>'
	mimeMessage['Subject'] = subject
	mimeMessage.attach(MIMEText(inlinedHtml, 'html'))

	imap.append('[Gmail]/Drafts', '', imaplib.Time2Internaldate(time.time()), mimeMessage.as_bytes())
	logMessage(f"Created draft for Joelle Brotemarkle")

except Exception as error:
	errorMessage = f"Error sending email: {error}"
	errorLogging(errorMessage)
	sys.exit(1)

logMessage("---- Complete ----")
