-- test-nameplates-parity-r2.lua: EllesmereUI parity round 2 keeps v0.2.8 plates and regions, then switches each new nameplate option on, checks it on its events, and switches it off again.
local N = dofile("Tools/regression/nameplates_env.lua")

local function saved(own)
	own = own or {}
	own.enabled = true
	return { version = 42, profiles = { Default = { Nameplates = own } }, characters = {}, layouts = {} }
end

local function near(a, b)
	return math.abs(a - b) < 1e-6
end

local function same(got, want, what)
	assert(near(got[1], want[1]) and near(got[2], want[2]) and near(got[3], want[3]),
		what .. ": got " .. tostring(got[1]) .. ", " .. tostring(got[2]) .. ", " .. tostring(got[3]))
end

local function boot(units, opts)
	opts = opts or {}
	opts.saved = opts.saved or saved()
	local env, K, ns = N.New(opts)
	env._units.player = env._units.player or { level = 15 }
	for token, data in pairs(units) do
		N.Add(env, token, data)
	end
	local function set(key, value)
		K.Options.Write("Nameplates", key, value)
		env.RunTimers()
		local got = K.Options.Read("Nameplates", key)
		assert(type(value) == "table" or got == value, key)
	end
	return env, K, ns, set
end

local function bar(plate)
	local source = plate.health.fillSource
	if source then return { source[1], source[2], source[3] } end
	return { plate.health:GetStatusBarColor() }
end

local function val(env, v)
	return env.issecretvalue(v) and env.Reveal(v) or v
end

local function alpha(env, region)
	local a = region:GetAlpha()
	return env.issecretvalue(a) and val(env, a) or a
end

local function important(env)
	env.C_Spell.IsSpellImportant = function(id) return env.Secret(id == 133) end
end

local NEW = {
	["level.x"] = 0, ["level.y"] = 0, ["cast.iconScale"] = 1, ["cast.iconX"] = 0, ["cast.iconY"] = 0, ["cast.offsetX"] = 0, ["cast.border"] = true,
	["cast.important"] = false, ["cast.importantGlow"] = false, ["cast.importantKick"] = false, ["cast.scale"] = 1,
	["debuffs.timePlace"] = "BELOW", ["debuffs.timeX"] = 0, ["debuffs.timeY"] = 0, ["debuffs.countPlace"] = "TOPRIGHT",
	["debuffs.countX"] = 0, ["debuffs.countY"] = 0, ["debuffs.border"] = true, ["debuffs.cropped"] = false, ["debuffs.crop"] = 10,
	["debuffs.raise"] = false, ["debuffs.dispelColor"] = false, ["debuffs.pandemic"] = false, ["debuffs.tooltips"] = false,
	["threat.overBoss"] = true, ["threat.overMiniBoss"] = true, ["threat.overCaster"] = true, ["threat.tankOverBoss"] = true,
	["threat.tankOverOthers"] = true, ["target.glow"] = false, ["target.glowAlpha"] = 0.9, ["target.fill"] = false,
	["target.fillAlpha"] = 0.2, ["target.scale"] = 1, ["resource.show"] = false, ["resource.place"] = "BOTTOM", ["resource.scale"] = 1,
	["resource.spacing"] = 2, ["resource.energy"] = false, ["resource.energyHeight"] = 3, ["resource.energyPlace"] = "BELOW",
	["resource.energyWidth"] = 1, ["resource.energyHideFull"] = false,
}

-- v0.2.8 profiles keep every default, build no new region, keep the plate's scale and write no CVar.
do
	local env, K, ns = boot({ nameplate1 = { threat = 2 } }, { playerClass = "ROGUE" })
	N.Target(env, "nameplate1")
	N.Cast(env, "nameplate1", { name = "Fear", text = "Fear", texture = 136183 })
	local plate = ns.Plates.Get("nameplate1")
	for key, value in pairs(NEW) do
		assert(K.Options.Read("Nameplates", key) == value, "v0.2.8 profiles keep " .. key)
	end
	for _, key in ipairs({ "castImportantFill", "castImportantGlow", "targetGlow", "targetFill", "resource", "boost" }) do
		assert(plate[key] == nil, "no " .. key .. " until its option is on")
	end
	assert(plate.castBar.barEdge.hard:IsShown(), "the cast bar keeps its edge")
	assert(K.Options.Read("Nameplates", "threat.display") == "glow", "the threat display stays the glow")
	for _, write in ipairs(env._cvarWrites) do
		assert(write.name == "nameplateShowSelf" or write.name ~= "nameplateShowEnemies", "no enemy plate CVar is written by default")
	end
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end
collectgarbage()

