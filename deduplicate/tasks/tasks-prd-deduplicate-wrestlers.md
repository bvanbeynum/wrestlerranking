## Relevant Files

- `deduplicate/get_wrestler_team_history.sql` - New script to get the team history for each wrestler.
- `deduplicate/get_wrestler_pairs.sql` - New script to get wrestler pairs who have wrestled for the same team.
- `deduplicate/compare_wrestler_names.sql` - New script to compare wrestler names using Levenshtein and Soundex.
- `deduplicate/determine_survivor_wrestler.sql` - New script to determine the survivor and duplicate records.
- `deduplicate/generate_deduplication_report.sql` - New script to generate the final deduplication report.
- `deduplicate/test_deduplication.sql` - New script to test the deduplication logic.

## Tasks

- [x] 1.0 Create a script to get the team history for each wrestler
  - [x] 1.1 Create a new SQL file `get_wrestler_team_history.sql` in the `deduplicate` directory.
  - [x] 1.2 Write a query to select `WrestlerID` and `TeamName` from the `EventWrestlerMatch` table.
  - [x] 1.3 Use `DISTINCT` to ensure each wrestler-team pair is unique.
- [x] 2.0 Create the base query to select wrestler pairs who have wrestled for the same team
  - [x] 2.1 Create a new SQL file `get_wrestler_pairs.sql` in the `deduplicate` directory.
  - [x] 2.2 Use the logic from `get_wrestler_team_history.sql` in a CTE.
  - [x] 2.3 Self-join the CTE on `TeamName` to create pairs of wrestlers who have wrestled for the same team.
  - [x] 2.4 Ensure the self-join excludes pairs of the same wrestler record (`w1.WrestlerID <> w2.WrestlerID`).
- [x] 3.0 Implement Levenshtein distance and Soundex comparison logic
  - [x] 3.1 Create a new SQL file `compare_wrestler_names.sql` in the `deduplicate` directory.
  - [x] 3.2 Add a user-defined function for Levenshtein distance to the script.
  - [x] 3.3 Add a `WHERE` clause to filter the wrestler pairs based on a Levenshtein distance of 1 or 2.
  - [x] 3.4 Add to the `WHERE` clause to also include pairs with the same `SOUNDEX` value.
  - [x] 3.5 Use an `OR` condition to combine the Levenshtein and Soundex filters.
- [x] 4.0 Determine the survivor and duplicate records based on match count and creation date
  - [x] 4.1 Create a new SQL file `determine_survivor_wrestler.sql` in the `deduplicate` directory.
  - [x] 4.2 Create a CTE to count the number of matches for each wrestler from the `EventWrestlerMatch` table.
  - [x] 4.3 Join the match count CTE to the wrestler pairs.
  - [x] 4.4 Add a `CASE` statement to determine the survivor based on the rules in the PRD (higher match count, then older record).
  - [x] 4.5 Structure the query to clearly label the `SurvivorWrestlerID`, `SurvivorWrestlerName`, `DuplicateWrestlerID`, and `DuplicateWrestlerName`.
- [x] 5.0 Finalize the report format and add comments
  - [x] 5.1 Create a new SQL file `generate_deduplication_report.sql` in the `deduplicate` directory.
  - [x] 5.2 Combine the logic from the previous scripts into a single query.
  - [x] 5.3 Add the `TeamName`, `DetectionMethod` and `SimilarityScore` columns to the final `SELECT` statement.
  - [x] 5.4 Ensure the `DetectionMethod` column correctly indicates 'Levenshtein' or 'Soundex'.
  - [x] 5.5 Add comments to the SQL script to explain the logic of the different sections.
- [ ] 6.0 Create a script to test the deduplication logic with sample data
  - [ ] 6.1 Create a new SQL file `test_deduplication.sql` in the `deduplicate` directory.
  - [ ] 6.2 Create temporary tables for `Wrestler`, `Team`, and `EventWrestlerMatch`.
  - [ ] 6.3 Insert sample data into the temporary tables, including known duplicates.
  - [ ] 6.4 Execute the `generate_deduplication_report.sql` logic against the temporary tables.
  - [ ] 6.5 Print the results to verify the output.
  - [ ] 6.6 Drop the temporary tables.
