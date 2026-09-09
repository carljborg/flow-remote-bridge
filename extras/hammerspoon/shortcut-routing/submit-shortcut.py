#!/usr/bin/env python3
import json,pathlib,sys,time,uuid,os
shortcuts={'CLOSE_WINDOW','QUIT_APP','SCREENSHOT_REGION','SPOTLIGHT'}
allowed=shortcuts
if len(sys.argv) not in (2,3) or sys.argv[1] not in allowed:raise SystemExit('Unsupported shortcut')
base=pathlib.Path.home()/'.local/state/flow-shortcut-routing'
try:
 r=json.loads((base/'receiver.json').read_text())
 if not r.get('ready') or time.time()-r['time']>4:raise ValueError()
except Exception:raise SystemExit('Shortcut receiver needs to be running with Accessibility access')
stamp=time.time()
if sys.argv[1] in shortcuts:
 if len(sys.argv)!=3:raise SystemExit('Shortcut requires original timestamp')
 stamp=float(sys.argv[2])
 if not 0 <= time.time()-stamp < 2:raise SystemExit('Shortcut expired or clocks differ')
 if sys.argv[1] not in {'SCREENSHOT_REGION','SPOTLIGHT'} and (not r.get('appPid') or not r.get('windowId')):raise SystemExit('No focused target window')
 if time.time()-r['time']>0.5:raise SystemExit('Shortcut receiver stale')
q=base/'queue'
if len(list(q.glob('*.json')))>12:raise SystemExit('Shortcut queue full')
u=uuid.uuid4().hex;f=q/(str(time.time_ns())+'-'+u+'.tmp');f.write_text(json.dumps({'action':sys.argv[1],'time':stamp,'id':u,'appPid':r.get('appPid'),'windowId':r.get('windowId')}));f.chmod(0o600);f.rename(f.with_suffix('.json'))
