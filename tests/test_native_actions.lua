local n,status,selected,opened=0,nil,nil,nil
local function check(x)assert(x,'check '..(n+1));n=n+1 end
local now=1000000000
local app={pid=function()return 42 end,focusedWindow=function()return {id=function()return 7 end} end,bundleID=function()return 'browser' end}
local front=app
local menus={{AXTitle='File',AXChildren={{AXTitle='Close Tab',AXEnabled=true,AXMenuItemCmdChar='W',AXMenuItemCmdModifiers={'cmd'}}}}}
app.getMenuItems=function(_,fn)fn(menus)end
app.selectMenuItem=function(_,path)selected=table.concat(path,'/');return true end
hs={
 timer={absoluteTime=function()return now end},
 application={frontmostApplication=function()return front end,launchOrFocusByBundleID=function(b)opened=b;return true end},
 task={new=function(path,fn,args)opened={path=path,args=args};return {start=function()return true end}end},
 eventtap=setmetatable({},{__index=function()error('No keyboard synthesis allowed')end}),
}
local m=dofile('extras/hammerspoon/shortcut-routing/native_actions.lua')
local function run(a)m.run(a,app,7,function(s)status=s end)end
run('CLOSE_WINDOW');check(status=='menu-selected');check(selected=='File/Close Tab')
run('QUIT_APP');check(status=='menu-action-unavailable')
front=nil;run('CLOSE_WINDOW');check(status=='target-changed-or-expired')
run('SPOTLIGHT');check(opened=='com.apple.Spotlight')
run('SCREENSHOT_REGION');check(opened.path=='/usr/bin/open');check(opened.args[1]=='cleanshot://capture-area')
front={bundleID=function()return 'com.apple.Spotlight'end,hide=function()return true end}
run('SPOTLIGHT');check(status=='spotlight-hidden')
run('INVALID');check(status=='unsupported-action')
print('Passed '..n..' native-action checks without keyboard synthesis')
