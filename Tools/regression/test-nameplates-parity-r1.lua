-- test-nameplates-parity-r1.lua: EllesmereUI parity round 1 keeps v0.2.8 plates and regions, then switches each new nameplate option on, checks it on events, and switches it off again.
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
	local r, g, b = got[1], got[2], got[3]
	assert(near(r, want[1]) and near(g, want[2]) and near(b, want[3]), what .. ": got " .. tostring(r) .. ", " .. tostring(g) .. ", " .. tostring(b))
end

local function boot(units, opts)
	opts = opts or {}
	opts.saved = opts.saved or saved()
	local env, K, ns = N.New(opts)
	env._units.player = { level = 15 }
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
	if source then return source[1], source[2], source[3] end
	return plate.health:GetStatusBarColor()
end

local function revealed(env, text)
	local args
	for i = #text._calls, 1, -1 do
		local call = text._calls[i]
		if call.method == "SetText" or call.method == "SetFormattedText" then
			args = call.args
			break
		end
	end
	local out = {}
	for i = 1, args and args.n or 0 do
		out[i] = tostring(env.issecretvalue(args[i]) and env.Reveal(args[i]) or args[i])
	end
	return table.concat(out, "|")
end

local NEW = {
	["enemy.playersUseEnemy"] = false, ["types.boss"] = false, ["types.miniBoss"] = false, ["types.neutral"] = false,
	["types.minor"] = false, ["types.normal"] = false, ["name.afk"] = false, ["name.dnd"] = false, ["level.colorMode"] = "",
	["cast.iconRight"] = false, ["cast.offsetY"] = 0, ["cast.inFront"] = false, ["cast.nameAlign"] = "LEFT", ["cast.showTarget"] = false,
	["threat.name"] = false, ["threat.calm"] = false, ["threat.overTypes"] = true, ["threat.percent"] = false,
	["threat.percentPlace"] = "LEFT", ["threat.percentColor"] = false, ["target.friendly"] = true, ["target.hashLine"] = false,
	["target.hashPercent"] = 30, ["focus.letter"] = "", ["focus.letterSize"] = 12, ["focus.letterX"] = 0, ["focus.letterY"] = 0,
	["markers.nameRaid"] = false, ["markers.nameRaidSize"] = 14, ["markers.pvp"] = false, ["markers.pvpEnemyOnly"] = false,
	["markers.pvpPlayersOnly"] = true, ["cvars.showEnemies"] = "game", ["cvars.showFriends"] = "game", ["cvars.enemyMinions"] = "game",
	["cvars.friendlyMinions"] = "game", ["cvars.friendlyNpcs"] = "game", ["cvars.friendlyNameOnly"] = "game",
}

-- v0.2.8 profiles keep every default, build no new region and leave the cast layer and CVars alone.
do
	local env, K, ns = boot({ nameplate1 = { raid = 3, isPlayer = true, pvp = true, afk = true, threat = 2, threatPct = 55 } })
	local plate = ns.Plates.Get("nameplate1")
	for key, value in pairs(NEW) do
		assert(K.Options.Read("Nameplates", key) == value, "v0.2.8 profiles keep " .. key)
	end
	for _, key in ipairs({ "focusLetter", "hashLine", "threatText", "nameRaid", "pvpBadge" }) do
		assert(plate[key] == nil, "no " .. key .. " region until its option is on")
	end
	assert(plate.castGate:GetFrameLevel() == plate:GetFrameLevel() + 1, "casts keep their layer")
	assert(revealed(env, plate.name) == "KOBOLD MINER", "names carry no status tag by default")
	for _, write in ipairs(env._cvarWrites) do
		assert(write.name == "nameplateShowSelf" or not write.name:find("Show", 1, true), "no visibility CVar is written by default: " .. write.name)
	end
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end
collectgarbage()