-- Cast bar: the icon's scale and offsets, the wider offset range, the border, and plates growing while they cast.
do
	local env, K, ns, set = boot({ nameplate1 = {} })
	local plate = ns.Plates.Get("nameplate1")
	set("cast.showIcon", true)
	local side = val(env, plate.castIcon:GetWidth())
	local room = ns.Cast.Room(plate)
	set("cast.iconScale", 2)
	assert(near(val(env, plate.castIcon:GetWidth()), side * 2), "the icon scales")
	local _, _, _, x, y = plate.castIcon:GetPoint(1)
	assert(x < 0 and y > 0, "a larger icon stays centred on its place")
	assert(ns.Cast.Room(plate) > room, "and the plate keeps room for it below the bar")
	set("cast.iconX", 10)
	set("cast.iconY", -4)
	local _, _, _, x2, y2 = plate.castIcon:GetPoint(1)
	assert(near(x2 - x, K.Widgets.Snap(plate, 10)) and y2 < y, "the offsets move the icon")
	set("cast.iconScale", 1)
	set("cast.iconX", 0)
	set("cast.iconY", 0)
	local _, _, _, x3, y3 = plate.castIcon:GetPoint(1)
	assert(near(x3, 0) and near(y3, 0) and near(val(env, plate.castIcon:GetWidth()), side), "defaults restore the icon")
	set("cast.offsetY", -10)
	local _, _, _, _, top = plate.cast:GetPoint(1)
	assert(top > 0, "below zero, the cast bar moves up into the health bar")
	set("cast.offsetY", 0)
	set("cast.offsetX", 12)
	local _, _, _, left = plate.cast:GetPoint(1)
	assert(near(left, K.Widgets.Snap(plate, 12)), "the cast bar moves sideways")
	set("cast.offsetX", 0)
	set("cast.border", false)
	assert(not plate.castBar.barEdge.hard:IsShown(), "the border hides")
	set("cast.border", true)
	assert(plate.castBar.barEdge.hard:IsShown(), "and returns")

	local scale = plate:GetScale()
	set("cast.enabled", false)
	set("cast.scale", 1.3)
	N.Cast(env, "nameplate1", { name = "Fear", text = "Fear", texture = 136183 })
	assert(near(plate:GetScale(), scale * 1.3), "a casting enemy grows, with cast bars hidden too")
	env._units.nameplate1.cast = nil
	env.FireEvent("UNIT_SPELLCAST_STOP", "nameplate1")
	assert(near(plate:GetScale(), scale), "and shrinks back when the cast stops")
	set("cast.enabled", true)
	N.Cast(env, "nameplate1", { name = "Fear", text = "Fear", texture = 136183 })
	assert(near(plate:GetScale(), scale * 1.3), "with cast bars shown as well")
	set("cast.scale", 1)
	assert(near(plate:GetScale(), scale), "1 restores the size mid-cast")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end
collectgarbage()

