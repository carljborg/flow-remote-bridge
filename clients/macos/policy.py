"""Small, testable pieces of the Flow-history and Parsec connection policy."""
import sqlite3


def history_rows(connection, watermark, pending_ids, app_id):
    ids = list(pending_ids)
    clause = ' OR rowid IN (' + ','.join('?' for _ in ids) + ')' if ids else ''
    return connection.execute(
        "SELECT rowid, transcriptEntityId, status, app, "
        "CASE WHEN app=? THEN coalesce(nullif(pastedText,''),formattedText,'') "
        "ELSE '' END AS body FROM History WHERE rowid>?" + clause +
        ' ORDER BY rowid LIMIT 128', [app_id, watermark, *ids]).fetchall()


def parsec_connected(log_tail):
    events = [line.strip() for line in log_tail.splitlines()
              if 'Client Status received:' in line or '===== Parsec:' in line]
    return bool(events and events[-1].endswith('Client Status received: 0'))


def formatted_body(row, app_id):
    if row['app'] == app_id and row['status'] == 'formatted' and row['body']:
        return row['body']
    return None


def pending_action(age_seconds, foreground):
    """Keep an armed target while away; never renew its original expiry."""
    if age_seconds > 1500:
        return 'expire'
    return 'ready' if foreground else 'pause'
