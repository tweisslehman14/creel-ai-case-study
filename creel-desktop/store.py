"""Private, local Creel library. Source revisions never contain desktop edits."""
from __future__ import annotations

import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import re
import sqlite3
import stat
import threading
import uuid
import zipfile
from datetime import datetime, timezone
from functools import wraps

MAX_BYTES = 250 * 1024 * 1024
MAX_FILES = 5000
KINDS = {'unclassified', 'catchFish', 'observation', 'contextChange', 'journal'}


def now():
    return datetime.now(timezone.utc).isoformat()


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=False, allow_nan=False)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def review_source_fingerprint(review):
    """Only review inputs used by extraction; approving a fact does not change its evidence."""
    return sha(canonical({'note': review.get('note', ''), 'transcripts': review.get('transcripts', {}), 'kind': review.get('kind')}).encode())


def searchable_event(event):
    review, processing = event.get('review', {}), event.get('processing', {})
    values = [h.get('text', '') for h in event.get('text_history', [])]
    values.append(review.get('note', ''))
    for field, value in review.get('fields', {}).items():
        values.append(field)
        values.append(value.get('value') if isinstance(value, dict) else value)
    raw = {t.get('attachment_id'): t for t in processing.get('transcripts', []) if isinstance(t, dict)} if isinstance(processing.get('transcripts'), list) else {}
    corrected = review.get('transcripts', {})
    for attachment in event.get('attachments', []):
        aid = attachment['id']
        if aid in corrected:
            values.append(corrected[aid])
        elif aid in raw and raw[aid].get('attachment_sha256') == attachment.get('sha256'):
            # A phone note edit does not invalidate a transcript of the unchanged original audio.
            values.append(raw[aid].get('raw_text', ''))
    if not event.get('processing_stale'):
        dismissed = set(review.get('dismissed_fact_ids', []))
        for fact in processing.get('facts', []):
            if isinstance(fact, dict) and fact.get('id') not in dismissed:
                values.append(fact.get('value'))
    return canonical(values).casefold()


def inherited_context(events):
    """Conservative, labeled continuity from human-reviewed changes; never source mutation."""
    changes = {k: [] for k in ('rig', 'technique', 'fly')}
    ambiguous = {k: [] for k in changes}
    unknown = set()
    def instant(value):
        return datetime.fromisoformat(value.replace('Z', '+00:00')).timestamp()
    def effective_time(event):
        review = event.get('review', {})
        return review.get('occurred_at') if 'occurred_at' in review else event.get('occurred_at')
    for event in events:
        review = event.get('review', {})
        if event.get('deleted') or review.get('hidden') or (review.get('kind') or event.get('kind')) != 'contextChange':
            continue
        when = effective_time(event)
        end = None if 'occurred_at' in review else event.get('occurred_until')
        for field in changes:
            value = review.get('fields', {}).get(field)
            value = value.get('value') if isinstance(value, dict) else value
            if value is None or value == '':
                continue
            if not when:
                unknown.add(field)
            elif end or ('occurred_at' not in review and event.get('occurrence_basis') in ('unknown', 'user_range')):
                ambiguous[field].append((instant(when), instant(end) if end else float('inf')))
            else:
                changes[field].append((instant(when), value, event['id'], when))
    for event in events:
        event['inherited_context'] = {}
        when = effective_time(event)
        review = event.get('review', {})
        if not when or event.get('deleted') or review.get('hidden') or ('occurred_at' not in review and event.get('occurred_until')):
            continue
        at = instant(when)
        for field, candidates in changes.items():
            if field in unknown or field in review.get('fields', {}):
                continue
            eligible = [c for c in candidates if c[0] < at]
            if not eligible:
                continue
            latest_time = max(c[0] for c in eligible)
            latest = [c for c in eligible if c[0] == latest_time]
            if len({canonical(c[1]) for c in latest}) != 1:
                continue
            # An uncertain change after the last exact change breaks continuity.
            if any(start <= at and end >= latest_time for start, end in ambiguous[field]):
                continue
            _, value, source_id, source_time = latest[0]
            event['inherited_context'][field] = {'value': value, 'source_event_id': source_id,
                'occurred_at': source_time, 'attribution': 'inherited', 'basis': 'human_reviewed_context_change'}
    return events


def parse_json(data):
    def pairs(items):
        result = {}
        for key, value in items:
            if key in result:
                raise ValueError('Duplicate JSON key: ' + key)
            result[key] = value
        return result
    try:
        return json.loads(data, object_pairs_hook=pairs,
                          parse_constant=lambda value: (_ for _ in ()).throw(ValueError('Non-finite JSON value')))
    except (UnicodeError, json.JSONDecodeError, RecursionError, TypeError) as exc:
        raise ValueError('Invalid JSON in package.') from exc