-- Unit types, enemy players and threat against types colour the bar, follow level and faction events, and restore.
do
	local env, K, ns, set = boot({
		nameplate1 = { classification = "worldboss", level = -1 },
		nameplate2 = { classification = "elite", level = 20 },
		nameplate3 = { reaction = 4 },
		nameplate4 = { classification = "minus" },
		nameplate5 = { classification = "normal" },
		nameplate6 = { isPlayer = true, class = "MAGE" },
	})
	local p = {}
	for i = 1, 6 do p[i] = ns.Plates.Get("nameplate" .. i) end
	local before = {}
	for i = 1, 6 do before[i] = { bar(p[i]) } end
	local function is(i, token, what)
		local r, g, b = bar(p[i])
		same({ r, g, b }, { K.Tokens.Color(token) }, what)
	end
	local function restored(i, what)
		local r, g, b = bar(p[i])
		same({ r, g, b }, before[i], what)
	end
	set("types.boss", true)
	is(1, "hostile", "a boss takes the boss colour")
	set("types.bossColor", { r = 0.1, g = 0.2, b = 0.3 })
	same({ bar(p[1]) }, { 0.1, 0.2, 0.3 }, "the boss colour applies")
	set("types.boss", false)
	restored(1, "bosses return to their colour")
	set("types.miniBoss", true)
	is(2, "legendary", "an elite above the player's level is a mini-boss")
	env._units.player.level = 25
	env.FireEvent("PLAYER_LEVEL_UP", 25)
	restored(2, "levelling past the elite clears the mini-boss colour")
	env._units.player.level = 15
	env._units.nameplate2.level = 21
	env.FireEvent("UNIT_LEVEL", "nameplate2")
	is(2, "legendary", "a unit's level change refreshes its type")
	set("types.miniBoss", false)
	restored(2, "mini-bosses return to their colour")
	set("types.neutral", true)
	set("types.neutralColor", { r = 0.9, g = 0.8, b = 0.1 })
	same({ bar(p[3]) }, { 0.9, 0.8, 0.1 }, "neutral mobs take the neutral colour")
	env._units.nameplate3.reaction = 2
	env.FireEvent("UNIT_FACTION", "nameplate3")
	is(3, "plateHostile", "a mob turning hostile loses the neutral colour")
	env._units.nameplate3.reaction = 4
	env.FireEvent("UNIT_FACTION", "nameplate3")
	set("types.neutral", false)
	restored(3, "neutral mobs return to their reaction colour")
	set("types.minor", true)
	is(4, "poor", "minor mobs take the minor colour")
	set("types.minor", false)
	restored(4, "minor mobs return to their colour")
	set("types.normal", true)
	set("types.normalColor", { r = 0.3, g = 0.3, b = 0.9 })
	same({ bar(p[5]) }, { 0.3, 0.3, 0.9 }, "normal mobs take the normal colour")
	same({ bar(p[1]) }, before[1], "bosses are not normal")
	set("types.normal", false)
	restored(5, "normal mobs return to their colour")
	set("enemy.playersUseEnemy", true)
	is(6, "plateHostile", "enemy players take the enemy colour")
	set("enemy.colorSource", "custom")
	set("enemy.color", { r = 0.2, g = 0.7, b = 0.2 })
	same({ bar(p[6]) }, { 0.2, 0.7, 0.2 }, "and the custom enemy colour")
	set("enemy.colorSource", "class")
	set("enemy.playersUseEnemy", false)
	restored(6, "enemy players return to their class colour")

	set("threat.display", "health")
	set("threat.groupOnly", false)
	set("types.boss", true)
	env._units.nameplate1.threat = 3
	env.FireEvent("UNIT_THREAT_LIST_UPDATE", "nameplate1")
	local dr, dg, db = K.ColorVision.Color(2, K.Tokens.Color("hostile"))
	same({ bar(p[1]) }, { dr, dg, db }, "threat beats unit types by default")
	set("threat.overTypes", false)
	same({ bar(p[1]) }, { 0.1, 0.2, 0.3 }, "off, the boss colour stays under threat")
	set("threat.overTypes", true)
	same({ bar(p[1]) }, { dr, dg, db }, "on again, threat wins")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end
collectgarbage()

