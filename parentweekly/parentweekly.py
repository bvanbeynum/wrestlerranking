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

def loadDualResults(dataDate, sheetsService):
	sheetId = "1-jIN_qDGDd9GC2FNQmfN8ysvddnOmu8-9Lwhnabv4a8"
	tabName = "2024-2025 Duals" #"2025-26 Duals"
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

	for row in allrows:
		# Skip empty rows
		if not any(row):
			continue

		if len(row) > totalColumnIndex and len(row) > 2:
			
			if row[0]:
				currentEventDateStr = row[0].strip()
				dateOfEvent = datetime.strptime(currentEventDateStr, "%m/%d/%Y").date()
				if dateOfEvent > dataDate.date():
					break
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
					dateOfEvent = datetime.strptime(eventDate, "%m/%d/%Y").date()
					isPastWeek = (datetime.now().date() - dateOfEvent).days <= 7 and (datetime.now().date() - dateOfEvent).days >= 0
					
					dualData.append({
						"eventDate": eventDate,
						"opponentName": opponentName,
						"fmScore": fmScore,
						"oppScore": oppScore,
						"isPastWeek": isPastWeek
					})
					
					eventDate = None
					opponentName = None
					fmScore = None
					oppScore = None

	logMessage(f"found { len(dualData)} records")

	if not dualData:
		return pd.DataFrame(columns=["eventDate", "opponentName", "fmScore", "oppScore", "isPastWeek"])

	dualResults = pd.DataFrame(dualData)
	return dualResults

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
			eventDate = datetime.strptime(row[2], "%m/%d/%Y")
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
				"address": row[6],
				"payment": row[7] if len(row) > 7 else ""
			})

		elif len(row) > 6 and row[0] == "JV":
			jvEvents.append({
				"date": row[2],
				"time": row[3],
				"event": row[4],
				"location": row[5],
				"address": row[6],
				"payment": row[7] if len(row) > 7 else ""
			})

		elif len(row) > 6 and row[0] == "Middle":
			msEvents.append({
				"date": row[2],
				"time": row[3],
				"event": row[4],
				"location": row[5],
				"address": row[6],
				"payment": row[7] if len(row) > 7 else ""
			})
	
	logMessage(f"Varsity: {len(varsityEvents)}, JV: {len(jvEvents)}, Middle: {len(msEvents)}")

	calendars["varsity"] = pd.DataFrame(varsityEvents)
	calendars["jv"] = pd.DataFrame(jvEvents)
	calendars["ms"] = pd.DataFrame(msEvents)

	return calendars

# def loadCalendar(dataDate, calendarService):
# 	varsityCalendarId = "socialcranberry.com_n7ukj4ggnsvi6mncqei7b0g6ec@group.calendar.google.com"
# 	middleCalendarId = "socialcranberry.com_69uthbij08ikd9jui20mg4q728@group.calendar.google.com"

# 	calendars = {}

# 	# Get the current time in UTC (RFC3339 format)
# 	# This tells the API to get events starting from "now"
# 	nowUTC = dataDate.replace(tzinfo=timezone.utc)
# 	timeMin = nowUTC.isoformat()

# 	# Calculate days until Sunday (Monday=0, Sunday=6)
# 	daysUntilSunday = (6 - nowUTC.weekday())

# 	# Get the date for the upcoming Sunday
# 	sundayDate = nowUTC.date() + timedelta(days=daysUntilSunday)

# 	timeMax = datetime(sundayDate.year, sundayDate.month, sundayDate.day, 23, 59, 59, tzinfo=timezone.utc).isoformat()
# 	logMessage(f"Range: {timeMin} to {timeMax}")

# 	# Call the Calendar API
# 	eventsResult = calendarService.events().list(
# 		calendarId=varsityCalendarId,
# 		timeMin=timeMin,
# 		timeMax=timeMax,
# 		maxResults=50,
# 		singleEvents=True, # Expand recurring events
# 		orderBy='startTime' # Order them by start time
# 	).execute()

# 	calendars["varsity"] = pd.DataFrame([ {
# 			"startDate": event["start"],
# 			"endDate": event["end"],
# 			"summary": event["summary"],
# 			"location": event.get("location", "")
# 		} for event in eventsResult.get('items', []) if not re.search(r'practice', event["summary"], re.IGNORECASE)
#  ])

# 	logMessage(f"Loaded { len(calendars["varsity"])} varsity events")

# 	# Call the Calendar API
# 	eventsResult = calendarService.events().list(
# 		calendarId=middleCalendarId,
# 		timeMin=timeMin,
# 		timeMax=timeMax,
# 		maxResults=50,
# 		singleEvents=True, # Expand recurring events
# 		orderBy='startTime' # Order them by start time
# 	).execute()

# 	calendars["middle"] = pd.DataFrame([ {
# 			"startDate": event["start"],
# 			"endDate": event["end"],
# 			"summary": event["summary"],
# 			"location": event.get("location", "")
# 		} for event in eventsResult.get('items', []) if not re.search(r'practice', event["summary"], re.IGNORECASE)
# 	])
	
# 	return calendars

def loadSQLData(loadDate):
	datasets = {}

	logMessage("Connect to database")

	db = sqlalchemy.create_engine(f"mssql+pyodbc://{config['database']['user']}:{config['database']['password']}@{config['database']['server']}/{config['database']['database']}?driver={quote_plus("ODBC Driver 18 for SQL Server")}&encrypt=no", isolation_level="AUTOCOMMIT")

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
	
	prompts.append("""
Request support for the Blue & Gold tournament that we're hosting on 11/22/2025.
- Volunteer signup: https://www.signupgenius.com/go/10C0C4CACA722ABF4CF8-60444081-blue/48549563#/
- Food signup: https://www.signupgenius.com/go/10C0C4CACA722ABF4CF8-60444313-blue/48549563#/
- Include a countdown to the tournament.
- Great way to meet other team parents.
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
loadDate = datetime(2025, 11, 16)

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
	dualResults = loadDualResults(loadDate, sheetsService)
except Exception as error:
	errorMessage = f"Error dual results: {error}"
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
1 Upcoming Events
2 Dual Results
3 Additional Information
4 Performance Highlights

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

	if len(dataResults["ironman"]) > 0 or len(dataResults["forged"]) > 0 or len(dataResults["grinder"]) > 0:
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
	subject = f"Weekly Email Analysis - {loadDate.strftime('%m/%d/%Y')}"
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

except Exception as error:
	errorMessage = f"Error sending email: {error}"
	errorLogging(errorMessage)
	sys.exit(1)

logMessage("---- Complete ----")