def identifier(value, label):
    if not isinstance(value, str):
        raise ValueError(label + ' must be a UUID.')
    try:
        uuid.UUID(value)
    except (ValueError, AttributeError) as exc:
        raise ValueError(label + ' must be a UUID.') from exc
    return value


def positive(value, label, zero=False):
    if type(value) is not int or value < (0 if zero else 1):
        raise ValueError(label + ' must be a valid integer.')
    return value


def timestamp(value, label, optional=False):
    if optional and value is None:
        return
    try:
        if not isinstance(value, str) or datetime.fromisoformat(value.replace('Z', '+00:00')).tzinfo is None:
            raise ValueError()
    except (ValueError, TypeError):
        raise ValueError(label + ' must be an ISO timestamp with a timezone.')


def safe_path(name):
    if not isinstance(name, str) or not name or '\\' in name or '\x00' in name or ':' in name:
        raise ValueError('Unsafe archive path.')
    path = PurePosixPath(name)
    if path.is_absolute() or any(p in ('', '.', '..') for p in name.split('/')):
        raise ValueError('Unsafe archive path.')
    return name


def read_zip(data):
    if not isinstance(data, bytes) or not data or len(data) > MAX_BYTES:
        raise ValueError('Package must be a ZIP file no larger than 250 MB.')
    try:
        with zipfile.ZipFile(io.BytesIO(data)) as archive:
            entries = archive.infolist()
            if len(entries) > MAX_FILES:
                raise ValueError('Too many files in package.')
            files = {}
            total = 0
            for entry in entries:
                name = safe_path(entry.filename)
                mode = entry.external_attr >> 16
                if entry.is_dir() or stat.S_ISLNK(mode) or (stat.S_IFMT(mode) not in (0, stat.S_IFREG)):
                    raise ValueError('Only regular files are allowed in packages.')
                if name in files or entry.flag_bits & 1:
                    raise ValueError('Duplicate or encrypted archive entry.')
                total += entry.file_size
                if total > MAX_BYTES or entry.file_size > MAX_BYTES:
                    raise ValueError('Expanded package exceeds 250 MB.')
                if entry.file_size > 1024 * 1024 and entry.file_size > max(1, entry.compress_size) * 200:
                    raise ValueError('Unsafe archive compression ratio.')
                payload = archive.read(entry)
                if len(payload) != entry.file_size:
                    raise ValueError('Archive length mismatch.')
                files[name] = payload
            return files
    except (zipfile.BadZipFile, RuntimeError, NotImplementedError, OSError) as exc:
        raise ValueError('The ZIP is damaged or unsupported.') from exc


def validate_manifest(files, backup=False):
    key = 'backup-manifest.json' if backup else 'manifest.json'
    manifest = parse_json(files.get(key, b''))
    if not isinstance(manifest, dict):
        raise ValueError('Manifest must be an object.')
    version = manifest.get('schema_version')
    if not isinstance(version, str) or version.split('.')[0] != '1':
        raise ValueError('Unsupported package schema version.')
    listing = manifest.get('files')
    if not isinstance(listing, list):
        raise ValueError('Manifest file list is missing.')
    expected = set()
    for item in listing:
        if not isinstance(item, dict):
            raise ValueError('Invalid manifest entry.')
        name = safe_path(item.get('path'))
        if name in expected or name == key:
            raise ValueError('Duplicate manifest entry.')
        expected.add(name)
        payload = files.get(name)
        if payload is None or positive(item.get('byte_length'), 'File length', True) != len(payload) or item.get('sha256') != sha(payload):
            raise ValueError('File failed its size or SHA-256 integrity check: ' + name)
    if set(files) != expected | {key}:
        raise ValueError('Archive and manifest file lists do not match.')
    return manifest