-- Threat on the name, the safe colour without aggro and the threat percent.
do
	local env, K, ns, set = boot({ nameplate1 = { threat = 2, threatPct = 55 }, nameplate2 = { threat = 0, threatPct = 20 }, nameplate3 = { canAttack = false, threatPct = 40 } })
	local p1, p2, p3 = ns.Plates.Get("nameplate1"), ns.Plates.Get("nameplate2"), ns.Plates.Get("nameplate3")
	set("threat.groupOnly", false)
	local white = { K.Tokens.Color("textEmphasis") }
	same({ p1.name:GetTextColor() }, white, "names stay white by default")
	set("threat.name", true)
	local dr, dg, db = K.ColorVision.Color(2, K.Tokens.Color("hostile"))
	same({ p1.name:GetTextColor() }, { dr, dg, db }, "the name takes the threat colour")
	set("name.colorMode", "custom")
	same({ p1.name:GetTextColor() }, { dr, dg, db }, "threat wins over the name's text colour")
	env._units.nameplate1.threat = nil
	env.FireEvent("UNIT_THREAT_SITUATION_UPDATE", "nameplate1")
	local c = K.Options.Read("Nameplates", "name.color")
	same({ p1.name:GetTextColor() }, { c.r, c.g, c.b }, "losing threat restores the text colour on the event")
	set("name.colorMode", "")
	env._units.nameplate1.threat = 2
	env.FireEvent("UNIT_THREAT_SITUATION_UPDATE", "nameplate1")
	set("threat.name", false)
	same({ p1.name:GetTextColor() }, white, "off restores the name colour")

	assert(p2.threatState == nil, "lower threat shows nothing for damage dealers by default")
	set("threat.calm", true)
	assert(p2.threatState == "safe", "the safe colour shows while the unit attacks someone else")
	set("threat.role", "tank")
	assert(p2.threatState == "danger", "tanks keep their own map")
	set("threat.role", "auto")
	set("threat.calm", false)
	assert(p2.threatState == nil, "off restores the calm plate")

	set("threat.percent", true)
	local text = assert(p1.threatText, "the threat percent builds its text")
	assert(text:IsShown() and revealed(env, text) == "%.0f%%|55", "the percent reads the detailed threat: " .. revealed(env, text))
	same({ text:GetTextColor() }, white, "the percent is white until coloured")
	assert(text:GetPoint(1) == "LEFT", "it sits at the bar's left")
	assert(not (p3.threatText and p3.threatText:IsShown()), "friendly plates show no threat percent")
	set("threat.percentColor", true)
	same({ text:GetTextColor() }, { dr, dg, db }, "colour by threat")
	set("threat.display", "off")
	same({ text:GetTextColor() }, { dr, dg, db }, "the percent and its colour work with the threat display off")
	set("threat.display", "glow")
	set("threat.percentPlace", "RIGHT")
	assert(text:GetPoint(1) == "RIGHT", "the position applies")
	env._units.nameplate1.threatPct = 80
	env.FireEvent("UNIT_THREAT_LIST_UPDATE", "nameplate1")
	assert(revealed(env, text) == "%.0f%%|80", "threat list updates refresh the percent")
	env._units.nameplate1.threatPct = nil
	env.FireEvent("UNIT_THREAT_LIST_UPDATE", "nameplate1")
	assert(not text:IsShown(), "off the threat list, the percent hides")
	env._units.nameplate1.threatPct = 30
	env.FireEvent("UNIT_THREAT_LIST_UPDATE", "nameplate1")
	set("threat.percent", false)
	assert(not text:IsShown(), "off hides the percent")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end
collectgarbage()

