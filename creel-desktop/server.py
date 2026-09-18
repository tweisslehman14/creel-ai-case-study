#!/usr/bin/env python3
"""Creel desktop: loopback-only journal. Python standard library, no installation step."""
from __future__ import annotations
import argparse
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import mimetypes
import os
from pathlib import Path
import secrets
import threading
from urllib.parse import urlsplit, parse_qs, unquote

from store import Store, review_source_fingerprint
import processing

STATIC = Path(__file__).parent / 'static'
MAX_UPLOAD = 270 * 1024 * 1024

def now():
    return datetime.now(timezone.utc).isoformat()

class App:
    def __init__(self, root: Path):
        self.store = Store(root)
        self.lock = threading.RLock()
        self.token = secrets.token_urlsafe(32)
        self.jobs = {}
        self.pool = ThreadPoolExecutor(max_workers=1, thread_name_prefix='creel-processing')
        self.downloads = {}
        # An interrupted processing run must not remain stuck in a running state after restart.
        for trip in self.store.list_trips(include_deleted=True):
            for event in self.store.get_trip(trip['id'])['events']:
                old = event.get('processing', {})
                if old.get('status') == 'running':
                    old.update(status='interrupted', errors=['Processing stopped when the desktop app closed. Your originals are intact. Retry when ready.'])
                    self.store.save_processing(event['id'], old)

    def process(self, event_id, options):
        with self.lock:
            event = self.store.get_event(event_id)
            if event.get('deleted') or event.get('review', {}).get('hidden'):
                raise ValueError('Restore this moment before processing it.')
            if event_id in self.jobs:
                return {'status': 'running', 'event_id': event_id}
            if options.get('enable_ai') is not True and options.get('transcribe') is not True:
                raise ValueError('Choose transcription or extraction before processing.')
            # Only fixed server-configured local providers. No arbitrary URLs/commands from the browser.
            opts = {'enable_ai': options.get('enable_ai') is True, 'transcribe': options.get('transcribe') is True}
            opts['manual_transcripts'] = event.get('review', {}).get('transcripts', {})
            fingerprint = hashlib.sha256(json.dumps({'source': {k:v for k,v in event.items() if k not in ('processing','review','processing_stale','review_conflict','inherited_context')}, 'review_input': review_source_fingerprint(event.get('review', {})), 'options': opts, 'providers': processing.status()}, sort_keys=True).encode()).hexdigest()
            previous = event.get('processing', {})
            if previous.get('job_fingerprint') == fingerprint and previous.get('status') in ('complete', 'completed', 'success', 'processed'):
                return {'status': 'unchanged', 'event_id': event_id, 'message': 'This source has already been processed with these settings.'}
            running = dict(previous)
            running.update(status='running', started_at=now(), errors=[], source_revision=event['revision'], source_review_fingerprint=review_source_fingerprint(event.get('review', {})))
            self.store.save_processing(event_id, running)
            self.jobs[event_id] = True
        def run():
            try:
                effective_event = dict(event)
                effective_event['kind'] = event.get('review', {}).get('kind') or event.get('kind', 'unclassified')
                result = processing.process_event(effective_event, self.store.media_file, opts)
                result['source_review_fingerprint'] = review_source_fingerprint(event.get('review', {}))
                result['job_fingerprint'] = fingerprint
                result['finished_at'] = now()
                with self.lock:
                    self.store.save_processing(event_id, result)
            except Exception as exc:
                failed = dict(previous)
                failed.update(status='failed', errors=[str(exc)], finished_at=now())
                with self.lock:
                    self.store.save_processing(event_id, failed)
            finally:
                with self.lock:
                    self.jobs.pop(event_id, None)
        self.pool.submit(run)
        return {'status':'running', 'event_id':event_id}