def validate_package(data):
    files = read_zip(data)
    manifest = validate_manifest(files)
    trip = parse_json(files.get('trip.json', b''))
    events = parse_json(files.get('events.json', b''))
    if not isinstance(trip, dict) or not isinstance(events, list):
        raise ValueError('Trip and event records are invalid.')
    tid = identifier(trip.get('id'), 'Trip ID')
    rev = positive(trip.get('revision'), 'Trip revision')
    if manifest.get('trip_id') != tid or manifest.get('trip_revision') != rev:
        raise ValueError('Manifest trip identity or revision does not match.')
    identifier(manifest.get('package_id'), 'Package ID')
    timestamp(manifest.get('exported_at'), 'Export time')
    for key in ('created_at', 'started_at'):
        timestamp(trip.get(key), key)
    timestamp(trip.get('ended_at'), 'ended_at', True)
    for key in ('title', 'waterbody', 'companions', 'timezone', 'outcome'):
        if key in trip and not isinstance(trip[key], str):
            raise ValueError('Invalid trip ' + key)
    eids, aids, paths = set(), set(), set()
    for event in events:
        if not isinstance(event, dict):
            raise ValueError('Invalid event.')
        eid = identifier(event.get('id'), 'Event ID')
        if eid in eids or event.get('trip_id') != tid:
            raise ValueError('Duplicate event or incorrect trip association.')
        eids.add(eid)
        positive(event.get('revision'), 'Event revision')
        timestamp(event.get('captured_at'), 'Capture time')
        timestamp(event.get('updated_at'), 'Update time')
        timestamp(event.get('occurred_at'), 'Occurrence time', True)
        timestamp(event.get('occurred_until'), 'Occurrence end', True)
        if event.get('occurred_until') and (not event.get('occurred_at') or datetime.fromisoformat(event['occurred_until'].replace('Z', '+00:00')) < datetime.fromisoformat(event['occurred_at'].replace('Z', '+00:00'))):
            raise ValueError('Occurrence range is invalid.')
        if event.get('kind') not in KINDS or type(event.get('deleted', False)) is not bool:
            raise ValueError('Invalid event kind or deletion marker.')
        history = event.get('text_history', [])
        if not isinstance(history, list) or any(not isinstance(h, dict) or not isinstance(h.get('text'), str) for h in history):
            raise ValueError('Invalid source text history.')
        for h in history:
            timestamp(h.get('saved_at'), 'Text save time')
        attachments = event.get('attachments', [])
        if not isinstance(attachments, list):
            raise ValueError('Invalid attachment list.')
        for attachment in attachments:
            if not isinstance(attachment, dict):
                raise ValueError('Invalid attachment.')
            aid = identifier(attachment.get('id'), 'Attachment ID')
            path = safe_path(attachment.get('path'))
            if aid in aids or path in paths or not path.startswith('media/') or len(path.split('/')) != 2:
                raise ValueError('Duplicate or invalid attachment.')
            aids.add(aid); paths.add(path)
            payload = files.get(path)
            if payload is None or positive(attachment.get('byte_length'), 'Attachment length', True) != len(payload) or attachment.get('sha256') != sha(payload):
                raise ValueError('Original media integrity check failed.')
            if not isinstance(attachment.get('mime_type'), str) or not re.fullmatch(r'(audio|image)/[A-Za-z0-9.+-]+', attachment['mime_type']) or attachment['mime_type'].lower() == 'image/svg+xml':
                raise ValueError('Unsupported attachment media type. Raster photos and audio are supported.')
    if set(files) != {'manifest.json', 'trip.json', 'events.json'} | paths:
        raise ValueError('Unreferenced files in trip package.')
    return trip, events, files


def locked(method):
    @wraps(method)
    def wrapper(self, *args, **kwargs):
        with self.lock:
            return method(self, *args, **kwargs)
    return wrapper