-- Level colour: difficulty, custom and back, on level events.
do
	local env, K, ns, set = boot({ nameplate1 = { level = 20 }, nameplate2 = { level = -1 } }, {
		setup = function(env)
			env.GetCreatureDifficultyColor = function(level)
				return level > 17 and { r = 0.9, g = 0.1, b = 0.1 } or { r = 0.25, g = 0.75, b = 0.25 }
			end
		end,
	})
	local p1, p2 = ns.Plates.Get("nameplate1"), ns.Plates.Get("nameplate2")
	same({ p1.levelText:GetTextColor() }, { K.Theme.Brighten(0.9, 0.1, 0.1) }, "a Medallions enemy level reads in its difficulty colour by default")
	set("level.colorMode", "difficulty")
	same({ p1.levelText:GetTextColor() }, { K.Theme.Brighten(0.9, 0.1, 0.1) }, "a hard unit's level reads red")
	env._units.nameplate1.level = 12
	env.FireEvent("UNIT_LEVEL", "nameplate1")
	same({ p1.levelText:GetTextColor() }, { K.Theme.Brighten(0.25, 0.75, 0.25) }, "the level event repaints it")
	same({ p2.levelText:GetTextColor() }, { K.Tokens.Color("hostile") }, "the skull stays hostile")
	set("level.colorMode", "custom")
	set("level.color", { r = 0.4, g = 0.5, b = 0.6 })
	same({ p1.levelText:GetTextColor() }, { 0.4, 0.5, 0.6 }, "a custom level colour")
	set("level.colorMode", "")
	same({ p1.levelText:GetTextColor() }, { K.Theme.Brighten(0.25, 0.75, 0.25) }, "off restores the Medallions difficulty colour")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end
collectgarbage()

-- Cast bar: gap, icon side, layer, name position and target.
do
	local env, K, ns, set = boot({ nameplate1 = { spellTarget = "Thaldrin" } })
	local plate = ns.Plates.Get("nameplate1")
	local _, _, _, _, y0 = plate.cast:GetPoint(1)
	local room0 = ns.Components[1].Room(plate)
	set("cast.offsetY", 6)
	local _, _, _, _, y1 = plate.cast:GetPoint(1)
	assert(y1 < y0, "the gap moves the cast bar down")
	assert(ns.Components[1].Room(plate) > room0, "and the plate's footprint grows with it")
	set("cast.offsetY", 0)
	local _, _, _, _, y2 = plate.cast:GetPoint(1)
	assert(near(y2, y0) and near(ns.Components[1].Room(plate), room0), "zero restores the cast bar")
	set("cast.showIcon", true)
	set("cast.iconRight", true)
	assert(plate.castIcon:GetPoint(1) == "TOPRIGHT" and plate.castBar:GetPoint(1) == "TOPLEFT", "the icon moves right")
	set("cast.iconRight", false)
	assert(plate.castIcon:GetPoint(1) == "TOPLEFT" and plate.castBar:GetPoint(1) == "TOPRIGHT", "and back")
	set("cast.inFront", true)
	assert(plate.castGate:GetFrameLevel() == plate:GetFrameLevel() + 100, "casts draw in front of other plates")
	set("cast.inFront", false)
	assert(plate.castGate:GetFrameLevel() == plate:GetFrameLevel() + 1, "off restores the layer")
	set("cast.nameAlign", "RIGHT")
	assert(plate.castName:GetJustifyH() == "RIGHT" and N.Last(plate.castName, "SetWidth")[1] > 0, "the spell name aligns right across the bar")
	set("cast.nameAlign", "LEFT")
	assert(plate.castName:GetJustifyH() == "LEFT" and N.Last(plate.castName, "SetWidth")[1] == 0, "left restores the free width")
	N.Cast(env, "nameplate1", { name = "Fear", text = "Fear", texture = 136183 })
	assert(revealed(env, plate.castName) == "FEAR", "no target by default: " .. revealed(env, plate.castName))
	set("cast.caster", false)
	set("cast.showTarget", true)
	N.Cast(env, "nameplate1", { name = "Fear", text = "Fear", texture = 136183 })
	assert(revealed(env, plate.castName) == "%s > %s|FEAR|Thaldrin", "the target follows the spell: " .. revealed(env, plate.castName))
	set("cast.enabled", false)
	set("cast.enabled", true)
	set("cast.showTarget", false)
	N.Cast(env, "nameplate1", { name = "Fear", text = "Fear", texture = 136183 })
	assert(revealed(env, plate.castName) == "FEAR", "off drops the target")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end
collectgarbage()

