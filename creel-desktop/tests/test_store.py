import copy
import io
import json
from pathlib import Path
import stat
import sys
import tempfile
import unittest
import uuid
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from store import Store, canonical, sha, review_source_fingerprint, inherited_context

DATE = '2026-09-17T10:00:00Z'


def fixture():
    tid, eid, aid = (str(uuid.uuid4()) for _ in range(3))
    media = b'An original media payload, untouched.'
    attachment = {'id': aid, 'path': 'media/' + aid + '.m4a', 'mime_type': 'audio/mp4',
                  'byte_length': len(media), 'sha256': sha(media), 'captured_at': DATE,
                  'origin': 'test', 'duration': 3.0}
    trip = {'id': tid, 'revision': 1, 'title': 'An evening', 'waterbody': 'Madison',
            'created_at': DATE, 'started_at': DATE, 'timezone': 'America/Denver',
            'companions': '', 'outcome': 'unspecified', 'moments': []}
    event = {'id': eid, 'trip_id': tid, 'revision': 1, 'kind': 'unclassified',
             'captured_at': DATE, 'updated_at': DATE, 'occurrence_basis': 'unknown',
             'text_history': [{'text': 'Saw an otter near the side channel.', 'saved_at': DATE}],
             'attachments': [attachment], 'deleted': False}
    return trip, [event], {attachment['path']: media}


def package(trip, events, media, override=None):
    files = {'trip.json': canonical(trip).encode(), 'events.json': canonical(events).encode(), **media}
    manifest = {'schema_version': '1.0', 'package_id': str(uuid.uuid4()), 'exported_at': DATE,
                'app_version': '0.1', 'trip_id': trip['id'], 'trip_revision': trip['revision'],
                'files': [{'path': k, 'byte_length': len(v), 'mime_type': 'application/json' if k.endswith('.json') else 'audio/mp4', 'sha256': sha(v)} for k, v in files.items()]}
    if override:
        override(manifest, files)
    files['manifest.json'] = canonical(manifest).encode()
    out = io.BytesIO()
    with zipfile.ZipFile(out, 'w') as archive:
        for name, data in files.items():
            archive.writestr(name, data)
    return out.getvalue()


class StoreTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.store = Store(self.root / 'library')
        self.trip, self.events, self.media = fixture()

    def tearDown(self):
        self.store.close()
        self.temp.cleanup()

    def importing(self, trip=None, events=None):
        preview = self.store.preview_import(package(trip or self.trip, events or self.events, self.media))
        return self.store.import_package(preview['token'])

    def test_roundtrip_persists_originals_without_fabricated_time(self):
        self.assertEqual(self.importing()['status'], 'imported')
        self.store.close(); self.store = Store(self.root / 'library')
        result = self.store.get_trip(self.trip['id'])
        self.assertEqual(result['trip'], self.trip)
        self.assertNotIn('occurred_at', result['events'][0])
        aid = self.events[0]['attachments'][0]['id']
        path, mime = self.store.media_file(aid)
        self.assertEqual(path.read_bytes(), next(iter(self.media.values())))
        self.assertEqual(mime, 'audio/mp4')

    def test_duplicate_is_noop_even_new_package_id(self):
        self.importing()
        self.assertEqual(self.importing()['status'], 'duplicate')
        self.assertEqual(self.store.db.execute('SELECT count(*) FROM packages').fetchone()[0], 1)

    def test_newer_preserves_reviews_processing_history_and_sources(self):
        self.importing(); eid = self.events[0]['id']
        self.store.save_review(eid, {'note': 'Human note', 'fields': {'species': 'rainbow'}, 'hidden': True})
        self.store.save_processing(eid, {'source_revision': 1, 'transcripts': {'raw': 'First original'}})
        self.store.save_processing(eid, {'source_revision': 1, 'transcripts': {'raw': 'Retry original'}})
        self.trip['revision'] = 2; self.events[0]['revision'] = 2
        self.events[0]['text_history'].append({'text': 'More detail', 'saved_at': DATE})
        self.assertEqual(self.importing()['status'], 'updated')
        event = self.store.get_event(eid)
        self.assertEqual(event['review']['note'], 'Human note')
        self.assertTrue(event['review']['hidden'])
        self.assertTrue(event['processing_stale'])
        self.assertEqual(self.store.db.execute('SELECT count(*) FROM processing_history').fetchone()[0], 2)
        self.assertEqual(self.store.db.execute('SELECT count(*) FROM histories').fetchone()[0], 4)

    def test_old_revision_cannot_downgrade(self):
        self.importing(); old_trip = copy.deepcopy(self.trip)
        self.trip['revision'] = 2; self.trip['title'] = 'Later name'; self.importing()
        self.assertEqual(self.importing(trip=old_trip)['status'], 'older')
        self.assertEqual(self.store.get_trip(self.trip['id'])['trip']['title'], 'Later name')

    def test_same_revision_different_content_is_conflict(self):
        self.importing(); self.trip['title'] = 'Changed without revision'
        preview = self.store.preview_import(package(self.trip, self.events, self.media))
        self.assertEqual(preview['status'], 'conflict')
        with self.assertRaises(ValueError): self.store.import_package(preview['token'])
        self.assertEqual(self.store.get_trip(self.trip['id'])['trip']['title'], 'An evening')

    def test_lower_event_revision_in_newer_trip_rejected(self):
        self.events[0]['revision'] = 2; self.importing()
        self.trip['revision'] = 2; self.events[0]['revision'] = 1
        with self.assertRaises(ValueError): self.importing()
        self.assertEqual(self.store.get_event(self.events[0]['id'])['revision'], 2)

    def test_source_text_and_media_cannot_be_rewritten(self):
        self.importing(); self.trip['revision'] = 2; self.events[0]['revision'] = 2
        self.events[0]['text_history'][0]['text'] = 'Overwritten'
        with self.assertRaises(ValueError): self.importing()
        self.assertIn('otter', self.store.get_event(self.events[0]['id'])['text_history'][0]['text'])

    def test_phone_deletion_keeps_originals_and_review_conflict_visible(self):
        self.importing(); eid = self.events[0]['id']
        self.store.save_review(eid, {'note': 'Keep for later'})
        self.trip['revision'] = 2; self.events[0]['revision'] = 2; self.events[0]['deleted'] = True
        self.importing()
        self.assertEqual(self.store.list_trips()[0]['event_count'], 0)
        self.assertEqual(self.store.list_trips(include_deleted=True)[0]['event_count'], 1)
        self.assertTrue(self.store.get_event(eid)['review_conflict'])
        self.assertTrue(self.store.media_file(self.events[0]['attachments'][0]['id'])[0].exists())

    def test_omitted_event_requires_deletion_marker(self):
        self.importing(); self.trip['revision'] = 2
        preview = self.store.preview_import(package(self.trip, [], {}))
        self.assertEqual(preview['status'], 'conflict')

    def test_review_revision_conflict_does_not_overwrite(self):
        self.importing(); eid = self.events[0]['id']
        self.store.save_review(eid, {'expected_revision': 0, 'note': 'Version one'})
        with self.assertRaises(ValueError): self.store.save_review(eid, {'expected_revision': 0, 'note': 'Lost update'})
        self.assertEqual(self.store.get_event(eid)['review']['note'], 'Version one')
        self.assertEqual(self.store.get_event(eid)['text_history'], self.events[0]['text_history'])

    def test_searches_source_transcript_and_review_filters(self):
        self.importing(); eid = self.events[0]['id']; aid = self.events[0]['attachments'][0]['id']
        self.store.save_review(eid, {'kind': 'observation', 'note': 'Bridge access', 'transcripts': {aid: 'Caddis everywhere'}})
        for word in ('otter', 'bridge', 'caddis'):
            self.assertEqual(self.store.list_trips(query=word)[0]['matched_event_ids'], [eid])
        self.assertEqual(len(self.store.list_trips(waterbody='mad', kind='observation', date_from='2026-09-17')), 1)
        self.assertEqual(self.store.list_trips(kind='catchFish'), [])
        self.assertEqual(self.store.list_trips(date_to='2026-09-16'), [])

    def test_corrupt_media_manifest_and_schema_rejected_before_commit(self):
        for override in (
            lambda m, f: f.update({next(iter(self.media)): b'corrupt'}),
            lambda m, f: m.update(schema_version='2.0'),
            lambda m, f: m.update(trip_id=str(uuid.uuid4())),
        ):
            with self.assertRaises(ValueError): self.store.preview_import(package(self.trip, self.events, self.media, override))
        self.assertEqual(self.store.list_trips(), [])

    def test_zip_traversal_symlink_duplicate_and_unlisted_file_rejected(self):
        good = package(self.trip, self.events, self.media)
        for path, mode in [('../escape', None), ('/absolute', None), ('media\\escape', None), ('link', stat.S_IFLNK | 0o777), ('trip.json', None), ('extra', None)]:
            out = io.BytesIO(good)
            with zipfile.ZipFile(out, 'a') as archive:
                entry = zipfile.ZipInfo(path)
                if mode: entry.external_attr = mode << 16
                archive.writestr(entry, b'invalid')
            with self.assertRaises(ValueError): self.store.preview_import(out.getvalue())
        self.assertFalse((self.root / 'escape').exists())

    def test_backup_restore_preserves_sources_reviews_histories_and_raw(self):
        self.importing(); eid = self.events[0]['id']; aid = self.events[0]['attachments'][0]['id']
        self.store.save_review(eid, {'note': 'My correction', 'transcripts': {aid: 'Edited transcript'}})
        self.store.save_processing(eid, {'source_revision': 1, 'transcripts': {aid: 'Original transcript'}})
        backup = self.store.backup().read_bytes()
        other = Store(self.root / 'restored')
        try:
            preview = other.preview_restore(backup)
            self.assertEqual(preview['counts']['trips'], 1)
            self.assertEqual(other.restore(preview['token'])['status'], 'restored')
            self.assertEqual(other.get_trip(self.trip['id']), self.store.get_trip(self.trip['id']))
            self.assertEqual(other.media_file(aid)[0].read_bytes(), next(iter(self.media.values())))
            self.assertEqual(other.db.execute('SELECT count(*) FROM processing_history').fetchone()[0], 1)
            with self.assertRaises(ValueError): other.restore(other.preview_restore(backup)['token'])
        finally: other.close()

    def test_corrupt_backup_rejected_and_empty_library_unchanged(self):
        self.importing(); backup = self.store.backup().read_bytes()
        original = zipfile.ZipFile(io.BytesIO(backup))
        out = io.BytesIO()
        with zipfile.ZipFile(out, 'w') as archive:
            for info in original.infolist():
                archive.writestr(info.filename, b'bad media' if info.filename.startswith('media/') else original.read(info))
        other = Store(self.root / 'restore-empty')
        try:
            with self.assertRaises(ValueError): other.preview_restore(out.getvalue())
            self.assertEqual(other.list_trips(), [])
        finally: other.close()

    def test_active_svg_and_header_injection_media_types_rejected(self):
        for mime in ('image/svg+xml', 'image/jpeg\r\nX-Injected: yes'):
            self.events[0]['attachments'][0]['mime_type'] = mime
            with self.assertRaises(ValueError):
                self.store.preview_import(package(self.trip, self.events, self.media))

    def test_reset_time_override_follows_future_phone_source(self):
        self.importing(); eid = self.events[0]['id']
        self.store.save_review(eid, {'occurred_at': '2026-09-17T08:00:00Z'})
        review = self.store.save_review(eid, {'reset_fields': ['occurred_at']})
        self.assertNotIn('occurred_at', review)
        self.trip['revision'] = 2; self.events[0]['revision'] = 2
        self.events[0]['occurred_at'] = '2026-09-17T09:00:00Z'
        self.importing()
        result = self.store.get_event(eid)
        self.assertNotIn('occurred_at', result['review'])
        self.assertEqual(result['occurred_at'], '2026-09-17T09:00:00Z')
        with self.assertRaises(ValueError):
            self.store.save_review(eid, {'reset_fields': ['occurred_at'], 'occurred_at': None})
        with self.assertRaises(ValueError): self.store.save_review(eid, {'reset_fields': ['revision']})

    def test_search_excludes_dismissed_and_stale_proposals_and_metadata(self):
        self.importing(); eid = self.events[0]['id']
        self.store.save_processing(eid, {'source_revision': 1, 'model': 'SECRET_MODEL', 'facts': [
            {'id': 'proposal-one', 'value': 'Brook trout'}, {'id': 'proposal-two', 'value': 'Stonefly'}]})
        self.assertEqual(len(self.store.list_trips(query='Brook trout')), 1)
        self.store.save_review(eid, {'dismissed_fact_ids': ['proposal-one']})
        self.assertEqual(self.store.list_trips(query='Brook trout'), [])
        self.assertEqual(self.store.list_trips(query='SECRET_MODEL'), [])
        self.trip['revision'] = 2; self.events[0]['revision'] = 2
        self.importing()
        self.assertEqual(self.store.list_trips(query='Stonefly'), [])
        self.store.save_review(eid, {'fields': {'fly': {'value': 'Stonefly', 'source': {'quote': 'Rejected metadata value'}}}})
        self.assertEqual(len(self.store.list_trips(query='Stonefly')), 1)
        self.assertEqual(self.store.list_trips(query='Rejected metadata value'), [])

    def test_transcript_search_uses_correction_over_original(self):
        self.importing(); eid = self.events[0]['id']; a = self.events[0]['attachments'][0]
        self.store.save_processing(eid, {'source_revision': 1, 'transcripts': [{'attachment_id': a['id'], 'attachment_sha256': a['sha256'], 'raw_text': 'Badger sighting'}]})
        self.assertEqual(len(self.store.list_trips(query='Badger')), 1)
        self.store.save_review(eid, {'transcripts': {a['id']: 'Beaver sighting'}})
        self.assertEqual(self.store.list_trips(query='Badger'), [])
        self.assertEqual(len(self.store.list_trips(query='Beaver')), 1)

    def test_source_review_fingerprint_ignores_acceptance_but_tracks_evidence_edits(self):
        self.importing(); eid = self.events[0]['id']
        self.store.save_processing(eid, {'source_revision': 1, 'source_review_fingerprint': review_source_fingerprint({}), 'facts': []})
        self.store.save_review(eid, {'dismissed_fact_ids': ['proposal'], 'fields': {'fly': 'Caddis'}})
        self.assertFalse(self.store.get_event(eid)['processing_stale'])
        self.store.save_review(eid, {'note': 'New evidence'})
        self.assertTrue(self.store.get_event(eid)['processing_stale'])

    def test_inherited_context_is_human_only_exact_prior_and_labeled(self):
        def event(id, when, kind='catchFish', fields=None, until=None):
            return {'id': id, 'kind': kind, 'occurred_at': when, 'occurred_until': until, 'review': {'fields': fields or {}}, 'processing': {'facts': [{'field': 'fly', 'value': 'AI only'}]}}
        rows = [event('change', '2026-09-17T10:00:00Z', 'contextChange', {'fly': {'value': 'Caddis'}}),
                event('earlier', '2026-09-17T09:00:00Z'), event('later', '2026-09-17T11:00:00Z')]
        result = inherited_context(rows)
        self.assertEqual(result[1]['inherited_context'], {})
        self.assertEqual(result[2]['inherited_context']['fly']['value'], 'Caddis')
        self.assertEqual(result[2]['inherited_context']['fly']['source_event_id'], 'change')
        self.assertEqual(result[2]['inherited_context']['fly']['attribution'], 'inherited')
        rows.append(event('conflict', '2026-09-17T10:00:00Z', 'contextChange', {'fly': 'Midge'}))
        self.assertEqual(inherited_context(rows)[2]['inherited_context'], {})
        rows.pop(); rows.append(event('range', '2026-09-17T10:30:00Z', 'contextChange', {'fly': 'Midge'}, '2026-09-17T11:30:00Z'))
        self.assertEqual(inherited_context(rows)[2]['inherited_context'], {})
        rows.pop(); rows.append(event('unknown', None, 'contextChange', {'fly': 'Midge'}))
        self.assertEqual(inherited_context(rows)[2]['inherited_context'], {})

    def test_preview_tokens_cannot_escape_staging(self):
        with self.assertRaises(ValueError): self.store.import_package('../library.sqlite3')

    def test_unknown_additive_fields_survive_source_and_backup(self):
        self.trip['future_optional'] = {'some': 'value'}
        self.events[0]['new_measurement'] = None
        self.importing()
        self.assertEqual(self.store.get_trip(self.trip['id'])['trip']['future_optional'], {'some': 'value'})
        self.assertIn('new_measurement', self.store.get_event(self.events[0]['id']))


if __name__ == '__main__': unittest.main()
