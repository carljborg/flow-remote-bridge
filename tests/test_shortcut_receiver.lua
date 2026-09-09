local checks, callback, request, posted, current, last = 0, nil, nil, {}, nil, nil
local function check(v) assert(v,'check '..(checks+1)); checks=checks+1 end
local app={pid=function()return 42 end,focusedWindow=function()return {id=function()return 7 end} end}
current=app
local oldOpen,oldRemove,oldRename=io.open,os.remove,os.rename
io.open=function()return {read=function()return 'request' end,write=function()end,close=function()end} end
os.remove=function()end;os.rename=function()end
package.preload.shortcut_actions=function()return dofile('extras/hammerspoon/shortcut-routing/host_actions.example.lua') end
hs={
 keycodes={map={w=13,q=12,['4']=21,space=49}},
 accessibilityState=function()return true end,
 application={frontmostApplication=function()return current end},
 timer={secondsSinceEpoch=function()return 100 end,doEvery=function(_,fn)callback=fn;return {} end},
 fs={dir=function() local once=false;return function()if not once then once=true;return 'request.json' end end end},
 json={decode=function()return request end,encode=function(v)last=v;return '' end},
 eventtap={keyStroke=function()error('Must not mutate shared modifier state') end,event={types={keyDown=10,keyUp=11},newEvent=function()
  local e={}
  for _,name in ipairs({'Type','KeyCode','Flags'}) do e['set'..name]=function(self,v)self[name]=v;return self end end
  e.post=function(self,target)self.target=target;posted[#posted+1]=self;return self end
  return e
 end}},
}
dofile('extras/hammerspoon/shortcut-routing/shortcut_receiver.lua')
local function run(action,opts)
 posted={};request={action=action,time=99.5,id='test',appPid=42,windowId=7}
 for k,v in pairs(opts or {}) do request[k]=v end
 callback()
end
run('CLOSE_WINDOW');check(#posted==2);check(posted[1].target==app);check(posted[2].target==app)
check(posted[1].Type==10 and posted[2].Type==11);check(posted[1].Flags.cmd and posted[2].Flags.cmd)
run('QUIT_APP');check(#posted==2 and posted[1].KeyCode==12)
run('CLOSE_WINDOW',{windowId=8});check(#posted==0)
run('CLOSE_WINDOW',{time=97.5});check(#posted==0)
run('UNKNOWN');check(#posted==0)
current=nil
run('CLOSE_WINDOW');check(#posted==0)
run('SCREENSHOT_REGION');check(#posted==2);check(posted[1].target==nil and posted[2].target==nil)
check(posted[1].Flags.cmd and posted[1].Flags.shift)
run('SPOTLIGHT');check(#posted==2 and posted[1].target==nil and posted[1].KeyCode==49)
io.open,os.remove,os.rename=oldOpen,oldRemove,oldRename
print('Passed '..checks..' shortcut receiver checks')
