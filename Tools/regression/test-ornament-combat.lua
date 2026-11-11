-- test-ornament-combat.lua: in combat lockdown a unit frame's ornaments change nothing on a protected owner until PLAYER_REGEN_ENABLED, and restyle at once on an owner the game leaves movable.
local U = dofile("Tools/regression/unitframes_env.lua")
local env, K, ns = U.New()
U.SetUnit(env, "target", { name = "Shadowgale Poacher", level = 12, health = 50, healthMax = 100, reaction = 2, canAttack = true, classification = "elite" })
env.FireEvent("PLAYER_TARGET_CHANGED")
env.RunTimers()
assert(K.Widgets.Setting("ornaments") == "Full", "a profile without a stored level is Full")
local view = ns.Frames.Get("target").views[1]
local handles = { view.health.ornament, view.portraitOrnament, view.chrome.ornament }
local owners = { view.panel, view.portraitFrame }
for _, owner in ipairs(owners) do
	assert(owner:IsProtected() ~= true, "the ornament owners are plain frames, not the secure unit button")
end
local function changes(object)
	local n = 0
	for _, call in ipairs(object._calls) do
		if not call.method:find("^Get") and not call.method:find("^Is") then n = n + 1 end
	end
	return n
end
local function calls()
	local n = 0
	for _, handle in ipairs(handles) do
		for _, t in ipairs(handle.textures) do n = n + changes(t) end
		if handle.host then n = n + changes(handle.host) end
	end
	return n
end
local restyles, touched = 0, {}
for _, handle in ipairs(handles) do
	local restyle = handle.Restyle
	handle.Restyle = function(self, ...)
		restyles, touched[self] = restyles + 1, true
		return restyle(self, ...)
	end
end

for _, owner in ipairs(owners) do
	owner.IsProtected = function() return true end
end
env.SetCombat(true)
local before, seen = calls(), restyles
for handle in pairs(touched) do touched[handle] = nil end
K.Options.Write("Widgets", "ornaments", "Subtle")
env.RunTimers()
assert(restyles > seen, "the level change reaches the unit frame's ornaments in combat")
assert(calls() == before, "in lockdown nothing sets, shows, hides or anchors a protected owner's ornament textures or host")
for _, handle in ipairs(handles) do
	assert(handle.queued or not touched[handle], "a protected owner's restyle waits for the end of combat")
end
env.SetCombat(false)
env.RunTimers()
for _, handle in ipairs(handles) do
	assert(not handle.queued, "PLAYER_REGEN_ENABLED runs the queued restyle")
end

for _, owner in ipairs(owners) do
	owner.IsProtected = function() return false end
end
env.SetCombat(true)
seen = restyles
K.Options.Write("Widgets", "ornaments", "Full")
env.RunTimers()
for _, handle in ipairs(handles) do
	assert(not handle.queued, "an owner the game leaves movable restyles in combat without queueing")
end
assert(restyles > seen, "the movable owners restyled in combat")
env.SetCombat(false)
assert(#env._errors == 0 and K.ErrorCount() == 0, "no errors: " .. tostring(env._errors[1]))
print("ok ornament restyles respect combat lockdown")
