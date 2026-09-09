local now,flags,secure,callback,sent,stopped=0,{cmd=true},false,nil,0,false
hs={timer={absoluteTime=function()return now end,doEvery=function(_,fn)callback=fn;return {stop=function()stopped=true end}end},eventtap={checkKeyboardModifiers=function()return flags end,isSecureInputEnabled=function()return secure end,keyStroke=function(mods,key,delay)assert(mods[1]=='cmd' and key=='space');sent=sent+1 end}}
local m=dofile('extras/hammerspoon/shortcut-routing/spotlight_shortcut.lua')
local result,n=nil,0
local function check(v)assert(v,'check '..(n+1));n=n+1 end
local function done(s)result=s end
m.toggle(done);callback();check(sent==0)
m.toggle(done);check(result=='spotlight-request-already-pending')
flags={};now=100000000;callback();check(sent==0)
now=150000000;callback();check(sent==1 and stopped);check(result=='spotlight-shortcut-sent')
m.toggle(done);flags={cmd=true};now=1800000000;callback();check(sent==1);check(result=='spotlight-modifiers-still-held')
now=2000000000;flags={};secure=true;m.toggle(done);callback();now=2050000000;callback();check(sent==1);check(result=='spotlight-secure-input')
print('Passed '..n..' Spotlight release-gate checks')
