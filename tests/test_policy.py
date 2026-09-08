import sqlite3
import sys
from pathlib import Path
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'clients/macos'))
from policy import formatted_body, history_rows, parsec_connected


class PolicyTests(unittest.TestCase):
    def setUp(self):
        self.db = sqlite3.connect(':memory:')
        self.db.row_factory = sqlite3.Row
        self.db.execute('CREATE TABLE History(transcriptEntityId, status, app, pastedText, formattedText)')
        self.app = 'tv.parsec.www'

    def tearDown(self):
        self.db.close()

    def insert(self, ident, app, status='formatted', pasted='', formatted=''):
        return self.db.execute('INSERT INTO History VALUES(?,?,?,?,?)',
                               (ident, status, app, pasted, formatted)).lastrowid

    def test_old_history_excluded(self):
        old = self.insert('old', self.app, pasted='old text')
        self.assertEqual(history_rows(self.db, old, [], self.app), [])
        new = self.insert('new', self.app, pasted='new text')
        rows = history_rows(self.db, old, [], self.app)
        self.assertEqual([r['rowid'] for r in rows], [new])

    def test_other_app_text_not_returned(self):
        self.insert('other', 'local-editor', pasted='must stay local')
        row = history_rows(self.db, 0, [], self.app)[0]
        self.assertEqual(row['body'], '')
        self.assertIsNone(formatted_body(row, self.app))

    def test_unicode_spacing_and_fallback(self):
        self.insert('unicode', self.app, pasted='Hei æøå 👋\n世界 ', formatted='different')
        self.insert('fallback', self.app, formatted='fallback')
        rows = history_rows(self.db, 0, [], self.app)
        self.assertEqual(formatted_body(rows[0], self.app), 'Hei æøå 👋\n世界 ')
        self.assertEqual(formatted_body(rows[1], self.app), 'fallback')

    def test_pending_row_update_is_observed(self):
        row_id = self.insert('pending', None, status=None)
        self.db.execute('UPDATE History SET app=?,status=?,pastedText=? WHERE rowid=?',
                        (self.app, 'formatted', 'completed', row_id))
        rows = history_rows(self.db, row_id, [row_id], self.app)
        self.assertEqual(formatted_body(rows[0], self.app), 'completed')

    def test_incomplete_status_never_qualifies(self):
        self.insert('unfinished', self.app, status='processing', pasted='partial')
        self.assertIsNone(formatted_body(history_rows(self.db, 0, [], self.app)[0], self.app))

    def test_latest_parsec_event_wins(self):
        self.assertFalse(parsec_connected(''))
        self.assertTrue(parsec_connected('[I] Client Status received: 0\nordinary line'))
        self.assertFalse(parsec_connected('Client Status received: 0\nClient Status received: 20'))
        self.assertFalse(parsec_connected('Client Status received: 0\n===== Parsec: started'))
        self.assertTrue(parsec_connected('===== Parsec: started\nClient Status received: 0'))
        self.assertFalse(parsec_connected('Client Status received: 01'))


if __name__ == '__main__':
    unittest.main()
