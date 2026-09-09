local n=0
local function check(ok) assert(ok, 'check '..(n+1)); n=n+1 end
hs={keycodes={map={space=49,w=13,q=12,['4']=21,v=9,c=8,r=15,t=17}},eventtap={event={types={keyDown=10,keyUp=11},properties={}}}}
local active=true
local sent={}
local route=dofile('extras/hammerspoon/shortcut-routing/shortcut_router.lua').new({
 routes=dofile('extras/hammerspoon/shortcut-routing/routes.example.lua'),
 active=function() return active end,
 send=function(a) sent[#sent+1]=a end,
})
local function event(key,kind,flags)
 return {getType=function()return kind or 10 end,getKeyCode=function()return hs.keycodes.map[key] end,getFlags=function()return flags or {cmd=true} end}
end
check(route(event('w')));check(sent[1]=='CLOSE_WINDOW')
check(route(event('w')));check(#sent==1) -- autorepeat swallowed
active=false
check(route(event('w',11,{}))) -- release swallowed after focus changed
check(not route(event('q')));active=true
check(route(event('q')));check(sent[2]=='QUIT_APP');check(route(event('q',11)))
check(not route(event('4')))
check(route(event('4',10,{cmd=true,shift=true})));check(sent[3]=='SCREENSHOT_REGION')
check(route(event('4',11,{})))
for _,key in ipairs({'v','c','r','t'}) do check(not route(event(key))) end
check(not route(event('w',10,{cmd=true,alt=true})))
check(not route(event('w',10,{cmd=true,shift=true})))
check(not route(event('w',10,{cmd=true,ctrl=true})))
check(not route(event('w',10,{cmd=true,fn=true})))
check(not route(event('w',10,{})))
check(not route(event('w',11)))
check(not route(event('w',12)))
check(#sent==3)
check(route(event('space')));check(sent[4]=='SPOTLIGHT');check(route(event('space',11)))
print('Passed '..n..' selective-shortcut policy checks')