-- Game plate visibility: written under management, out of combat, and handed back.
do
	local env, K, _, set = boot({})
	local function cvar(name) return env._cvars[name] end
	set("cvars.showEnemies", "hide")
	assert(cvar("nameplateShowEnemies") == "1", "nothing changes while management is off")
	set("cvars.enabled", true)
	assert(cvar("nameplateShowEnemies") == "0", "management hides enemy plates")
	set("cvars.friendlyNameOnly", "show")
	assert(cvar("nameplateShowOnlyNameForFriendlyPlayerUnits") == "1", "friendly players show names only")
	env._combat = true
	env.FireEvent("PLAYER_REGEN_DISABLED")
	set("cvars.friendlyNpcs", "show")
	assert(cvar("nameplateShowFriendlyNpcs") == "0", "combat queues the write")
	env._combat = false
	env.FireEvent("PLAYER_REGEN_ENABLED")
	env.RunTimers()
	assert(cvar("nameplateShowFriendlyNpcs") == "1", "and it lands after combat")
	set("cvars.showEnemies", "game")
	assert(cvar("nameplateShowEnemies") == "1", "the game's setting hands the player's value back")
	set("cvars.enabled", false)
	assert(cvar("nameplateShowOnlyNameForFriendlyPlayerUnits") == "0" and cvar("nameplateShowFriendlyNpcs") == "0", "management off restores every value")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end
collectgarbage()

-- Target and focus marks: friendly targets, the health line and the focus letter follow target and focus changes.
do
	local env, K, ns, set = boot({ nameplate1 = {}, nameplate2 = { canAttack = false, reaction = 5 } })
	local enemy, friend = ns.Plates.Get("nameplate1"), ns.Plates.Get("nameplate2")
	N.Target(env, "nameplate2")
	assert(friend.brackets:IsShown(), "friendly targets are highlighted by default")
	set("target.friendly", false)
	assert(not friend.brackets:IsShown(), "off skips friendly targets")
	N.Target(env, "nameplate1")
	assert(enemy.brackets:IsShown(), "enemy targets keep the highlight")
	set("target.friendly", true)
	set("target.hashLine", true)
	local line = assert(enemy.hashLine, "the health line builds its texture")
	assert(line:IsShown() and not (friend.hashLine and friend.hashLine:IsShown()), "only the target shows the line")
	local _, _, _, x = line:GetPoint(1)
	assert(near(x, K.Widgets.Snap(enemy, enemy.barW * 0.3)), "at 30 percent of the bar")
	set("target.hashPercent", 50)
	_, _, _, x = line:GetPoint(1)
	assert(near(x, K.Widgets.Snap(enemy, enemy.barW * 0.5)), "the percent applies")
	N.Target(env, "nameplate2")
	assert(not line:IsShown() and friend.hashLine:IsShown(), "the line follows the target")
	set("target.hashLine", false)
	assert(not friend.hashLine:IsShown(), "off hides the line")

	set("focus.letter", "CENTER")
	local letter = assert(enemy.focusLetter, "the focus letter builds its text")
	assert(not letter:IsShown(), "no focus, no letter")
	N.Focus(env, "nameplate1")
	assert(letter:IsShown() and revealed(env, letter) == "F", "the focus shows F")
	set("focus.letterX", 7)
	set("focus.letterY", -3)
	local point, _, _, lx, ly = letter:GetPoint(1)
	assert(point == "CENTER" and near(lx, K.Widgets.Snap(enemy.health, 7)) and near(ly, K.Widgets.Snap(enemy.health, -3)), "offsets apply")
	N.Focus(env, "nameplate2")
	assert(not letter:IsShown() and friend.focusLetter:IsShown(), "the letter follows the focus")
	set("focus.letter", "")
	assert(not friend.focusLetter:IsShown(), "off hides the letter")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end
collectgarbage()

