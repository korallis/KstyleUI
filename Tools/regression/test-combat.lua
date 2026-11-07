-- test-combat.lua: Combat.Queue holds protected work until combat ends, and Safe hides Blizzard frames only out of combat and Edit Mode.
local CoreEnv = dofile("Tools/regression/core_env.lua")
local Raises = CoreEnv.Raises

local function listeners(env, event)
	local n = 0
	for _, frame in ipairs(env._frames) do
		if frame:IsEventRegistered(event) then
			n = n + 1
		end
	end
	return n
end

-- Combat.Queue ---------------------------------------------------------------------------------

do
	local env, K = CoreEnv.New()
	CoreEnv.Boot(env)
	local Queue = K.Combat.Queue
	local ran = {}
	local function add(name)
		return function()
			ran[#ran + 1] = name
		end
	end

	Queue(add("now"))
	assert(ran[1] == "now", "out of combat, Queue runs the function at once")
	assert(listeners(env, "PLAYER_REGEN_ENABLED") == 0, "with nothing queued, the core does not listen for PLAYER_REGEN_ENABLED")

	env.SetCombat(true)
	Queue(add("a"))
	Queue(add("b"))
	Queue(function()
		error("queued failure")
	end)
	Queue(add("c"))
	assert(#ran == 1, "in combat, Queue holds the work")
	assert(listeners(env, "PLAYER_REGEN_ENABLED") == 1, "queued work listens for PLAYER_REGEN_ENABLED")
	env.SetCombat(false)
	assert(table.concat(ran, ",") == "now,a,b,c", "queued work runs in order after combat, got " .. table.concat(ran, ","))
	assert(#env._errors == 1 and tostring(env._errors[1]):find("queued failure", 1, true), "a failing entry is reported and the rest still run")
	assert(listeners(env, "PLAYER_REGEN_ENABLED") == 0, "an empty queue stops listening")

	env.SetCombat(true)
	env.SetCombat(false)
	assert(#ran == 4, "each entry runs once")

	-- Work queued while the queue runs is out of combat, so it runs at once and keeps the order.
	ran = {}
	env.SetCombat(true)
	Queue(function()
		ran[#ran + 1] = "outer"
		Queue(add("inner"))
	end)
	Queue(add("after"))
	env.SetCombat(false)
	assert(table.concat(ran, ",") == "outer,inner,after", "got " .. table.concat(ran, ","))

	Raises(function() Queue("SetBinding") end, "function", "Queue without a function")
end

-- Safe.HideBlizzard ----------------------------------------------------------------------------

local function editModeEnv()
	return CoreEnv.New({
		setup = function(env)
			env.EditModeManagerFrame = env.CreateFrame("Frame", "EditModeManagerFrame", env.UIParent)
			env.EditModeManagerFrame:Hide()
			local callbacks = {}
			env._editModeCallbacks = callbacks
			env.EventRegistry = {
				RegisterCallback = function(_, event, fn, owner)
					assert(type(event) == "string" and type(fn) == "function" and owner ~= nil)
					callbacks[event] = callbacks[event] or {}
					callbacks[event][owner] = fn
					return owner
				end,
				UnregisterCallback = function(_, event, owner)
					if callbacks[event] then
						callbacks[event][owner] = nil
					end
				end,
				TriggerEvent = function(_, event, ...)
					for owner, fn in pairs(callbacks[event] or {}) do
						fn(owner, ...)
					end
				end,
			}
		end,
	})
end

local function setParentCalls(frame)
	local n = 0
	for _, call in ipairs(frame._calls) do
		if call.method == "SetParent" then
			n = n + 1
		end
	end
	return n
end

do
	local env, K = editModeEnv()
	CoreEnv.Boot(env)
	local Safe = K.Safe
	local bar = env.CreateFrame("Frame", "MainActionBar", env.UIParent)

	Safe.HideBlizzard(bar)
	assert(bar:GetParent() == env.UIParent, "HideBlizzard defers the reparent with C_Timer.After(0)")
	env.RunTimers()
	local hidden = bar:GetParent()
	assert(hidden ~= env.UIParent and hidden:IsShown() == false, "the frame is reparented to a hidden frame")
	assert(not bar:IsVisible(), "the reparented frame is no longer visible")
	assert(hidden:GetParent() == nil or hidden:GetParent() == env.UIParent)

	-- Calling it again does nothing more.
	Safe.HideBlizzard(bar)
	env.RunTimers()
	assert(setParentCalls(bar) == 1, "a frame is reparented once")

	-- In combat the reparent waits for the combat queue.
	local frame = env.CreateFrame("Frame", "PlayerFrame", env.UIParent)
	Safe.HideBlizzard(frame)
	env.SetCombat(true)
	env.RunTimers()
	assert(frame:GetParent() == env.UIParent, "no reparent in combat")
	env.SetCombat(false)
	assert(frame:GetParent() == hidden, "the reparent runs after combat")

	-- While Edit Mode is open it waits for Edit Mode to close.
	local target = env.CreateFrame("Frame", "TargetFrame", env.UIParent)
	env.EditModeManagerFrame:Show()
	Safe.HideBlizzard(target)
	env.RunTimers()
	assert(target:GetParent() == env.UIParent, "no reparent while Edit Mode is open")
	env.EditModeManagerFrame:Hide()
	env.EventRegistry:TriggerEvent("EditMode.Exit")
	env.RunTimers()
	assert(target:GetParent() == hidden, "the reparent runs after Edit Mode closes")
	local owners = 0
	for _ in pairs(env._editModeCallbacks["EditMode.Exit"] or {}) do
		owners = owners + 1
	end
	assert(owners == 0, "the Edit Mode callback is removed once nothing waits for it")

	-- Restore puts a frame back on its own parent, out of combat.
	Safe.RestoreBlizzard(bar)
	env.RunTimers()
	assert(bar:GetParent() == env.UIParent, "RestoreBlizzard returns the frame to its first parent")
	Safe.HideBlizzard(bar)
	env.RunTimers()
	assert(bar:GetParent() == hidden, "a restored frame can be hidden again")

	-- A Blizzard frame that does not exist on this client is skipped and logged, not an error.
	Safe.HideBlizzard(nil)
	env.RunTimers()
	assert(#env._errors == 0, "HideBlizzard(nil) must not error")
	local logged = false
	for _, entry in ipairs(env.KstyleUIDB.devlog) do
		logged = logged or (entry.module == "Safe" and entry.message:find("missing", 1, true) ~= nil)
	end
	assert(logged, "a missing frame is logged to the devlog")
	Raises(function() Safe.HideBlizzard("PlayerFrame") end, "frame", "HideBlizzard with a name instead of a frame")
end

-- Safe.Side ------------------------------------------------------------------------------------

do
	local _, K = CoreEnv.New()
	local Side = K.Safe.Side
	local a, b = {}, {}
	local sa = Side(a)
	assert(type(sa) == "table" and Side(a) == sa, "Side returns the same table for the same frame")
	assert(Side(b) ~= sa, "each frame has its own side table")
	sa.restyled = true
	assert(a.restyled == nil, "side state is never written onto the frame")

	local probe = setmetatable({}, { __mode = "v" })
	do
		local frame = {}
		probe[1] = Side(frame)
	end
	collectgarbage()
	collectgarbage()
	assert(probe[1] == nil, "side tables are weak-keyed, so a collected frame frees its state")
	Raises(function() Side(nil) end, "frame", "Side(nil)")
end

print("combat ok")
