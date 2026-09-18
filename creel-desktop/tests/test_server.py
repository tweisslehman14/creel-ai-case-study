"""HTTP regression checks; use an isolated temporary library, never the user's journal."""
import http.client
import json
from pathlib import Path
import sys
import tempfile
import threading
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from server import App, Handler, ThreadingHTTPServer
from test_store import package, fixture

class HTTPTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory()
        self.app=App(Path(self.temp.name))
        self.http=ThreadingHTTPServer(('127.0.0.1',0),Handler)
        self.http.app=self.app
        self.thread=threading.Thread(target=self.http.serve_forever,daemon=True);self.thread.start()
    def tearDown(self):
        self.http.shutdown();self.http.server_close();self.app.pool.shutdown(wait=True);self.app.store.close();self.temp.cleanup()
    def request(self,path,body=None,headers=None):
        connection=http.client.HTTPConnection('127.0.0.1',self.http.server_port)
        merged={'X-Creel-Token':self.app.token}
        if headers:merged.update(headers)
        if isinstance(body,dict):body=json.dumps(body).encode();merged['Content-Type']='application/json'
        connection.request('GET' if body is None else 'POST',path,body=body,headers=merged)
        response=connection.getresponse();result=(response.status,dict(response.getheaders()),response.read());connection.close();return result
    def test_static_status_and_cross_site_write_protection(self):
        code,headers,data=self.request('/')
        self.assertEqual(code,200);self.assertIn(b'Every trip has a story',data);self.assertIn("frame-ancestors 'none'",headers['Content-Security-Policy'])
        self.assertEqual(self.request('/api/status',headers={'Host':'attacker.example'})[0],403)
        self.assertEqual(self.request('/api/backup',{},headers={'Origin':'https://attacker.example'})[0],403)
        self.assertEqual(self.request('/api/backup',{},headers={'X-Creel-Token':'wrong'})[0],403)
    def test_roundtrip_media_range_and_duplicate_import(self):
        trip,events,media=fixture()
        preview=json.loads(self.request('/api/import/preview',package(trip,events,media))[2])
        self.assertEqual(preview['status'],'new')
        result=json.loads(self.request('/api/import',{'token':preview['token']})[2])
        self.assertEqual(result['trip_id'],trip['id'])
        aid=events[0]['attachments'][0]['id']
        code,headers,data=self.request('/api/media/'+aid,headers={'Range':'bytes=0-5'})
        self.assertEqual(code,206);self.assertEqual(data,next(iter(media.values()))[:6]);self.assertEqual(headers['X-Content-Type-Options'],'nosniff')
        eventid=events[0]['id']
        code,_,_=self.request('/api/events/'+eventid+'/review',{'expected_revision':0,'note':'My correction'})
        self.assertEqual(code,200)
        preview=json.loads(self.request('/api/import/preview',package(trip,events,media))[2]);self.assertEqual(preview['status'],'duplicate')
        self.request('/api/import',{'token':preview['token']})
        saved=json.loads(self.request('/api/trips/'+trip['id'])[2]);self.assertEqual(saved['events'][0]['review']['note'],'My correction')

    def test_invalid_upload_does_not_mutate_and_backup_link_works(self):
        code,_,body=self.request('/api/import/preview',b'not a zip')
        self.assertEqual(code,400)
        self.assertEqual(json.loads(self.request('/api/library')[2])['trips'],[])
        code,_,body=self.request('/api/backup',{})
        self.assertEqual(code,200)
        code,headers,archive=self.request(json.loads(body)['url'])
        self.assertEqual(code,200);self.assertTrue(archive.startswith(b'PK'));self.assertIn('attachment',headers['Content-Disposition'])

if __name__=='__main__':unittest.main()
