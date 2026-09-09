-- A policy callback, not a second event tap. Call after the Wispr paste guard.
local M = {}
function M.new(options)
    assert(type(options.active) == 'function' and type(options.send) == 'function')
    local routes, held = {}, {}
    local types = hs.eventtap.event.types
    for _, r in ipairs(options.routes or {}) do
        assert(type(r.action) == 'string' and r.action:match('^[A-Z][A-Z0-9_]*$'))
        local code = assert(hs.keycodes.map[r.key], 'Unknown key')
        local mods = {}
        for _, mod in ipairs(r.mods) do
            assert(mod == 'cmd' or mod == 'alt' or mod == 'ctrl' or mod == 'shift')
            mods[mod] = true
        end
        routes[#routes + 1] = {code = code, mods = mods, action = r.action}
    end
    return function(e)
        local kind, code = e:getType(), e:getKeyCode()
        if kind ~= types.keyDown and kind ~= types.keyUp then return false end
        -- Consume the matching release even if focus or modifiers changed.
        if held[code] then
            if kind == types.keyUp then held[code] = nil end
            return true
        end
        if kind ~= types.keyDown or not options.active() then return false end
        local flags = e:getFlags()
        if flags.fn then return false end
        for _, r in ipairs(routes) do
            local match = code == r.code
            for _, mod in ipairs({'cmd', 'alt', 'ctrl', 'shift'}) do
                if not not flags[mod] ~= not not r.mods[mod] then match = false end
            end
            if match then
                held[code] = true
                -- Never replay failed requests or leak a failed route locally.
                options.send(r.action)
                return true
            end
        end
        return false
    end
end
return M
