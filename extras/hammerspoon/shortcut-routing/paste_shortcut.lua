-- Paste shortcuts wait for release and preserve the original target app/window.
local M={pending=nil}
function M.run(action,app,windowId,done)
 local mods=action=='PASTE_HISTORY' and {'cmd','shift'} or {'cmd','alt','shift'}
 local pid=app and app:pid()
 if M.pending then done('paste-request-already-pending');return end
 local started=hs.timer.absoluteTime()
 local clearSince=nil
 local timer
 timer=hs.timer.doEvery(0.02,function()
  local now=hs.timer.absoluteTime()
  local flags=hs.eventtap.checkKeyboardModifiers()
  if now-started>1500000000 then
   timer:stop();M.pending=nil;done('paste-modifiers-still-held');return
  end
  if flags.cmd or flags.alt or flags.ctrl or flags.shift or flags.fn then clearSince=nil;return end
  clearSince=clearSince or now
  if now-clearSince<40000000 then return end
  timer:stop();M.pending=nil
  if hs.eventtap.isSecureInputEnabled() then done('paste-secure-input');return end
  local front=hs.application.frontmostApplication()
  local window=front and front:focusedWindow()
  if not front or front:pid()~=pid or (window and window:id())~=windowId then done('paste-target-changed');return end
  hs.eventtap.keyStroke(mods,'v',10000)
  done('paste-shortcut-sent')
 end)
 M.pending=timer
end
return M
