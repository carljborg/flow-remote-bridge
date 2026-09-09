-- Policy tests use a fake event tap. No keyboard input is captured or generated.
local callbacks = {}
local enabled, foreground, accessibility = true, 'tv.parsec.www', true
local log = os.tmpname()
local function writeLog(text)
 local f=assert(io.open(log,'w'));f:write(text);f:close()
end
writeLog('[I] Client Status received: 0\n')
local tapRunning, timerRunning = false, true
hs={
 keycodes={map={v=9}},
 application={
  applicationsForBundleID=function(b)
   if b=='com.electron.wispr-flow.accessibility-mac-app' then return {{pid=function() return 42 end}} end
   return {}
  end,
  frontmostApplication=function()
   if not foreground then return nil end
   return {bundleID=function() return foreground end}
  end,
 },
 accessibilityState=function() return accessibility end,
 eventtap={event={types={keyDown=1,keyUp=2},properties={eventSourceUnixProcessID=7}},
  new=function(_,fn)
   callbacks.event=fn
   return {start=function() tapRunning=true end,stop=function() tapRunning=false end,isEnabled=function() return tapRunning end}
  end,
 },
 timer={doEvery=function(_,fn)
  callbacks.tick=fn
  return {stop=function() timerRunning=false end}
 end},
}
local guard=dofile('extras/hammerspoon/flow_paste_guard.lua').start({parsecLog=log,bridgeEnabled=function() return enabled end})
local function event(key,pid,kind)
 return {getKeyCode=function() return key end,getProperty=function() return pid end,getType=function() return kind or 1 end}
end
local checks=0
local function check(value,message) assert(value,message);checks=checks+1 end
check(callbacks.event(event(9,42))==true,'Wispr down must be suppressed')
check(callbacks.event(event(9,42,2))==true,'Wispr up must be suppressed')
check(callbacks.event(event(9,0))==false,'Physical V/manual paste must pass')
check(callbacks.event(event(9,100))==false,'Other applications must pass')
check(callbacks.event(event(8,42))==false,'Other keys must pass')
foreground='com.apple.Terminal';check(callbacks.event(event(9,42))==false,'Other foreground apps must pass')
foreground=nil;check(callbacks.event(event(9,42))==false,'Unknown foreground must pass')
foreground='tv.parsec.www';enabled=false;check(callbacks.event(event(9,42))==false,'Disabled bridge must pass')
enabled=true;writeLog('[I] Client Status received: 0\n[I] Client Status received: -1\n');callbacks.tick()
check(callbacks.event(event(9,42))==false,'Disconnected Parsec must pass')
writeLog('[I] Client Status received: 0\n[F] ===== Parsec: Started =====\n');callbacks.tick()
check(callbacks.event(event(9,42))==false,'Restart clears connected state')
os.remove(log);callbacks.tick();check(callbacks.event(event(9,42))==false,'Missing log must pass')
writeLog('[I] Client Status received: 0\n');callbacks.tick()
check(callbacks.event(event(9,42))==true,'Reconnection restores filter')
hs.application.applicationsForBundleID=function() return {{pid=function() return 43 end}} end;callbacks.tick()
check(callbacks.event(event(9,42))==false,'Old PID must no longer match')
check(callbacks.event(event(9,43))==true,'Replacement process must match')
check(guard.status().suppressed==3,'Counts key-down suppressions only')
tapRunning=false;callbacks.tick();check(tapRunning,'Disabled tap restarts with permission')
tapRunning=false;accessibility=false;callbacks.tick();check(not tapRunning,'No permission cannot start tap')
guard.stop();check(not tapRunning and not timerRunning,'Stop disables tap and timer')
os.remove(log)
print('Passed '..checks..' optional paste-guard checks')
