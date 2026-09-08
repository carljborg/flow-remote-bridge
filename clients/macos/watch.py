#!/usr/bin/env python3
"""Forward new Flow dictations targeted at a connected, foreground Parsec client."""
import argparse
import json
from pathlib import Path
import re
import sqlite3
import subprocess
import time

from policy import formatted_body, history_rows, parsec_connected, pending_action


def log(message):
    # Never log transcript bodies or exception messages (which can contain payloads).
    print(time.strftime('%Y-%m-%dT%H:%M:%S'), message, flush=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--config', type=Path, default=Path.home() / '.config/flow-remote-bridge/config.json')
    parser.add_argument('--health', action='store_true')
    args = parser.parse_args()
    config = json.loads(args.config.read_text())
    host = config['ssh_host']
    client = config['client_id']
    if not re.fullmatch(r'[A-Za-z0-9_-]{1,64}', client):
        raise SystemExit('client_id must contain 1–64 letters, digits, underscores or hyphens')
    if not host or host.startswith('-') or any(c.isspace() for c in host):
        raise SystemExit('ssh_host must be an SSH alias or user@host, not SSH options')
    app_id = 'tv.parsec.www'
    database = Path(config.get('flow_database', '~/Library/Application Support/Wispr Flow/flow.sqlite')).expanduser()
    parsec_log = Path(config.get('parsec_log', '~/.parsec/log.txt')).expanduser()
    frontmost = Path(__file__).with_name('frontmost')

    def foreground():
        try:
            with parsec_log.open('rb') as stream:
                stream.seek(0, 2)
                stream.seek(max(0, stream.tell() - 131072))
                if not parsec_connected(stream.read().decode('utf-8', 'replace')):
                    return False
            return subprocess.check_output([str(frontmost)], text=True, timeout=3).strip() == app_id
        except (OSError, subprocess.SubprocessError):
            return False

    def request(payload):
        payload['client'] = client
        response = subprocess.run(
            ['ssh', '-T', '-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=yes',
             '-o', 'ConnectTimeout=5', host, '.local/bin/flow-remote-submit'],
            input=json.dumps(payload, ensure_ascii=False) + '\n', encoding='utf-8',
            capture_output=True, timeout=12)
        if response.returncode:
            return {'status': 'transport-failed'}
        return json.loads(response.stdout)

    if args.health:
        print(json.dumps(request({'op': 'health'})))
        return

    while True:
        try:
            connection = sqlite3.connect(database.as_uri() + '?mode=ro', uri=True, timeout=1)
            connection.row_factory = sqlite3.Row
            watermark = connection.execute('SELECT coalesce(max(rowid),0) FROM History').fetchone()[0]
            break
        except sqlite3.Error:
            log('Waiting for Flow history database')
            time.sleep(5)
    pending = {}
    log('Started; existing history excluded')
    while True:
        try:
            for row in history_rows(connection, watermark, pending, app_id):
                number = row['rowid']
                fresh = number > watermark
                watermark = max(watermark, number)
                if fresh:
                    if row['app'] and row['app'] != app_id:
                        continue
                    if len(pending) >= 64 or not foreground():
                        continue
                    arm = request({'op': 'arm', 'id': row['transcriptEntityId']})
                    if arm.get('status') != 'armed':
                        log('Arm skipped: ' + arm.get('status', 'unknown'))
                        continue
                    pending[number] = dict(id=row['transcriptEntityId'], token=arm['token'],
                                           born=time.monotonic(), body=None, stable=0)
                item = pending.get(number)
                if not item:
                    continue
                action = pending_action(time.monotonic() - item['born'], foreground())
                if action == 'expire':
                    del pending[number]
                    log('Cancelled: expired')
                    continue
                if row['app'] and row['app'] != app_id:
                    del pending[number]
                    continue
                if action == 'pause':
                    continue
                body = formatted_body(row, app_id)
                if body:
                    if item['body'] != body:
                        item.update(body=body, stable=time.monotonic())
                        continue
                    if time.monotonic() - item['stable'] < 0.7:
                        continue
                    if foreground():
                        del pending[number]  # Consume only when attempting delivery; never retry.
                        reply = request(dict(op='paste', id=item['id'], token=item['token'], text=body))
                        log('Delivery: ' + reply.get('status', 'unknown')
                            + ' age_s=' + str(int(time.monotonic() - item['born']))
                            + ' bytes=' + str(len(body.encode('utf-8'))))
            time.sleep(0.3)
        except Exception as error:
            pending.clear()
            log('Paused: ' + type(error).__name__)
            time.sleep(2)


if __name__ == '__main__':
    main()
