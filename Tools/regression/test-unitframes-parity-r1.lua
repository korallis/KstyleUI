-- test-unitframes-parity-r1.lua: parity round 1 options keep v0.2.8 looks and regions, then write and apply fill and prediction opacity, colour by health, gradient, decimals, portrait mirror and zoom, friendly level colour, PvP filters, elite and pet badges, hover and target highlights, tooltips, cast icon side, cast opacity and layering, and aura zoom.
local U = dofile("Tools/regression/unitframes_env.lua")
local W = U.W

local function saved(own)
	own = own or {}
	own.enabled = true
	return { version = 42, profiles = { Default = { UnitFrames = own } }, characters = {}, layouts = {} }
end

local function near(a, b)
	return math.abs(a - b) < 1e-6
end

local function plain(env, value)
	if env.issecretvalue(value) then
		return env.Reveal(value)
	end
	return value
end

local function clean(env, K)
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

local function count(object, method)
	return #W.Calls(object, method)
end

local function keys(schema)
	local out = {}
	for _, row in ipairs(schema) do
		if row.key then out[row.key] = row end
	end
	return out
end

local env, K, ns = U.New({
	saved = saved(),
	setup = function(e)
		e.C_Texture = { GetAtlasInfo = function() return { leftTexCoord = 0.1, rightTexCoord = 0.3, topTexCoord = 0.5, bottomTexCoord = 0.7 } end }
		e.C_PetInfo = { GetPetHappiness = function() return e._mood end }
		e._mood, e._hunter = 3, true
		e.HasPetUI = function() return true, e._hunter end
		e.GetCreatureDifficultyColor = function() return { r = 1, g = 0.1, b = 0.1 } end
	end,
})
local Settings = ns.Settings

local function write(key, value)
	K.Options.Write("UnitFrames", key, value)
	env.RunTimers()
	assert(K.Options.Read("UnitFrames", key) == value, key .. " must round-trip")
end

-- Old profiles keep today's look and make no new regions.
local DEFAULTS = {
	healthAlpha = 1, healthGradient = "", incomingAlpha = 0.45, absorbAlpha = 0.35, healAbsorbAlpha = 0.7,
	portraitMirror = false, portraitZoom = 0, levelFriendly = false, pvpEnemyOnly = false, pvpPlayersOnly = false,
	elite = false, hoverBorder = false, targetBorder = false, castbarAlpha = 1, castbarIconRight = false,
	auraZoom = 0.07, auraTooltipCombat = true,
}
for _, kind in ipairs(U.KINDS) do
	for key, value in pairs(DEFAULTS) do
		assert(Settings.Value(kind, key) == value, kind .. "." .. key .. " keeps its default")
	end
	for _, view in ipairs(ns.Frames.Get(kind).views) do
		assert(view.edge == nil and view.extraIcon == nil, kind .. " makes no highlight or badge until an option needs one")
	end
end
assert(Settings.Value("pet", "happiness") == false, "pet happiness starts off")
local module = Settings.Module()
assert(not module.healthDecimal and module.unitTooltip == "always" and not module.castbarRaise, "module options keep today's behaviour")

local schema = keys(Settings.Schema())
assert(schema["pet.happiness"] and not schema["target.happiness"], "only the pet has a happiness row")
assert(schema["focus.targetBorder"] and not schema["target.targetBorder"], "the target frame has no target highlight row")
assert(schema["target.elite"] and not schema["player.elite"] and not schema["pet.elite"], "the elite badge is for other units")

U.SetUnit(env, "target", { name = "Ogre", level = 62, health = 3000, healthMax = 4000, power = 30, powerMax = 100,
	reaction = 2, canAttack = true, classification = "elite", pvp = true, faction = "Alliance", isPlayer = true })
env._units.player.faction = "Alliance"
local target = ns.Frames.Get("target").views[1]
local bar = target.health
assert(W.LastCall(bar, "SetStatusBarColor").n == 3, "a solid fill keeps the three-channel colour")
assert(near(W.LastCall(target.incoming, "SetStatusBarColor")[4], 0.45), "incoming heals keep their opacity")

