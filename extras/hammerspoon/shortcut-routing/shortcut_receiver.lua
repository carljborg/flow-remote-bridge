local M = {}
local root = os.getenv('HOME') .. '/.local/state/flow-shortcut-routing'
local shortcuts = require('shortcut_actions')
local native = require('native_actions')
local allowed = {}
local function save(name,value)
  local f=io.open(root..'/'..name..'.tmp','w')
  if f then f:write(hs.json.encode(value));f:close();os.rename(root..'/'..name..'.tmp',root..'/'..name) end
end
local lastHeartbeat=0
local lastPermission=0
local ready=false
M.timer=hs.timer.doEvery(0.1,function()
 local now=hs.timer.secondsSinceEpoch()
 if now-lastPermission>10 then ready=hs.accessibilityState();lastPermission=now end
 local app=hs.application.frontmostApplication()
 local window=app and app:focusedWindow()
 local appPid=app and app:pid()
 local windowId=window and window:id()
 if now-lastHeartbeat>0.1 then save('receiver.json',{ready=ready,time=now,appPid=appPid,windowId=windowId});lastHeartbeat=now end
 local names={}
 for name in hs.fs.dir(root..'/queue') do if name:match('%.json$') then table.insert(names,name) end end
 table.sort(names)
 for _,name in ipairs(names) do
  if name:match('%.json$') then
   local path=root..'/queue/'..name
   local f=io.open(path,'r'); local raw=f and f:read('*a'); if f then f:close() end
   local ok,r=pcall(hs.json.decode,raw or '')
   os.remove(path)
   if ready and ok and type(r)=='table' and (allowed[r.action] or shortcuts[r.action]) and type(r.time)=='number' and now-r.time>=0 and now-r.time<3 then
    local shortcut=shortcuts[r.action]
    if shortcut then
     local current=hs.application.frontmostApplication()
     local focused=current and current:focusedWindow()
     appPid=current and current:pid();windowId=focused and focused:id()
     if now-r.time>=2 or (r.action~='SCREENSHOT_REGION' and r.action~='SPOTLIGHT' and (not windowId or r.appPid~=appPid or r.windowId~=windowId)) then
      save('last-action.json',{action=r.action,time=now,id=r.id,status='dropped-focus-or-age'})
      goto continue
     end
     native.run(r.action,current,windowId,function(status)
      save('last-action.json',{action=r.action,time=hs.timer.secondsSinceEpoch(),id=r.id,status=status})
     end)
     goto continue
    else
     hs.eventtap.event.newSystemKeyEvent(r.action,true):post()
     hs.eventtap.event.newSystemKeyEvent(r.action,false):post()
    end
    save('last-action.json',{action=r.action,time=now,id=r.id,status='posted'})
   end
  end
 ::continue::
 end
end)
return M
