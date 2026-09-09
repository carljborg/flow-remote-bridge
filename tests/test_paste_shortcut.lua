local now,flags,secure,callback,sent,stopped=0,{cmd=true},false,nil,0,false
hs={timer={absoluteTime=function()return now end,doEvery=function(_,fn)callback=fn;return {stop=function()stopped=true end}end},eventtap={checkKeyboardModifiers=function()return flags end,isSecureInputEnabled=function()return secure end,keyStroke=function(mods,key,delay)assert(mods[1]=='cmd' and key=='v' and (mods[2]=='shift' or mods[2]=='alt'));sent=sent+1 end}}
hs.application={frontmostApplication=function()return app end}; app={pid=function()return 42 end,focusedWindow=function()return {id=function()return 7 end}end}; local m=dofile('extras/hammerspoon/shortcut-routing/paste_shortcut.lua')
local result,n=nil,0
local function check(v)assert(v,'check '..(n+1));n=n+1 end
local function done(s)result=s end
m.run('PASTE_HISTORY',app,7,done);callback();check(sent==0)
m.run('PASTE_HISTORY',app,7,done);check(result=='paste-request-already-pending')
flags={};now=100000000;callback();check(sent==0)
now=150000000;callback();check(sent==1 and stopped);check(result=='paste-shortcut-sent')
m.run('PASTE_HISTORY',app,7,done);flags={cmd=true};now=1800000000;callback();check(sent==1);check(result=='paste-modifiers-still-held')
now=2000000000;flags={};secure=true;m.run('PASTE_HISTORY',app,7,done);callback();now=2050000000;callback();check(sent==1);check(result=='paste-secure-input')
print('Passed '..n..' Paste release-gate checks')

secure=false;now=3000000000;m.run('PASTE_MATCH_STYLE',app,7,done);callback();now=3050000000;callback();check(sent==2)
now=4000000000;m.run('PASTE_HISTORY',app,7,done);callback();app=nil;now=4050000000;callback();check(sent==2);check(result=='paste-target-changed')
print('Passed plain-paste dispatch and focus-change cancellation checks')
