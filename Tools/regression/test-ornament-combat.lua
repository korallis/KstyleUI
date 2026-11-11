-- test-ornament-combat.lua: in combat lockdown a unit frame's and its cast bar's ornaments change nothing on a protected owner until PLAYER_REGEN_ENABLED, and restyle at once on an owner the game leaves movable.
local U = dofile("Tools/regression/unitframes_env.lua")
local env, K, ns = U.New()
U.SetUnit(env, "target", { name = "Shadowgale Poacher", level = 12, health = 50, healthMax = 100, reaction = 2, canAttack = true, classification = "elite" })
env.FireEvent("PLAYER_TARGET_CHANGED")
env._units.target.cast = { name = "Frostbolt", texture = 135846, start = 1000, finish = 3500, spellID = 116 }
env.FireEvent("UNIT_SPELLCAST_START", "target", "Cast-2", 116)
env.RunTimers()
assert(K.Widgets.Setting("ornaments") == "Full", "a profile without a stored level is Full")
local view = ns.Frames.Get("target").views[1]
local cb = view.castbar
assert(cb and cb.ornament and cb.panel, "the target has a cast bar with its own ornament handle")
local handles = { view.health.ornament, view.portraitOrnament, view.chrome.ornament, cb.ornament }
local owners = { view.panel, view.portraitFrame, cb.panel }
for _, owner in ipairs(owners) do
	assert(owner:IsVisible(), "every ornament owner shows, the cast bar's with its cast")
end
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
for i, handle in ipairs(handles) do
	assert(touched[handle], "the level change reaches ornament handle " .. i .. " in combat")
	assert(handle.queued, "a protected owner's restyle waits for the end of combat: handle " .. i)
	touched[handle] = nil
end
env.SetCombat(false)
env.RunTimers()
for i, handle in ipairs(handles) do
	assert(not handle.queued and touched[handle], "PLAYER_REGEN_ENABLED runs the queued restyle: handle " .. i)
end
assert(calls() > before, "the queued restyles draw the new level after combat")

for _, owner in ipairs(owners) do
	owner.IsProtected = function() return false end
end
env.SetCombat(true)
seen = restyles
for handle in pairs(touched) do touched[handle] = nil end
K.Options.Write("Widgets", "ornaments", "Full")
env.RunTimers()
for i, handle in ipairs(handles) do
	assert(not handle.queued and touched[handle], "an owner the game leaves movable restyles in combat without queueing: handle " .. i)
end
assert(restyles > seen, "the movable owners restyled in combat")
env.SetCombat(false)
assert(#env._errors == 0 and K.ErrorCount() == 0, "no errors: " .. tostring(env._errors[1]))
print("ok ornament restyles respect combat lockdown")
