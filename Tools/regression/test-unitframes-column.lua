-- test-unitframes-column.lua: the owner's picture (LEE-20) draws the player and target as mirrored columns: bars as wide as the frame, a round portrait outside them, the older vitals line and sigil kept as a choice.
local U = dofile("Tools/regression/unitframes_env.lua")
local W = U.W

local env, K, ns = U.New()
local Settings, Geometry, Frames = ns.Settings, ns.Geometry, ns.Frames
local Tokens, Layouts = K.Tokens, K.Setup.Layouts

local function noErrors(where)
	assert(#env._errors == 0, where .. ": " .. tostring(env._errors[1]))
	assert(K.ErrorCount() == 0, where .. ": KstyleUI caught an error")
end

local function near(a, b, eps)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (eps or 1e-6)
end

local function inside(part, w, h, what)
	assert(part.x >= -1e-6 and part.y >= -1e-6 and part.x + part.w <= w + 1e-6 and part.y + part.h <= h + 1e-6, what .. " stays inside the frame")
end

noErrors("enable")

for _, kind in ipairs({ "player", "target" }) do
	assert(Settings.Value(kind, "style") == "column", kind .. " is a column frame by default")
	assert(Settings.Form(kind) == "column" and Settings.Snapshot(kind).form == "column", kind .. " takes the column form")
	assert(Settings.Value(kind, "healthColor") == "hud", kind .. " takes the picture's colours")
end
assert(Settings.Value("player", "healthOrientation") == "RIGHT" and Settings.Value("target", "healthOrientation") == "LEFT", "the target's health fills from the right, reversed")
assert(Settings.Value("target", "powerOrientation") == "LEFT", "and so does its power")
assert(Settings.Value("target", "auraPosition") == "SIDE" and Settings.Value("target", "auraSize") == 27.6, "your debuffs are 27.6 units, right of the portrait")
for _, kind in ipairs({ "focus", "boss", "targettarget", "focustarget", "pet" }) do
	assert(Settings.Value(kind, "style") == "lumen", kind .. " keeps its Lumen form")
end
K.Options.Write("UnitFrames", "focus.style", "column")
assert(Settings.Form("focus") == "card", "a frame with no column form falls back to its Lumen form")
K.Options.Write("UnitFrames", "focus.style", "lumen")

local PLAYER = Layouts.Element("unitframes.player")
local TARGET = Layouts.Element("unitframes.target")
assert(PLAYER.width == 491 and PLAYER.height == 77.5, "the player element is the picture's bar column, 491 by 77.5")
assert(TARGET.width == 491 and TARGET.height == 102.5, "the target element is 491 by 102.5")

local pg = Geometry.Frame(Settings.Snapshot("player"), PLAYER.width, PLAYER.height, 1)
assert(pg.form == "column" and not pg.mirror and not pg.compact and pg.chrome == false, "the player is a column with no glass")
assert(near(pg.health.x, 0) and near(pg.health.w, 491) and near(pg.power.x, 0) and near(pg.power.w, 491), "both bars run the whole 491, the portrait takes none of it")
assert(near(pg.portrait.w, 70) and near(pg.portrait.h, 70) and near(pg.portrait.y, 0), "a 70-unit portrait, at the frame's top")
assert(near(pg.portrait.x + pg.portrait.w, -21.5), "outside the bars at the left, keeping the 91.5-unit reserve")
assert(near(pg.health.y, 38.78) and near(pg.health.h, 21.5), "the health bar is the KSTY-44 mock-up's 19 of 431 across the bar's 491")
assert(near(pg.power.y, 63.72) and near(pg.power.h, 8), "the power bar is the picture's 14 px box, from the column constant not the slider")
assert(pg.name and near(pg.name.y + pg.name.h, 27.28), "the name row stands 11.5 above the taller health bar")
assert(near(pg.health.y - (pg.name.y + pg.name.h), 11.5), "the gap under the name stays 11.5")
assert(pg.caption and pg.caption.x >= pg.name.x, "the class word follows the name")
assert(pg.healthText and pg.healthSub and near(pg.healthSub.x + pg.healthSub.w, 491), "the value ends at the bar's right edge")
assert(near(pg.healthText.y + pg.healthText.h, pg.name.y + pg.name.h, 1), "the value shares the name's baseline")
assert(near(pg.nameDrop, 0.24 * 22, 0.01) and near(pg.captionLift, 0.105 * 22, 0.01), "the 22-unit name drops 0.24 of its size so its Cinzel baseline stands on the value's, and the class word lifts 0.105 of it to share that baseline")
assert(near(pg.valueDrop, 0.13 * 22, 0.01), "the value drops 0.13 of the name size: Alegreya's oldstyle figures then stand on the name's baseline as the picture's do")
assert(pg.cast == nil and pg.aura == nil, "the player's cast bar is its own element and it has no side auras")
assert(pg.badge and pg.badge.x + pg.badge.w / 2 > pg.portrait.x + pg.portrait.w / 2 and pg.badge.y + pg.badge.h / 2 > pg.portrait.y + pg.portrait.h / 2, "the level disc is on the portrait's lower right")

local tg = Geometry.Frame(Settings.Snapshot("target"), TARGET.width, TARGET.height, 1)
assert(tg.mirror and tg.form == "column", "the target mirrors the player")
assert(near(tg.health.w, 491) and tg.power == nil, "the target's health is 491 wide and, as the KSTY-44 mock-up draws it, it has no power line by default")
assert(near(tg.portrait.x, 512.5) and near(tg.portrait.y, 0) and near(tg.portrait.w, 70), "a 70-unit portrait at the right, keeping the 91.5-unit reserve")
assert(near(tg.health.y, 46) and near(tg.health.h, 19), "health is the mock-up's 17 of 439 across 491; the cast element stays")
assert(tg.cast and near(tg.cast.x, 0) and near(tg.cast.w, 491) and near(tg.cast.y, 76) and near(tg.cast.y + tg.cast.h, 102.5), "the cast bar and its label run the full 491 under the health bar")
assert(tg.healthText and near(tg.healthText.x, 0), "the percentage is at the left")
assert(tg.name and near(tg.name.x + tg.name.w, 491), "the name ends at the bars' right edge")
assert(tg.caption, "the creature type sits by the name")
assert(tg.badge.x + tg.badge.w / 2 < tg.portrait.x + tg.portrait.w / 2, "the level disc is on the portrait's lower left")
assert(near(tg.aura.x, 599) and near(tg.aura.y, 14.5), "your debuffs start 16.5 right of the portrait, 14.5 down")
for _, g in ipairs({ pg, tg }) do
	for key, part in pairs(g) do
		if type(part) == "table" and part.w and key ~= "portrait" and key ~= "badge" and key ~= "aura" and key ~= "marker" and key ~= "glass" and key ~= "panel" then
			inside(part, 491, g == pg and 77.5 or 102.5, key)
		end
	end
end
for _, h in ipairs({ 30, 45, 60, 80 }) do
	local short = Geometry.Frame(Settings.Snapshot("target"), 491, h, 1)
	for key, part in pairs(short) do
		if type(part) == "table" and part.w and key ~= "portrait" and key ~= "badge" and key ~= "aura" and key ~= "marker" and key ~= "glass" and key ~= "panel" then
			inside(part, 491, h, "a " .. h .. "-unit target's " .. key)
		end
	end
end
local reachLeft = Geometry.Reach(Settings.Snapshot("player"))
assert(near(reachLeft, 91.5), "the player's portrait reaches 91.5 outside its element on the left, got " .. tostring(reachLeft))

local player = Frames.Get("player").views[1]
assert(not player.chrome.fill[5]:IsShown(), "no glass behind the column")
assert(player.disc:IsShown() and U.Shown(env, player.levelText) == "60", "the level shows in the disc")
assert(near(select(2, env.Look(player.health:GetSize())), 21.5, 0.6), "the health bar is the mock-up proportion, 21.5 units")
assert(near(select(2, player.power:GetSize()), 8, 0.6), "the power bar is the picture's 14 px box")
assert(player.health.unitBar and player.power.unitBar, "health and power are the clean unit bar")
assert(not player.health.background and not player.health.keyline and not player.power.keyline, "no texture, keyline or rail of the old kit bar around them")
assert(player.health.under.edgeHard:IsShown() and player.power.under.edgeHard:IsShown(), "each bar keeps the one black pixel edge")
assert(player.health.under:GetStatusBarTexture():IsShown() and not player.power.under:GetStatusBarTexture():IsShown(), "health draws the pale loss band, power does not")
assert(player.health.sparkFrame and not player.power.sparkFrame, "health has the spark, power does not")
local br, bg, bb = Tokens.Color("hudPlayerHealth")
local hc = player.health.colorRGBA
assert(near(hc[1], br) and near(hc[2], bg) and near(hc[3], bb), "the player's health is the picture's blue")
assert(player.health:GetReverseFill() == false, "the player's health fills from the left")
assert(U.Shown(env, player.healthText) == "3120" and U.Shown(env, player.healthSub) == "/ 3980", "203 / 237 in the picture: current bold, then the max")
assert(U.Shown(env, player.caption) == "Hunter", "the class word after the name: " .. U.Shown(env, player.caption))
assert(player.name:GetFont() == Tokens.Font("unit"), "the name uses the picture's tight unit-name face")
local shadowX, shadowY = player.name:GetShadowOffset()
assert(shadowX > 0 and shadowY == -shadowX, "world-space unit names retain the kit's soft shadow")
assert(not tostring(W.LastCall(player.name, "SetText")[1]):find("\226\128\137"), "the name carries no thin space")
local inset = W.LastCall(player.button, "SetHitRectInsets")
assert(inset and near(inset[1], -91.5) and near(inset[2], 0), "the portrait outside the bars takes clicks through the button's hit rect")

U.SetUnit(env, "target", { name = "Shadowgale Poacher", level = 12, health = 50, healthMax = 100, reaction = 2, creature = "Humanoid", canAttack = true, power = 40, powerMax = 100 })
env.SetTarget(true)
local target = Frames.Get("target").views[1]
local tr, tgc, tb = Tokens.Color("hudTargetHealth")
local tc = target.health.colorRGBA
assert(near(tc[1], tr) and near(tc[2], tgc) and near(tc[3], tb), "a hostile target's health is the picture's red")
assert(target.health:GetReverseFill() == true and target.power:GetReverseFill() == true, "health and power are reversed")
assert(U.Shown(env, target.healthText) == "50%", "the percentage reads 50%: " .. U.Shown(env, target.healthText))
local percent = W.LastCall(target.healthText, "SetFormattedText")
assert(percent and percent[1] == "%.0f%%" and env.issecretvalue(percent[2]), "the percentage reaches SetFormattedText as a secret from UnitHealthPercent")
local plain = W.LastCall(target.healthText, "SetText")
assert(plain == nil or plain[1] == "", "and never goes through SetText with the health")
assert(U.Shown(env, target.caption) == "Humanoid", "the creature type in grey: " .. U.Shown(env, target.caption))
assert(U.Shown(env, target.levelText) == "12" and target.disc:IsShown(), "the level in the disc")
local point, rel, relPoint, captionX = target.caption:GetPoint(1)
assert(point == "BOTTOMRIGHT" and rel == target.name and relPoint == "BOTTOMLEFT", "the creature type hangs off the name's left edge")
assert(near(captionX, -K.Widgets.Snap(target.parent, 9)), "the mirrored caption keeps the picture's nine-unit gap without moving its baseline")
local ap, arel, arp, ax, ay = target.auras.host:GetPoint(1)
assert(ap == "TOPLEFT" and arel == target.button and arp == "TOPLEFT" and near(ax, 599) and near(ay, -14.5, 0.5), "your debuffs sit right of the portrait")
local tinset = W.LastCall(target.button, "SetHitRectInsets")
assert(tinset and near(tinset[1], 0) and near(tinset[2], -(505 + 77.5 - 491)), "the target's portrait takes clicks too")
for _, hp in ipairs({ 3980, 3120, 400 }) do
	env._units.player.health = hp
	env.FireEvent("UNIT_HEALTH", "player")
	U.SetUnit(env, "target", { name = "Shadowgale Poacher", level = 12, health = hp > 1000 and 50 or 5, healthMax = 100, reaction = 2, creature = "Humanoid", canAttack = true, power = 40, powerMax = 100 })
	env.SetTarget(true)
	assert(not player.ringGlow:IsShown() and not target.ringGlow:IsShown(), "no light glow outside either column portrait, at rest or hurt (" .. hp .. ")")
end
env._units.player.health = 3120
env.FireEvent("UNIT_HEALTH", "player")
noErrors("live column")

local uf = Frames.Get("player")
local before = #W.Calls(player.button, "SetHitRectInsets")
env.SetCombat(true)
Frames.Relayout(uf)
assert(#W.Calls(player.button, "SetHitRectInsets") == before, "no hit rect is set in combat")
env.SetCombat(false)
env.RunTimers()
assert(#W.Calls(player.button, "SetHitRectInsets") == before + 1, "the queued layout runs when combat ends")
noErrors("combat")

-- A name needs room: with none, neither it nor its caption draws, and a name wider than its room is bounded, secret or not.
do
	for _, width in ipairs({ 40, 120, 200 }) do
		local g = Geometry.Frame(Settings.Snapshot("target"), width, 102.5, 1)
		assert((g.name == nil) == (g.caption == nil), width .. ": the name and its caption go together")
		if g.name then
			assert(g.nameRoom >= 2 * 18 and g.name.w > 0, width .. ": a name that draws has room: " .. g.nameRoom)
		end
	end
	local g120 = Geometry.Frame(Settings.Snapshot("target"), 120, 102.5, 1)
	assert(g120.name == nil and g120.caption == nil and g120.nameRoom == nil, "a 120-unit target has no room for its name over the value")
	local g491 = Geometry.Frame(Settings.Snapshot("target"), 491, 102.5, 1)
	assert(g491.name and g491.caption and g491.nameRoom > 100, "the full frame keeps both")
	Frames.Relayout(Frames.Get("target"))
	env.RunTimers()
	ns.Style.Layout(target, Settings.Snapshot("target"), 120, 102.5)
	assert(not target.name:IsShown() and not target.caption:IsShown(), "with no room neither region draws")
	ns.Style.Layout(target, Settings.Snapshot("target"), 491, 102.5)
	assert(target.name:IsShown(), "and both return with room")

	U.SetUnit(env, "target", { name = "Shadowgale Poacher of the Endless Wastes and Beyond", level = 12, health = 50, healthMax = 100, reaction = 2, canAttack = true })
	env.SetTarget(true)
	env._textWidth = function(text) return 9999 end
	Frames.Relayout(Frames.Get("target"))
	env.RunTimers()
	assert(target.name:GetWidth() > 0 and near(target.name:GetWidth(), K.Widgets.Snap(target.name, target.geometry.nameRoom), 0.6), "a name wider than its room is bounded to it: " .. target.name:GetWidth())
	env._textWidth = function(text, _, size) return #text * size * 0.5 end
	U.SetUnit(env, "target", { name = "Poacher", level = 12, health = 50, healthMax = 100, reaction = 2, canAttack = true })
	env.SetTarget(true)
	assert(target.name:GetWidth() == 0, "a short name sizes itself, so the caption hugs it")
	U.SetUnit(env, "target", { name = "Poacher", secretName = true, level = 12, health = 50, healthMax = 100, reaction = 2, canAttack = true })
	env.SetTarget(true)
	assert(near(env.Look(target.name:GetWidth()), K.Widgets.Snap(target.name, target.geometry.nameRoom), 0.6), "a secret name is always bounded to its room: " .. env.Look(target.name:GetWidth()))
	Frames.Relayout(Frames.Get("target"))
	env.RunTimers()
	assert(near(env.Look(target.name:GetWidth()), K.Widgets.Snap(target.name, target.geometry.nameRoom), 0.6), "and stays bounded through a relayout")
	noErrors("name room")
end

do
	local function nameY()
		local _, _, _, _, y = player.name:GetPoint(1)
		return y
	end
	local function valueY()
		local _, _, _, _, y = player.healthSub:GetPoint(1)
		return y
	end
	local valueDropped = valueY()
	local dropped = nameY()
	K.Options.Write("UnitFrames", "player.fonts.name.font", Tokens.FontPath("AlegreyaSansBold"))
	Frames.Relayout(Frames.Get("player"))
	env.RunTimers()
	assert(near(nameY() - dropped, player.geometry.nameDrop, 0.6), "a name in another face keeps the layout row: the Cinzel correction does not move it, " .. tostring(dropped) .. " against " .. tostring(nameY()))
	assert(near(valueY() - valueDropped, player.geometry.valueDrop, 0.6), "and so does the value: only a name in the unit face moves it")
	K.Options.Write("UnitFrames", "player.fonts.name.font", "theme")
	noErrors("custom name font")
end

do
	local function nameY()
		local _, _, _, _, y = player.name:GetPoint(1)
		return y
	end
	local function valueY()
		local _, _, _, _, y = player.healthSub:GetPoint(1)
		return y
	end
	local roomy, valueRoomy = nameY(), valueY()
	ns.Unit.SetName(player, string.rep("W", 80))
	assert(player.name:GetFont() == Tokens.Font("body"), "a name too long for its room falls back to the body font")
	assert(near(nameY() - roomy, player.geometry.nameDrop, 0.6), "and then loses the Cinzel baseline correction, " .. tostring(roomy) .. " against " .. tostring(nameY()))
	assert(near(valueY() - valueRoomy, player.geometry.valueDrop, 0.6), "the value loses its drop with the name's Cinzel face, so it keeps the layout row")
	ns.Unit.SetName(player, "Korallis")
	assert(player.name:GetFont() == Tokens.Font("unit") and near(nameY(), roomy, 0.6), "a short name gets the Cinzel face and its correction back")
	assert(near(valueY(), valueRoomy, 0.6), "and the value gets its drop back")
	noErrors("name fallback")
end

K.Options.Write("UnitFrames", "player.healthTexture", "Glass")
Frames.Restyle(Frames.Get("player"))
assert(player.health.textureKey == "Glass", "a chosen texture reaches the fill")
assert(player.health.cleanLit:IsShown() and player.health.under.edgeHard:IsShown(), "and the clean edge and highlight stay")
K.Options.Write("UnitFrames", "player.healthTexture", "Flat")
K.Options.Write("UnitFrames", "player.style", "lumen")
Frames.Restyle(Frames.Get("player"))
assert(Settings.Form("player") == "vitals", "leaving the column is the vitals line")
assert(player.health.unitBar and player.health.under.edgeHard:IsShown(), "every form keeps the clean bar")
player.power:SetBarColor(0.5, 0.6, 0.7)
local powerCall = W.LastCall(player.power, "SetStatusBarColor")
assert(powerCall and near(powerCall[1], 0.5) and near(powerCall[2], 0.6) and near(powerCall[3], 0.7), "power SetStatusBarColor got the plain colour")
K.Options.Write("UnitFrames", "player.style", "column")
Frames.Restyle(Frames.Get("player"))
noErrors("leave column on Flat")

local older, _, nsOlder = U.New({ lumen = true })
assert(nsOlder.Settings.Form("player") == "vitals" and nsOlder.Settings.Form("target") == "sigil", "a profile that keeps Lumen draws the vitals line and the sigil")
assert(nsOlder.CastBars.ElementLive("player") == false, "and the player's cast sits inside its frame, not in the element")
assert(#older._errors == 0, "no errors")
