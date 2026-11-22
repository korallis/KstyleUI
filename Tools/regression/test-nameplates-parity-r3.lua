-- test-nameplates-parity-r3.lua: EllesmereUI parity round 3 keeps v0.2.8 plates and regions, then switches each new nameplate option on, checks it on its events, and switches it off again.
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
	local setup = opts.setup
	opts.setup = function(env)
		N.Curves(env)
		if setup then setup(env) end
	end
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

-- shown(env, region) -> the text a font string last received, formatted, and whether it held a secret.
local function shown(env, region)
	for i = #region._calls, 1, -1 do
		local call = region._calls[i]
		if call.method == "SetText" then return val(env, call.args[1]), env.issecretvalue(call.args[1]) end
		if call.method == "SetFormattedText" then
			local args = {}
			for j = 2, call.args.n do args[#args + 1] = val(env, call.args[j]) end
			return string.format(call.args[1], unpack(args)), env.issecretvalue(call.args[2])
		end
	end
end

local function alpha(env, region)
	return val(env, region:GetAlpha())
end

local function clean(env, K)
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

local NEW = {
	["health.border"] = true, ["health.absorbs"] = false, ["health.absorbAlpha"] = 0.35, ["health.absorbPlace"] = "after",
	["health.execute"] = false, ["health.executePercent"] = 30, ["range.fade"] = false, ["range.alpha"] = 0.5, ["range.spell"] = "",
	["friendly.nameMode"] = "", ["friendly.playerFormat"] = "", ["friendly.title"] = false, ["friendly.guild"] = "", ["friendly.guildSize"] = 12,
	["friendly.guildMatch"] = true, ["friendly.npcFormat"] = "", ["friendly.npcSize"] = 0, ["friendly.npcNameMode"] = "", ["friendly.petSize"] = 0,
	["friendly.owner"] = false, ["friendly.ownerOwnSize"] = false, ["friendly.ownerSize"] = 12, ["friendly.ownerMatch"] = true,
	["level.diamond"] = 1, ["cast.bgAlpha"] = 1, ["debuffs.nameGap"] = 8, ["target.fillOwn"] = false,
	["target.hover"] = false, ["focus.fill"] = false, ["focus.fillAlpha"] = 0.2, ["focus.castHeight"] = 1, ["markers.instances"] = true,
	["cvars.lineOfSight"] = false, ["cvars.lineOfSightAlpha"] = 0.4,
}

-- v0.2.8 profiles keep every default, build no new region, register nothing new and write no CVar.
do
	local env, K, ns = boot({ nameplate1 = { threat = 2 }, nameplate2 = { canAttack = false, reaction = 5, isPlayer = true, guild = "Vanguard" } })
	N.Target(env, "nameplate1")
	N.Focus(env, "nameplate2")
	local plate, friend = ns.Plates.Get("nameplate1"), ns.Plates.Get("nameplate2")
	for key, value in pairs(NEW) do
		assert(K.Options.Read("Nameplates", key) == value, "v0.2.8 profiles keep " .. key)
	end
	for _, p in ipairs({ plate, friend }) do
		for _, key in ipairs({ "absorb", "executeGate", "targetFill", "subtitle", "who", "castFocus", "outOfRange" }) do
			assert(p[key] == nil, "no " .. key .. " until its option is on")
		end
		assert(p.health.under.edgeHard:IsShown() and p.health.under.edgeSoft:IsShown(), "the health bar keeps its edge")
	end
	assert(#N.Calls(plate.castBar.background, "SetVertexColor") > 0 and near(select(4, plate.castBar.background:GetVertexColor()), select(4, K.Widgets.Rgba("track"))),
		"the cast track keeps its opacity")
	env._mouseUnit = "nameplate1"
	env.FireEvent("UPDATE_MOUSEOVER_UNIT")
	assert(not plate.hovered, "the mouse is not watched")
	for _, write in ipairs(env._cvarWrites) do
		assert(write.name ~= "nameplateOccludedAlphaMult", "no line of sight CVar is written by default")
	end
	clean(env, K)
end
collectgarbage()

-- Health bar: the border, the diamond size, absorb shields in each placement and the execute glow, each on its events.
do
	local env, K, ns, set = boot({ nameplate1 = { health = 20, absorb = 15 }, nameplate2 = { canAttack = false, reaction = 5 } })
	local plate, friend = ns.Plates.Get("nameplate1"), ns.Plates.Get("nameplate2")
	local edge = plate.health.under
	set("health.border", false)
	assert(not edge.edgeHard:IsShown() and not edge.edgeSoft:IsShown(), "the border goes")
	set("threat.groupOnly", false)
	set("threat.display", "healthEdge")
	env._units.nameplate1.threat = 3
	env.FireEvent("UNIT_THREAT_LIST_UPDATE", "nameplate1")
	assert(edge.edgeHard:IsShown(), "a threat edge still shows without the border")
	env._units.nameplate1.threat = nil
	env.FireEvent("UNIT_THREAT_LIST_UPDATE", "nameplate1")
	assert(not edge.edgeHard:IsShown(), "and goes with the threat")
	N.Focus(env, "nameplate1")
	assert(edge.edgeHard:IsShown(), "the focus edge shows too")
	N.Focus(env, nil)
	set("health.border", true)
	assert(edge.edgeHard:IsShown() and edge.edgeSoft:IsShown(), "on again restores the border")

	local side = val(env, plate.level:GetWidth())
	set("level.diamond", 1.5)
	assert(val(env, plate.level:GetWidth()) > side * 1.4, "the diamond grows")
	assert(ns.Plate.DiamondReach(plate) > ns.Plate.DiamondSize(plate), "and its reach follows")
	set("level.diamond", 1)
	assert(near(val(env, plate.level:GetWidth()), side), "1 restores it")

	set("health.absorbs", true)
	local absorb = assert(plate.absorb, "absorbs build their bar")
	assert(absorb:IsShown() and val(env, absorb:GetValue()) == 15 and select(2, absorb:GetMinMaxValues()) == 100, "the shield is the unit's absorb against its health")
	assert(env.issecretvalue(absorb:GetValue()), "the secret absorb goes straight to the bar")
	same({ select(1, absorb:GetStatusBarColor()), select(2, absorb:GetStatusBarColor()), select(3, absorb:GetStatusBarColor()) }, { 1, 1, 1 }, "in white")
	assert(near(select(4, absorb:GetStatusBarColor()), 0.35), "at the absorb opacity")
	env._units.nameplate1.absorb = 40
	env.FireEvent("UNIT_ABSORB_AMOUNT_CHANGED", "nameplate1")
	assert(val(env, absorb:GetValue()) == 40, "the absorb event updates it")
	local point, relative, relPoint = absorb:GetPoint(1)
	assert(point == "LEFT" and relative == plate.health:GetStatusBarTexture() and relPoint == "RIGHT" and not absorb:GetReverseFill(), "after the health")
	for place, want in pairs({ back = { "RIGHT", true, true }, far = { "RIGHT", false, true }, near = { "LEFT", false, false } }) do
		set("health.absorbPlace", place)
		point, relative = absorb:GetPoint(1)
		assert(point == want[1] and (relative == plate.health:GetStatusBarTexture()) == want[2] and absorb:GetReverseFill() == want[3], place)
	end
	set("health.absorbPlace", "after")
	set("health.reverse", true)
	point = absorb:GetPoint(1)
	assert(point == "RIGHT" and absorb:GetReverseFill(), "a reversed bar mirrors the shield")
	set("health.reverse", false)
	set("health.absorbAlpha", 0.6)
	assert(near(select(4, absorb:GetStatusBarColor()), 0.6), "the opacity applies")
	assert(friend.absorb and val(env, friend.absorb:GetValue()) == 0, "a unit without a shield shows none")
	set("health.absorbs", false)
	assert(not absorb:IsShown(), "off hides the shield")
	env._units.nameplate1.absorb = 5
	env.FireEvent("UNIT_ABSORB_AMOUNT_CHANGED", "nameplate1")
	assert(val(env, absorb:GetValue()) == 40, "and stops listening")

	set("health.execute", true)
	local gate = assert(plate.executeGate, "the execute glow builds its frames")
	assert(gate:IsShown() and env.issecretvalue(gate:GetAlpha()) and alpha(env, gate) == 1, "below 30 percent the glow shows through a secret curve")
	assert(plate.executePulse:IsPlaying(), "and pulses")
	assert(not (friend.executeGate and friend.executeGate:IsShown()), "friendly plates do not glow")
	env._units.nameplate1.health = 45
	env.FireEvent("UNIT_HEALTH", "nameplate1")
	assert(alpha(env, gate) == 0, "above the line the health event hides it")
	set("health.executePercent", 50)
	assert(alpha(env, gate) == 1, "the percent applies")
	K.Motion.SetLevel("off")
	set("health.executePercent", 49)
	assert(gate:IsShown() and not plate.executePulse:IsPlaying(), "with motion off the glow holds still")
	K.Motion.SetLevel("full")
	set("health.execute", false)
	assert(not gate:IsShown() and not plate.executePulse:IsPlaying(), "off hides it")
	clean(env, K)
end
collectgarbage()

-- Markers in instances: off, entering an instance drops the elite rim and the quest colour; leaving or on restores them.
do
	local env, K, ns, set = boot({ nameplate1 = { classification = "elite", quest = true } })
	local plate = ns.Plates.Get("nameplate1")
	set("types.quest", true)
	set("types.questColor", { r = 0.1, g = 0.9, b = 0.1 })
	local rim = { plate.level.rim:GetVertexColor() }
	same(bar(plate), { 0.1, 0.9, 0.1 }, "the quest colour shows")
	set("markers.instances", false)
	same({ plate.level.rim:GetVertexColor() }, rim, "outside an instance nothing changes")
	env._instance = true
	env.FireEvent("PLAYER_ENTERING_WORLD")
	assert(plate.rimWeight == 1, "inside, the elite rim goes plain")
	local now = bar(plate)
	assert(not N.SameColor(now[1], now[2], now[3], 0.1, 0.9, 0.1), "and the quest colour goes")
	set("markers.instances", true)
	assert(plate.rimWeight == 2, "on restores the rim")
	same(bar(plate), { 0.1, 0.9, 0.1 }, "and the quest colour")
	set("markers.instances", false)
	env._instance = false
	env.FireEvent("PLAYER_ENTERING_WORLD")
	assert(plate.rimWeight == 2, "leaving the instance restores them too")
	clean(env, K)
end
collectgarbage()

-- The gap between the name and the debuffs above it.
do
	local env, K, ns, set = boot({ nameplate1 = {} })
	local plate = ns.Plates.Get("nameplate1")
	N.Debuffs(env, "nameplate1", 2)
	local y0 = select(5, plate.auras:GetPoint(1))
	set("debuffs.nameGap", 14)
	assert(near(select(5, plate.auras:GetPoint(1)) - y0, K.Widgets.Snap(plate, 14) - K.Widgets.Snap(plate, 8)), "the debuffs move up by the gap")
	set("debuffs.nameGap", 8)
	assert(near(select(5, plate.auras:GetPoint(1)), y0), "8 restores them")
	clean(env, K)
end
collectgarbage()

-- Friendly names: player colour, title, format and guild line; NPC format, size and colour; pet size and owner line.
do
	local env, K, ns, set = boot({
		nameplate1 = { name = "Thaldrin", canAttack = false, reaction = 5, isPlayer = true, class = "WARRIOR", pvpName = "Sergeant Thaldrin", guild = "Vanguard" },
		nameplate2 = { name = "Innkeeper Hale", canAttack = false, reaction = 5, level = 30 },
		nameplate3 = { name = "Ember", canAttack = false, reaction = 5, pet = true, ownerGUID = "Player-1" },
		nameplate4 = { name = "Gnoll", isPlayer = true, class = "MAGE", pvpName = "Lord Gnoll", guild = "Pack" },
	})
	env._players["Player-1"] = "Thaldrin"
	local player, npc, pet, enemy = ns.Plates.Get("nameplate1"), ns.Plates.Get("nameplate2"), ns.Plates.Get("nameplate3"), ns.Plates.Get("nameplate4")
	local nameY = select(5, player.name:GetPoint(1))
	local size = select(2, player.name:GetFont())

	set("friendly.nameMode", "custom")
	set("friendly.nameColor", { r = 0.2, g = 0.4, b = 0.6 })
	same({ player.name:GetTextColor() }, { 0.2, 0.4, 0.6 }, "friendly players take the player name colour")
	same({ npc.name:GetTextColor() }, { K.Tokens.Color("textEmphasis") }, "NPCs keep theirs")
	same({ enemy.name:GetTextColor() }, { K.Tokens.Color("textEmphasis") }, "and enemies theirs")
	set("friendly.nameMode", "class")
	same({ player.name:GetTextColor() }, { K.Theme.ClassTextColorForWidget("WARRIOR") }, "or their class colour")
	set("name.colorMode", "custom")
	same({ player.name:GetTextColor() }, { K.Theme.ClassTextColorForWidget("WARRIOR") }, "which beats the shared name colour")
	set("name.colorMode", "")

	set("friendly.title", true)
	assert(player.name:GetText() == K.Locale.Upper("Sergeant Thaldrin"), "titles join the name")
	assert(enemy.name:GetText() == K.Locale.Upper("Gnoll"), "enemy players keep their bare name")
	set("friendly.playerFormat", "[name] ([level])")
	assert(player.name:GetText() == "Sergeant Thaldrin (10)", "the player format writes the name, with its title")
	assert(npc.name:GetText() == K.Locale.Upper("Innkeeper Hale"), "NPCs keep theirs")
	env._units.nameplate1.level = 11
	env.FireEvent("UNIT_LEVEL", "nameplate1")
	assert(player.name:GetText() == "Sergeant Thaldrin (11)", "the format follows its tag events")
	set("friendly.playerFormat", "")

	set("friendly.guild", "plain")
	local sub = assert(player.subtitle, "the guild builds its line")
	assert(sub:IsShown() and shown(env, sub) == "Vanguard", "with the guild name")
	assert(select(5, player.name:GetPoint(1)) > nameY, "the name moves up over it")
	assert(select(2, sub:GetFont()) == ns.Settings.Get("friendly.guildSize"), "at the guild size")
	assert(not (enemy.subtitle and enemy.subtitle:IsShown()), "enemy players show no guild")
	same({ sub:GetTextColor() }, { K.Theme.ClassTextColorForWidget("WARRIOR") }, "in the name's colour")
	set("friendly.guildMatch", false)
	set("friendly.guildColor", { r = 0.3, g = 0.3, b = 0.3 })
	same({ sub:GetTextColor() }, { 0.3, 0.3, 0.3 }, "or the guild colour")
	set("friendly.guild", "brackets")
	assert(shown(env, sub) == "<Vanguard>", "in brackets")
	env._units.nameplate1.secretGuild = true
	env.FireEvent("UNIT_NAME_UPDATE", "nameplate1")
	local text, secret = shown(env, sub)
	assert(secret and text == "<Vanguard>", "a secret guild goes straight to the text")
	env._units.nameplate1.guild = nil
	env.FireEvent("UNIT_NAME_UPDATE", "nameplate1")
	assert(not sub:IsShown() and near(select(5, player.name:GetPoint(1)), nameY), "no guild, no line")
	env._units.nameplate1.guild, env._units.nameplate1.secretGuild = "Vanguard", false
	env.FireEvent("UNIT_NAME_UPDATE", "nameplate1")
	set("friendly.guildSize", 19)
	assert(select(2, sub:GetFont()) > size, "the guild size applies")
	set("friendly.guild", "")
	set("friendly.title", false)
	set("friendly.nameMode", "")
	assert(not sub:IsShown() and near(select(5, player.name:GetPoint(1)), nameY), "off removes the line")
	assert(player.name:GetText() == K.Locale.Upper("Thaldrin"), "and the title")
	same({ player.name:GetTextColor() }, { K.Tokens.Color("textEmphasis") }, "and the colour")

	set("friendly.npcFormat", "[name] [level]")
	assert(npc.name:GetText() == "Innkeeper Hale 30" and player.name:GetText() == K.Locale.Upper("Thaldrin"), "the NPC format writes NPC names only")
	set("friendly.npcSize", 18)
	assert(select(2, npc.name:GetFont()) > size and near(select(2, player.name:GetFont()), size), "NPC names take their size")
	set("friendly.npcNameMode", "custom")
	set("friendly.npcColor", { r = 0.7, g = 0.6, b = 0.5 })
	same({ npc.name:GetTextColor() }, { 0.7, 0.6, 0.5 }, "and their colour")
	env._units.nameplate2.canAttack = true
	env.FireEvent("UNIT_FACTION", "nameplate2")
	assert(near(select(2, npc.name:GetFont()), size), "an NPC turning hostile drops the friendly size")
	same({ npc.name:GetTextColor() }, { K.Tokens.Color("textEmphasis") }, "and colour")
	env._units.nameplate2.canAttack = false
	env.FireEvent("UNIT_FACTION", "nameplate2")
	same({ npc.name:GetTextColor() }, { 0.7, 0.6, 0.5 }, "and takes them again when it turns back")
	set("friendly.npcFormat", "")
	set("friendly.npcSize", 0)
	set("friendly.npcNameMode", "")
	assert(near(select(2, npc.name:GetFont()), size) and npc.name:GetText() == K.Locale.Upper("Innkeeper Hale"), "off restores NPC names")

	set("friendly.petSize", 13)
	assert(near(select(2, pet.name:GetFont()), 13) and size < 13, "pet names take their size over the Medallions 11-unit name")
	set("friendly.owner", true)
	local owner = assert(pet.subtitle, "the owner builds its line")
	assert(owner:IsShown() and shown(env, owner) == "Thaldrin", "with the owner's name")
	assert(near(select(2, owner:GetFont()), select(2, pet.name:GetFont())), "at the pet name's size")
	assert(not (player.subtitle and player.subtitle:IsShown()) and not (npc.subtitle and npc.subtitle:IsShown()), "only pets show an owner")
	set("friendly.ownerOwnSize", true)
	set("friendly.ownerSize", 14)
	assert(select(2, owner:GetFont()) > select(2, pet.name:GetFont()), "or its own size")
	set("friendly.ownerMatch", false)
	set("friendly.ownerColor", { r = 0.4, g = 0.5, b = 0.6 })
	same({ owner:GetTextColor() }, { 0.4, 0.5, 0.6 }, "in the owner colour")
	env._units.nameplate3.ownerGUID = nil
	env.FireEvent("UNIT_NAME_UPDATE", "nameplate3")
	assert(not owner:IsShown(), "no owner, no line")
	set("friendly.owner", false)
	set("friendly.petSize", 0)
	assert(near(select(2, pet.name:GetFont()), size), "off restores pet names")
	clean(env, K)
end
collectgarbage()

-- Highlights: the focus bar highlight, the bar's own colour and the plate under the mouse.
do
	local env, K, ns, set = boot({ nameplate1 = {}, nameplate2 = {}, nameplate3 = {} })
	local p1, p2, p3 = ns.Plates.Get("nameplate1"), ns.Plates.Get("nameplate2"), ns.Plates.Get("nameplate3")
	set("focus.fill", true)
	set("focus.fillColor", { r = 0.2, g = 0.3, b = 0.4 })
	set("focus.fillAlpha", 0.5)
	N.Focus(env, "nameplate2")
	assert(p2.targetFill:IsShown() and not p1.targetFill:IsShown(), "the focus brightens on its own")
	same({ p2.targetFill:GetVertexColor() }, { 0.2, 0.3, 0.4 }, "in the focus highlight colour")
	assert(near(alpha(env, p2.targetFill), 0.5), "at its opacity")
	set("target.fill", true)
	N.Target(env, "nameplate2")
	same({ p2.targetFill:GetVertexColor() }, { K.Tokens.Color("white") }, "the target highlight wins on a focused target")
	N.Target(env, nil)
	set("target.fillOwn", true)
	same({ p2.targetFill:GetVertexColor() }, bar(p2), "highlights can take the bar's own colour")
	set("types.normal", true)
	set("types.normalColor", { r = 0.6, g = 0.1, b = 0.1 })
	same({ p2.targetFill:GetVertexColor() }, { K.ColorVision.Color(2, 0.6, 0.1, 0.1) }, "and follow it")
	N.Focus(env, nil)
	assert(not p2.targetFill:IsShown(), "losing the focus hides it")

	set("target.hover", true)
	env._mouseUnit = "nameplate3"
	env.FireEvent("UPDATE_MOUSEOVER_UNIT")
	assert(p3.targetFill and p3.targetFill:IsShown(), "the plate under the mouse brightens")
	env._mouseUnit = "nameplate1"
	env.FireEvent("UPDATE_MOUSEOVER_UNIT")
	assert(p1.targetFill:IsShown() and not p3.targetFill:IsShown(), "and follows the mouse")
	env._mouseUnit = nil
	env.FireEvent("UPDATE_MOUSEOVER_UNIT")
	assert(not p1.targetFill:IsShown(), "and goes when the mouse leaves")
	env._mouseUnit = "nameplate1"
	env.FireEvent("UPDATE_MOUSEOVER_UNIT")
	N.Remove(env, "nameplate1")
	N.Add(env, "nameplate1", {})
	assert(not p1.hovered, "a recycled plate forgets the mouse")
	set("target.hover", false)
	env._mouseUnit = "nameplate3"
	env.FireEvent("UPDATE_MOUSEOVER_UNIT")
	assert(not p3.hovered and not p3.targetFill:IsShown(), "off stops watching the mouse")
	for _, key in ipairs({ "focus.fill", "target.fill", "target.fillOwn" }) do set(key, false) end
	N.Focus(env, "nameplate2")
	assert(not p2.targetFill:IsShown(), "off removes every highlight")
	clean(env, K)
end
collectgarbage()

-- Cast bar: the focus's taller bar and the track's opacity.
do
	local env, K, ns, set = boot({ nameplate1 = {}, nameplate2 = {} })
	local p1, p2 = ns.Plates.Get("nameplate1"), ns.Plates.Get("nameplate2")
	local h, room = val(env, p1.castBar:GetHeight()), ns.Cast.Room(p1)
	set("focus.castHeight", 2)
	set("cast.shieldColor", { r = 0.2, g = 0.2, b = 0.9 })
	N.Cast(env, "nameplate1", { name = "Fear", text = "Fear", texture = 136183, notInterruptible = true })
	N.Focus(env, "nameplate1")
	same({ p1.castBar:GetStatusBarColor() }, { K.ColorVision.Color(2, 0.2, 0.2, 0.9) }, "a cast keeps its colour through the resize")
	assert(near(val(env, p1.castBar:GetHeight()), K.Widgets.Snap(p1, h * 2)) and ns.Cast.Room(p1) > room, "the focus's cast bar is taller, with room under it")
	assert(near(val(env, p2.castBar:GetHeight()), h), "other cast bars keep their height")
	N.Focus(env, "nameplate2")
	assert(near(val(env, p1.castBar:GetHeight()), h) and near(ns.Cast.Room(p1), room), "a new focus restores the old one")
	set("focus.castHeight", 1)
	assert(near(val(env, p2.castBar:GetHeight()), h), "1 restores it")
	local track = select(4, p1.castBar.background:GetVertexColor())
	set("cast.bgAlpha", 0.25)
	assert(near(select(4, p1.castBar.background:GetVertexColor()), track * 0.25), "the track fades")
	assert(near(select(4, p1.castBar.barEdge.track:GetVertexColor()), 0.25), "with the edge's track")
	set("cast.bgAlpha", 1)
	assert(near(select(4, p1.castBar.background:GetVertexColor()), track), "1 restores it")
	clean(env, K)
end
collectgarbage()

-- Range: plates beyond the range spell fade on the ticker; a secret answer, a missing spell or off keeps them.
do
	local env, K, ns, set = boot({ nameplate1 = { outOfRange = true }, nameplate2 = {}, nameplate3 = { canAttack = false, reaction = 5, outOfRange = true } },
		{ playerClass = "ROGUE", known = { [1766] = true } })
	local p1, p2, p3 = ns.Plates.Get("nameplate1"), ns.Plates.Get("nameplate2"), ns.Plates.Get("nameplate3")
	set("target.smoothOpacity", false)
	set("range.fade", true)
	set("range.alpha", 0.4)
	env.RunTickers()
	assert(near(alpha(env, p1), 0.4) and near(alpha(env, p2), 1), "an enemy out of range fades")
	assert(near(alpha(env, p3), 1), "friendly plates do not")
	N.Target(env, "nameplate2")
	set("target.dimOthers", 0.5)
	assert(near(alpha(env, p1), 0.2), "it combines with the target dimming")
	env._units.nameplate1.outOfRange = false
	env.RunTickers()
	assert(near(alpha(env, p1), 0.5), "back in range it returns")
	env._units.nameplate1.outOfRange, env._units.nameplate1.secretRange = true, true
	env.RunTickers()
	assert(near(alpha(env, p1), 0.5), "a secret answer keeps the plate")
	env._units.nameplate1.secretRange = false
	set("range.spell", "Nothing Known")
	env.RunTickers()
	assert(near(alpha(env, p1), 0.2), "a named spell is checked too")
	set("range.fade", false)
	assert(near(alpha(env, p1), 0.5), "off restores the plates")
	local calls = #N.Calls(p1, "SetAlpha")
	env.RunTickers()
	assert(#N.Calls(p1, "SetAlpha") == calls, "and stops the ticker")
	clean(env, K)
end
collectgarbage()

-- Line of sight: the CVar is written out of combat under management, and handed back when off.
do
	local env, K, _, set = boot({}, { setup = function(env)
		env._cvars.nameplateOccludedAlphaMult, env._cvarDefaults.nameplateOccludedAlphaMult = "0.4", "0.4"
	end })
	set("cvars.enabled", true)
	set("cvars.lineOfSight", true)
	set("cvars.lineOfSightAlpha", 0.8)
	assert(env._cvars.nameplateOccludedAlphaMult == "0.8", "the opacity reaches the game")
	env._combat = true
	set("cvars.lineOfSightAlpha", 0.6)
	assert(env._cvars.nameplateOccludedAlphaMult == "0.8", "never in combat")
	env._combat = false
	env.FireEvent("PLAYER_REGEN_ENABLED")
	env.RunTimers()
	assert(env._cvars.nameplateOccludedAlphaMult == "0.6", "but after it")
	set("cvars.lineOfSight", false)
	assert(env._cvars.nameplateOccludedAlphaMult == "0.4", "off hands the player's value back")
	clean(env, K)
end
collectgarbage()

-- The Options preview draws each new option on a sample that shows it.
do
	local env, K, ns, set = boot({})
	local frame = ns.Preview.Build(env.UIParent)
	local plates = frame.plates
	assert(frame.chosen == 1, "the target sample by default")
	frame:SetSize(1, 1)
	frame.Refresh()
	assert(frame.chosen <= 3, "a preview too small for every sample still draws one of the first three")
	set("friendly.guild", "plain")
	frame.Refresh()
	assert(frame.chosen == 3, "a friendly player option keeps its sample even when it does not fit")
	set("friendly.guild", "")
	frame:SetSize(0, 0)
	frame.Refresh()
	for _, case in ipairs({ { "friendly.guild", "plain", 3 }, { "friendly.npcSize", 16, 4 }, { "friendly.owner", true, 5 }, { "target.hover", true, 2 } }) do
		set(case[1], case[2])
		frame.Refresh()
		assert(frame.chosen == case[3], case[1] .. " draws sample " .. case[3])
		set(case[1], NEW[case[1]])
		frame.Refresh()
	end
	set("friendly.guild", "plain")
	frame.Refresh()
	assert(plates[3].subtitle:IsShown() and shown(env, plates[3].subtitle) == K.L["Ashen Vanguard"], "the friendly sample shows its guild")
	set("friendly.guild", "")
	set("friendly.owner", true)
	frame.Refresh()
	assert(plates[5].subtitle:IsShown() and shown(env, plates[5].subtitle) == K.L["Thaldrin"], "the pet sample shows its owner")
	set("friendly.owner", false)
	set("health.absorbs", true)
	set("health.execute", true)
	set("focus.castHeight", 1.5)
	frame.Refresh()
	assert(plates[1].absorb:IsShown() and plates[1].executeGate:IsShown() and plates[1].castFocus, "the target sample shows absorbs, the execute glow and the focus cast")
	set("range.fade", true)
	frame.Refresh()
	assert(plates[2].outOfRange and frame.chosen == 2, "the enemy player sample fades out of range")
	clean(env, K)
end
collectgarbage()

print("nameplates parity round 3 ok")