class Store:
    def __init__(self, root: Path):
        self.root = Path(root)
        self.root.mkdir(parents=True, exist_ok=True)
        for child in ('media', 'archives', 'staging', 'backups'):
            (self.root / child).mkdir(exist_ok=True)
        self.lock = threading.RLock()
        self.db = sqlite3.connect(self.root / 'library.sqlite3', check_same_thread=False)
        self.db.row_factory = sqlite3.Row
        self.db.execute('PRAGMA foreign_keys=ON')
        self.db.execute('PRAGMA journal_mode=WAL')
        self.db.executescript('''
        CREATE TABLE IF NOT EXISTS trips(id TEXT PRIMARY KEY, revision INTEGER NOT NULL, source TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS events(id TEXT PRIMARY KEY, trip_id TEXT NOT NULL REFERENCES trips(id), revision INTEGER NOT NULL, source TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS media(id TEXT PRIMARY KEY, event_id TEXT NOT NULL REFERENCES events(id), hash TEXT NOT NULL, mime TEXT NOT NULL, source TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS histories(entity TEXT NOT NULL,id TEXT NOT NULL,revision INTEGER NOT NULL,source TEXT NOT NULL,PRIMARY KEY(entity,id,revision));
        CREATE TABLE IF NOT EXISTS reviews(event_id TEXT PRIMARY KEY REFERENCES events(id),data TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS processing(event_id TEXT PRIMARY KEY REFERENCES events(id),data TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS packages(hash TEXT PRIMARY KEY,trip_id TEXT NOT NULL,imported_at TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS processing_history(event_id TEXT NOT NULL,sequence INTEGER NOT NULL,data TEXT NOT NULL,saved_at TEXT NOT NULL,PRIMARY KEY(event_id,sequence));
        CREATE TABLE IF NOT EXISTS review_history(event_id TEXT NOT NULL,revision INTEGER NOT NULL,data TEXT NOT NULL,PRIMARY KEY(event_id,revision));
        ''')
        self.db.commit()

    def close(self):
        self.db.close()

    def _stage(self, data, kind):
        token = uuid.uuid4().hex
        target = self.root / 'staging' / (token + '.' + kind)
        target.write_bytes(data)
        return token

    def _staged(self, token, kind):
        if not isinstance(token, str) or not re.fullmatch('[0-9a-f]{32}', token):
            raise ValueError('Invalid preview token. Preview the file again.')
        path = self.root / 'staging' / (token + '.' + kind)
        if not path.is_file():
            raise ValueError('Preview expired. Select the file again.')
        return path

    def _status(self, trip, events):
        old = self.db.execute('SELECT * FROM trips WHERE id=?', (trip['id'],)).fetchone()
        if old and trip['revision'] < old['revision']:
            return 'older', 'An older phone revision cannot replace the current trip.'
        if old and trip['revision'] == old['revision']:
            saved_events = [json.loads(r['source']) for r in self.db.execute('SELECT source FROM events WHERE trip_id=? ORDER BY id', (trip['id'],))]
            if canonical(trip) == old['source'] and canonical(sorted(events, key=lambda e: e['id'])) == canonical(saved_events):
                return 'duplicate', 'Already imported. No changes are needed.'
            return 'conflict', 'Different content has the same trip revision. Neither version was overwritten.'
        if old:
            previous = {r['id']: json.loads(r['source']) for r in self.db.execute('SELECT id,source FROM events WHERE trip_id=?', (trip['id'],))}
            if not set(previous).issubset({e['id'] for e in events}):
                return 'conflict', 'Updated package omits prior events. Deletions need explicit markers.'
        for event in events:
            prior = self.db.execute('SELECT * FROM events WHERE id=?', (event['id'],)).fetchone()
            if prior:
                saved = json.loads(prior['source'])
                if prior['trip_id'] != trip['id'] or event['revision'] < prior['revision'] or (event['revision'] == prior['revision'] and canonical(event) != prior['source']):
                    return 'conflict', 'An event identity or revision conflicts with the local source.'
                old_media = {a['id']: a for a in saved.get('attachments', [])}
                new_media = {a['id']: a for a in event.get('attachments', [])}
                if not set(old_media).issubset(new_media) or any(canonical(a) != canonical(new_media[k]) for k, a in old_media.items()):
                    return 'conflict', 'Previously imported original media cannot be removed or changed.'
                hist = saved.get('text_history', [])
                if event.get('text_history', [])[:len(hist)] != hist or saved.get('captured_at') != event.get('captured_at') or saved.get('capture_location') != event.get('capture_location'):
                    return 'conflict', 'Previously captured source text or capture metadata changed.'
            for attachment in event.get('attachments', []):
                media = self.db.execute('SELECT * FROM media WHERE id=?', (attachment['id'],)).fetchone()
                if media and (media['event_id'] != event['id'] or media['source'] != canonical(attachment)):
                    return 'conflict', 'An attachment identity conflicts with a stored original.'
        return ('update', 'Newer phone source; your desktop reviews will be retained.') if old else ('new', 'Ready to import this trip.')

    @locked
    def preview_import(self, data: bytes):
        trip, events, _ = validate_package(data)
        status, message = self._status(trip, events)
        return {'token': self._stage(data, 'trip'), 'trip': trip, 'event_count': len(events),
                'attachment_count': sum(len(e.get('attachments', [])) for e in events), 'status': status, 'message': message}

    def _immutable(self, directory, digest, payload):
        path = self.root / directory / digest
        if path.exists():
            if sha(path.read_bytes()) != digest:
                raise ValueError('A stored original failed its integrity check.')
        else:
            temp = path.with_name('.' + uuid.uuid4().hex)
            try:
                with temp.open('xb') as output:
                    output.write(payload); output.flush(); os.fsync(output.fileno())
                os.replace(temp, path)
            finally:
                temp.unlink(missing_ok=True)
        return path

    @locked
    def import_package(self, token: str):
        path = self._staged(token, 'trip'); data = path.read_bytes()
        trip, events, files = validate_package(data)
        status, message = self._status(trip, events)
        if status == 'conflict':
            raise ValueError(message)
        if status in ('duplicate', 'older'):
            path.unlink()
            return {'status': status, 'trip_id': trip['id'], 'message': message}
        # Durable files precede the atomic metadata transaction. A failed commit only leaves unreferenced files.
        for event in events:
            for a in event.get('attachments', []):
                self._immutable('media', a['sha256'], files[a['path']])
        digest = sha(data); self._immutable('archives', digest, data)
        with self.db:
            self.db.execute('INSERT INTO trips VALUES(?,?,?) ON CONFLICT(id) DO UPDATE SET revision=excluded.revision,source=excluded.source', (trip['id'], trip['revision'], canonical(trip)))
            self.db.execute('INSERT OR IGNORE INTO histories VALUES(?,?,?,?)', ('trip', trip['id'], trip['revision'], canonical(trip)))
            for event in events:
                self.db.execute('INSERT INTO events VALUES(?,?,?,?) ON CONFLICT(id) DO UPDATE SET revision=excluded.revision,source=excluded.source', (event['id'], trip['id'], event['revision'], canonical(event)))
                self.db.execute('INSERT OR IGNORE INTO histories VALUES(?,?,?,?)', ('event', event['id'], event['revision'], canonical(event)))
                for a in event.get('attachments', []):
                    self.db.execute('INSERT OR IGNORE INTO media VALUES(?,?,?,?,?)', (a['id'], event['id'], a['sha256'], a['mime_type'], canonical(a)))
            self.db.execute('INSERT OR IGNORE INTO packages VALUES(?,?,?)', (digest, trip['id'], now()))
        path.unlink()
        return {'status': 'imported' if status == 'new' else 'updated', 'trip_id': trip['id'], 'message': 'Trip imported. Original files and desktop reviews are preserved.'}

    def _event(self, row):
        event = json.loads(row['source'])
        review = self.db.execute('SELECT data FROM reviews WHERE event_id=?', (row['id'],)).fetchone()
        processing = self.db.execute('SELECT data FROM processing WHERE event_id=?', (row['id'],)).fetchone()
        event['review'] = json.loads(review['data']) if review else {'revision': 0}
        event['processing'] = json.loads(processing['data']) if processing else {}
        event['processing_stale'] = bool(event['processing']) and (event['processing'].get('source_revision') != event['revision'] or ('source_review_fingerprint' in event['processing'] and event['processing']['source_review_fingerprint'] != review_source_fingerprint(event['review'])))
        event['review_conflict'] = bool(event.get('deleted') and review)
        return event

    @locked
    def get_event(self, eventid):
        row = self.db.execute('SELECT * FROM events WHERE id=?', (eventid,)).fetchone()
        if row is None:
            raise KeyError('Event not found.')
        return self._event(row)

    @locked
    def get_trip(self, id):
        row = self.db.execute('SELECT source FROM trips WHERE id=?', (id,)).fetchone()
        if row is None:
            raise KeyError('Trip not found.')
        events = [self._event(r) for r in self.db.execute('SELECT * FROM events WHERE trip_id=? ORDER BY id', (id,))]
        events.sort(key=lambda e: datetime.fromisoformat(((e['review'].get('occurred_at') if 'occurred_at' in e['review'] else e.get('occurred_at')) or e.get('captured_at')).replace('Z', '+00:00')).timestamp())
        return {'trip': json.loads(row['source']), 'events': inherited_context(events)}

    @locked
    def list_trips(self, query='', waterbody='', kind='', date_from='', date_to='', include_deleted=False):
        result = []
        for row in self.db.execute('SELECT source FROM trips ORDER BY json_extract(source,"$.started_at") DESC'):
            trip = json.loads(row['source'])
            date = trip.get('started_at', '')[:10]
            if (waterbody and waterbody.casefold() not in trip.get('waterbody', '').casefold()) or (date_from and date < date_from) or (date_to and date > date_to):
                continue
            events = self.get_trip(trip['id'])['events']
            visible = [e for e in events if include_deleted or not (e.get('deleted') or e['review'].get('hidden'))]
            matched = []
            trip_match = query.casefold() in ' '.join(str(trip.get(k, '')) for k in ('title', 'waterbody', 'companions')).casefold()
            for event in visible:
                if kind and (event['review'].get('kind') or event.get('kind')) != kind:
                    continue
                # Search source narratives, transcripts, extracted facts and human corrections, including long debriefs.
                searchable = searchable_event(event)
                if not query or trip_match or query.casefold() in searchable:
                    matched.append(event['id'])
            if (query or kind) and not matched and not (trip_match and not kind):
                continue
            summary = {k: trip.get(k) for k in ('id', 'title', 'waterbody', 'started_at', 'ended_at', 'outcome', 'revision', 'companions')}
            summary.update(event_count=len(visible), matched_event_ids=matched, attachment_count=sum(len(e.get('attachments', [])) for e in visible))
            result.append(summary)
        return result

    @locked
    def save_review(self, event_id, patch: dict):
        event = self.get_event(event_id)
        if not isinstance(patch, dict):
            raise ValueError('Review must be an object.')
        allowed = {'expected_revision', 'reset_fields', 'note', 'kind', 'occurred_at', 'fields', 'transcripts', 'dismissed_fact_ids', 'hidden'}
        if set(patch) - allowed:
            raise ValueError('Unknown review field.')
        review = event['review']
        reset_fields = patch.get('reset_fields', [])
        if not isinstance(reset_fields, list) or any(not isinstance(k, str) or k not in allowed - {'expected_revision', 'reset_fields'} for k in reset_fields):
            raise ValueError('Invalid review fields to reset.')
        if any(k in patch for k in reset_fields):
            raise ValueError('A review field cannot be set and reset in the same edit.')
        if 'expected_revision' in patch and patch['expected_revision'] != review['revision']:
            raise ValueError('Review changed elsewhere. Reload before saving.')
        if 'note' in patch and not isinstance(patch['note'], str):
            raise ValueError('Review note must be text.')
        if 'kind' in patch and patch['kind'] is not None and patch['kind'] not in KINDS:
            raise ValueError('Invalid review kind.')
        if 'occurred_at' in patch:
            timestamp(patch['occurred_at'], 'Review time', True)
        if 'hidden' in patch and type(patch['hidden']) is not bool:
            raise ValueError('Hidden must be true or false.')
        if 'fields' in patch and not isinstance(patch['fields'], dict):
            raise ValueError('Reviewed fields must be an object.')
        if 'transcripts' in patch:
            transcripts = patch['transcripts']; aids = {a['id'] for a in event.get('attachments', [])}
            if not isinstance(transcripts, dict) or any(k not in aids or not isinstance(v, str) for k, v in transcripts.items()):
                raise ValueError('Transcript must reference an attachment on this event.')
        if 'dismissed_fact_ids' in patch and (not isinstance(patch['dismissed_fact_ids'], list) or any(not isinstance(v, str) for v in patch['dismissed_fact_ids'])):
            raise ValueError('Dismissed facts must be an ID list.')
        updated = {**{k: v for k, v in review.items() if k not in reset_fields}, **{k: v for k, v in patch.items() if k not in ('expected_revision', 'reset_fields')}, 'revision': review['revision'] + 1, 'updated_at': now()}
        encoded = canonical(updated)
        if len(encoded.encode()) > 1024 * 1024:
            raise ValueError('Review is too large.')
        with self.db:
            self.db.execute('INSERT INTO reviews VALUES(?,?) ON CONFLICT(event_id) DO UPDATE SET data=excluded.data', (event_id, encoded))
            self.db.execute('INSERT INTO review_history VALUES(?,?,?)', (event_id, updated['revision'], encoded))
        return updated

    @locked
    def save_processing(self, eventid, result: dict):
        self.get_event(eventid)
        if not isinstance(result, dict):
            raise ValueError('Processing result must be an object.')
        encoded = canonical(result)
        if len(encoded.encode()) > 5 * 1024 * 1024:
            raise ValueError('Processing result is too large.')
        with self.db:
            sequence = self.db.execute('SELECT COALESCE(MAX(sequence),0)+1 FROM processing_history WHERE event_id=?', (eventid,)).fetchone()[0]
            self.db.execute('INSERT INTO processing_history VALUES(?,?,?,?)', (eventid, sequence, encoded, now()))
            self.db.execute('INSERT INTO processing VALUES(?,?) ON CONFLICT(event_id) DO UPDATE SET data=excluded.data', (eventid, encoded))
        return result

    @locked
    def media_file(self, attachment_id):
        row = self.db.execute('SELECT * FROM media WHERE id=?', (attachment_id,)).fetchone()
        if row is None:
            raise KeyError('Attachment not found.')
        path = self.root / 'media' / row['hash']
        if not path.is_file() or sha(path.read_bytes()) != row['hash']:
            raise ValueError('Original media is missing or failed its checksum.')
        return path, row['mime']

    @locked
    def backup(self):
        tables = ('trips', 'events', 'media', 'histories', 'reviews', 'processing', 'packages', 'review_history', 'processing_history')
        snapshot = {t: [dict(r) for r in self.db.execute('SELECT * FROM ' + t)] for t in tables}
        files = {'library.json': canonical(snapshot).encode()}
        for row in snapshot['media']:
            payload = (self.root / 'media' / row['hash']).read_bytes()
            if sha(payload) != row['hash']:
                raise ValueError('Cannot back up damaged original media.')
            files['media/' + row['hash']] = payload
        for row in snapshot['packages']:
            payload = (self.root / 'archives' / row['hash']).read_bytes()
            if sha(payload) != row['hash']:
                raise ValueError('Cannot back up a damaged original package.')
            files['archives/' + row['hash']] = payload
        if sum(map(len, files.values())) > MAX_BYTES:
            raise ValueError('This library exceeds the current 250 MB backup limit.')
        manifest = {'schema_version': '1.0', 'kind': 'creel-desktop-backup', 'created_at': now(), 'files': [{'path': k, 'byte_length': len(v), 'sha256': sha(v)} for k, v in files.items()]}
        output = self.root / 'backups' / ('Creel-backup-' + uuid.uuid4().hex[:12] + '.zip')
        temp = output.with_suffix('.tmp')
        try:
            with zipfile.ZipFile(temp, 'w', compression=zipfile.ZIP_STORED) as archive:
                for name, data in files.items():
                    archive.writestr(name, data)
                archive.writestr('backup-manifest.json', canonical(manifest))
            os.replace(temp, output)
        finally:
            temp.unlink(missing_ok=True)
        return output

    def _validate_backup(self, data):
        files = read_zip(data); manifest = validate_manifest(files, backup=True)
        if manifest.get('kind') != 'creel-desktop-backup':
            raise ValueError('This is not a Creel desktop backup.')
        snapshot = parse_json(files.get('library.json', b''))
        columns = {'trips': ('id', 'revision', 'source'), 'events': ('id', 'trip_id', 'revision', 'source'), 'media': ('id', 'event_id', 'hash', 'mime', 'source'), 'histories': ('entity', 'id', 'revision', 'source'), 'reviews': ('event_id', 'data'), 'processing': ('event_id', 'data'), 'packages': ('hash', 'trip_id', 'imported_at'), 'review_history': ('event_id', 'revision', 'data'), 'processing_history': ('event_id', 'sequence', 'data', 'saved_at')}
        if not isinstance(snapshot, dict) or set(snapshot) != set(columns):
            raise ValueError('Invalid backup library tables.')
        tids, eids = set(), set()
        for table, cols in columns.items():
            if not isinstance(snapshot[table], list):
                raise ValueError('Invalid backup rows.')
            for row in snapshot[table]:
                if not isinstance(row, dict) or set(row) != set(cols):
                    raise ValueError('Invalid backup columns.')
                for key in ('source', 'data'):
                    if key in row and not isinstance(parse_json(row[key]), dict):
                        raise ValueError('Invalid backup JSON record.')
        for row in snapshot['trips']:
            identifier(row['id'], 'Trip ID'); positive(row['revision'], 'Trip revision')
            source = parse_json(row['source'])
            if row['id'] in tids or source.get('id') != row['id'] or source.get('revision') != row['revision']:
                raise ValueError('Invalid backup trip identity.')
            tids.add(row['id'])
        for row in snapshot['events']:
            identifier(row['id'], 'Event ID'); positive(row['revision'], 'Event revision')
            source = parse_json(row['source'])
            if row['id'] in eids or row['trip_id'] not in tids or source.get('id') != row['id'] or source.get('trip_id') != row['trip_id'] or source.get('revision') != row['revision']:
                raise ValueError('Invalid backup event relation.')
            eids.add(row['id'])
        required = {'library.json', 'backup-manifest.json'}
        for table, directory in (('media', 'media'), ('packages', 'archives')):
            for row in snapshot[table]:
                if not isinstance(row['hash'], str) or not re.fullmatch('[a-f0-9]{64}', row['hash']):
                    raise ValueError('Invalid backup file hash.')
                path = directory + '/' + row['hash']; payload = files.get(path)
                if payload is None or sha(payload) != row['hash']:
                    raise ValueError('Backup original integrity mismatch.')
                required.add(path)
                if table == 'media' and (not isinstance(row['mime'], str) or not re.fullmatch(r'(audio|image)/[A-Za-z0-9.+-]+', row['mime']) or row['mime'].lower() == 'image/svg+xml'):
                    raise ValueError('Unsupported backup media type.')
                if table == 'media' and row['event_id'] not in eids or table == 'packages' and row['trip_id'] not in tids:
                    raise ValueError('Invalid backup media/package relation.')
        for table in ('reviews', 'processing', 'review_history', 'processing_history'):
            if any(r['event_id'] not in eids for r in snapshot[table]):
                raise ValueError('Invalid backup review relation.')
        # The portable backup is data, never a database file to execute. Validate references before insertion.
        media_by_id = {r['id']: r for r in snapshot['media']}
        if len(media_by_id) != len(snapshot['media']):
            raise ValueError('Duplicate media identities in backup.')
        referenced_media = set()
        for row in snapshot['events']:
            source = parse_json(row['source'])
            for attachment in source.get('attachments', []):
                media = media_by_id.get(attachment.get('id'))
                if not media or media['event_id'] != row['id'] or media['hash'] != attachment.get('sha256') or media['mime'] != attachment.get('mime_type') or canonical(parse_json(media['source'])) != canonical(attachment):
                    raise ValueError('Backup attachment relationship mismatch.')
                if len(files['media/' + media['hash']]) != attachment.get('byte_length'):
                    raise ValueError('Backup media length mismatch.')
                referenced_media.add(media['id'])
        if referenced_media != set(media_by_id):
            raise ValueError('Unreferenced media records in backup.')
        archived_sources = {}
        for row in snapshot['packages']:
            trip, package_events, _ = validate_package(files['archives/' + row['hash']])
            if trip['id'] != row['trip_id']:
                raise ValueError('Backup original package association mismatch.')
            for entity, source in [('trip', trip)] + [('event', e) for e in package_events]:
                key = (entity, source['id'], source['revision'])
                if key in archived_sources and archived_sources[key] != canonical(source):
                    raise ValueError('Conflicting source revisions inside backup originals.')
                archived_sources[key] = canonical(source)
        history_keys = set()
        history_sources = {}
        for row in snapshot['histories']:
            source = parse_json(row['source'])
            if row['entity'] not in ('trip', 'event') or row['id'] not in (tids if row['entity'] == 'trip' else eids) or source.get('id') != row['id'] or source.get('revision') != row['revision']:
                raise ValueError('Invalid source history relationship.')
            key = (row['entity'], row['id'], row['revision'])
            if key in history_keys:
                raise ValueError('Duplicate source history revision.')
            if archived_sources.get(key) != canonical(source):
                raise ValueError('Backup source history does not match its original package.')
            history_keys.add(key)
            history_sources[key] = canonical(source)
        for table, entity in (('trips', 'trip'), ('events', 'event')):
            for row in snapshot[table]:
                if history_sources.get((entity, row['id'], row['revision'])) != canonical(parse_json(row['source'])):
                    raise ValueError('Current source is missing or differs from its history record.')
        if set(files) != required:
            raise ValueError('Unreferenced files in backup.')
        return snapshot, files, columns

    @locked
    def preview_restore(self, data):
        snapshot, _, _ = self._validate_backup(data)
        return {'token': self._stage(data, 'backup'), 'counts': {k: len(snapshot[k]) for k in ('trips', 'events', 'media', 'reviews')}, 'message': 'Restore is available only into an empty library. Originals and reviews are included.'}

    @locked
    def restore(self, token):
        if self.db.execute('SELECT COUNT(*) FROM trips').fetchone()[0]:
            raise ValueError('Restore requires an empty library; your existing trips have not been changed.')
        path = self._staged(token, 'backup')
        snapshot, files, columns = self._validate_backup(path.read_bytes())
        for name, payload in files.items():
            if name.startswith(('media/', 'archives/')):
                directory, digest = name.split('/')
                self._immutable(directory, digest, payload)
        try:
            with self.db:
                for table, cols in columns.items():
                    for row in snapshot[table]:
                        self.db.execute('INSERT INTO ' + table + ' VALUES(' + ','.join('?' for _ in cols) + ')', tuple(row[c] for c in cols))
        except sqlite3.IntegrityError as exc:
            raise ValueError('Backup has conflicting identities; nothing was restored.') from exc
        path.unlink()
        return {'status': 'restored', 'message': 'Library restored with originals, reviews and processing.', 'counts': {k: len(snapshot[k]) for k in ('trips', 'events', 'media', 'reviews')}}
