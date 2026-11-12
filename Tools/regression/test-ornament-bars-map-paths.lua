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
local function Shown(handle)
	local n = 0
	for i = 1, handle.used do
		if handle.textures[i]:IsVisible() then n = n + 1 end
	end
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

local env, K, ns, game = D.New()
D.W.Settle(env)
PropagateShow(env)
assert(K.Widgets.Setting("ornaments") == "Full", "a profile without a stored level is Full")
local xp, rep = ns.Bars.views.xp, ns.Bars.views.rep
assert(xp.ornament.used > 0 and Shown(xp.ornament) == xp.ornament.used, "the experience bar places its pieces at Full")
Count(xp.ornament)
D.W.Settle(env)
env.RunTimers()

local function Step(what, fn, restyles)
	Reset()
	fn()
	D.W.Settle(env)
	env.RunTimers()
	if restyles == 0 then
		assert(Total() == 0, what .. " makes no ornament call, not " .. Total())
	else
		assert(counts.Restyle == restyles, what .. " restyles " .. restyles .. " time(s), not " .. counts.Restyle)
	end
end

local label = xp.text:GetText()
Step("an experience gain that keeps the label's width", function()
	game.xp = game.xp + 1
	env.FireEvent("PLAYER_XP_UPDATE", "player")
end, 0)
assert(xp.text:GetText() == label, "the fixture's gain keeps the label")
Step("UPDATE_EXHAUSTION with the same rested share", function() env.FireEvent("UPDATE_EXHAUSTION") end, 0)
Step("PLAYER_UPDATE_RESTING", function() env.FireEvent("PLAYER_UPDATE_RESTING") end, 0)
Step("a reputation gain on a bar whose text shows on hover", function()
	game.faction.currentStanding = (game.faction.currentStanding or 0) + 1
	env.FireEvent("UPDATE_FACTION")
end, 0)
Step("rested experience running out, which shortens the label", function()
	game.rested = nil
	env.FireEvent("UPDATE_EXHAUSTION")
end, 1)
assert(xp.text:GetText() ~= label, "the label lost its rested share")

local enter, leave = rep.holder:GetScript("OnEnter"), rep.holder:GetScript("OnLeave")
Step("the pointer entering the reputation bar, which shows its text", function() enter(rep.holder) end, 1)
Step("the pointer leaving it", function() leave(rep.holder) end, 1)

Step("the experience bar hiding at the level cap, which restyles it and the two bars that avoid it", function()
	game.level = game.maxLevel
	env.FireEvent("PLAYER_LEVEL_UP", game.maxLevel)
end, 3)
assert(not xp.content:IsShown() and xp.ornament.stale, "the hidden experience bar's ornament is stale")
Step("an experience event while the bar is hidden", function() env.FireEvent("PLAYER_XP_UPDATE", "player") end, 0)
Reset()
game.level = 38
env.FireEvent("PLAYER_LEVEL_UP", 38)
D.W.Settle(env)
assert(xp.content:IsShown() and not xp.ornament.stale and Shown(xp.ornament) == xp.ornament.used and xp.ornament.used > 0, "the bar places its pieces again when it shows")
Step("the reputation bar moving, which restyles it and the two bars that avoid it", function()
	K.Callbacks.Fire("LayoutChanged", "databars.rep")
end, 3)
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
