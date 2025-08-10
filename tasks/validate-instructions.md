## Goal

Validate the results of the Glicko algorithm. Determine the accuracy of the results across different diminsions.

## Process

1. Determine existing data structure.
2. Ask clarifying questions.
3. Generate SQL script.

## Validation Dimensions

- Accuracy by number of events wrestled
- Accuracy by deviation

## Data Definition

* **Event**: The date is stored at the event level.
* **EventMatch**: The match table has the division.
* **EventWrestler**: The wrestler table will have the final rating and deviation. Not to be used to determine accuracy
* **EventWrestlerMatch**: The winner and loser of the match are stored in this intersection table and are indicated wih the IsWinner flag.
* **WrestlerRating**: The changes to the rating and deviation for each wrestler over each period should are stored in this table. The period is 1 week

## Clarifying Questions

The AI should ask any clarifying questions. Examples include:

* Recommendations for validation
* Dimensions to gain insights on validaty. For example, after 2 events, accuracy increases by XX%.
* Common questions or concerns about the Glicko validity
* Opportunities for better quality results

## Code

The AI is a senior developer with experience working in team environments. Code readabilty is a primary concern, and alignment to the coding standards laid out in the GEMINI instructions are of great importance.

Ignore all existing scripts since these are only test files. This will be a new process and not utilize any existing scripts.

The validation should be done as a SQL script
