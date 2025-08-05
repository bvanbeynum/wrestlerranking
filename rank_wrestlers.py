
import os
import pyodbc
import json
from datetime import timedelta

def get_connection():
    with open('config.json', 'r') as f:
        config = json.load(f)

    db_config = config['database']
    conn_str = f"DRIVER={{ODBC Driver 18 for SQL Server}};SERVER={db_config['server']};DATABASE={db_config['database']};UID={db_config['user']};PWD={db_config['password']}"
    return pyodbc.connect(conn_str)

def execute_query(conn, query_name, params=None):
    with conn.cursor() as cursor:
        if params:
            cursor.execute(sql_queries[query_name], params)
        else:
            cursor.execute(sql_queries[query_name])
        return cursor.fetchall()

def main():
    sql_queries = {}
    for filename in os.listdir('sql'):
        if filename.endswith('.sql'):
            with open(os.path.join('sql', filename), 'r') as f:
                sql_queries[filename.replace('.sql', '')] = f.read()

    conn = get_connection()

    # 1. Get all wrestlers
    wrestlers = execute_query(conn, 'get_wrestlers')

    # 2. Get all matches
    matches = execute_query(conn, 'get_matches')

    # 3. Get match winner and loser
    match_results = execute_query(conn, 'get_match_winner_and_loser')

    # 4. Glicko-2 calculation
    # Initialize wrestlers with default ratings
    players = {row.ID: glicko2.Player(rating=1500, rd=500, vol=0.06) for row in wrestlers}

    # Group matches by week
    matches_by_week = {}
    for match in matches:
        event_date = match.EventDate
        week_end = event_date + timedelta(days=6 - event_date.weekday())
        if week_end not in matches_by_week:
            matches_by_week[week_end] = []
        matches_by_week[week_end].append(match)

    # Process matches week by week
    for week_end in sorted(matches_by_week.keys()):
        # Create a list of match results for each player for the current week
        player_results = {player_id: [] for player_id in players.keys()}
        for match in matches_by_week[week_end]:
            winner_id = [r.WinnerID for r in match_results if r.EventMatchID == match.ID][0]
            loser_id = [r.LoserID for r in match_results if r.EventMatchID == match.ID][0]

            winner = players[winner_id]
            loser = players[loser_id]

            player_results[winner_id].append((loser.rating, loser.rd, 1))
            player_results[loser_id].append((winner.rating, winner.rd, 0))

        # Update ratings for the week
        for player_id, results in player_results.items():
            if results:
                players[player_id].rate(results)
                # Log the rating change
                execute_query(conn, 'insert_wrestler_rating', (player_id, week_end, players[player_id].rating, players[player_id].rd))

    # 5. Update wrestler ratings
    for player_id, player in players.items():
        execute_query(conn, 'update_event_wrestler', (player.rating, player.rd, player_id))

    conn.close()

if __name__ == '__main__':
    main()