-- Important casts: the colour follows the game's secret flag, the interrupt-ready exception and the glow.
do
	local env, K, ns, set = boot({ nameplate1 = {}, nameplate2 = {} }, { setup = important })
	local p1, p2 = ns.Plates.Get("nameplate1"), ns.Plates.Get("nameplate2")
	set("cast.important", true)
	local fill = assert(p1.castImportantFill, "the important colour builds its overlay")
	N.Cast(env, "nameplate1", { name = "Fear", text = "Fear", texture = 136183 })
	local flag = fill._state.AlphaFromBoolean
	assert(flag and env.issecretvalue(flag[1]) and alpha(env, fill) == 1, "important casts take the colour through the engine")
	same({ fill:GetVertexColor() }, { K.Tokens.Color("legendary") }, "in the important colour")
	N.Cast(env, "nameplate2", { name = "Bolt", text = "Bolt", texture = 136183, channel = true })
	assert(alpha(env, p2.castImportantFill) == 0, "other casts keep the usual colour")
	local hides = #N.Calls(p2.castImportantFill, "SetAlpha")
	N.Cast(env, "nameplate2", { name = "Bolt", text = "Bolt", texture = 136183, channel = true })
	assert(#N.Calls(p2.castImportantFill, "SetAlpha") == hides, "a hidden overlay is not hidden again")
	ns.Interrupt.spell, ns.Interrupt.ready = 1766, true
	set("cast.importantKick", true)
	assert(alpha(env, fill) == 0, "while the interrupt is ready, important casts keep the usual colour")
	ns.Interrupt.ready = false
	ns.Cast.RepaintAll()
	assert(alpha(env, fill) == 1, "and take it again while it recharges")
	set("cast.importantGlow", true)
	local glow = assert(p1.castImportantGlow, "the glow builds its slice")
	assert(glow[1]:IsShown() and alpha(env, glow[1]) == 1, "important casts glow")
	assert(not p2.castImportantGlow[1]:IsShown() or alpha(env, p2.castImportantGlow[1]) == 0, "other casts do not")
	env.FireEvent("UNIT_SPELLCAST_INTERRUPTED", "nameplate1")
	assert(alpha(env, fill) == 0 and not glow[1]:IsShown(), "an interrupted cast drops both")
	N.Cast(env, "nameplate1", { name = "Fear", text = "Fear", texture = 136183 })
	set("cast.important", false)
	set("cast.importantGlow", false)
	assert(alpha(env, fill) == 0 and not glow[1]:IsShown(), "off restores the usual cast bar")
	env.C_Spell.IsSpellImportant = nil
	set("cast.important", true)
	N.Cast(env, "nameplate1", { name = "Fear", text = "Fear", texture = 136183 })
	assert(alpha(env, fill) == 0, "without the API no cast is marked")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end
collectgarbage()

-- Target effects: the glow, the bar highlight and the size follow target changes, are independent of the brackets, and restore.
do
	local env, K, ns, set = boot({ nameplate1 = {}, nameplate2 = { canAttack = false, reaction = 5 } })
	local enemy, friend = ns.Plates.Get("nameplate1"), ns.Plates.Get("nameplate2")
	set("target.highlight", false)
	set("target.glow", true)
	set("target.fill", true)
	set("target.fillColor", { r = 0.5, g = 0.6, b = 0.7 })
	set("target.fillAlpha", 0.4)
	set("target.scale", 1.25)
	local scale = enemy:GetScale()
	N.Target(env, "nameplate1")
	assert(enemy.targetGlow[1]:IsShown() and enemy.targetFill:IsShown(), "the target glows and brightens with the brackets off")
	same({ enemy.targetFill:GetVertexColor() }, { 0.5, 0.6, 0.7 }, "in the highlight colour")
	assert(near(alpha(env, enemy.targetFill), 0.4), "at the highlight opacity")
	assert(near(enemy:GetScale(), scale * 1.25), "the target plate grows")
	assert(not (friend.targetGlow and friend.targetGlow[1]:IsShown()), "other plates do not glow")
	set("target.glowAlpha", 0.5)
	assert(near(alpha(env, enemy.targetGlow[1]), 0.5), "the glow opacity applies")
	N.Target(env, "nameplate2")
	assert(not enemy.targetGlow[1]:IsShown() and not enemy.targetFill:IsShown() and near(enemy:GetScale(), scale), "the effects follow the target")
	assert(friend.targetGlow[1]:IsShown(), "friendly targets glow by default")
	set("target.friendly", false)
	assert(not friend.targetGlow[1]:IsShown() and not friend.targetFill:IsShown(), "unless friendly targets are off")
	N.Target(env, "nameplate1")
	set("target.glow", false)
	set("target.fill", false)
	set("target.scale", 1)
	assert(not enemy.targetGlow[1]:IsShown() and not enemy.targetFill:IsShown() and near(enemy:GetScale(), scale), "off restores the target plate")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end
collectgarbage()

-- Threat: per-type exceptions by role, the bar with its edge, and the name alone.
do
	local env, K, ns, set = boot({ nameplate1 = { classification = "worldboss", level = -1, threat = 3 }, nameplate2 = { threat = 3 } })
	local boss, mob = ns.Plates.Get("nameplate1"), ns.Plates.Get("nameplate2")
	set("threat.groupOnly", false)
	set("threat.display", "health")
	set("types.boss", true)
	set("types.bossColor", { r = 0.1, g = 0.2, b = 0.3 })
	local danger = { K.ColorVision.Color(2, K.Tokens.Color("hostile")) }
	same(bar(boss), danger, "threat beats the boss colour by default")
	set("threat.overBoss", false)
	same(bar(boss), { 0.1, 0.2, 0.3 }, "damage dealers can keep the boss colour")
	same(bar(mob), danger, "other units still take threat")
	set("threat.role", "tank")
	local safe = { K.ColorVision.Color(1, K.Tokens.Color("friendly")) }
	same(bar(boss), safe, "tanks keep their own switch")
	set("threat.tankOverBoss", false)
	same(bar(boss), { 0.1, 0.2, 0.3 }, "tanks can keep the boss colour too")
	set("threat.tankOverBoss", true)
	set("threat.role", "auto")
	env._units.nameplate1.threat = 1
	env.FireEvent("UNIT_THREAT_LIST_UPDATE", "nameplate1")
	local warning = { K.ColorVision.Color(3, K.Tokens.Color("neutral")) }
	same(bar(boss), { 0.1, 0.2, 0.3 }, "a damage dealer keeps the boss colour while threat changes hands")
	env._role = "TANK"
	env.FireEvent("PLAYER_ROLES_ASSIGNED")
	same(bar(boss), warning, "becoming the tank in the group recolours the plate on the role event")
	env._role = "DAMAGER"
	env.FireEvent("PLAYER_ROLES_ASSIGNED")
	same(bar(boss), { 0.1, 0.2, 0.3 }, "and back")
	env._units.nameplate1.threat = 3
	env.FireEvent("UNIT_THREAT_LIST_UPDATE", "nameplate1")
	set("threat.overBoss", true)
	same(bar(boss), danger, "on again, threat wins")

	set("types.boss", false)
	set("threat.display", "healthEdge")
	same(bar(mob), danger, "the bar takes the threat colour")
	same({ N.Last(mob.health.under.edgeHard, "SetColorTexture")[1], N.Last(mob.health.under.edgeHard, "SetColorTexture")[2],
		N.Last(mob.health.under.edgeHard, "SetColorTexture")[3] }, danger, "and so does its edge")
	set("threat.display", "name")
	same({ mob.name:GetTextColor() }, danger, "the name alone takes the threat colour")
	same(bar(mob), { K.Tokens.Color("plateHostile") }, "the bar keeps its colour")
	set("threat.display", "glow")
	same({ mob.name:GetTextColor() }, { K.Tokens.Color("textEmphasis") }, "back to the glow, the name is white again")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end
collectgarbage()

-- Level offsets move the level, which Medallions draws as bare text.
do
	local env, K, ns, set = boot({ nameplate1 = {} })
	local plate = ns.Plates.Get("nameplate1")
	-- Any write leaves the lumen preset, whose 9-unit Medallions bar then takes the 12-unit default, so measure that bar.
	set("preset", "custom")
	local _, _, _, x0, y0 = plate.levelText:GetPoint(1)
	set("level.x", -6)
	set("level.y", 3)
	local _, _, _, x1, y1 = plate.levelText:GetPoint(1)
	assert(x1 < x0 and y1 > y0, "the level moves")
	set("level.x", 0)
	set("level.y", 0)
	local _, _, _, x2, y2 = plate.levelText:GetPoint(1)
	assert(near(x2, x0) and near(y2, y0), "zero restores it")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end
collectgarbage()

-- Debuffs: timer and stacks positions, the border, cropped icons, the layer, dispel colours, the pandemic mark and tooltips.
do
	local env, K, ns, set = boot({ nameplate1 = {} })
	local plate = ns.Plates.Get("nameplate1")
	N.Debuffs(env, "nameplate1", 2)
	local button = plate.auras:GetAuraGroupFrame("debuffs", 1)
	local aura = button._aura
	local function point(region) return region:GetPoint(1) end
	assert(point(aura.timer) == "TOP" and point(aura.count) == "TOPRIGHT", "the timer sits under the icon, the stacks at the top right")
	local lane = ns.Auras.Lane(plate)
	set("debuffs.timePlace", "CENTER")
	set("debuffs.timeX", 3)
	set("debuffs.timeY", 4)
	local p, _, _, tx, ty = aura.timer:GetPoint(1)
	assert(p == "CENTER" and near(tx, K.Widgets.Snap(plate, 3)) and near(ty, K.Widgets.Snap(plate, 4)) and ns.Auras.Lane(plate) == 0 and lane > 0,
		"a timer on the icon frees its lane and takes both offsets")
	set("debuffs.countPlace", "BOTTOMLEFT")
	set("debuffs.countY", 2)
	local cx = select(4, aura.count:GetPoint(1))
	set("debuffs.countX", 3)
	assert(point(aura.count) == "BOTTOMLEFT" and near(select(4, aura.count:GetPoint(1)) - cx, K.Widgets.Snap(plate, 3)), "the stacks move")
	for _, key in ipairs({ "timePlace", "timeX", "timeY", "countPlace", "countX", "countY" }) do set("debuffs." .. key, NEW["debuffs." .. key]) end
	assert(point(aura.timer) == "TOP" and point(aura.count) == "TOPRIGHT" and ns.Auras.Lane(plate) == lane, "defaults restore them")

	local w, h = val(env, button:GetWidth()), val(env, button:GetHeight())
	set("debuffs.cropped", true)
	assert(near(val(env, button:GetWidth()), w) and val(env, button:GetHeight()) < h, "cropped icons are wide tiles")
	local _, _, top, bottom = aura.icon:GetTexCoord()
	assert(top > 0.07 and bottom < 0.93, "the icon is trimmed top and bottom")
	set("debuffs.crop", 20)
	assert(val(env, button:GetHeight()) < h * 0.7, "the crop applies")
	set("debuffs.cropped", false)
	assert(near(val(env, button:GetHeight()), h), "off restores square icons")

	local ring = select(1, aura.icon:GetParent():GetRegions())
	set("debuffs.border", false)
	local _, _, _, ix = aura.icon:GetPoint(1)
	assert(near(ix, 0), "without the border the icon fills the tile")
	set("debuffs.border", true)
	_, _, _, ix = aura.icon:GetPoint(1)
	assert(ix > 0 and ring:IsShown(), "the border returns")

	set("debuffs.raise", true)
	assert(plate.auras:GetFrameLevel() == plate:GetFrameLevel() + 100, "debuffs draw in front of other plates")
	set("debuffs.raise", false)
	assert(plate.auras:GetFrameLevel() == plate:GetFrameLevel() + 1, "off restores their layer")

	set("debuffs.dispelColor", true)
	assert(#aura.dispel == 1, "dispel types colour the ring through the engine")
	set("debuffs.border", false)
	assert(#aura.dispel == 0, "with no border there is no ring to colour")
	set("debuffs.border", true)
	set("debuffs.dispelColor", false)
	assert(#aura.dispel == 0, "off unbinds it")
	set("debuffs.pandemic", true)
	assert(#aura.pandemic == 1, "the pandemic mark is an engine region")
	set("debuffs.pandemic", false)
	assert(#aura.pandemic == 0, "off removes it")
	set("debuffs.tooltips", true)
	assert(N.Last(button, "SetMouseMotionEnabled")[1] == true, "tooltips take the mouse")
	set("debuffs.tooltips", false)
	assert(N.Last(button, "SetMouseMotionEnabled")[1] == false, "off lets the mouse through again")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end
collectgarbage()

-- Combo points: on the target for rogues, following the target, power and combat, with the energy bar; nothing for other classes.
do
	local env, K, ns, set = boot({ nameplate1 = {}, nameplate2 = {} }, { playerClass = "ROGUE" })
	env._units.player = { level = 15, power = 40, powerMax = 100 }
	local plain = env.UnitPower
	env.UnitPower = function(token, kind)
		if token == "player" then return kind == 4 and 3 or env._units.player.power end
		return plain(token, kind)
	end
	local p1, p2 = ns.Plates.Get("nameplate1"), ns.Plates.Get("nameplate2")
	set("preset", "custom")
	local y0 = select(5, p1:GetPoint(1))
	set("resource.show", true)
	assert(math.abs(select(5, p1:GetPoint(1)) - y0) < 0.5, "no plate moves before a target carries the points, beyond pixel alignment")
	N.Target(env, "nameplate1")
	local frame = assert(p1.resource, "the target carries the points")
	assert(frame:IsShown() and frame.pips[3]:GetValue() == 3, "showing the combo points")
	N.Target(env, "nameplate2")
	assert(p2.resource:IsShown() and not frame:IsShown(), "the points follow the target")
	frame = p2.resource
	env.UnitPower = function(token, kind)
		if token == "player" then return kind == 4 and 5 or env._units.player.power end
		return plain(token, kind)
	end
	env.FireEvent("UNIT_POWER_FREQUENT", "player", "COMBO_POINTS")
	assert(frame.pips[5]:GetValue() == 5, "power events refresh them")
	local placed = #N.Calls(frame.pips[1], "SetPoint")
	p2:UpdateHighlight()
	p2:UpdateHighlight()
	assert(#N.Calls(frame.pips[1], "SetPoint") == placed, "highlight updates do not lay the points out again")
	set("resource.energy", true)
	assert(frame.energy:IsShown() and frame.energy:GetValue() == 40, "the energy bar shows")
	set("resource.energyHideFull", true)
	env._units.player.power = 100
	env.FireEvent("UNIT_POWER_FREQUENT", "player", "ENERGY")
	assert(not frame.energy:IsShown(), "full energy out of combat hides")
	env.FireEvent("PLAYER_REGEN_DISABLED")
	assert(frame.energy:IsShown(), "and shows in combat")
	env.FireEvent("PLAYER_REGEN_ENABLED")
	assert(not frame.energy:IsShown(), "and hides again after it")
	set("resource.place", "TOP")
	assert(frame:GetPoint(1) == "BOTTOM", "the points can sit above the name")
	set("resource.scale", 2)
	assert(val(env, frame.pips[1]:GetWidth()) > 10, "and grow")
	set("resource.show", false)
	assert(not frame:IsShown(), "off hides them")
	assert(select(5, p1:GetPoint(1)) == y0, "and gives the room back")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end
do
	local env, K, ns, set = boot({ nameplate1 = {} })
	set("resource.show", true)
	N.Target(env, "nameplate1")
	assert(ns.Plates.Get("nameplate1").resource == nil, "other classes have no points to show")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end
collectgarbage()

-- The Options preview, at its own size, shows each option on the sample plate it draws.
do
	local env, K, ns, set = boot({})
	local preview = ns.Preview.Build(env.UIParent)
	preview:SetSize(248, 516)
	local function seen(region)
		while region do
			if not region:IsShown() then return false end
			region = region:GetParent()
		end
		return true
	end
	local function drawn() return preview.plates[preview.chosen] end
	local function on(key, value, check)
		local before = K.Options.Read("Nameplates", key)
		set(key, value)
		preview.Refresh()
		assert(check(drawn()), key .. " shows on the drawn sample")
		set(key, before)
		preview.Refresh()
	end
	preview.Refresh()
	on("cast.important", true, function(p) return alpha(env, p.castImportantFill) == 1 end)
	on("cast.importantGlow", true, function(p) return seen(p.castImportantGlow[1]) end)
	on("target.glow", true, function(p) return seen(p.targetGlow[1]) end)
	on("target.fill", true, function(p) return seen(p.targetFill) end)
	on("resource.show", true, function(p) return seen(p.resource) and p.resource.pips[3]:GetValue() == 3 end)
	on("debuffs.timePlace", "CENTER", function(p) return seen(p.sampleAuras[1].tile.time) end)
	on("debuffs.countPlace", "TOPLEFT", function(p) return seen(p.sampleAuras[1].tile.count) end)
	on("debuffs.pandemic", true, function(p) return seen(p.sampleAuras[2].tile.cue) end)
	on("debuffs.dispelColor", true, function(p) return seen(p.sampleAuras[1].tile.dispel) end)
	on("target.scale", 1.3, function(p) return near(p:GetScale(), 1.3) end)
	on("threat.display", "healthEdge", function(p) return p.sample.threat ~= nil end)
	on("threat.display", "name", function(p) return p.sample.threat ~= nil end)
	assert(not (drawn().sampleAuras[1].tile.over and drawn().sampleAuras[1].tile.over:IsShown()), "default text options leave the sample as it was")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end
collectgarbage()

-- Finding 9: the keys the review found untested change what they name.
do
	local env, K, ns, set = boot({ nameplate1 = { classification = "elite", level = 20, threat = 3 }, nameplate2 = { powerType = 0, powerMax = 100, threat = 3 } })
	local mini, caster = ns.Plates.Get("nameplate1"), ns.Plates.Get("nameplate2")
	set("threat.groupOnly", false)
	set("threat.display", "health")
	set("types.miniBoss", true)
	set("types.miniBossColor", { r = 0.1, g = 0.2, b = 0.3 })
	set("types.caster", true)
	set("types.casterColor", { r = 0.4, g = 0.5, b = 0.6 })
	local danger = { K.ColorVision.Color(2, K.Tokens.Color("hostile")) }
	same(bar(mini), danger, "threat beats the mini-boss colour by default")
	same(bar(caster), danger, "and the caster colour")
	set("threat.overMiniBoss", false)
	same(bar(mini), { 0.1, 0.2, 0.3 }, "damage dealers can keep the mini-boss colour")
	same(bar(caster), danger, "without touching casters")
	set("threat.overCaster", false)
	same(bar(caster), { 0.4, 0.5, 0.6 }, "or keep the caster colour")
	set("threat.role", "tank")
	local safe = { K.ColorVision.Color(1, K.Tokens.Color("friendly")) }
	same(bar(mini), safe, "tanks follow their own switch")
	set("threat.tankOverOthers", false)
	same(bar(mini), { 0.1, 0.2, 0.3 }, "tanks can keep the mini-boss colour")
	same(bar(caster), { 0.4, 0.5, 0.6 }, "and the caster colour")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end
collectgarbage()
do
	local env, K, ns, set = boot({ nameplate1 = {} }, { playerClass = "ROGUE" })
	env._units.player = { level = 15, power = 40, powerMax = 100 }
	set("resource.show", true)
	set("resource.energy", true)
	N.Target(env, "nameplate1")
	local frame = ns.Plates.Get("nameplate1").resource
	local function x(i) return select(4, frame.pips[i]:GetPoint(1)) end
	local function y(region) return select(5, region:GetPoint(1)) end
	local gap = x(2) - x(1)
	set("resource.spacing", 6)
	assert(near(x(2) - x(1) - gap, 4), "Spacing spreads the points")
	local h, w = val(env, frame.energy:GetHeight()), val(env, frame.energy:GetWidth())
	set("resource.energyHeight", 6)
	assert(val(env, frame.energy:GetHeight()) > h, "Energy bar height grows the bar")
	set("resource.energyWidth", 2)
	assert(val(env, frame.energy:GetWidth()) > w * 1.5, "Energy bar width widens it")
	assert(y(frame.energy) < 0 and y(frame.pips[1]) == 0, "the energy bar sits under the points")
	set("resource.energyPlace", "ABOVE")
	assert(y(frame.energy) == 0 and y(frame.pips[1]) < 0, "or above them")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end
collectgarbage()

-- Every option on at once raises nothing at four screen sizes, the live preview included.
local ALL_ON = {
	["level.x"] = 4, ["cast.showIcon"] = true, ["cast.iconScale"] = 1.5, ["cast.iconX"] = -2, ["cast.offsetY"] = -4, ["cast.border"] = false,
	["cast.important"] = true, ["cast.importantGlow"] = true, ["cast.importantKick"] = true, ["cast.scale"] = 1.2,
	["debuffs.timePlace"] = "TOP", ["debuffs.countPlace"] = "CENTER", ["debuffs.border"] = true, ["debuffs.cropped"] = true,
	["debuffs.raise"] = true, ["debuffs.dispelColor"] = true, ["debuffs.pandemic"] = true, ["debuffs.tooltips"] = true,
	["threat.overBoss"] = false, ["threat.display"] = "healthEdge", ["target.glow"] = true, ["target.fill"] = true, ["target.scale"] = 1.2,
	["resource.show"] = true, ["resource.energy"] = true, ["resource.energyHideFull"] = true, ["resource.place"] = "TOP",
	["cvars.enabled"] = true,
}
local scene = dofile("Tools/render/scene.lua")
for _, size in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	local own = {}
	for key, value in pairs(ALL_ON) do
		local first, last = key:match("^(%w+)%.(%w+)$")
		own[first] = own[first] or {}
		own[first][last] = value
	end
	local env, K, ns = boot({ nameplate1 = { classification = "worldboss", threat = 3 } },
		{ saved = saved(own), width = size[1], height = size[2], playerClass = "ROGUE", setup = important })
	N.Target(env, "nameplate1")
	N.Debuffs(env, "nameplate1", 3)
	N.Cast(env, "nameplate1", { name = "Fear", text = "Fear", texture = 136183 })
	ns.Preview.Build(env.UIParent).Refresh()
	env._bases.nameplate1:SetPoint("CENTER", env.UIParent, "CENTER")
	local s, plate, at = scene.RectSolver(env), ns.Plates.Get("nameplate1"), size[1] .. "x" .. size[2]
	local ix, _, iw = scene.RectIn(s, plate.castIcon)
	assert(ix + iw <= scene.RectIn(s, plate.castBar) + 1e-6, at .. ": the larger cast icon clears the bar")
	local _, ry, _, rh = scene.RectIn(s, plate.resource)
	assert(ry + rh < select(2, scene.RectIn(s, plate.health)) - K.Widgets.Snap(plate, ns.Plate.NAME_GAP), at .. ": the points sit above the name")
	assert(#env._errors == 0 and K.ErrorCount() == 0, at .. ": " .. tostring(env._errors[1]))
	collectgarbage()
end
-- Review of #611: each block reproduces one finding of the review at e9c32164 and must hold after the fixes.

-- Finding 1: a lockdown that begins before PLAYER_REGEN_DISABLED could leave enemy plates hidden for the whole fight, so the option is gone and an old profile keeps the player's value.
do
	local env, K, ns = boot({}, { saved = saved({ cvars = { enabled = true, enemiesInCombat = true } }) })
	env._combat = true
	env.FireEvent("PLAYER_REGEN_DISABLED")
	assert(env._cvars.nameplateShowEnemies == "1", "enemy plates stay shown when the lockdown comes first")
	env._combat = false
	env.FireEvent("PLAYER_REGEN_ENABLED")
	env.RunTimers()
	assert(env._cvars.nameplateShowEnemies == "1", "and after combat")
	assert(ns.Settings.Row("cvars.enemiesInCombat") == nil, "the option is not offered")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end
collectgarbage()

-- Findings 2 and 3: a new combo target refreshes the points; other power ticks and a removed target write nothing; an energy tick writes only the value.
do
	local env, K, ns, set = boot({ nameplate1 = {} }, { playerClass = "ROGUE" })
	env._units.player = { level = 15, power = 70, powerMax = 100 }
	local points = 1
	env.GetComboPoints = function() return points end
	set("resource.show", true)
	N.Target(env, "nameplate1")
	local frame = ns.Plates.Get("nameplate1").resource
	points = 3
	env.FireEvent("COMBO_TARGET_CHANGED")
	assert(frame.pips[1]:GetValue() == 3, "a new combo target refreshes the points")
	local function writes() return #N.Calls(frame.pips[1], "SetValue") end
	local before = writes()
	env.FireEvent("UNIT_POWER_FREQUENT", "player", "ENERGY")
	assert(writes() == before, "an energy tick leaves the points alone")
	set("resource.energy", true)
	local energy = frame.energy
	local function setup()
		return #N.Calls(energy, "SetMinMaxValues") + #N.Calls(energy, "SetShown") + #N.Calls(energy, "Show") + #N.Calls(energy, "Hide")
	end
	before = setup()
	env._units.player.power = 75
	env.FireEvent("UNIT_POWER_FREQUENT", "player", "ENERGY")
	assert(setup() == before and val(env, energy:GetValue()) == 75, "an energy tick writes only the value")
	N.Remove(env, "nameplate1")
	before = writes()
	env.FireEvent("UNIT_POWER_FREQUENT", "player", "COMBO_POINTS")
	assert(writes() == before, "a removed target's points are let go")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end
collectgarbage()

-- Finding 3: a repaint of an unchanged cast leaves its glow alone.
do
	local env, K, ns, set = boot({ nameplate1 = {} })
	local plate = ns.Plates.Get("nameplate1")
	set("cast.importantGlow", true)
	env.C_Spell.IsSpellImportant = function() return env.Secret(false) end
	N.Cast(env, "nameplate1", { name = "Bolt", text = "Bolt", texture = 136183 })
	local count = 0
	for _, piece in ipairs(plate.castImportantGlow) do
		local shown, flag = piece.SetShown, piece.SetAlphaFromBoolean
		piece.SetShown = function(self, ...) count = count + 1; return shown(self, ...) end
		piece.SetAlphaFromBoolean = function(self, ...) count = count + 1; return flag(self, ...) end
	end
	ns.Cast.RepaintAll()
	assert(count == 0, "a repaint does not show the glow again: " .. count)
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end
collectgarbage()

-- Finding 4: a larger cast icon keeps clear of the bar; the target's points move no other plate; a cast bar moved up keeps them under the health bar.
do
	local env, K, ns, set = boot({ nameplate1 = {}, nameplate2 = {} }, { playerClass = "ROGUE" })
	local p1, p2 = ns.Plates.Get("nameplate1"), ns.Plates.Get("nameplate2")
	env._bases.nameplate1:SetPoint("CENTER", env.UIParent, "CENTER")
	env._bases.nameplate2:SetPoint("CENTER", env.UIParent, "CENTER", 0, 200)
	set("cast.showIcon", true)
	set("cast.iconScale", 2)
	set("cast.height", 20)
	local s = scene.RectSolver(env)
	local ix, _, iw = scene.RectIn(s, p1.castIcon)
	local bx = scene.RectIn(s, p1.castBar)
	assert(ix + iw <= bx + 1e-6, "a larger icon does not cover the bar: " .. (ix + iw - bx))
	set("cast.iconRight", true)
	s = scene.RectSolver(env)
	ix = scene.RectIn(s, p1.castIcon)
	local rx, _, rw = scene.RectIn(s, p1.castBar)
	assert(rx + rw <= ix + 1e-6, "on the right either")
	set("cast.iconRight", false)
	set("cast.iconScale", 1)
	set("cast.height", 6)
	set("cast.showIcon", false)
	local y = select(5, p2:GetPoint(1))
	set("resource.show", true)
	N.Target(env, "nameplate1")
	assert(math.abs(select(5, p2:GetPoint(1)) - y) < 0.5, "the target's points move no other plate, beyond pixel alignment")
	set("cast.showName", false)
	set("cast.offsetY", -25)
	s = scene.RectSolver(env)
	local _, hy, _, hh = scene.RectIn(s, p1.health)
	local _, py = scene.RectIn(s, p1.resource)
	assert(py >= hy + hh, "points under the plate stay under the health bar")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end
collectgarbage()

-- Finding 5: while the interrupt is ready, an important cast it cannot stop keeps the important colour.
do
	local env, K, ns, set = boot({ nameplate1 = {} })
	local plate = ns.Plates.Get("nameplate1")
	env.C_Spell.IsSpellImportant = function() return true end
	set("cast.important", true)
	set("cast.importantKick", true)
	ns.Interrupt.spell, ns.Interrupt.ready = 1766, true
	N.Cast(env, "nameplate1", { name = "Ward", text = "Ward", texture = 136183, notInterruptible = true })
	local fill = plate.castImportantFill
	assert(alpha(env, fill) == 1, "a protected important cast keeps its tint")
	same({ fill:GetVertexColor() }, { K.Tokens.Color("legendary") }, "in the important colour")
	N.Cast(env, "nameplate1", { name = "Bolt", text = "Bolt", texture = 136183, notInterruptible = false })
	assert(alpha(env, fill) == 0, "an interruptible one keeps the usual colour")
	N.Cast(env, "nameplate1", { name = "Ward", text = "Ward", texture = 136183, notInterruptible = true, secret = true })
	local call = N.Last(fill, "SetVertexColorFromBoolean")
	assert(call and env.issecretvalue(call[1]) and alpha(env, fill) == 1, "a secret flag picks the colour in the engine")
	same({ call[2].r, call[2].g, call[2].b }, { K.Tokens.Color("legendary") }, "the important colour for a cast the interrupt cannot stop")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end
collectgarbage()

-- Finding 6: Highlight friendly targets governs the target size; the preview keeps the target sample for target options; the name alone draws no threat shape.
do
	local env, K, ns, set = boot({ nameplate1 = { canAttack = false, reaction = 5 }, nameplate2 = { threat = 3 } })
	local friend = ns.Plates.Get("nameplate1")
	local scale = friend:GetScale()
	set("target.scale", 1.25)
	set("target.friendly", false)
	N.Target(env, "nameplate1")
	assert(near(friend:GetScale(), scale), "a friendly target keeps its size with friendly targets off")
	assert(not ns.Settings.Row("target.friendly").disableWhen({ target = { highlight = false, glow = false, fill = false, scale = 1.25 } }),
		"the friendly switch stays open for the size alone")
	set("threat.groupOnly", false)
	set("threat.display", "name")
	assert(not ns.Plates.Get("nameplate2").threatShape:IsShown(), "the name alone draws no threat shape")
	local preview = ns.Preview.Build(env.UIParent)
	preview:SetSize(248, 516)
	set("threat.display", "healthEdge")
	set("target.glow", true)
	preview.Refresh()
	local drawn = preview.plates[preview.chosen]
	assert(drawn.targetGlow and drawn.targetGlow[1]:IsShown(), "the preview draws the target glow beside a threat display")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end
collectgarbage()

-- Finding 7: Full opacity while casting still needs a drawn cast bar, as in v0.2.8.
do
	local env, K, ns, set = boot({ nameplate1 = {}, nameplate2 = {} })
	set("target.smoothOpacity", false)
	set("target.dimOthers", 0.4)
	set("cast.enabled", false)
	set("cast.fullOpacity", true)
	N.Target(env, "nameplate1")
	local plate = ns.Plates.Get("nameplate2")
	N.Cast(env, "nameplate2", { name = "Bolt", text = "Bolt", texture = 136183 })
	assert(plate.alphaGoal == 0.4, "a cast with cast bars hidden keeps the v0.2.8 dimming")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end
collectgarbage()

-- Finding 8: a missing API refuses its feature instead of raising.
do
	local env, _, ns, set = boot({ nameplate1 = {} }, { playerClass = "DRUID" })
	env._units.player = { level = 15, power = 70, powerMax = 100, powerType = 3 }
	set("resource.show", true)
	N.Target(env, "nameplate1")
	env.UnitPowerType = nil
	assert(pcall(ns.Resource.Place, ns.Plates.Get("nameplate1"), true), "a missing UnitPowerType refuses the points")
end
collectgarbage()
do
	local env, _, ns, set = boot({ nameplate1 = {} }, { playerClass = "ROGUE" })
	env._units.player = { level = 15, power = 100, powerMax = 100 }
	set("resource.show", true)
	set("resource.energy", true)
	set("resource.energyHideFull", true)
	N.Target(env, "nameplate1")
	local secret = env.issecretvalue
	env.issecretvalue = nil
	local ok, err = pcall(ns.Resource.Update)
	local shown = ns.Plates.Get("nameplate1").resource.energy:IsShown()
	env.issecretvalue = secret
	assert(ok, "a missing issecretvalue refuses the full-energy test: " .. tostring(err))
	assert(shown, "and keeps the bar shown")
end
collectgarbage()
do
	local env, K, ns, set = boot({ nameplate1 = {} })
	local plate = ns.Plates.Get("nameplate1")
	N.Debuffs(env, "nameplate1", 2)
	local buttons = { plate.auras:GetAuraGroupFrame("debuffs", 1), plate.auras:GetAuraGroupFrame("debuffs", 2) }
	for _, button in ipairs(buttons) do button.AddDispelTypeTexture = nil end
	set("debuffs.dispelColor", true)
	set("debuffs.pandemic", true)
	for _, button in ipairs(buttons) do
		assert(#button._aura.dispel == 0 and #button._aura.pandemic == 1, "a missing AddDispelTypeTexture refuses the dispel colour and keeps the other cues")
	end
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end
collectgarbage()

print("nameplates parity round 2 ok: casts, important casts, target effects, threat, level, debuffs, combo points, the preview and the #611 review")