-- Fill opacity, on and after the events that recolour the bar.
write("target.healthAlpha", 0.5)
assert(W.LastCall(bar, "SetStatusBarColor")[4] == 0.5, "fill opacity reaches the health fill")
env.FireEvent("UNIT_FACTION", "target")
assert(W.LastCall(bar, "SetStatusBarColor")[4] == 0.5, "a faction change keeps the fill opacity")
write("target.healthAlpha", 1)
assert(W.LastCall(bar, "SetStatusBarColor").n == 3, "full opacity restores the solid colour")

-- Gradient: follows colour changes and relayouts; off restores the flat colour.
write("target.healthGradient", "HORIZONTAL")
local fill = bar:GetStatusBarTexture()
local gradient = assert(W.LastCall(fill, "SetGradient"), "the gradient shades the fill")
assert(gradient[1] == "HORIZONTAL", "the gradient runs the chosen way")
local before = count(fill, "SetGradient")
ns.Frames.Relayout(ns.Frames.Get("target"))
assert(count(fill, "SetGradient") > before, "a relayout reapplies the gradient its bar restyle cleared")
local flat = count(bar, "SetStatusBarColor")
write("target.healthGradient", "")
assert(not target.gradient and count(bar, "SetStatusBarColor") > flat, "turning the gradient off repaints the flat colour")

-- Colour by health left: follows UNIT_HEALTH, and grey states still win.
write("target.healthColor", "health")
local function fillColor()
	local call = W.LastCall(bar, "SetStatusBarColor")
	return plain(env, call[1]), plain(env, call[2]), plain(env, call[3])
end
local r, g, b = fillColor()
local wr, wg, wb = ns.Unit.ShareColor(0.75)
assert(near(r, wr) and near(g, wg) and near(b, wb), "the fill takes the colour for three quarters health")
env._units.target.health = 1000
env.FireEvent("UNIT_HEALTH", "target")
r, g, b = fillColor()
wr, wg, wb = ns.Unit.ShareColor(0.25)
assert(near(r, wr) and near(g, wg) and near(b, wb), "UNIT_HEALTH moves the colour toward red")
env._units.target.offline = true
env.FireEvent("UNIT_CONNECTION", "target")
r, g, b = fillColor()
wr, wg, wb = K.Tokens.Color("textDisabled")
assert(near(r, wr) and near(g, wg) and near(b, wb), "an offline unit stays grey")
local paints = count(bar, "SetStatusBarColor")
env.FireEvent("UNIT_HEALTH", "target")
assert(count(bar, "SetStatusBarColor") == paints, "a grey unit is not recoloured on health updates")
env._units.target.offline = nil
write("target.healthColor", "hud")
paints = count(bar, "SetStatusBarColor")
env.FireEvent("UNIT_HEALTH", "target")
assert(count(bar, "SetStatusBarColor") == paints, "other colour sources do no work on health updates")
env._units.target.health = 3000

-- Prediction opacity.
write("target.incomingAlpha", 0.8)
write("target.absorbAlpha", 0.6)
assert(near(W.LastCall(target.incoming, "SetStatusBarColor")[4], 0.8), "incoming heal opacity applies")
assert(near(W.LastCall(target.absorb, "SetStatusBarColor")[4], 0.6), "absorb opacity applies")
write("target.healAbsorbs", true)
write("target.healAbsorbAlpha", 0.4)
assert(near(W.LastCall(target.healAbsorb, "SetStatusBarColor")[4], 0.4), "heal absorb opacity applies")

-- Friendly level colour.
write("target.levelDifficulty", true)
env._units.target.canAttack = false
env.FireEvent("UNIT_FACTION", "target")
local er, eg, eb = K.Tokens.Color("textEmphasis")
r, g, b = target.levelText:GetTextColor()
assert(near(r, er) and near(g, eg) and near(b, eb), "a friendly level keeps its colour by default")
write("target.levelFriendly", true)
local dr, dg, db = K.Theme.Brighten(1, 0.1, 0.1)
r, g, b = target.levelText:GetTextColor()
assert(near(r, dr) and near(g, dg) and near(b, db), "friendly level colour colours a friendly level")
write("target.levelFriendly", false)
r, g, b = target.levelText:GetTextColor()
assert(near(r, er) and near(g, eg) and near(b, eb), "off restores the friendly level's colour")
env._units.target.canAttack = true

