-- test-unitframes-indicators.lua: raid markers, leader, role, PvP, combat and resting icons and the threat glow follow their unit and settings, secrets included.
local U = dofile("Tools/regression/unitframes_env.lua")
local W = U.W

local env, K, ns = U.New()
local Frames = ns.Frames
local player = Frames.Get("player").views[1]
local target = Frames.Get("target").views[1]

local function noErrors(where)
	assert(#env._errors == 0, where .. ": " .. tostring(env._errors[1]))
	assert(K.ErrorCount() == 0, where .. ": KstyleUI caught an error")
end

local function visible(region)
	return region:IsShown() == true and (region:GetAlpha() or 1) > 0
end

-- Every view has the icons, the marker and the glow, all hidden while nothing applies.
for _, key in ipairs(ns.Indicators.SLOTS) do
	assert(player.icons[key], "the player frame has a " .. key .. " icon")
end
assert(player.marker and player.glowFrame, "the player frame has a raid marker and a threat glow")
assert(not visible(player.icons.leader) and not visible(player.marker) and not player.glowFrame:IsShown(), "nothing shows by default")

-- The status icons sit on the panel's top edge, starting at the end away from the portrait.
local function centreX(region)
	local _, _, _, x = region:GetPoint(1)
	return x
end
assert(centreX(player.icons.leader) > centreX(player.icons.role), "the player's icons run leftward from the panel's right end")
assert(centreX(target.icons.leader) < centreX(target.icons.role), "the target's icons run rightward from the panel's left end")
local _, _, _, mx = player.marker:GetPoint(1)
local g = player.geometry
local r, fit = g.medal.w / 2, ns.Geometry.SLAB_FIT
assert(math.abs(mx - g.marker.x) < 1 and math.abs(g.marker.x + g.marker.w / 2 - (g.medal.x + r - r * fit.across)) < 0.5 and math.abs(g.marker.y + g.marker.h / 2 - (g.medal.y + r - r * fit.rise)) < 0.5,
	"Fitted slabs: the raid marker sits in a socket on the medallion's upper outer rim, opposite the level plaque")
local rowY = select(5, player.icons.leader:GetPoint(1))
assert(-rowY + player.icons.leader.socket:GetHeight() / 2 <= 0.5 and player.icons.leader.socket:GetWidth() > player.icons.leader:GetWidth(),
	"Fitted slabs: each status icon sits in a socket resting on the slab's top edge, not across it")
K.Options.Write("UnitFrames", "fittedSlabs", false)
env.RunTimers()
g = player.geometry
assert(g.marker.x + g.marker.w <= g.medal.x or g.marker.x >= g.medal.x + g.medal.w, "off: the raid marker sits beside the medallion")
assert(math.abs(select(5, player.icons.leader:GetPoint(1))) < 0.5 and not player.icons.leader.socket.on, "off: the icons centre on the top edge with no sockets")
K.Options.Write("UnitFrames", "fittedSlabs", true)
env.RunTimers()

-- Leader: a plain answer shows or hides; a secret one goes through SetAlphaFromBoolean.
env._units.player.leader = true
env.FireEvent("PARTY_LEADER_CHANGED")
assert(visible(player.icons.leader), "the leader icon shows for the group leader")
env._units.player.leader = env.Secret(false)
env.FireEvent("GROUP_ROSTER_UPDATE")
local alpha = W.LastCall(player.icons.leader, "SetAlphaFromBoolean")
assert(alpha and env.issecretvalue(alpha[1]) and alpha[2] == 1 and alpha[3] == 0, "a secret leader flag reaches SetAlphaFromBoolean")
env._units.player.leader = false

-- Role and PvP use Blizzard's atlases.
env._units.player.role = "TANK"
env.FireEvent("PLAYER_ROLES_ASSIGNED")
assert(W.LastCall(player.icons.role, "SetAtlas")[1] == "roleicon-tiny-tank" and visible(player.icons.role), "a tank shows the tank icon")
env._units.player.role = "NONE"
env.FireEvent("PLAYER_ROLES_ASSIGNED")
assert(not visible(player.icons.role), "no role, no icon")
env._units.player.pvp, env._units.player.faction = true, "Horde"
env.FireEvent("PLAYER_FLAGS_CHANGED", "player")
assert(W.LastCall(player.icons.pvp, "SetAtlas")[1] == "UI-HUD-UnitFrame-SmallCircle-Horde" and visible(player.icons.pvp), "a flagged Horde player shows the Horde badge")
env._units.player.ffa = true
env.FireEvent("UNIT_FACTION", "player")
assert(W.LastCall(player.icons.pvp, "SetAtlas")[1] == "UI-HUD-UnitFrame-Player-PVP-FFAIcon", "free-for-all PvP shows its own badge")
env._units.player.pvp, env._units.player.ffa = false, false
env.FireEvent("UNIT_FACTION", "player")
assert(not visible(player.icons.pvp), "unflagged: no badge")

-- Combat and resting on the player.
env._units.player.combat = true
env.SetCombat(true)
assert(visible(player.icons.combat), "the combat icon shows in combat")
env._units.player.combat = false
env.SetCombat(false)
assert(not visible(player.icons.combat), "and hides after it")
env._resting = true
env.FireEvent("PLAYER_UPDATE_RESTING")
assert(visible(player.icons.resting) and player.icons.resting:GetText() == "Zz", "resting shows Zz")
env._resting = false
env.FireEvent("PLAYER_UPDATE_RESTING")
assert(not visible(player.icons.resting), "not resting: no Zz")
assert(not visible(target.icons.combat) and not visible(target.icons.resting), "the target frame shows no combat or resting icon by default")
noErrors("status icons")

-- The raid marker: a secret index reaches SetSpriteSheetCell; none hides it.
U.SetUnit(env, "target", { name = "Wolf", level = 12, health = 50, healthMax = 200, reaction = 2, canAttack = true, marker = 8 })
env.SetTarget(true)
local cell = W.LastCall(target.marker, "SetSpriteSheetCell")
assert(cell and env.issecretvalue(cell[1]) and cell[2] == 4 and cell[3] == 4 and visible(target.marker), "the skull marker shows from a secret index")
env._units.target.marker = nil
env.FireEvent("RAID_TARGET_UPDATE")
assert(not visible(target.marker), "a cleared marker hides")
local cells = #W.Calls(target.marker, "SetSpriteSheetCell")
env.FireEvent("RAID_TARGET_UPDATE")
assert(#W.Calls(target.marker, "SetSpriteSheetCell") == cells, "a secret nil index never reaches SetSpriteSheetCell")

-- Threat: the player's status on a hostile target, in the glass-tuned threat colour that nameplates use.
env._units.target.threatOn = 3
env.FireEvent("UNIT_THREAT_LIST_UPDATE", "target")
assert(target.glowFrame:IsShown(), "tanking the target lights its glow")
assert(W.SameRGB(target.glow[1], K.Theme.ThreatColor(3)), "in the hostile token, not Blizzard's raw red")
env._units.target.threatOn = 1
env.FireEvent("UNIT_THREAT_LIST_UPDATE", "target")
local nr, ng, nb = K.Tokens.Color("neutral")
assert(W.SameRGB(target.glow[1], nr, ng, nb), "higher threat than the tank is the neutral token")
env._units.target.threatOn = 0
env.FireEvent("UNIT_THREAT_SITUATION_UPDATE", "player")
assert(not target.glowFrame:IsShown(), "no threat: no glow")
env._units.target.threatOn = env.Secret(2)
env.FireEvent("UNIT_THREAT_SITUATION_UPDATE", "player")
assert(not target.glowFrame:IsShown(), "a secret status is never compared; the glow stays off")
env._units.player.threat = 2
env.FireEvent("UNIT_THREAT_SITUATION_UPDATE", "player")
assert(player.glowFrame:IsShown(), "the player frame glows with the player's own threat")

-- UNIT_THREAT_LIST_UPDATE fires for every mob in combat. One for a unit no frame shows repaints
-- nothing, and an unchanged status is not repainted.
env._units.target.threatOn = 3
env.FireEvent("UNIT_THREAT_LIST_UPDATE", "target")
assert(target.glowFrame:IsShown(), "the target glows again")
local painted = #W.Calls(target.glow[1], "SetVertexColor")
local playerPainted = #W.Calls(player.glow[1], "SetVertexColor")
env.FireEvent("UNIT_THREAT_LIST_UPDATE", "nameplate7")
assert(#W.Calls(target.glow[1], "SetVertexColor") == painted, "a threat list update for a unit no frame shows repaints nothing")
assert(#W.Calls(player.glow[1], "SetVertexColor") == playerPainted, "not even the player frame")
env.FireEvent("UNIT_THREAT_LIST_UPDATE", "target")
assert(#W.Calls(target.glow[1], "SetVertexColor") == painted, "an unchanged threat status is not repainted")
env._units.target.threatOn = 1
env.FireEvent("UNIT_THREAT_LIST_UPDATE", "target")
assert(#W.Calls(target.glow[1], "SetVertexColor") > painted, "a new status repaints")
assert(W.SameRGB(target.glow[1], nr, ng, nb), "in the new colour")
env._units.target.threatOn = 3
env.FireEvent("UNIT_THREAT_SITUATION_UPDATE", "player")
assert(W.SameRGB(target.glow[1], K.Theme.ThreatColor(3)), "the player's own threat update reaches the target frame")
noErrors("marker and threat")

-- The resting text follows the module's accent at once.
env._resting = true
env.FireEvent("PLAYER_UPDATE_RESTING")
K.Options.Write("UnitFrames", "accent", "custom")
K.Options.Write("UnitFrames", "accentColor", { r = 0.2, g = 0.3, b = 0.9 })
local tr, tg, tb = player.icons.resting:GetTextColor()
assert(tr == 0.2 and tg == 0.3 and tb == 0.9, "the Zz takes a new accent without waiting for a status change")
K.Options.Write("UnitFrames", "accent", "class")
env._resting = false
env.FireEvent("PLAYER_UPDATE_RESTING")

-- Settings switch each indicator off.
K.Options.Write("UnitFrames", "player.threat", false)
assert(not player.glowFrame:IsShown(), "threat glow off")
K.Options.Write("UnitFrames", "player.combat", false)
env._units.player.combat = true
env.SetCombat(true)
assert(not visible(player.icons.combat), "combat icon off")
env.SetCombat(false)
K.Options.Write("UnitFrames", "player.iconSize", 20)
local _, h = player.icons.leader:GetSize()
assert(math.abs(h - 20) < 1, "the icon size follows its setting")
noErrors("settings")

-- Baine, 2026-11-21: in the icon's square "Zz" is wider than its box, so the game cut it to two dots.
-- The Zz fits its text in the kit's glyphs at each test screen; the PvP countdown keeps the square's edge.
local scene = dofile("Tools/render/scene.lua")
for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	local e, k, n = U.New({ width = screen[1], height = screen[2], size = "auto", setup = function(e)
		e.IsPVPTimerRunning = function() return true end
		e.GetPVPTimer = function() return 61000 end
	end })
	local p, at = n.Frames.Get("player").views[1], screen[1] .. "x" .. screen[2] .. ": "
	local z, side = p.icons.resting, p.spots.resting.size
	e._textWidth = function(text, path, size) return scene.TextWidth(text, size, path) end
	e._units.player.pvp, e._units.player.faction = true, "Horde"
	k.Options.Write("UnitFrames", "player.pvpTimer", true)
	e.FireEvent("PLAYER_FLAGS_CHANGED", "player")
	local x = scene.Rect(e, p.pvpTimer)
	e._resting = true
	e.FireEvent("PLAYER_UPDATE_RESTING")
	local _, zzSize = z:GetFont()
	assert(z:IsShown() and not z:IsTruncated() and zzSize == p.icons.combat:GetHeight(), at .. "the Zz is whole, as tall as the combat icon: " .. z:GetWidth() .. " wide, size " .. zzSize)
	z:SetSize(side, side)
	assert(scene.Rect(e, p.pvpTimer) == x, at .. "the PvP countdown sits at the Zz square's edge: " .. x .. " against " .. scene.Rect(e, p.pvpTimer))
end

-- Frames: the raid marker sits over the portrait's centre.
do
	local fenv, FK, fns = U.New({ frames = true })
	local view = fns.Frames.Get("player").views[1]
	local _, _, _, x = view.marker:GetPoint(1)
	x = x + view.marker:GetWidth() / 2
	local fg = view.geometry
	assert(math.abs(x - (fg.portrait.x + fg.portrait.w / 2)) < 1, "the Frames raid marker sits over the portrait's centre")
	assert(#fenv._errors == 0 and FK.ErrorCount() == 0, tostring(fenv._errors[1]))
end

print("unitframes indicators ok")
