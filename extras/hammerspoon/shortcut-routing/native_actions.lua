-- Native app actions; Spotlight has a separate release-gated OS shortcut.
local M={tasks={}}
local function matches(item,key)
 if (item.AXMenuItemCmdChar or ''):lower()~=key then return false end
 local mods=item.AXMenuItemCmdModifiers or {}
 return #mods==1 and (mods[1]=='cmd' or mods[1]=='command')
end
local function locate(items,key,path,found)
 for _,item in ipairs(items or {}) do
  local nextPath={table.unpack(path)}
  if item.AXTitle and item.AXTitle~='' then nextPath[#nextPath+1]=item.AXTitle end
  if matches(item,key) and item.AXEnabled~=false and item.AXEnabled~=0 then found[#found+1]=nextPath end
  locate(item.AXChildren,key,nextPath,found)
  -- AXMenu wrappers are represented as anonymous arrays, not AXChildren nodes.
  if item[1] then locate(item,key,path,found) end
 end
end
function M.run(action,app,windowId,done)
 if action=='SCREENSHOT_REGION' then
  local task
  task=hs.task.new('/usr/bin/open',function(code)
   M.tasks[task]=nil;done(code==0 and 'opened-cleanshot' or 'cleanshot-open-failed')
  end,{'cleanshot://capture-area'})
  if not task then done('task-unavailable');return end
  M.tasks[task]=true
  if not task:start() then M.tasks[task]=nil;done('cleanshot-open-failed') end
 elseif action=='SPOTLIGHT' then
  require('spotlight_shortcut').toggle(done)
 elseif action=='CLOSE_WINDOW' or action=='QUIT_APP' or action=='NEW_TAB' then
  if not app then done('no-target');return end
  local started=hs.timer.absoluteTime()
  app:getMenuItems(function(items)
   local front=hs.application.frontmostApplication()
   local window=front and front:focusedWindow()
   if hs.timer.absoluteTime()-started>2000000000 or not front or front:pid()~=app:pid() or not window or window:id()~=windowId then done('target-changed-or-expired');return end
   local found={};locate(items,({CLOSE_WINDOW='w',QUIT_APP='q',NEW_TAB='t'})[action],{},found)
   if #found~=1 then done('menu-action-unavailable');return end
   done(app:selectMenuItem(found[1]) and 'menu-selected' or 'menu-action-failed')
  end)
 else done('unsupported-action') end
end
return M
