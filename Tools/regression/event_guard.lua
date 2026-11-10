-- event_guard.lua: Core/Events.lua keeps one handler per owner and event, so a second Register by the same owner
-- silently replaces the first (LEE-60: Auras lost two of its three PLAYER_ENTERING_WORLD handlers this way).
-- Guard.Install(K) wraps K.Events and records every such replacement with the source lines of both handlers;
-- Guard.Check(found, stage) fails on any that is not in KNOWN, and Guard.Known(found) fails on a KNOWN entry
-- that no longer happens, so the list shrinks as owners fix theirs.
local Guard = {}

-- Collisions listed for their owner's thread rather than fixed in LEE-60. Each value says what is lost.
Guard.KNOWN = {}

local function where(fn)
	local info = debug.getinfo(fn, "S")
	return info.short_src .. ":" .. info.linedefined
end

function Guard.Install(K)
	local E = K.Events
	local held, found = {}, {}
	local function hold(owner, event, fn)
		local mine = held[owner]
		if not mine then
			mine = {}
			held[owner] = mine
		end
		local old = mine[event]
		if old and old ~= fn then
			local key = owner .. " " .. event
			found[key] = found[key] or (key .. ": the handler at " .. where(fn) .. " replaces the one at " .. where(old))
		end
		mine[event] = fn
	end
	local register, registerUnit, unregister, unregisterAll = E.Register, E.RegisterUnit, E.Unregister, E.UnregisterAll
	E.Register = function(owner, event, fn)
		register(owner, event, fn)
		hold(owner, event, fn)
	end
	E.RegisterUnit = function(owner, event, fn, ...)
		registerUnit(owner, event, fn, ...)
		hold(owner, event, fn)
	end
	E.Unregister = function(owner, event)
		unregister(owner, event)
		if held[owner] then
			held[owner][event] = nil
		end
	end
	E.UnregisterAll = function(owner)
		unregisterAll(owner)
		held[owner] = nil
	end
	return found
end

function Guard.Check(found, stage)
	local lines = {}
	for key, text in pairs(found) do
		if not Guard.KNOWN[key] then
			lines[#lines + 1] = "  " .. text
		end
	end
	table.sort(lines)
	assert(#lines == 0, stage .. ": an owner registered one event twice, and Core/Events.lua keeps only the last handler."
		.. " Give each piece of work its own owner, or one handler that calls them all:\n" .. table.concat(lines, "\n"))
end

function Guard.Known(found)
	for key, lost in pairs(Guard.KNOWN) do
		assert(found[key], "event_guard.lua lists " .. key .. " (" .. lost .. "), but it no longer happens: remove it from KNOWN")
	end
end

return Guard
