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
	["resource.energyWidth"] = 1, ["resource.energyHideFull"] = false, ["cvars.enemiesInCombat"] = false,
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

-- Level offsets move the level.
do
	local env, K, ns, set = boot({ nameplate1 = {} })
	local plate = ns.Plates.Get("nameplate1")
	local _, _, _, x0, y0 = plate.level:GetPoint(1)
	set("level.x", -6)
	set("level.y", 3)
	local _, _, _, x1, y1 = plate.level:GetPoint(1)
	assert(x1 < x0 and y1 > y0, "the level moves")
	set("level.x", 0)
	set("level.y", 0)
	local _, _, _, x2, y2 = plate.level:GetPoint(1)
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
	local p, _, _, tx = aura.timer:GetPoint(1)
	assert(p == "CENTER" and near(tx, K.Widgets.Snap(plate, 3)) and ns.Auras.Lane(plate) == 0 and lane > 0, "a timer on the icon frees its lane")
	set("debuffs.countPlace", "BOTTOMLEFT")
	set("debuffs.countY", 2)
	assert(point(aura.count) == "BOTTOMLEFT", "the stacks move")
	for _, key in ipairs({ "timePlace", "timeX", "countPlace", "countY" }) do set("debuffs." .. key, NEW["debuffs." .. key]) end
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
	local y0 = select(5, p1:GetPoint(1))
	set("resource.show", true)
	assert(select(5, p1:GetPoint(1)) > y0, "plates make room for the points below")
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

-- Enemy plates in combat only: written under management as combat starts and ends, and handed back.
do
	local env, K, _, set = boot({})
	local function shown() return env._cvars.nameplateShowEnemies end
	set("cvars.enemiesInCombat", true)
	assert(shown() == "1", "nothing changes while management is off")
	set("cvars.enabled", true)
	assert(shown() == "0", "out of combat, enemy plates hide")
	env.FireEvent("PLAYER_REGEN_DISABLED")
	env._combat = true
	assert(shown() == "1", "they show as combat starts")
	env._combat = false
	env.FireEvent("PLAYER_REGEN_ENABLED")
	env.RunTimers()
	assert(shown() == "0", "and hide after it")
	set("cvars.enemiesInCombat", false)
	assert(shown() == "1", "off hands the player's value back")
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

-- Every option on at once raises nothing at four screen sizes, the live preview included.
local ALL_ON = {
	["level.x"] = 4, ["cast.showIcon"] = true, ["cast.iconScale"] = 1.5, ["cast.iconX"] = 2, ["cast.offsetY"] = -4, ["cast.border"] = false,
	["cast.important"] = true, ["cast.importantGlow"] = true, ["cast.importantKick"] = true, ["cast.scale"] = 1.2,
	["debuffs.timePlace"] = "TOP", ["debuffs.countPlace"] = "CENTER", ["debuffs.border"] = true, ["debuffs.cropped"] = true,
	["debuffs.raise"] = true, ["debuffs.dispelColor"] = true, ["debuffs.pandemic"] = true, ["debuffs.tooltips"] = true,
	["threat.overBoss"] = false, ["threat.display"] = "healthEdge", ["target.glow"] = true, ["target.fill"] = true, ["target.scale"] = 1.2,
	["resource.show"] = true, ["resource.energy"] = true, ["resource.energyHideFull"] = true, ["resource.place"] = "TOP",
	["cvars.enabled"] = true, ["cvars.enemiesInCombat"] = true,
}
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
	assert(#env._errors == 0 and K.ErrorCount() == 0, size[1] .. "x" .. size[2] .. ": " .. tostring(env._errors[1]))
	collectgarbage()
end
print("nameplates parity round 2 ok: casts, important casts, target effects, threat, level, debuffs, combo points, combat plates and the preview")