-- PvP filters refresh on faction changes.
local pvp = target.icons.pvp
assert(pvp:IsShown(), "a flagged unit shows the PvP badge")
write("target.pvpEnemyOnly", true)
assert(not pvp:IsShown(), "other faction only hides a same-faction badge")
env._units.target.faction = "Horde"
env.FireEvent("UNIT_FACTION", "target")
assert(pvp:IsShown(), "UNIT_FACTION shows the badge once the unit is of the other faction")
write("target.pvpPlayersOnly", true)
env._units.target.isPlayer = false
env.FireEvent("UNIT_FACTION", "target")
assert(not pvp:IsShown(), "players only hides the badge on an NPC")
env._units.target.ffa = true
env.FireEvent("PLAYER_FLAGS_CHANGED", "target")
assert(not pvp:IsShown(), "players only hides an NPC's free-for-all badge too")
env._units.target.ffa, env._units.target.isPlayer = nil, true
write("target.pvpPlayersOnly", false)
write("target.pvpEnemyOnly", false)
assert(pvp:IsShown(), "turning the filters off shows the badge again")

-- Elite badge: lazily made, follows classification changes, shares the resting slot.
write("target.elite", true)
local badge = assert(target.extraIcon, "turning the elite badge on makes it")
assert(badge:IsShown() and W.LastCall(badge, "SetAtlas")[1] == "nameplates-icon-elite-gold", "an elite target shows the gold dragon")
assert(W.LastCall(badge, "SetAllPoints")[1] == target.icons.resting, "the badge takes the player-only resting slot")
env._units.target.classification = "rareelite"
env.FireEvent("UNIT_CLASSIFICATION_CHANGED", "target")
assert(W.LastCall(badge, "SetAtlas")[1] == "nameplates-icon-elite-silver", "a rare elite shows the silver dragon")
env._units.target.classification = "normal"
env.FireEvent("UNIT_CLASSIFICATION_CHANGED", "target")
assert(not badge:IsShown(), "a normal unit shows no badge")
local hides = count(badge, "Hide")
env.FireEvent("UNIT_LEVEL", "target")
assert(count(badge, "Hide") == hides, "a hidden badge is not hidden again")
env._units.target.classification = "elite"
write("target.elite", false)
assert(not badge:IsShown(), "turning the badge off hides it")

-- Pet happiness.
U.SetUnit(env, "pet", { name = "Wolf", level = 58, health = 1460, healthMax = 2000, power = 80, powerMax = 100, reaction = 5 })
local pet = ns.Frames.Get("pet").views[1]
write("pet.happiness", true)
local mood = assert(pet.extraIcon, "turning happiness on makes the badge")
assert(mood:IsShown() and W.LastCall(mood, "SetAtlas")[1] == "UI-PetHappiness", "a happy pet shows its mood")
local spot = W.LastCall(mood, "SetPoint")
assert(pet.form == "row" and spot[1] == "BOTTOMRIGHT" and spot[2] == pet.parent and spot[3] == "TOPRIGHT", "a row frame's badge sits above the frame, clear of its name")
env._mood = 1
env.FireEvent("UNIT_HAPPINESS", "pet")
assert(W.LastCall(mood, "SetAtlas")[1] == "UI-PetMad", "UNIT_HAPPINESS updates the mood")
env._hunter = false
env.FireEvent("UNIT_HAPPINESS", "pet")
assert(not mood:IsShown(), "a pet that is not a hunter's shows no mood")
env._hunter = true
write("pet.happiness", false)
assert(not mood:IsShown(), "turning happiness off hides it")

