-- Optional client-side filter for Wispr's synthetic paste leaking into Parsec.
-- Does not read or alter clipboard contents, dictation text, or modifiers.
local M = {}

function M.start(options)
    options = options or {}
    assert(type(options.bridgeEnabled) == 'function',
        'Provide bridgeEnabled() so the guard can be disabled with the bridge')
    local event = hs.eventtap.event
    local types = event.types
    local parsecBundle = options.parsecBundle or 'tv.parsec.www'
    local logPath = options.parsecLog or (os.getenv('HOME') .. '/.parsec/log.txt')
    local bundles = options.wisprBundles or {
        'com.electron.wispr-flow',
        'com.electron.wispr-flow.accessibility-mac-app',
    }
    local state = {connected = false, pids = {}, suppressed = 0}
    local guard = {}

    local function refresh()
        local pids = {}
        for _, bundle in ipairs(bundles) do
            for _, app in ipairs(hs.application.applicationsForBundleID(bundle)) do
                pids[app:pid()] = true
            end
        end
        state.pids = pids
        -- Fail open when connection state cannot be established.
        state.connected = false
        local f = io.open(logPath, 'r')
        if not f then return end
        local size = f:seek('end')
        if not size then f:close(); return end
        f:seek('set', math.max(0, size - 131072))
        local data = f:read('*a')
        f:close()
        for line in (data or ''):gmatch('[^\r\n]+') do
            if line:find('===== Parsec:', 1, true) then
                state.connected = false
            elseif line:find('Client Status received:', 1, true) then
                state.connected = line:match('Client Status received: 0%s*$') ~= nil
            end
        end
    end

    guard.tap = hs.eventtap.new({types.keyDown, types.keyUp}, function(e)
        if e:getKeyCode() ~= hs.keycodes.map.v then return false end
        local ok, enabled = pcall(options.bridgeEnabled)
        if not ok or enabled ~= true or not state.connected then return false end
        local app = hs.application.frontmostApplication()
        if not app or app:bundleID() ~= parsecBundle then return false end
        local pid = e:getProperty(event.properties.eventSourceUnixProcessID)
        if not state.pids[pid] then return false end
        if e:getType() == types.keyDown then state.suppressed = state.suppressed + 1 end
        return true
    end)

    function guard.status()
        return {connected = state.connected, running = guard.tap:isEnabled(),
            suppressed = state.suppressed}
    end
    function guard.stop()
        guard.timer:stop()
        guard.tap:stop()
    end
    local function tick()
        local ok = pcall(refresh)
        if not ok then state.pids = {}; state.connected = false end
        if not guard.tap:isEnabled() and hs.accessibilityState() then guard.tap:start() end
    end
    tick()
    guard.timer = hs.timer.doEvery(1, tick)
    return guard
end

return M