class Handler(BaseHTTPRequestHandler):
    server_version = 'Creel/0.2'
    protocol_version = 'HTTP/1.1'
    @property
    def app(self): return self.server.app

    def log_message(self, fmt, *args):
        # Do not print journal search terms, file names or source text.
        if args and isinstance(args[0], str):
            print(f'Creel: {self.command} {self.path.split("?")[0]}', flush=True)

    def _guard(self, mutation=False):
        allowed = {f'127.0.0.1:{self.server.server_port}', f'localhost:{self.server.server_port}'}
        host = self.headers.get('Host', '')
        if host not in allowed:
            raise PermissionError('Creel only accepts requests on this Mac.')
        origin = self.headers.get('Origin')
        if origin and origin not in {f'http://{h}' for h in allowed}:
            raise PermissionError('This request came from another website.')
        if self.headers.get('Sec-Fetch-Site') == 'cross-site':
            raise PermissionError('Cross-site requests are not allowed.')
        if mutation and not secrets.compare_digest(self.headers.get('X-Creel-Token', ''), self.app.token):
            raise PermissionError('Reload Creel and try again.')

    def _headers(self, code, content_type, length, extra=None):
        self.send_response(code)
        self.send_header('Content-Type', content_type)
        self.send_header('Content-Length', str(length))
        self.send_header('Cache-Control', 'no-store')
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.send_header('Referrer-Policy', 'no-referrer')
        self.send_header('Content-Security-Policy', "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data: blob:; media-src 'self' blob:; connect-src 'self'; object-src 'none'; base-uri 'none'; frame-ancestors 'none'; form-action 'self'")
        if extra:
            for k,v in extra.items(): self.send_header(k,v)
        self.end_headers()

    def _json(self, value, code=200):
        data = json.dumps(value, ensure_ascii=False).encode()
        self._headers(code,'application/json; charset=utf-8',len(data))
        if self.command != 'HEAD': self.wfile.write(data)

    def _body(self, max_length=MAX_UPLOAD):
        if self.headers.get('Transfer-Encoding'):
            raise ValueError('Upload a file with a known length.')
        size = int(self.headers.get('Content-Length', '0'))
        if size < 1 or size > max_length:
            raise ValueError('The file is empty or larger than the supported upload limit.')
        self.connection.settimeout(120)
        data = self.rfile.read(size)
        if len(data) != size: raise ValueError('The upload was interrupted. Nothing was imported.')
        return data

    def _file(self, path, mime, download=False, filename=None):
        size = path.stat().st_size
        start, end, code = 0, size-1, 200
        extra = {'Accept-Ranges': 'bytes'}
        if download: extra['Content-Disposition'] = 'attachment; filename="' + (filename or path.name).replace('"','') + '"'
        byte_range = self.headers.get('Range')
        if byte_range and not download:
            try:
                unit, requested = byte_range.split('=',1)
                first, last = requested.split('-',1)
                if unit != 'bytes' or ',' in requested: raise ValueError()
                if first:
                    start = int(first); end = min(int(last), size-1) if last else size-1
                else:
                    start = max(0, size-int(last))
                if start < 0 or start > end or start >= size: raise ValueError()
                code = 206; extra['Content-Range'] = f'bytes {start}-{end}/{size}'
            except ValueError:
                self._headers(416,'text/plain',0,{'Content-Range':f'bytes */{size}'})
                return
        self._headers(code,mime,max(0,end-start+1),extra)
        if self.command != 'HEAD':
            with path.open('rb') as f:
                f.seek(start); remaining = end-start+1
                while remaining > 0:
                    chunk = f.read(min(1024*1024,remaining))
                    if not chunk: break
                    self.wfile.write(chunk); remaining -= len(chunk)

    def do_HEAD(self): self.do_GET()

    def do_GET(self):
        try:
            self._guard()
            parsed = urlsplit(self.path); path = unquote(parsed.path); query = parse_qs(parsed.query)
            if path == '/api/status':
                return self._json({'token':self.app.token,'processing':processing.status(),'jobs':list(self.app.jobs),'version':'0.2','local_only':True})
            if path == '/api/library':
                args = {k:query.get(k,[''])[0] for k in ('query','waterbody','kind','date_from','date_to')}
                args['include_deleted'] = query.get('include_deleted',['false'])[0] == 'true'
                with self.app.lock: trips = self.app.store.list_trips(**args)
                return self._json({'trips':trips})
            if path.startswith('/api/trips/'):
                with self.app.lock: trip = self.app.store.get_trip(path.rsplit('/',1)[1])
                return self._json(trip)
            if path.startswith('/api/media/'):
                with self.app.lock: media, mime = self.app.store.media_file(path.rsplit('/',1)[1])
                safe_inline = mime.startswith('audio/') or mime in ('image/jpeg','image/png','image/webp','image/heic','image/heif','image/gif')
                return self._file(media, mime if safe_inline else 'application/octet-stream', download=bool(query.get('download')) or not safe_inline, filename='original-'+path.rsplit('/',1)[1]+(mimetypes.guess_extension(mime) or '.bin'))
            if path.startswith('/api/download/'):
                token = path.rsplit('/',1)[1]
                file = self.app.downloads.get(token)
                if file is None: raise KeyError('This download is no longer available. Create a fresh backup.')
                return self._file(file,'application/zip',download=True)
            files = {'/':'index.html','/index.html':'index.html','/app.js':'app.js','/style.css':'style.css'}
            if path not in files: raise KeyError('Page not found')
            file = STATIC / files[path]
            return self._file(file,mimetypes.guess_type(file.name)[0] or 'application/octet-stream')
        except (ValueError, KeyError, PermissionError) as exc:
            self.close_connection = True
            self._json({'error':str(exc).strip("'")},403 if isinstance(exc,PermissionError) else 400 if isinstance(exc,ValueError) else 404)
        except (BrokenPipeError, ConnectionResetError): pass
        except Exception as exc:
            self._json({'error':f'Creel could not complete this request: {exc}'},500)

    def do_POST(self):
        try:
            self._guard(mutation=True)
            path = urlsplit(self.path).path
            if path in ('/api/import/preview','/api/restore/preview'):
                data = self._body()
                with self.app.lock:
                    result = self.app.store.preview_import(data) if path.startswith('/api/import') else self.app.store.preview_restore(data)
                return self._json(result)
            body = json.loads(self._body(2*1024*1024))
            if not isinstance(body,dict): raise ValueError('Expected an object.')
            if path in ('/api/import','/api/restore'):
                with self.app.lock:
                    if self.app.jobs and path == '/api/restore': raise ValueError('Wait for processing to finish before restoring.')
                    result = self.app.store.import_package(body.get('token','')) if path == '/api/import' else self.app.store.restore(body.get('token',''))
                return self._json(result)
            if path.startswith('/api/events/') and path.endswith('/review'):
                event_id = path.split('/')[3]
                with self.app.lock: result = self.app.store.save_review(event_id,body)
                return self._json(result)
            if path.startswith('/api/events/') and path.endswith('/process'):
                return self._json(self.app.process(path.split('/')[3],body),202)
            if path == '/api/backup':
                with self.app.lock:
                    if self.app.jobs: raise ValueError('Wait for processing to finish before creating a backup.')
                    file = self.app.store.backup()
                token = secrets.token_urlsafe(24); self.app.downloads[token] = file
                return self._json({'url':f'/api/download/{token}', 'message':'Backup created on this Mac.'})
            raise KeyError('Unknown action')
        except (ValueError, KeyError, PermissionError) as exc:
            self.close_connection = True
            self._json({'error':str(exc).strip("'")},403 if isinstance(exc,PermissionError) else 400 if isinstance(exc,ValueError) else 404)
        except (BrokenPipeError, ConnectionResetError): pass
        except Exception as exc:
            self._json({'error':f'Nothing was confirmed. Creel could not finish: {exc}'},500)


def main():
    parser = argparse.ArgumentParser(description='Run Creel privately on this Mac.')
    parser.add_argument('--port', type=int, default=8767)
    parser.add_argument('--data-dir',type=Path,default=Path(__file__).parent/'data')
    args = parser.parse_args()
    app = App(args.data_dir.expanduser().resolve())
    server = ThreadingHTTPServer(('127.0.0.1',args.port),Handler); server.app = app
    print(f'Creel is ready at http://127.0.0.1:{args.port} — keep this window open. Data: {args.data_dir}',flush=True)
    try: server.serve_forever()
    except KeyboardInterrupt: print('\nCreel stopped. Your library is saved.')
    finally: server.server_close(); app.pool.shutdown(wait=True)

if __name__ == '__main__': main()