-- Hover and target highlights: made on first use, shown and hidden on their events.
write("pet.hoverBorder", true)
assert(pet.edge == nil, "the hover highlight waits for the mouse before it is made")
W.Enter(pet.button)
local edge = assert(pet.edge, "hovering makes the highlight")
assert(edge:IsShown() and W.LastCall(edge, "SetAllPoints")[1] == pet.panel, "the highlight outlines the painted frame")
assert(edge:GetFrameLevel() > pet.health:GetFrameLevel() and edge:GetFrameLevel() < pet.top:GetFrameLevel(), "it draws over the bars, under the text")
W.Leave(pet.button)
assert(not edge:IsShown(), "leaving hides it")
local hidden = count(edge, "Hide")
W.Leave(pet.button)
assert(count(edge, "Hide") == hidden, "a hidden highlight is not hidden again")
env._units.focus = env._units.target
env.RunUnitWatches()
local focus = ns.Frames.Get("focus").views[1]
write("focus.targetBorder", true)
local mark = assert(focus.edge, "the target highlight shows while the focus is also the target")
assert(mark:IsShown(), "the focus is outlined")
env._units.target = { name = "Wolf", level = 60, health = 10, healthMax = 10, reaction = 2 }
env.FireEvent("PLAYER_TARGET_CHANGED")
assert(not mark:IsShown(), "PLAYER_TARGET_CHANGED clears the highlight when the target moves on")
env._units.target = env._units.focus
env._secretCompare = true
env.FireEvent("PLAYER_TARGET_CHANGED")
assert(not mark:IsShown(), "a secret comparison does not light the highlight")
env._secretCompare = nil
env.FireEvent("PLAYER_TARGET_CHANGED")
assert(mark:IsShown(), "a readable comparison lights it again")
write("focus.targetBorder", false)
assert(not mark:IsShown(), "turning the target highlight off hides it")

-- Unit tooltips.
local player = ns.Frames.Get("player").views[1]
write("unitTooltip", "never")
W.Enter(player.button)
assert(env._tooltip == nil, "never shows no unit tooltip")
W.Leave(player.button)
write("unitTooltip", "noCombat")
env.SetCombat(true)
W.Enter(player.button)
assert(env._tooltip == nil, "out of combat only hides the tooltip in combat")
W.Leave(player.button)
env.SetCombat(false)
W.Enter(player.button)
assert(env._tooltip == "player", "and shows it out of combat")
W.Leave(player.button)
write("unitTooltip", "always")

-- Health percent decimal, with room for the extra digits, queued in combat.
local width = target.geometry.healthText.w
write("healthDecimal", true)
assert(U.Shown(env, target.healthText):find("75.0%", 1, true), "health percent shows a decimal: " .. U.Shown(env, target.healthText))
assert(width and target.geometry.healthText.w > width, "the percent column widens for the decimal")
env.SetCombat(true)
write("healthDecimal", false)
env.FireEvent("UNIT_HEALTH", "target")
assert(U.Shown(env, target.healthText):find("75.0%", 1, true), "a combat change waits for combat to end")
env.SetCombat(false)
env.RunTimers()
assert(U.Shown(env, target.healthText):find("75%", 1, true) and not U.Shown(env, target.healthText):find("75.0", 1, true), "combat's end applies the whole percent")

-- Portrait mirror and zoom, for portraits and class art, kept through portrait updates.
local portrait = player.portrait
write("player.portraitMirror", true)
local coords = W.LastCall(portrait, "SetTexCoord")
assert(coords[1] == 1 and coords[2] == 0 and coords[3] == 0 and coords[4] == 1, "mirror flips the portrait")
write("player.portraitZoom", 0.2)
coords = W.LastCall(portrait, "SetTexCoord")
assert(near(coords[1], 0.9) and near(coords[2], 0.1) and near(coords[3], 0.1) and near(coords[4], 0.9), "zoom crops evenly into a mirrored portrait")
env.FireEvent("UNIT_PORTRAIT_UPDATE", "player")
coords = W.LastCall(portrait, "SetTexCoord")
assert(near(coords[1], 0.9), "a portrait update keeps the crop")
write("player.portraitStyle", "class")
coords = W.LastCall(portrait, "SetTexCoord")
assert(near(coords[1], 0.28) and near(coords[2], 0.12) and near(coords[3], 0.52) and near(coords[4], 0.68), "class art crops and flips inside its atlas")
write("player.portraitMirror", false)
write("player.portraitZoom", 0)
coords = W.LastCall(portrait, "SetTexCoord")
assert(coords[1] == 0 and coords[2] == 1, "off leaves the atlas's own coordinates")
write("player.portraitStyle", "portrait")

