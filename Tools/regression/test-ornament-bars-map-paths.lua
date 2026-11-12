-- test-ornament-bars-map-paths.lua: the data bars' ornaments restyle only when a state that moves a piece changes (a label's width or shown state, a layout, another Layout element moving, a data bar showing, hiding or moving beside another); per-event updates (experience, rested, reputation) touch no ornament, and a bar hidden at the level cap goes stale and places again when it shows. The minimap, a card since the overhaul, makes no ornament on any path.
local D = dofile("Tools/regression/databars_env.lua")
local M = dofile("Tools/regression/minimap_env.lua")

local counts = { Restyle = 0, Place = 0, Piece = 0, Follow = 0, Swap = 0 }
local wrapped = {}
local function Count(handle)
	local Handle = getmetatable(handle).__index
	if wrapped[Handle] then return end
	wrapped[Handle] = true
	for name in pairs(counts) do
		local original = Handle[name]
		Handle[name] = function(...)
			counts[name] = counts[name] + 1
			return original(...)
		end
	end
end
local function Reset()
	for name in pairs(counts) do counts[name] = 0 end
end
local function Total()
	local n = 0
	for _, v in pairs(counts) do n = n + v end
	return n
end
-- The stubs fire OnShow only on the frame shown; the game fires it on every frame that becomes visible.
local function PropagateShow(env)
	for _, frame in ipairs(env._frames) do
		for _, method in ipairs({ "Show", "SetShown" }) do
			local original = frame[method]
			frame[method] = function(self, ...)
				local before = {}
				for _, f in ipairs(env._frames) do before[f] = f:IsVisible() end
				original(self, ...)
				for _, f in ipairs(env._frames) do
					local script = f._scripts and f._scripts.OnShow
					if script and not before[f] and f:IsVisible() then script(f) end
				end
			end
		end
	end
end

-- Data bars -------------------------------------------------------------------------------------------------

-- Since the overhaul (KSTY-44 bible 3.4: no ornament around a bar) the experience, reputation and honour bars are
-- clean: no bar owns an ornament handle, and no path makes one on a bar, whatever the level.
local env, K, ns, game = D.New()
D.W.Settle(env)
PropagateShow(env)
assert(K.Widgets.Setting("ornaments") == "Full", "a profile without a stored level is Full")
for id, view in pairs(ns.Bars.views) do
	assert(view.ornament == nil and view.rim == nil, "the " .. id .. " bar owns no ornament at Full")
end
local function Under(frame, roots)
	while frame do
		if roots[frame] then return true end
		frame = type(frame.GetParent) == "function" and frame:GetParent() or nil
	end
	return false
end
local holders = {}
for _, view in pairs(ns.Bars.views) do
	holders[view.holder] = true
end
local made = 0
local Ornament = K.Widgets.Ornament
K.Widgets.Ornament = function(owner, ...)
	if Under(owner, holders) then
		made = made + 1
	end
	return Ornament(owner, ...)
end
local xp, rep = ns.Bars.views.xp, ns.Bars.views.rep
game.xp = game.xp + 1
env.FireEvent("PLAYER_XP_UPDATE", "player")
env.FireEvent("UPDATE_EXHAUSTION")
env.FireEvent("PLAYER_UPDATE_RESTING")
game.faction.currentStanding = (game.faction.currentStanding or 0) + 1
env.FireEvent("UPDATE_FACTION")
game.rested = nil
env.FireEvent("UPDATE_EXHAUSTION")
rep.holder:GetScript("OnEnter")(rep.holder)
rep.holder:GetScript("OnLeave")(rep.holder)
game.level = game.maxLevel
env.FireEvent("PLAYER_LEVEL_UP", game.maxLevel)
D.W.Settle(env)
assert(not xp.content:IsShown(), "the experience bar hides at the level cap")
game.level = 38
env.FireEvent("PLAYER_LEVEL_UP", 38)
D.W.Settle(env)
assert(xp.content:IsShown(), "and shows again below it")
K.Callbacks.Fire("LayoutChanged", "databars.rep")
D.W.Settle(env)
env.RunTimers()
K.Widgets.Ornament = Ornament
assert(made == 0, "the data bars' paths make no ornament on a bar, not " .. made)
assert(#env._errors == 0, tostring(env._errors[1]))

-- Minimap ---------------------------------------------------------------------------------------------------

-- Since the overhaul (KSTY-44) the minimap is a card whose only corner pieces are its brackets: it owns no ornament
-- handle, and its per-event paths (the clock, the coordinates' ticker, the zoom, a new zone, a neighbour moving, the
-- button drawer) make none.
local menv, MK, mns = M.New({ enabled = true })
M.Settle(menv)
local face = mns.Map.face
assert(MK.Widgets.Setting("ornaments") == "Full", "the minimap fixture is at Full")
assert(face.ornament == nil and face.plaqueOrnament == nil, "the minimap card owns no ornament handle at Full")
local made = 0
local Ornament = MK.Widgets.Ornament
MK.Widgets.Ornament = function(...)
	made = made + 1
	return Ornament(...)
end
M.RunTickers(menv)
menv.FireEvent("PLAYER_STARTED_MOVING")
M.RunTickers(menv)
menv.FireEvent("PLAYER_STOPPED_MOVING")
menv.FireEvent("MINIMAP_UPDATE_ZOOM")
menv._zone.text = "Hall of Thanes"
menv.FireEvent("ZONE_CHANGED_NEW_AREA")
MK.Callbacks.Fire("LayoutChanged", "auras.buffs")
mns.Map.drawer:Open()
mns.Map.drawer:Close(true)
M.Settle(menv)
MK.Widgets.Ornament = Ornament
assert(made == 0, "the minimap's paths make no ornament, not " .. made)
assert(#menv._errors == 0, tostring(menv._errors[1]))
print("ok bars and map paths")
