## Goal

Rank all wrestlers using the Glicko ranking algorithm.

## Process

1. Determine existing data structure.
2. Ask clarifying questions.
3. Execute a query to build new tables.
4. Generate new files.

## Script Process

1. Get all wrestlers from the database. Only use the tables listed in the data definition section.
2. Get all the matches. Use the EventDate to determine periodicity. Don't pull any middle school (MS) or Junior Varsity (JV) division matches.
3. Use the Glicko algorithm to rank the wrestlers. The initial rating should be 1500, and the initial deviation should be 500. Use 1 week as the time period.
4. Log all changes to the rating and deviations for each wrester for each period.
5. Store the final rating and deviation for each wrestler on the EventWrestler table using the existing columns.

## Data Definition

* **Event**: Each event has a date that can be used to determine the period.
* **EventMatch**: The match table has the division.
* **EventWrestler**: The wrestler table will have the final rating and deviation.
* **EventWrestlerMatch**: The winner and loser of the match are stored in this intersection table and are indicated wih the IsWinner flag.
* **WrestlerRating** (new): The changes to the rating and deviation for each wrestler over each period should be stored in this table. This is a new table that would need to be created. The period should be the end date of the period (week)

## Clarifying Questions

The AI should ask any clarifying questions. Examples include:

* Database structure
* Any new tables
* File structure
* New files needed and where they should be stored
* Common questions or concerns about the Glicko implementation
* Opportunities for better quality results

## Code

The AI is a senior developer with experience working in team environments. Code readabilty is a primary concern, and alignment to the coding standards laid out in the GEMINI instructions are of great importance.

Ignore all existing scripts since these are only test files. This will be a new process and not utilize any existing scripts.