-- Names: AFK and DND tags, the raid marker by the name and the PvP badge follow their events.
do
	local env, K, ns, set = boot({
		nameplate1 = { isPlayer = true, canAttack = false, reaction = 5, afk = true, raid = 4, pvp = true, faction = "Horde" },
		nameplate2 = { pvp = true, faction = "Horde" },
		nameplate3 = { isPlayer = true, secretName = true, dnd = true },
	})
	local p1, p2, p3 = ns.Plates.Get("nameplate1"), ns.Plates.Get("nameplate2"), ns.Plates.Get("nameplate3")
	set("name.afk", true)
	assert(revealed(env, p1.name) == "KOBOLD MINER <AFK>", "away players carry <AFK>: " .. revealed(env, p1.name))
	env._units.nameplate1.afk = false
	env.FireEvent("PLAYER_FLAGS_CHANGED", "nameplate1")
	assert(revealed(env, p1.name) == "KOBOLD MINER", "coming back drops the tag")
	set("name.dnd", true)
	assert(revealed(env, p3.name) == "%s <%s>|Kobold Miner|DND", "secret names keep the tag through the engine: " .. revealed(env, p3.name))
	set("name.dnd", false)
	assert(revealed(env, p3.name) == "Kobold Miner", "off drops it")

	set("markers.nameRaid", true)
	local icon = assert(p1.nameRaid, "the name marker builds its texture")
	assert(icon:IsShown() and icon:GetPoint(1) == "RIGHT", "it sits before the name")
	assert(not (p2.nameRaid and p2.nameRaid:IsShown()), "unmarked units show none")
	env._units.nameplate1.raid = nil
	env.FireEvent("RAID_TARGET_UPDATE")
	assert(not icon:IsShown(), "clearing the marker hides it")
	env._units.nameplate1.raid = 4
	env.FireEvent("RAID_TARGET_UPDATE")
	set("name.show", false)
	assert(not icon:IsShown(), "hidden names hide their marker")
	set("name.show", true)
	set("cast.hideUnitName", true)
	N.Cast(env, "nameplate1", { name = "Fear", text = "Fear", texture = 136183 })
	assert(icon:GetAlpha() == 0, "the marker hides with the name while casting")
	env._units.nameplate1.cast = nil
	env.FireEvent("UNIT_SPELLCAST_STOP", "nameplate1")
	assert(icon:GetAlpha() == 1, "and returns with it")
	set("markers.nameRaid", false)
	assert(not icon:IsShown(), "off hides the name marker")

	set("markers.pvp", true)
	local badge = assert(p1.pvpBadge, "the PvP flag builds its badge")
	assert(badge:IsShown() and badge:GetAtlas() == "UI-HUD-UnitFrame-SmallCircle-Horde", "flagged players show their faction")
	assert(not (p2.pvpBadge and p2.pvpBadge:IsShown()), "flagged NPCs show none by default")
	set("markers.pvpPlayersOnly", false)
	assert(p2.pvpBadge:IsShown(), "unless players only is off")
	env._units.nameplate1.faction = "Alliance"
	env.FireEvent("UNIT_FACTION", "nameplate1")
	assert(badge:GetAtlas() == "UI-HUD-UnitFrame-SmallCircle-Alliance", "faction events repaint the badge")
	set("markers.pvpEnemyOnly", true)
	assert(not badge:IsShown(), "the player's own faction is hidden for opposite faction only")
	set("markers.pvpEnemyOnly", false)
	env._units.nameplate1.pvp = false
	env.FireEvent("UNIT_FACTION", "nameplate1")
	assert(not badge:IsShown(), "losing the flag hides the badge")
	set("markers.pvp", false)
	assert(not p2.pvpBadge:IsShown(), "off hides every badge")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end
collectgarbage()

