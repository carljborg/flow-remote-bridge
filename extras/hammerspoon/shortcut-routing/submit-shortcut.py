#!/usr/bin/env python3
import json,pathlib,sys,time,uuid,os
shortcuts={'CLOSE_WINDOW','QUIT_APP','SCREENSHOT_REGION','SPOTLIGHT'}
allowed=shortcuts
if len(sys.argv) not in (2,3) or sys.argv[1] not in allowed:raise SystemExit('Unsupported media command')
base=pathlib.Path.home()/'.local/state/flow-shortcut-routing'
try:
 r=json.loads((base/'receiver.json').read_text())
 if not r.get('ready') or time.time()-r['time']>4:raise ValueError()
except Exception:raise SystemExit('Media receiver needs to be running with Accessibility access')
stamp=time.time()
if sys.argv[1] in shortcuts:
 if sys.argv[1] not in {'SCREENSHOT_REGION','SPOTLIGHT'} and (not r.get('appPid') or not r.get('windowId')):raise SystemExit('No focused target window')
 if time.time()-r['time']>1.5:raise SystemExit('Shortcut receiver stale')
q=base/'queue'
if len(list(q.glob('*.json')))>12:raise SystemExit('Media queue full')
u=uuid.uuid4().hex;f=q/(str(time.time_ns())+'-'+u+'.tmp');f.write_text(json.dumps({'action':sys.argv[1],'time':stamp,'id':u,'appPid':r.get('appPid'),'windowId':r.get('windowId')}));f.chmod(0o600);f.rename(f.with_suffix('.json'))