-- Cast bars: icon side, fill opacity, layering.
local geometry = ns.CastBars.Geometry(200, 20, true, true, 10, nil, true)
assert(geometry.icon.x == 180 and geometry.panel.x == 0 and geometry.panel.x + geometry.panel.w <= geometry.icon.x, "the icon sits at the right end, clear of the bar")
geometry = ns.CastBars.Geometry(200, 20, true, true, 10)
assert(geometry.icon.x == 0 and geometry.panel.x > 0, "the default keeps the icon on the left")
local cb = ns.CastBars.Get("player")[1]
write("player.castbarIconRight", true)
local icon = cb.geometry.icon
assert(icon and icon.x > 0 and cb.bar.opts.width <= icon.x, "the caption bar stops before a right-hand icon")
write("player.castbarAlpha", 0.6)
env._units.player.cast = { name = "Frostbolt", texture = 135846, start = 1000, finish = 3000, spellID = 116 }
env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-1", 116)
assert(near(W.LastCall(cb.bar, "SetStatusBarColor")[4], 0.6), "fill opacity reaches the cast fill")
env._units.player.secretCast = true
env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-2", 116)
env.FireEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE", "player")
local locked = W.LastCall(cb.bar:GetStatusBarTexture(), "SetVertexColorFromBoolean")
assert(locked and near(locked[2].a, 0.6) and near(locked[3].a, 0.6), "secret locked casts keep the fill opacity")
env._units.player.cast, env._units.player.secretCast = nil, nil
env.FireEvent("UNIT_SPELLCAST_STOP", "player", "Cast-2", 116)
write("player.castbarAlpha", 1)
write("player.castbarIconRight", false)
cb.frame:SetFrameStrata("MEDIUM")
write("castbarRaise", true)
assert(W.LastCall(cb.frame, "SetFrameStrata")[1] == "HIGH", "cast bars rise above other frames")
write("castbarRaise", false)
assert(W.LastCall(cb.frame, "SetFrameStrata")[1] == "MEDIUM", "off restores the bar's own layer")

-- Aura zoom and combat tooltips reach every aura button.
local auras = target.auras
assert(auras and #auras.buttons > 0, "the target has aura buttons")
write("target.auraZoom", 0.15)
write("target.auraTooltipCombat", false)
for _, entry in ipairs(auras.buttons) do
	coords = W.LastCall(entry.icon, "SetTexCoord")
	assert(near(coords[1], 0.15) and near(coords[2], 0.85), "aura zoom crops each icon")
	assert(entry.button._aura.SetHideTooltipInCombat[1] == true, "aura tooltips hide in combat")
end
write("target.auraZoom", 0.07)
write("target.auraTooltipCombat", true)
for _, entry in ipairs(auras.buttons) do
	assert(near(W.LastCall(entry.icon, "SetTexCoord")[1], 0.07), "the default crop returns")
	assert(entry.button._aura.SetHideTooltipInCombat[1] == false, "aura tooltips return in combat")
end

-- The preview shows each option.
write("edit", "target")
local pane = ns.Preview.Build(env.UIParent)
local sample = pane.views.target
write("target.healthAlpha", 0.5)
write("target.elite", true)
write("target.hoverBorder", true)
write("healthDecimal", true)
pane:Refresh()
assert(W.LastCall(sample.health, "SetStatusBarColor")[4] == 0.5, "the preview fill takes its opacity")
assert(sample.extraIcon and sample.extraIcon:IsShown(), "the elite sample shows its badge")
assert(sample.edge and sample.edge:IsShown(), "the preview shows the highlight")
assert(U.Shown(env, sample.healthText):find("55.7%", 1, true), "the preview percent shows a decimal: " .. U.Shown(env, sample.healthText))
write("target.healthColor", "health")
pane:Refresh()
r, g, b = W.LastCall(sample.health, "SetStatusBarColor")[1], W.LastCall(sample.health, "SetStatusBarColor")[2], W.LastCall(sample.health, "SetStatusBarColor")[3]
wr, wg, wb = ns.Unit.ShareColor(2240 / 4020)
assert(near(r, wr) and near(g, wg) and near(b, wb), "the preview colours its sample by health left")
write("target.portraitMirror", true)
write("target.portrait", true)
pane:Refresh()
coords = W.LastCall(sample.portrait, "SetTexCoord")
assert(coords and coords[1] == 1 and coords[2] == 0, "the preview portrait mirrors")
write("target.elite", false)
write("target.hoverBorder", false)
pane:Refresh()
assert(not sample.extraIcon:IsShown() and not sample.edge:IsShown(), "the preview clears them when turned off")
write("edit", "pet")
write("pet.happiness", true)
pane:Refresh()
assert(pane.views.pet.extraIcon and pane.views.pet.extraIcon:IsShown(), "the pet preview shows its mood")
clean(env, K)
print("test-unitframes-parity-r1: ok")