-- Review of 6795e26b: the size and visibility rows apply, the threat percent and health text share the right edge, tags survive
-- name formats, enemy players keep a class name, cast width restores, the player's faction repaints badges, casting keeps its
-- colour under threat, and events skip work their options do not need.
do
	local env, K, ns, set = boot({
		nameplate1 = { isPlayer = true, class = "MAGE", afk = true, threat = 2, threatPct = 55, pvp = true, faction = "Horde" },
		nameplate2 = { threat = 2 },
	})
	local plate, mob = ns.Plates.Get("nameplate1"), ns.Plates.Get("nameplate2")
	set("focus.letter", "RIGHT")
	local _, small = plate.focusLetter:GetFont()
	set("focus.letterSize", 20)
	local _, large = plate.focusLetter:GetFont()
	assert(near(large / small, 20 / 12), "the focus letter size applies")
	set("markers.nameRaid", true)
	local w = env.Reveal(plate.nameRaid:GetWidth())
	set("markers.nameRaidSize", 28)
	assert(env.Reveal(plate.nameRaid:GetWidth()) > w, "the name raid marker size applies")
	set("cvars.enabled", true)
	set("cvars.showFriends", "hide")
	set("cvars.enemyMinions", "hide")
	set("cvars.friendlyMinions", "show")
	assert(env._cvars.nameplateShowFriendlyPlayers == "0" and env._cvars.nameplateShowEnemyMinions == "0"
		and env._cvars.nameplateShowFriendlyPlayerMinions == "1", "the friendly, enemy minion and friendly minion rows write their CVars")
	set("cvars.enabled", false)
	assert(env._cvars.nameplateShowFriendlyPlayers == "1" and env._cvars.nameplateShowEnemyMinions == "1"
		and env._cvars.nameplateShowFriendlyPlayerMinions == "0", "and management off hands them back")

	set("name.afk", true)
	set("name.textFormat", "[name]")
	assert(revealed(env, plate.name):find("<AFK>", 1, true), "a name format keeps the AFK tag: " .. revealed(env, plate.name))
	set("name.textFormat", "")
	set("name.classColor", true)
	set("enemy.playersUseEnemy", true)
	same({ plate.name:GetTextColor() }, { K.Theme.ClassTextColorForWidget("MAGE") }, "an enemy player on the enemy bar colour keeps a class-coloured name")
	set("threat.groupOnly", false)
	set("threat.percent", true)
	set("threat.percentPlace", "RIGHT")
	set("healthText.show", true)
	local _, rel = plate.threatText:GetPoint(1)
	assert(rel == plate.healthText, "the threat percent sits beside the health text, not on it")
	set("cast.nameAlign", "RIGHT")
	set("cast.nameBelow", false)
	set("cast.nameAlign", "LEFT")
	set("cast.nameBelow", true)
	assert(N.Last(plate.castName, "SetWidth")[1] == 0, "left alignment below the bar restores the free width")

	local calls, query = 0, env.UnitThreatSituation
	env.UnitThreatSituation = function(...) calls = calls + 1; return query(...) end
	env.FireEvent("UNIT_THREAT_LIST_UPDATE", "nameplate1")
	env.UnitThreatSituation = query
	assert(calls == 1, "an uncoloured threat percent adds no threat query: " .. calls)
	local hides = #N.Calls(plate.threatText, "Hide")
	env._units.nameplate1.threatPct = nil
	for _ = 1, 4 do env.FireEvent("UNIT_THREAT_LIST_UPDATE", "nameplate1") end
	assert(#N.Calls(plate.threatText, "Hide") - hides == 1, "a hidden threat percent is not hidden again")
	set("name.afk", false)
	local writes = #plate.name._calls
	env.FireEvent("PLAYER_FLAGS_CHANGED", "nameplate1")
	assert(#plate.name._calls == writes, "flag changes leave the name alone with both tags off")

	set("markers.pvp", true)
	set("markers.pvpEnemyOnly", true)
	assert(plate.pvpBadge:IsShown(), "a Horde player shows to an Alliance player")
	local faction = env.UnitFactionGroup
	env.UnitFactionGroup = function(token) if token == "player" then return "Horde", "Horde" end return faction(token) end
	env.FireEvent("UNIT_FACTION", "player")
	assert(not plate.pvpBadge:IsShown(), "the player's own faction change repaints opposite-faction badges")

	set("threat.display", "health")
	set("types.casting", true)
	set("types.castingColor", { r = 0.1, g = 0.2, b = 0.3 })
	set("threat.overTypes", false)
	N.Cast(env, "nameplate2", { name = "Fear", text = "Fear", texture = 136183 })
	same({ bar(mob) }, { 0.1, 0.2, 0.3 }, "with threat beating types off, casting keeps its colour under threat")
	set("threat.overTypes", true)
	local count, classify = 0, env.UnitClassification
	env.UnitClassification = function(...) count = count + 1; return classify(...) end
	env._units.nameplate2.threat = 1
	env.FireEvent("UNIT_THREAT_LIST_UPDATE", "nameplate2")
	env.UnitClassification = classify
	assert(count == 0, "threat that always wins skips the unit type lookup")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end
collectgarbage()

-- The Options preview, at its own size, shows each option on the sample plate it actually draws.
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
	local function on(key, value, field, text)
		set(key, value)
		preview.Refresh()
		local plate = preview.plates[preview.chosen]
		assert(seen(plate[field]), key .. " shows on the drawn sample")
		assert(not text or revealed(env, plate[field]):find(text, 1, true), key .. ": " .. revealed(env, plate[field]))
		set(key, NEW[key])
	end
	preview.Refresh()
	assert(preview.chosen == 1, "the preview draws the first sample by default")
	on("threat.percent", true, "threatText")
	set("cast.caster", false)
	on("cast.showTarget", true, "castName", "Thaldrin")
	set("cast.caster", true)
	on("focus.letter", "RIGHT", "focusLetter")
	on("target.hashLine", true, "hashLine")
	on("markers.nameRaid", true, "nameRaid")
	on("markers.pvp", true, "pvpBadge")
	on("name.afk", true, "name", "<AFK>")
	on("name.dnd", true, "name", "<DND>")
	for _, key in ipairs({ "enemy.playersUseEnemy", "threat.name", "threat.percentColor" }) do
		set(key, true)
		preview.Refresh()
		local sample = preview.plates[preview.chosen].sample
		assert(sample.isPlayer and sample.enemy and sample.threat, key .. " draws the enemy player under threat")
		set(key, NEW[key])
	end
	preview.Refresh()
	assert(preview.chosen == 1, "and returns to it")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end
collectgarbage()

-- Every option on at once raises nothing at four screen sizes, the live preview included.
local ALL_ON = {
	["types.boss"] = true, ["types.miniBoss"] = true, ["types.neutral"] = true, ["types.minor"] = true, ["types.normal"] = true,
	["enemy.playersUseEnemy"] = true, ["name.afk"] = true, ["name.dnd"] = true, ["level.colorMode"] = "difficulty",
	["cast.showIcon"] = true, ["cast.iconRight"] = true, ["cast.offsetY"] = 4, ["cast.inFront"] = true, ["cast.nameAlign"] = "CENTER",
	["cast.showTarget"] = true, ["threat.name"] = true, ["threat.calm"] = true, ["threat.overTypes"] = false, ["threat.percent"] = true,
	["threat.percentColor"] = true, ["target.friendly"] = false, ["target.hashLine"] = true, ["focus.letter"] = "RIGHT",
	["markers.nameRaid"] = true, ["markers.pvp"] = true, ["markers.pvpPlayersOnly"] = false,
}
for _, size in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	local own = {}
	for key, value in pairs(ALL_ON) do
		local first, last = key:match("^(%w+)%.(%w+)$")
		own[first] = own[first] or {}
		own[first][last] = value
	end
	local env, K, ns = boot({ nameplate1 = { isPlayer = true, pvp = true, raid = 2, threat = 3, threatPct = 100, spellTarget = "Thaldrin" } },
		{ saved = saved(own), width = size[1], height = size[2] })
	N.Focus(env, "nameplate1")
	N.Cast(env, "nameplate1", { name = "Fear", text = "Fear", texture = 136183 })
	ns.Preview.Build(env.UIParent).Refresh()
	assert(#env._errors == 0 and K.ErrorCount() == 0, size[1] .. "x" .. size[2] .. ": " .. tostring(env._errors[1]))
	collectgarbage()
end
print("nameplates parity round 1 ok: defaults, unit types, threat, level colour, casts, visibility, target, focus, names and markers")
