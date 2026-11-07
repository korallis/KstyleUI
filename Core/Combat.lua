-- Combat.lua: a queue that holds protected work in combat and runs it on PLAYER_REGEN_ENABLED.
local _, ns = ...

local Combat = {}
ns.Combat = Combat

local queue = {}

local function flush()
	if InCombatLockdown() then
		return
	end
	ns.Events.Unregister("Combat", "PLAYER_REGEN_ENABLED")
	local batch = queue
	queue = {}
	for i = 1, #batch do
		ns.Call(batch[i])
	end
end

function Combat.Queue(fn)
	if type(fn) ~= "function" then
		error("KstyleUI.Combat.Queue: fn must be a function, got " .. type(fn), 2)
	end
	if not InCombatLockdown() then
		fn()
		return
	end
	queue[#queue + 1] = fn
	if #queue == 1 then
		ns.Events.Register("Combat", "PLAYER_REGEN_ENABLED", flush)
	end
end

function Combat.Pending()
	return #queue
end
