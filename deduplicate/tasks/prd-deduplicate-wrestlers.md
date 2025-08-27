# PRD: Wrestler Deduplication Script

## 1. Introduction/Overview

This document outlines the requirements for creating a T-SQL script to identify potential duplicate wrestler records within the database. The primary problem is that minor variations in wrestler names (e.g., "Jon Smith" vs. "John Smith") on the same team can lead to multiple records for a single individual. This skews data, affects ranking accuracy, and complicates reporting.

The goal of this task is to create a script that generates a clear, actionable report of these potential duplicates for manual review and future merging. The script will not perform any data modification itself.

## 2. Goals

- **Identify Duplicates:** Develop a T-SQL script that programmatically finds potential duplicate wrestler records based on name similarity and team affiliation.
- **Generate a Report:** Produce a clean result set that pairs a suggested "survivor" record with its potential "duplicate" for easy manual review.
- **Improve Data Integrity:** Provide the necessary data to allow administrators to clean up the wrestler database, leading to more accurate analytics and rankings.

## 3. User Stories

- "As a data analyst, I want to identify and get a report of duplicate wrestler records so that our rankings and reports are more accurate."

## 4. Functional Requirements

1.  The script must be written in T-SQL for Microsoft SQL Server.
2.  The script must only compare wrestlers who are registered to the same team.
3.  The script must identify potential duplicates using two distinct methods:
    - **Levenshtein Distance:** Names that have a Levenshtein distance of 1 or 2.
    - **Phonetic Similarity:** Names that have the same `SOUNDEX` value.
4.  The script must produce a single result set for manual review with the following columns:
    - `SurvivorWrestlerID`: The ID of the wrestler record recommended to be kept.
    - `SurvivorWrestlerName`: The name of the survivor wrestler.
    - `DuplicateWrestlerID`: The ID of the wrestler record recommended for merging/deletion.
    - `DuplicateWrestlerName`: The name of the duplicate wrestler.
    - `TeamName`: The name of the team the wrestlers share.
    - `DetectionMethod`: A field indicating how the match was found ('Levenshtein' or 'Soundex').
    - `SimilarityScore`: The Levenshtein distance if applicable, otherwise NULL.
5.  The "Survivor" record in any potential duplicate pair must be determined using the following priority:
    - **Primary Rule:** The wrestler with the greater number of associated matches.
    - **Tie-Breaker Rule:** If the match count is equal, the wrestler with the earlier creation date (the oldest record) is the survivor.
6.  The script must be read-only. It **must not** `UPDATE`, `DELETE`, or `MERGE` any data in the database.

## 5. Non-Goals (Out of Scope)

- This feature will **not** automatically merge or delete any records. All merging actions will be handled manually in a separate process.
- This feature will **not** re-assign associated records (e.g., matches) from a duplicate wrestler to a survivor wrestler.
- This feature will **not** include a user interface (UI) for reviewing or acting upon the results. The output is strictly a SQL result set.

## 6. Technical Considerations

- The script's logic will depend on a `LEVENSHTEIN` function being available in the database. If a native function does not exist, a User-Defined Function (UDF) for calculating Levenshtein distance will need to be created first.
- The built-in T-SQL `SOUNDEX()` function should be used for the phonetic comparison.
- The self-join logic for comparing wrestlers on the same team should be optimized to avoid excessive performance degradation on large datasets.

## 7. Success Metrics

- The script successfully identifies over 80% of known, manually-found duplicates in a test environment.
- The generated report is deemed clear and actionable by the data analysis team.
- A measurable reduction in data-related support tickets or manual cleanup tasks within three months of using the script's output.

## 8. Open Questions

- What are the specific table and column names for:
    - Wrestler's Team affiliation?
    - Wrestler's creation date?
    - Wrestler's name?
    - The link between a wrestler and their matches (to get the count)?
- Does a `LEVENSHTEIN` User-Defined Function (UDF) already exist in the target database?