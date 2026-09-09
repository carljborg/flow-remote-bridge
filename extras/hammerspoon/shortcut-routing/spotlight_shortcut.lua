-- Spotlight alone uses the OS shortcut, after modifiers have been released.
local M={pending=nil}
function M.toggle(done)
 if M.pending then done('spotlight-request-already-pending');return end
 local started=hs.timer.absoluteTime()
 local clearSince=nil
 local timer
 timer=hs.timer.doEvery(0.02,function()
  local now=hs.timer.absoluteTime()
  local flags=hs.eventtap.checkKeyboardModifiers()
  if now-started>1500000000 then
   timer:stop();M.pending=nil;done('spotlight-modifiers-still-held');return
  end
  if flags.cmd or flags.alt or flags.ctrl or flags.shift or flags.fn then clearSince=nil;return end
  clearSince=clearSince or now
  if now-clearSince<40000000 then return end
  timer:stop();M.pending=nil
  if hs.eventtap.isSecureInputEnabled() then done('spotlight-secure-input');return end
  hs.eventtap.keyStroke({'cmd'},'space',10000)
  done('spotlight-shortcut-sent')
 end)
 M.pending=timer
end
return M
