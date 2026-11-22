-- Settings.lua: the nameplates' defaults, settings page and checked, cached reads of each setting.
local _, ns = ...

local K = KstyleUI
local Tokens, L = K.Tokens, K.L

local Settings = {}
ns.Settings = Settings

local MODULE = "Nameplates"
Settings.MODULE = MODULE

local function Color(name)
	local r, g, b = Tokens.Color(name)
	return { r = r, g = g, b = b }
end

local BAR_TEXTURE = Tokens.Texture("barFlat")

local function ExtraText()
	return { font = "", size = 12, outline = "OUTLINE", colorMode = "", color = Color("textEmphasis"),
		textFormat = "", position = "CENTER", x = 0, y = 0 }
end

Settings.defaults = {
	preset = "lumen",
	extra1 = ExtraText(), extra2 = ExtraText(),
	personalResource = false,
	offsetY = 0,
	shrinkDistant = false,
	font = "",
	health = { width = 156.75, height = Tokens.Size("barHeight"), texture = BAR_TEXTURE, orientation = "HORIZONTAL", reverse = false,
		border = true, absorbs = false, absorbAlpha = 0.35, absorbPlace = "after", execute = false, executePercent = 30 },
	range = { fade = false, alpha = 0.5, spell = "" },
	enemy = { colorSource = "class", color = Color("plateHostile"), playersUseEnemy = false },
	friendly = { colorSource = "class", color = Color("friendly"), nameOnly = false,
		nameMode = "", nameColor = Color("friendly"), playerFormat = "", title = false, guild = "", guildSize = 12, guildMatch = true, guildColor = Color("text"),
		npcFormat = "", npcSize = 0, npcNameMode = "", npcColor = Color("friendly"),
		npcTitle = false, npcTitleSize = 12, npcTitleMatch = true, npcTitleColor = Color("text"),
		petSize = 0, owner = false, ownerOwnSize = false, ownerSize = 12, ownerMatch = true, ownerColor = Color("text") },
	types = {
		quest = false, questColor = Color("quest"), rare = false, rareColor = Color("rare"),
		elite = false, eliteColor = Color("neutral"), caster = false, casterColor = Color("epic"),
		casting = false, castingColor = Color("gilt"),
		boss = false, bossColor = Color("hostile"), miniBoss = false, miniBossColor = Color("legendary"),
		neutral = false, neutralColor = Color("neutral"), minor = false, minorColor = Color("poor"),
		normal = false, normalColor = Color("plateHostile"),
	},
	name = { show = true, size = 11, outline = "OUTLINE", upper = true, classColor = false, afk = false, dnd = false, font = "", colorMode = "", color = Color("textEmphasis"), textFormat = "" },
	level = { show = true, size = 12, outline = "OUTLINE", font = "", colorMode = "", color = Color("giltLit"), x = 0, y = 0, diamond = 1 },
	healthText = { show = false, size = 13, outline = "OUTLINE", format = "percent", font = "", colorMode = "", color = Color("textEmphasis"), textFormat = "" },
	cast = {
		enabled = true, outcomes = true, combatCues = true, shieldBadge = true, height = 6, texture = BAR_TEXTURE, orientation = "HORIZONTAL", reverse = false,
		colorSource = "custom", color = Color("gilt"), shieldColor = Color("steelDim"),
		waitColor = Color("giltDim"), interruptSpell = "", hideOnTarget = false,
		showIcon = false, iconRight = false, offsetY = 0, inFront = false, showTarget = false, nameAlign = "LEFT", spark = false, hideUnitName = false, fullOpacity = false, showName = true, nameSelectedOnly = true, nameBelow = true, showTime = false, textSize = 11, outline = "OUTLINE",
		iconScale = 1, iconFull = false, iconX = 0, iconY = 0, offsetX = 0, border = true, important = false, importantGlow = false, importantColor = Color("legendary"), importantKick = false, scale = 1,
		bgAlpha = 1, targetPlace = "", targetGlow = false, targetGlowColor = Color("hostile"),
	},
	buffs = { enabled = false, filter = "important", place = "RIGHT", count = 3, showTime = true, dispelGlow = false },
	ccs = { enabled = false, place = "LEFT", count = 2, showTime = true, first = false },
	debuffs = {
		enabled = true, onlyMine = true, dispellable = false, allowSpells = "", blockSpells = "", includePlateOnly = true, size = 22, spacing = 2, columns = 5, rows = 1, order = "important",
		growthX = "LEFT", growthY = "UP", showTime = true, showCount = true, textSize = 11, outline = "OUTLINE", readableText = true, expiring = 5,
		timePlace = "BELOW", timeX = 0, timeY = 0, countPlace = "TOPRIGHT", countX = 0, countY = 0,
		border = true, cropped = false, crop = 10, raise = false, dispelColor = false, pandemic = false, tooltips = false,
		nameGap = Tokens.Size("gapMedium"), sunder = false,
	},
	threat = {
		display = "glow", keyline = true, shapes = true, role = "auto", groupOnly = true, name = false, calm = false, overTypes = true,
		percent = false, percentPlace = "LEFT", percentColor = false,
		overBoss = true, overMiniBoss = true, overCaster = true, tankOverBoss = true, tankOverOthers = true,
		safe = Color("friendly"), warning = Color("neutral"), danger = Color("hostile"),
	},
	target = { readableTicks = true, smoothOpacity = true, highlight = true, friendly = true, colorSource = "custom", color = Color("giltLit"), dimOthers = 1, hashLine = false, hashPercent = 30,
		glow = false, glowAlpha = 0.9, fill = false, fillColor = Color("white"), fillAlpha = 0.2, scale = 1, fillOwn = false, hover = false,
		distance = false, distanceSize = 12, distanceX = 0, distanceY = 0 },
	focus = { fullOpacity = false, highlight = true, color = Color("rare"), letter = "", letterSize = 12, letterX = 0, letterY = 0,
		fill = false, fillColor = Color("white"), fillAlpha = 0.2, castHeight = 1 },
	markers = { classification = true, raid = true, raidSize = 16, nameRaid = false, nameRaidSize = 14, pvp = false, pvpEnemyOnly = false, pvpPlayersOnly = true, instances = true,
		questText = false, questSize = 12, questIcon = false, questIconScale = 1 },
	resource = { show = false, colorSource = "class", color = Color("gilt"), place = "BOTTOM", scale = 1, spacing = 2,
		energy = false, energyHeight = 3, energyPlace = "BELOW", energyWidth = 1, energyHideFull = false },
	stacking = { footprint = "plate", spacing = 1, clickWidth = 1, clickHeight = 1, friendlyClicks = true },
	cvars = {
		enabled = false, maxDistance = 40, verticalDistance = 0, stacking = "enemy",
		selectedScale = 1.2, minScale = 0.8, clickSize = 2,
		showEnemies = "game", showFriends = "game", enemyMinions = "game", friendlyMinions = "game", friendlyNpcs = "game", friendlyNameOnly = "game",
		lineOfSight = false, lineOfSightAlpha = 0.4,
	},
}

local rows

function Settings.Schema()
	if Settings.schema then return Settings.schema end
	local OUTLINES = {
		{ value = "NONE", label = L["None, soft shadow"] },
		{ value = "OUTLINE", label = L["Thin outline"] },
		{ value = "THICKOUTLINE", label = L["Thick outline"] },
	}
	local COLOR_SOURCES = {
		{ value = "class", label = L["Class colour for players"] },
		{ value = "reaction", label = L["Reaction colour"] },
		{ value = "custom", label = L["Custom colour"] },
	}
	local ACCENT_SOURCES = {
		{ value = "class", label = L["Accent (class colour)"] },
		{ value = "custom", label = L["Custom colour"] },
	}
	local ORIENTATIONS = {
		{ value = "HORIZONTAL", label = L["Horizontal"] },
		{ value = "VERTICAL", label = L["Vertical"] },
	}
	local HEALTH_FORMATS = {
		{ value = "percent", label = L["Percent"] },
		{ value = "value", label = L["Value"] },
		{ value = "both", label = L["Value and percent"] },
	}
	local THREAT_DISPLAYS = {
		{ value = "glow", label = L["Glow around the plate"] },
		{ value = "health", label = L["Health bar colour"] },
		{ value = "healthEdge", label = L["Health bar colour and edge"] },
		{ value = "name", label = L["The name only"] },
		{ value = "off", label = L["Off"] },
	}
	local THREAT_ROLES = {
		{ value = "auto", label = L["From my group role"] },
		{ value = "tank", label = L["Tank: I want aggro"] },
		{ value = "other", label = L["Damage or healing: I avoid aggro"] },
	}
	local GROWTH_X = {
		{ value = "RIGHT", label = L["Right"] },
		{ value = "LEFT", label = L["Left"] },
	}
	local GROWTH_Y = {
		{ value = "UP", label = L["Up, above the name"] },
		{ value = "DOWN", label = L["Down, under the cast bar"] },
	}
	local STACKING = {
		{ value = "none", label = L["Overlap"] },
		{ value = "enemy", label = L["Stack enemy plates"] },
		{ value = "all", label = L["Stack all plates"] },
	}
	local ORDERS = {
		{ value = "important", label = L["Important first"] },
		{ value = "longest", label = L["Most time left first"] },
		{ value = "expiring", label = L["Soonest to fade first"] },
		{ value = "default", label = L["The game's order"] },
	}
	local GAME_CHOICES = {
		{ value = "game", label = L["The game's setting"] },
		{ value = "show", label = L["On"] },
		{ value = "hide", label = L["Off"] },
	}
	local INSIDE = {
		{ value = "LEFT", label = L["Left"] },
		{ value = "CENTER", label = L["Centre"] },
		{ value = "RIGHT", label = L["Right"] },
	}
	local FOCUS_LETTER = { { value = "", label = L["Off"] }, INSIDE[1], INSIDE[2], INSIDE[3] }
	local LEVEL_COLORS = {
		{ value = "", label = L["Current style"] },
		{ value = "difficulty", label = L["Level difficulty colour"] },
		{ value = "custom", label = L["Custom colour"] },
	}
	local TIME_PLACES = {
		{ value = "BELOW", label = L["Under the icon"] }, { value = "CENTER", label = L["Centre"] },
		{ value = "TOP", label = L["Top"] }, { value = "BOTTOM", label = L["Bottom"] },
	}
	local COUNT_PLACES = {
		{ value = "TOPRIGHT", label = L["Top right"] }, { value = "TOPLEFT", label = L["Top left"] }, { value = "BOTTOMRIGHT", label = L["Bottom right"] },
		{ value = "BOTTOMLEFT", label = L["Bottom left"] }, { value = "CENTER", label = L["Centre"] },
	}
	local BUFF_FILTERS = {
		{ value = "important", label = L["Important"] }, { value = "dispellable", label = L["Only dispellable"] }, { value = "all", label = L["All buffs"] },
	}
	local PLACES = {
		{ value = "LEFT", label = L["Left of the bar"] }, { value = "RIGHT", label = L["Right of the bar"] }, { value = "TOP", label = L["Above the name"] },
		{ value = "TOPLEFT", label = L["Above the name, left"] }, { value = "TOPRIGHT", label = L["Above the name, right"] }, { value = "BOTTOM", label = L["Under the cast bar"] },
	}
	local FOOTPRINTS = {
		{ value = "plate", label = L["KstyleUI's plate"] },
		{ value = "game", label = L["The game's own size"] },
	}

	local TEXT_MIN, TEXT_MAX = 6, 20

	local function Is(key, value)
		return function(s)
			local node = s
			for part in key:gmatch("[^%.]+") do
				node = type(node) == "table" and node[part] or nil
			end
			return node == value
		end
	end

	local function Off(key, value)
		local on = Is(key, value == nil or value)
		return function(s)
			return not on(s)
		end
	end

	local function None(...)
		local tests = { ... }
		return function(s)
			for _, on in ipairs(tests) do
				if on(s) then return false end
			end
			return true
		end
	end
	local targetTint = None(Is("target.highlight", true), Is("target.glow", true))
	local function Either(a, b)
		return function(s) return a(s) or b(s) end
	end

	local function HasCVar(name)
		return function()
			local cvars = ns.CVars
			return not (cvars and type(cvars.Exists) == "function") or cvars.Exists(name)
		end
	end

	local function SharedTextRows(schema, key, label)
		schema[#schema + 1] = { type = "header", label = label }
		schema[#schema + 1] = { type = "toggle", key = key .. ".show", label = L["Show"], help = L["Shows this text on every plate."] }
		K.Widgets.TextRows(schema, key, { max = TEXT_MAX, outlines = OUTLINES, tags = key ~= "level",
			disableWhen = Off(key .. ".show"), custom = Is(key .. ".colorMode", "custom") })
	end

	local schema = {
		{ type = "header", label = L["Preset"] },
		{
			type = "dropdown", key = "preset", label = L["Preset"],
			help = L["Applies a whole set of plate settings. Changing a setting by hand makes it Custom."],
			options = function()
				return ns.Presets.LIST
			end,
		},
		{ type = "header", label = L["Plates"] },
		{
			type = "toggle", key = "personalResource", label = L["Personal resource display"],
			help = L["Changes Blizzard's bars near your character out of combat. Later Blizzard setting changes are kept."],
			showWhen = HasCVar("nameplateShowSelf"),
		},
		{
			type = "slider", key = "offsetY", label = L["Height above the unit"],
			help = L["Moves every plate up or down from where the game places it."],
			min = -40, max = 40, step = 1,
		},
		{
			type = "toggle", key = "shrinkDistant", label = L["Shrink distant plates"],
			help = L["Plates shrink with distance and grow on your target, as the game's own do."],
		},
		{ type = "toggle", key = "range.fade", label = L["Fade out of range"], help = L["Fades enemy plates your range spell cannot reach."] },
		{ type = "slider", key = "range.alpha", label = L["Out of range opacity"], help = L["How visible enemy plates out of range are."], min = 0.1, max = 1, step = 0.05, disableWhen = Off("range.fade") },
		{ type = "text", key = "range.spell", label = L["Range spell"], help = L["The spell whose range is checked. Blank uses your interrupt."], maxLetters = 40, disableWhen = Off("range.fade") },
		{
			type = "font", key = "font", label = L["Font"],
			options = K.Widgets.InheritedFontOptions,
			help = L["The font of plate values, debuff timers and optional cast text. Names use the kit's Cinzel heading."],
		},
		{ type = "header", label = L["Health bar"] },
		{
			type = "slider", key = "health.width", label = L["Width"],
			help = L["The width of the health bar, in interface units."], min = 80, max = 240, step = 1,
		},
	}
	K.Widgets.BarRows(schema, "health", { colors = false, height = { 6, 24, 1 } })
	local function append(list)
		for _, row in ipairs(list) do schema[#schema + 1] = row end
	end
	append({
		{
			type = "dropdown", key = "health.orientation", label = L["Orientation"],
			help = L["Fills the health bar across or upward."],
			options = ORIENTATIONS,
		},
		{
			type = "toggle", key = "health.reverse", label = L["Reverse fill"],
			help = L["Fills the bar from the other end."],
		},
		{ type = "toggle", key = "health.border", label = L["Health bar border"], help = L["Frames the health bar with its dark edge. Off drops it; threat and focus edges still show."] },
		{ type = "toggle", key = "health.absorbs", label = L["Absorb shields"], help = L["Shows absorb shields on the health bar, as the unit frames do."] },
		{ type = "slider", key = "health.absorbAlpha", label = L["Absorb opacity"], help = L["How solid absorb shields look on the health bar."], min = 0.1, max = 1, step = 0.05, disableWhen = Off("health.absorbs") },
		{ type = "dropdown", key = "health.absorbPlace", label = L["Absorb placement"], help = L["Where the shield is drawn on the health bar."], disableWhen = Off("health.absorbs"), options = {
			{ value = "after", label = L["After the health"] }, { value = "back", label = L["Back over the health"] },
			{ value = "far", label = L["From the far end"] }, { value = "near", label = L["From the near end"] } } },
		{ type = "toggle", key = "health.execute", label = L["Execute glow"], help = L["Pulses a red glow around enemies below the execute health percent."] },
		{ type = "slider", key = "health.executePercent", label = L["Execute health percent"], help = L["Enemies below this health percent glow."], min = 5, max = 50, step = 1, disableWhen = Off("health.execute") },
		{ type = "header", label = L["Enemy plates"] },
	})
	K.Widgets.BarRows(schema, "enemy", { texture = false, options = COLOR_SOURCES, custom = Is("enemy.colorSource", "custom") })
	schema[#schema + 1] = { type = "toggle", key = "enemy.playersUseEnemy", label = L["Enemy players use the enemy colour"],
		help = L["Enemy players take the enemy bar colour instead of their class colour."] }
	append({
		{ type = "header", label = L["Friendly plates"] },
	})
	K.Widgets.BarRows(schema, "friendly", { texture = false, options = COLOR_SOURCES, custom = Is("friendly.colorSource", "custom") })
	append({
		{
			type = "toggle", key = "friendly.nameOnly", label = L["Name only"],
			help = L["Friendly plates show just the name, without a health bar."],
		},
		{ type = "dropdown", key = "friendly.nameMode", label = L["Player name colour"], help = L["Colours friendly players' names. The current style keeps the name's own colour."], options = K.Widgets.TextColors() },
		{ type = "color", key = "friendly.nameColor", label = L["Custom player name colour"], help = L["The name colour when its colour mode is custom."], showWhen = Is("friendly.nameMode", "custom") },
		{ type = "text", key = "friendly.playerFormat", label = L["Player name format"], help = L["A format for friendly players' names, with the name tags. Blank uses the name's format."], maxLetters = 160 },
		{ type = "toggle", key = "friendly.title", label = L["Player titles"], help = L["Writes friendly players' names with their title."] },
		{ type = "dropdown", key = "friendly.guild", label = L["Guild under the name"], help = L["Shows a friendly player's guild on a line under the name."], options = {
			{ value = "", label = L["Off"] }, { value = "plain", label = L["Guild name"] }, { value = "brackets", label = L["<Guild name>"] } } },
		{ type = "slider", key = "friendly.guildSize", label = L["Guild text size"], help = L["The size of the guild line, in interface units."], min = TEXT_MIN, max = TEXT_MAX, step = 1, disableWhen = Is("friendly.guild", "") },
		{ type = "toggle", key = "friendly.guildMatch", label = L["Guild in the name colour"], help = L["Colours the guild like the player's name. Off uses the guild colour."], disableWhen = Is("friendly.guild", "") },
		{ type = "color", key = "friendly.guildColor", label = L["Guild colour"], help = L["The guild line's colour."], disableWhen = Either(Is("friendly.guild", ""), Is("friendly.guildMatch", true)) },
		{ type = "text", key = "friendly.npcFormat", label = L["NPC name format"], help = L["A format for friendly NPCs' names, with the name tags. Blank uses the name's format."], maxLetters = 160 },
		{ type = "slider", key = "friendly.npcSize", label = L["NPC name size"], help = L["The size of friendly NPCs' names. 0 uses the name size."], min = 0, max = TEXT_MAX, step = 1 },
		{ type = "dropdown", key = "friendly.npcNameMode", label = L["NPC name colour"], help = L["Colours friendly NPCs' names. The current style keeps the name's own colour."], options = K.Widgets.TextColors() },
		{ type = "color", key = "friendly.npcColor", label = L["Custom NPC name colour"], help = L["The name colour when its colour mode is custom."], showWhen = Is("friendly.npcNameMode", "custom") },
		{ type = "toggle", key = "friendly.npcTitle", label = L["NPC titles"], help = L["Shows a friendly NPC's title, such as Innkeeper, on a line under its name."], disableWhen = Off("name.show") },
		{ type = "slider", key = "friendly.npcTitleSize", label = L["NPC title size"], help = L["The size of this text, in interface units."], min = TEXT_MIN, max = TEXT_MAX, step = 1, disableWhen = Off("friendly.npcTitle") },
		{ type = "toggle", key = "friendly.npcTitleMatch", label = L["Title in the NPC name colour"], help = L["Colours the title like the NPC's name. Off uses the title colour."], disableWhen = Off("friendly.npcTitle") },
		{ type = "color", key = "friendly.npcTitleColor", label = L["NPC title colour"], help = L["The title line's colour."], disableWhen = Either(Off("friendly.npcTitle"), Is("friendly.npcTitleMatch", true)) },
		{ type = "slider", key = "friendly.petSize", label = L["Pet name size"], help = L["The size of friendly pets' and minions' names. 0 uses the name size."], min = 0, max = TEXT_MAX, step = 1 },
		{ type = "toggle", key = "friendly.owner", label = L["Owner under pet names"], help = L["Shows whose pet or minion it is on a line under a friendly pet's name."] },
		{ type = "toggle", key = "friendly.ownerOwnSize", label = L["Owner text uses its own size"], help = L["Off, the owner line takes the pet name's size."], disableWhen = Off("friendly.owner") },
		{ type = "slider", key = "friendly.ownerSize", label = L["Owner text size"], help = L["The size of the owner line, in interface units."], min = TEXT_MIN, max = TEXT_MAX, step = 1, disableWhen = Either(Off("friendly.owner"), Off("friendly.ownerOwnSize")) },
		{ type = "toggle", key = "friendly.ownerMatch", label = L["Owner in the pet name colour"], help = L["Colours the owner line like the pet's name. Off uses the owner colour."], disableWhen = Off("friendly.owner") },
		{ type = "color", key = "friendly.ownerColor", label = L["Owner colour"], help = L["The owner line's colour."], disableWhen = Either(Off("friendly.owner"), Is("friendly.ownerMatch", true)) },
		{ type = "header", label = L["Unit types"] },
	})
	for _, t in ipairs({
		{ "quest", L["Quest mobs"], L["Quest colour"], L["Colours the plates of mobs one of your quests needs. Wins over the other types."], L["The bar colour of quest mobs."] },
		{ "rare", L["Rares"], L["Rare colour"], L["Colours the plates of rare and rare elite mobs."], L["The bar colour of rares."] },
		{ "elite", L["Elites"], L["Elite colour"], L["Colours the plates of elites and bosses. Off, the gold diamond alone marks them."], L["The bar colour of elites."] },
		{ "caster", L["Casters"], L["Caster colour"], L["Colours the plates of mobs that have mana: the ones that cast and can be interrupted."], L["The bar colour of casters."] },
		{ "casting", L["Casting enemies"], L["Casting colour"], L["Colours enemies while they cast. Threat on the bar wins unless Threat beats unit types is off."], L["The bar colour of enemies while they cast."] },
		{ "boss", L["Bosses"], L["Boss colour"], L["Colours world bosses and skull-level mobs. Wins over rares and elites."] },
		{ "miniBoss", L["Mini-bosses"], L["Mini-boss colour"], L["Colours elites above your level."] },
		{ "neutral", L["Neutral mobs"], L["Neutral colour"], L["Colours mobs that leave you alone until you attack them."] },
		{ "minor", L["Minor mobs"], L["Minor colour"], L["Colours the small mobs that come in swarms."] },
		{ "normal", L["Normal mobs"], L["Normal colour"], L["Colours ordinary and trivial mobs. The other types win."] },
	}) do
		schema[#schema + 1] = { type = "toggle", key = "types." .. t[1], label = t[2], help = t[4] }
		schema[#schema + 1] = { type = "color", key = "types." .. t[1] .. "Color", label = t[3], help = t[5] or L["The bar colour of this unit type."], disableWhen = Off("types." .. t[1]) }
	end

	SharedTextRows(schema, "name", L["Name"])
	schema[#schema + 1] = {
		type = "toggle", key = "name.upper", label = L["Upper case"],
		help = L["Writes names in capitals. Names hidden by the game in combat stay as they are."],
		disableWhen = Off("name.show"),
	}
	schema[#schema + 1] = {
		type = "toggle", key = "name.classColor", label = L["Class-coloured player names"],
		help = L["Colours players' names with their class colour."],
		disableWhen = Off("name.show"),
	}
	schema[#schema + 1] = { type = "toggle", key = "name.afk", label = L["AFK tag"], help = L["Adds <AFK> to the names of players who are away."], disableWhen = Off("name.show") }
	schema[#schema + 1] = { type = "toggle", key = "name.dnd", label = L["DND tag"], help = L["Adds <DND> to the names of players who do not want to be disturbed."], disableWhen = Off("name.show") }
	SharedTextRows(schema, "level", L["Level"])
	schema[#schema + 1] = { type = "dropdown", key = "level.colorMode", label = L["Text colour"], options = LEVEL_COLORS,
		help = L["Keeps the current style, colours the level by how hard the unit is, or uses your own colour."], disableWhen = Off("level.show") }
	schema[#schema + 1] = { type = "color", key = "level.color", label = L["Custom text colour"], help = L["The text colour when its colour mode is custom."],
		showWhen = Is("level.colorMode", "custom"), disableWhen = Off("level.show") }
	schema[#schema + 1] = { type = "slider", key = "level.x", label = L["Horizontal offset"], help = L["Moves the level left or right."], min = -50, max = 50, step = 1 }
	schema[#schema + 1] = { type = "slider", key = "level.y", label = L["Vertical offset"], help = L["Moves the level up or down."], min = -50, max = 50, step = 1 }
	schema[#schema + 1] = { type = "slider", key = "level.diamond", label = L["Diamond size"], help = L["Scales the level diamond and its elite and rare rim."], min = 0.5, max = 1.5, step = 0.05 }
	SharedTextRows(schema, "healthText", L["Health text"])
	schema[#schema + 1] = {
		type = "dropdown", key = "healthText.format", label = L["Format"],
		help = L["Shows health as a percent, a value, or both."],
		options = HEALTH_FORMATS, disableWhen = Off("healthText.show"),
	}

	for i = 1, 2 do
		schema[#schema + 1] = { type = "header", label = L["Extra text"] .. " " .. i }
		K.Widgets.TextRows(schema, "extra" .. i, { max = TEXT_MAX, outlines = OUTLINES, tags = true, placement = true })
	end

	local rest = {
		{ type = "header", label = L["Cast bar"] },
		{ type = "toggle", key = "cast.spark", label = L["Cast spark"], help = L["Shows the current style's bright cast progress edge."] },
		{ type = "toggle", key = "cast.hideUnitName", label = L["Hide unit name while casting"], help = L["Hides the unit name for the duration of its cast."] },
		{ type = "toggle", key = "cast.fullOpacity", label = L["Keep casting units at full opacity"], help = L["Keeps casting units visible when other plates are dimmed."] },
		{ type = "toggle", key = "cast.shieldBadge", label = L["Interrupt shield"], help = L["Adds a shield beside casts you cannot interrupt. Off keeps the usual cast bar."] },
		{
			type = "toggle", key = "cast.combatCues", label = L["Combat cast cues"],
			help = L["Dims casts while your interrupt is unavailable and marks uninterruptible casts with a shield."],
		},
		{
			type = "toggle", key = "cast.enabled", label = L["Show cast bars"],
			help = L["Shows the spell a unit is casting under its health bar."],
		},
	}
	append(rest)
	K.Widgets.BarRows(schema, "cast", { options = ACCENT_SOURCES, custom = Is("cast.colorSource", "custom"),
		help = { color = L["The colour of casts you can interrupt."] },
		disableWhen = Off("cast.enabled"), height = { 6, 24, 1 } })
	rest = {
		{
			type = "dropdown", key = "cast.orientation", label = L["Orientation"],
			help = L["Fills the cast bar across or upward."],
			options = ORIENTATIONS, disableWhen = Off("cast.enabled"),
		},
		{
			type = "toggle", key = "cast.reverse", label = L["Reverse fill"],
			help = L["Fills the cast bar from the other end."],
			disableWhen = Off("cast.enabled"),
		},
		{
			type = "color", key = "cast.shieldColor", label = L["Uninterruptible colour"],
			help = L["The colour of casts nothing can interrupt."],
			disableWhen = Off("cast.enabled"),
		},
		{
			type = "color", key = "cast.waitColor", label = L["Interrupt recharging colour"],
			help = L["The colour of casts you could interrupt, while your interrupt is on cooldown."],
			disableWhen = Off("cast.enabled"),
		},
		{
			type = "text", key = "cast.interruptSpell", label = L["Interrupt spell"],
			help = L["The spell the recharging colour watches. Blank finds your class's interrupt."],
			maxLetters = 40, disableWhen = Off("cast.enabled"),
		},
		{
			type = "toggle", key = "cast.hideOnTarget", label = L["One cast for your target"],
			help = L["Hides your target's cast on its plate while the target frame shows that cast."],
			disableWhen = Off("cast.enabled"),
		},
		{
			type = "toggle", key = "cast.showIcon", label = L["Spell icon"],
			help = L["Shows the spell's icon at the left of the cast bar."],
			disableWhen = Off("cast.enabled"),
		},
		{ type = "toggle", key = "cast.iconRight", label = L["Icon on the right"], help = L["Puts the spell icon at the right of the cast bar."], disableWhen = Off("cast.showIcon") },
		{ type = "toggle", key = "cast.iconFull", label = L["Full-height icon"], help = L["Makes the spell icon a square as tall as the health and cast bars together, beside both."], disableWhen = Off("cast.showIcon") },
		{ type = "slider", key = "cast.iconScale", label = L["Icon scale"], help = L["Scales the spell icon around its place."], min = 0.5, max = 2, step = 0.1, disableWhen = Either(Off("cast.showIcon"), Is("cast.iconFull", true)) },
		{ type = "slider", key = "cast.iconX", label = L["Icon horizontal offset"], help = L["Moves the spell icon left or right."], min = -50, max = 50, step = 1, disableWhen = Off("cast.showIcon") },
		{ type = "slider", key = "cast.iconY", label = L["Icon vertical offset"], help = L["Moves the spell icon up or down."], min = -50, max = 50, step = 1, disableWhen = Off("cast.showIcon") },
		{ type = "slider", key = "cast.offsetX", label = L["Horizontal offset"], help = L["Moves the cast bar left or right."], min = -50, max = 50, step = 1, disableWhen = Off("cast.enabled") },
		{ type = "slider", key = "cast.offsetY", label = L["Gap under the health bar"], help = L["Moves the cast bar down from the health bar, or up into it below zero."], min = -25, max = 75, step = 1, disableWhen = Off("cast.enabled") },
		{ type = "toggle", key = "cast.inFront", label = L["Casts in front of plates"], help = L["Draws cast bars over neighbouring plates."], disableWhen = Off("cast.enabled") },
		{ type = "toggle", key = "cast.border", label = L["Cast bar border"], help = L["Frames the cast bar with the dark bar edge. Off draws it without one."], disableWhen = Off("cast.enabled") },
		{ type = "slider", key = "cast.bgAlpha", label = L["Cast background opacity"], help = L["How solid the dark track behind the cast fill is."], min = 0, max = 1, step = 0.05, disableWhen = Off("cast.enabled") },
		{ type = "toggle", key = "cast.important", label = L["Important cast colour"], help = L["Colours casts the game marks as important, such as spells that are deadly if not interrupted."], disableWhen = Off("cast.enabled") },
		{ type = "toggle", key = "cast.importantGlow", label = L["Important cast glow"], help = L["Glows around the cast bar during important casts."], disableWhen = Off("cast.enabled") },
		{ type = "color", key = "cast.importantColor", label = L["Important colour"], help = L["The colour of important casts and their glow."], disableWhen = None(Is("cast.important", true), Is("cast.importantGlow", true)) },
		{ type = "toggle", key = "cast.importantKick", label = L["Usual colour while you can interrupt"], help = L["Important casts keep the usual cast colour while your interrupt is ready."], disableWhen = Off("cast.important") },
		{ type = "slider", key = "cast.scale", label = L["Plate size while casting"], help = L["Draws enemy plates larger while they cast. 1 keeps their size."], min = 1, max = 1.5, step = 0.05 },
		{
			type = "toggle", key = "cast.showName", label = L["Spell name"],
			help = L["Shows the name of the spell being cast."],
			disableWhen = Off("cast.enabled"),
		},
		{
			type = "toggle", key = "cast.nameSelectedOnly", label = L["Spell names on target and focus only"],
			help = L["Keeps other plates quiet while showing the spell your target or focus is casting."],
			disableWhen = Off("cast.showName"),
		},
		{
			type = "toggle", key = "cast.nameBelow", label = L["Spell names below the cast bar"],
			help = L["Gives the spell name its own line. Off puts it inside the cast bar."],
			disableWhen = Off("cast.showName"),
		},
		{ type = "dropdown", key = "cast.nameAlign", label = L["Spell name position"], help = L["Aligns the spell name left, centred or right."], options = INSIDE, disableWhen = Off("cast.showName") },
		{ type = "toggle", key = "cast.showTarget", label = L["Spell target"], help = L["Adds who the spell is aimed at after the spell name."] },
		{ type = "dropdown", key = "cast.targetPlace", label = L["Spell target position"], help = L["Writes the target after the spell name, or on its own inside the cast bar."],
			options = { { value = "", label = L["After the spell name"] }, INSIDE[1], INSIDE[2], INSIDE[3] }, disableWhen = Off("cast.showTarget") },
		{ type = "toggle", key = "cast.targetGlow", label = L["Glow when a cast targets you"], help = L["Glows around the cast bar while the spell is aimed at you."], disableWhen = Off("cast.enabled") },
		{ type = "color", key = "cast.targetGlowColor", label = L["Targets-you colour"], help = L["The colour of the glow around casts aimed at you."], disableWhen = Off("cast.targetGlow") },
		{
			type = "toggle", key = "cast.showTime", label = L["Time left"],
			help = L["Shows the seconds left on the cast bar."],
			disableWhen = Off("cast.enabled"),
		},
		{
			type = "slider", key = "cast.textSize", label = L["Text size"],
			help = L["The size of the cast bar's text, in interface units."],
			min = TEXT_MIN, max = TEXT_MAX, step = 1, disableWhen = Off("cast.enabled"),
		},
		{
			type = "dropdown", key = "cast.outline", label = L["Outline"],
			help = L["An outline keeps text readable over the game world."],
			options = OUTLINES, disableWhen = Off("cast.enabled"),
		},
		{
			type = "toggle", key = "cast.outcomes", label = L["Readable cast outcomes"],
			help = L["Holds failed casts before fading. Off restores the original cast effects."],
		},
		{ type = "header", label = L["Debuffs"] },
		{
			type = "toggle", key = "debuffs.enabled", label = L["Show debuffs"],
			help = L["Shows debuffs on each unit."],
		},
		{
			type = "toggle", key = "debuffs.includePlateOnly", label = L["Nameplate-only debuffs"],
			help = L["Also shows debuffs that the game marks for nameplates only."],
			disableWhen = Off("debuffs.enabled"),
		},
		{
			type = "slider", key = "debuffs.size", label = L["Icon size"],
			help = L["The size of each debuff icon, in interface units."],
			min = 10, max = 40, step = 1, disableWhen = Off("debuffs.enabled"),
		},
		{
			type = "slider", key = "debuffs.spacing", label = L["Spacing"],
			help = L["The gap between debuff icons."],
			min = 0, max = 10, step = 1, disableWhen = Off("debuffs.enabled"),
		},
		{
			type = "slider", key = "debuffs.columns", label = L["Icons per row"],
			help = L["Shows up to this many debuffs in a row."],
			min = 1, max = 10, step = 1, disableWhen = Off("debuffs.enabled"),
		},
		{
			type = "slider", key = "debuffs.rows", label = L["Rows"],
			help = L["Shows up to icons per row times rows debuffs; a +N chip counts the rest."],
			min = 1, max = 4, step = 1, disableWhen = Off("debuffs.enabled"),
		},
		{
			type = "dropdown", key = "debuffs.growthX", label = L["Grow across"],
			help = L["Which way a row of debuffs grows."],
			options = GROWTH_X, disableWhen = Off("debuffs.enabled"),
		},
		{
			type = "dropdown", key = "debuffs.growthY", label = L["Grow"],
			help = L["Whether rows of debuffs stack upward above the name or downward under the cast bar."],
			options = GROWTH_Y, disableWhen = Off("debuffs.enabled"),
		},
		{ type = "slider", key = "debuffs.nameGap", label = L["Gap to the name"], help = L["The space between the name and debuffs that grow above it."], min = 0, max = 20, step = 1,
			disableWhen = Either(Off("debuffs.enabled"), Is("debuffs.growthY", "DOWN")) },
		{
			type = "toggle", key = "debuffs.showTime", label = L["Time left"],
			help = L["Shows the time left under each debuff."],
			disableWhen = Off("debuffs.enabled"),
		},
		{
			type = "toggle", key = "debuffs.showCount", label = L["Stacks"],
			help = L["Shows how many times a debuff has stacked."],
			disableWhen = Off("debuffs.enabled"),
		},
		{ type = "dropdown", key = "debuffs.timePlace", label = L["Time left position"], help = L["Where each debuff's time left sits."], options = TIME_PLACES, disableWhen = Off("debuffs.showTime") },
		{ type = "slider", key = "debuffs.timeX", label = L["Timer horizontal offset"], help = L["Moves each debuff's time left sideways."], min = -20, max = 20, step = 1, disableWhen = Off("debuffs.showTime") },
		{ type = "slider", key = "debuffs.timeY", label = L["Timer vertical offset"], help = L["Moves each debuff's time left up or down."], min = -20, max = 20, step = 1, disableWhen = Off("debuffs.showTime") },
		{ type = "dropdown", key = "debuffs.countPlace", label = L["Stacks position"], help = L["Where each debuff's stacks sit."], options = COUNT_PLACES, disableWhen = Off("debuffs.showCount") },
		{ type = "slider", key = "debuffs.countX", label = L["Stacks horizontal offset"], help = L["Moves each debuff's stacks sideways."], min = -20, max = 20, step = 1, disableWhen = Off("debuffs.showCount") },
		{ type = "slider", key = "debuffs.countY", label = L["Stacks vertical offset"], help = L["Moves each debuff's stacks up or down."], min = -20, max = 20, step = 1, disableWhen = Off("debuffs.showCount") },
		{ type = "toggle", key = "debuffs.border", label = L["Debuff border"], help = L["Rings each debuff with its dark and red edge. Off shows the bare icon."], disableWhen = Off("debuffs.enabled") },
		{ type = "toggle", key = "debuffs.dispelColor", label = L["Colour by dispel type"], help = L["Colours the red ring of each debuff by its type, such as magic or poison."], disableWhen = Off("debuffs.border") },
		{ type = "toggle", key = "debuffs.cropped", label = L["Cropped icons"], help = L["Trims the top and bottom of each debuff into a wide tile."], disableWhen = Off("debuffs.enabled") },
		{ type = "slider", key = "debuffs.crop", label = L["Crop"], help = L["How much is trimmed from the top and from the bottom, in percent."], min = 5, max = 25, step = 1, disableWhen = Off("debuffs.cropped") },
		{ type = "toggle", key = "debuffs.raise", label = L["Debuffs in front of plates"], help = L["Draws debuffs over neighbouring plates."], disableWhen = Off("debuffs.enabled") },
		{ type = "toggle", key = "debuffs.pandemic", label = L["Pandemic mark"], help = L["Underlines a debuff in gold once refreshing it keeps its full duration."], disableWhen = Off("debuffs.enabled") },
		{ type = "toggle", key = "debuffs.tooltips", label = L["Debuff tooltips"], help = L["Shows a debuff's tooltip while you hover it. The plate behind the icon does not take the mouse."], disableWhen = Off("debuffs.enabled") },
		{
			type = "toggle", key = "debuffs.readableText", label = L["Number font for debuffs"],
			help = L["Uses the number font for debuff timers and stacks. Turn off to use the plate font."],
			disableWhen = Off("debuffs.enabled"),
		},
		{
			type = "slider", key = "debuffs.expiring", label = L["Expiring timer colour"],
			help = L["Colours a debuff timer red below this many seconds. Set to zero to keep one colour."],
			min = 0, max = 20, step = 1, disableWhen = Off("debuffs.enabled"),
		},
		{
			type = "slider", key = "debuffs.textSize", label = L["Text size"],
			help = L["The size of the debuffs' text, in interface units."],
			min = TEXT_MIN, max = TEXT_MAX, step = 1, disableWhen = Off("debuffs.enabled"),
		},
		{
			type = "dropdown", key = "debuffs.outline", label = L["Outline"],
			help = L["An outline keeps text readable over the game world."],
			options = OUTLINES, disableWhen = Off("debuffs.enabled"),
		},
		{ type = "toggle", key = "debuffs.sunder", label = L["Show Sunder Armor"], help = L["Also shows Sunder Armor and its stacks when another warrior applied it."],
			disableWhen = Either(Off("debuffs.enabled"), Off("debuffs.onlyMine")), showWhen = function() return ns.Auras.Warrior() end },
		{ type = "header", label = L["Enemy buffs"] },
		{ type = "toggle", key = "buffs.enabled", label = L["Show enemy buffs"], help = L["Shows buffs on enemy plates in the debuffs' icon style."] },
		{ type = "dropdown", key = "buffs.filter", label = L["Enemy buff filter"], options = BUFF_FILTERS, disableWhen = Off("buffs.enabled"),
			help = L["Important shows the buffs the game marks for enemy plates; the others, dispellable buffs or all."] },
		{ type = "dropdown", key = "buffs.place", label = L["Position"], help = L["Where these icons sit around the plate."], options = PLACES, disableWhen = Off("buffs.enabled") },
		{ type = "slider", key = "buffs.count", label = L["Icons"], help = L["Shows up to this many icons."], min = 1, max = 8, step = 1, disableWhen = Off("buffs.enabled") },
		{ type = "toggle", key = "buffs.showTime", label = L["Time left"], help = L["Shows the time left on each icon."], disableWhen = Off("buffs.enabled") },
		{ type = "toggle", key = "buffs.dispelGlow", label = L["Dispel glow"], help = L["Glows around buffs that can be dispelled or purged, in their type's colour."], disableWhen = Off("buffs.enabled") },
		{ type = "header", label = L["Crowd control"] },
		{ type = "toggle", key = "ccs.enabled", label = L["Show crowd control"], help = L["Shows stuns, fears and other crowd control on enemies, from anyone. Yours leaves the debuff row."] },
		{ type = "dropdown", key = "ccs.place", label = L["Position"], help = L["Where these icons sit around the plate."], options = PLACES, disableWhen = Off("ccs.enabled") },
		{ type = "slider", key = "ccs.count", label = L["Icons"], help = L["Shows up to this many icons."], min = 1, max = 8, step = 1, disableWhen = Off("ccs.enabled") },
		{ type = "toggle", key = "ccs.showTime", label = L["Time left"], help = L["Shows the time left on each icon."], disableWhen = Off("ccs.enabled") },
		{ type = "toggle", key = "ccs.first", label = L["Crowd control first"], help = L["Puts crowd control nearest the plate when it shares a place with enemy buffs."], disableWhen = Off("ccs.enabled") },
		{ type = "header", label = L["Threat"] },
		{ type = "toggle", key = "threat.shapes", label = L["Threat shapes"], help = L["Adds a tick, triangle or square beside threat colours. Off keeps the colours alone."] },
		{ type = "toggle", key = "threat.keyline", label = L["Threat as an edge"],
			help = L["Colours the bar edge instead of glowing around it. Off restores the threat glow."] },
		{
			type = "dropdown", key = "threat.display", label = L["Threat display"],
			help = L["How a plate shows that its unit is attacking you or about to."],
			options = THREAT_DISPLAYS,
		},
		{
			type = "dropdown", key = "threat.role", label = L["Role"],
			help = L["Tanks want aggro; everyone else wants to avoid it."],
			options = THREAT_ROLES, disableWhen = Is("threat.display", "off"),
		},
		{
			type = "toggle", key = "threat.groupOnly", label = L["Only in a group"],
			help = L["Shows threat only while you are in a party or raid."],
			disableWhen = Is("threat.display", "off"),
		},
		{ type = "toggle", key = "threat.name", label = L["Threat on the name"], help = L["Also colours the unit's name with its threat colour."], disableWhen = Is("threat.display", "off") },
		{ type = "toggle", key = "threat.calm", label = L["Safe colour while you hold no aggro"],
			help = L["Damage dealers and healers see the safe colour on units attacking someone else."], disableWhen = Is("threat.display", "off") },
		{ type = "toggle", key = "threat.overTypes", label = L["Threat beats unit types"],
			help = L["Threat on the health bar wins over unit type colours. Off keeps the type colour."], disableWhen = Is("threat.display", "off") },
		{ type = "toggle", key = "threat.overBoss", label = L["Threat beats bosses"], help = L["Damage dealers and healers: threat wins over the boss colour."], disableWhen = Off("threat.overTypes") },
		{ type = "toggle", key = "threat.overMiniBoss", label = L["Threat beats mini-bosses"], help = L["Damage dealers and healers: threat wins over the mini-boss colour."], disableWhen = Off("threat.overTypes") },
		{ type = "toggle", key = "threat.overCaster", label = L["Threat beats casters"], help = L["Damage dealers and healers: threat wins over the caster colour."], disableWhen = Off("threat.overTypes") },
		{ type = "toggle", key = "threat.tankOverBoss", label = L["Tanks: threat beats bosses"], help = L["Tanks: threat wins over the boss colour."], disableWhen = Off("threat.overTypes") },
		{ type = "toggle", key = "threat.tankOverOthers", label = L["Tanks: threat beats mini-bosses and casters"], help = L["Tanks: threat wins over the mini-boss and caster colours."], disableWhen = Off("threat.overTypes") },
		{
			type = "color", key = "threat.safe", label = L["Safe colour"],
			help = L["A tank holds aggro."],
			disableWhen = Is("threat.display", "off"),
		},
		{
			type = "color", key = "threat.warning", label = L["Warning colour"],
			help = L["Aggro is about to change hands."],
			disableWhen = Is("threat.display", "off"),
		},
		{
			type = "color", key = "threat.danger", label = L["Danger colour"],
			help = L["A damage dealer or healer has aggro, or a tank lost it."],
			disableWhen = Is("threat.display", "off"),
		},
		{ type = "toggle", key = "threat.percent", label = L["Threat percent"], help = L["Shows your share of threat on units that are attacking your group."] },
		{ type = "dropdown", key = "threat.percentPlace", label = L["Threat percent position"], help = L["Where the threat percent sits inside the health bar."], options = INSIDE, disableWhen = Off("threat.percent") },
		{ type = "toggle", key = "threat.percentColor", label = L["Colour by threat"], help = L["Colours the threat percent with the threat colour. Off shows it in white."], disableWhen = Off("threat.percent") },
		{ type = "header", label = L["Target and focus"] },
		{ type = "toggle", key = "focus.fullOpacity", label = L["Keep focus at full opacity"], help = L["Keeps your focus visible when other plates are dimmed."] },
		{ type = "toggle", key = "target.readableTicks", label = L["Bright target ticks"],
			help = L["Medallions: bright, outlined ticks settle beside your target. Off restores the dark ticks."] },
		{ type = "toggle", key = "target.smoothOpacity", label = L["Smooth plate opacity"],
			help = L["Fades other plates smoothly when your target changes. Off changes their opacity immediately."] },
		{
			type = "toggle", key = "target.highlight", label = L["Highlight the target"],
			help = L["Draws a glow and an edge around your target's plate."],
		},
		{ type = "toggle", key = "target.glow", label = L["Target glow"], help = L["Glows around your target's plate in the target colour."] },
		{ type = "slider", key = "target.glowAlpha", label = L["Glow opacity"], help = L["How strong the target glow is."], min = 0, max = 1, step = 0.05, disableWhen = Off("target.glow") },
		{ type = "toggle", key = "target.fill", label = L["Target bar highlight"], help = L["Brightens your target's health bar."] },
		{ type = "color", key = "target.fillColor", label = L["Highlight colour"], help = L["The colour that brightens your target's health bar."], disableWhen = None(Is("target.fill", true), Is("target.hover", true)) },
		{ type = "slider", key = "target.fillAlpha", label = L["Highlight opacity"], help = L["How strongly your target's health bar is brightened."], min = 0, max = 1, step = 0.05, disableWhen = None(Is("target.fill", true), Is("target.hover", true)) },
		{ type = "slider", key = "target.scale", label = L["Target plate size"], help = L["Draws your target's plate larger. 1 keeps its size."], min = 1, max = 1.6, step = 0.05 },
		{ type = "toggle", key = "target.hover", label = L["Highlight under the mouse"], help = L["Brightens the health bar of the plate under your mouse with the highlight colour."] },
		{ type = "toggle", key = "target.fillOwn", label = L["Highlight in the bar's colour"], help = L["Highlights take the health bar's own colour instead of their highlight colour."],
			disableWhen = None(Is("target.fill", true), Is("focus.fill", true), Is("target.hover", true)) },
		{ type = "toggle", key = "target.friendly", label = L["Highlight friendly targets"], help = L["Also highlights your target when it is friendly."], disableWhen = None(Is("target.highlight", true), Is("target.glow", true), Is("target.fill", true), Off("target.scale", 1)) },
		{ type = "toggle", key = "target.hashLine", label = L["Health line on the target"], help = L["Marks a health percent, such as an execute range, on your target's health bar."] },
		{ type = "slider", key = "target.hashPercent", label = L["Health line percent"], help = L["The health percent the line marks."], min = 0, max = 100, step = 1, disableWhen = Off("target.hashLine") },
		{ type = "toggle", key = "target.distance", label = L["Distance to your target"], help = L["Writes how far away your target is in yards, such as 8-20, from your spells' ranges."] },
		{ type = "slider", key = "target.distanceSize", label = L["Text size"], help = L["The size of this text, in interface units."], min = TEXT_MIN, max = 32, step = 1, disableWhen = Off("target.distance") },
		{ type = "slider", key = "target.distanceX", label = L["Horizontal offset"], help = L["Moves this text left or right."], min = -100, max = 100, step = 1, disableWhen = Off("target.distance") },
		{ type = "slider", key = "target.distanceY", label = L["Vertical offset"], help = L["Moves this text up or down."], min = -100, max = 100, step = 1, disableWhen = Off("target.distance") },
		{
			type = "dropdown", key = "target.colorSource", label = L["Target colour"],
			help = L["The target highlight follows the accent or uses your own colour."],
			options = ACCENT_SOURCES, disableWhen = targetTint,
		},
		{
			type = "color", key = "target.color", label = L["Custom target colour"],
			help = L["The colour of the target highlight."],
			showWhen = Is("target.colorSource", "custom"), disableWhen = targetTint,
		},
		{
			type = "slider", key = "target.dimOthers", label = L["Other plates' opacity"],
			help = L["Fades plates that are not your target while you have one."],
			min = 0.2, max = 1, step = 0.05,
		},
		{
			type = "toggle", key = "focus.highlight", label = L["Mark the focus"],
			help = L["Gives your focus's plate a coloured edge."],
		},
		{
			type = "color", key = "focus.color", label = L["Focus colour"],
			help = L["The edge colour of your focus's plate."],
			disableWhen = Off("focus.highlight"),
		},
		{ type = "toggle", key = "focus.fill", label = L["Focus bar highlight"], help = L["Brightens your focus's health bar."] },
		{ type = "color", key = "focus.fillColor", label = L["Focus highlight colour"], help = L["The colour that brightens your focus's health bar."], disableWhen = Off("focus.fill") },
		{ type = "slider", key = "focus.fillAlpha", label = L["Focus highlight opacity"], help = L["How strongly your focus's health bar is brightened."], min = 0, max = 1, step = 0.05, disableWhen = Off("focus.fill") },
		{ type = "slider", key = "focus.castHeight", label = L["Focus cast bar height"], help = L["Draws your focus's cast bar taller. 1 keeps its height."], min = 1, max = 2, step = 0.05 },
		{ type = "dropdown", key = "focus.letter", label = L["Focus letter"], help = L["Writes F on your focus's health bar."], options = FOCUS_LETTER },
		{ type = "slider", key = "focus.letterSize", label = L["Text size"], help = L["The size of this text, in interface units."], min = TEXT_MIN, max = 32, step = 1, disableWhen = Is("focus.letter", "") },
		{ type = "slider", key = "focus.letterX", label = L["Horizontal offset"], help = L["Moves this text left or right."], min = -100, max = 100, step = 1, disableWhen = Is("focus.letter", "") },
		{ type = "slider", key = "focus.letterY", label = L["Vertical offset"], help = L["Moves this text up or down."], min = -100, max = 100, step = 1, disableWhen = Is("focus.letter", "") },
		{ type = "header", label = L["Class resource"] },
		{ type = "toggle", key = "resource.show", label = L["Combo points on the target"], help = L["Shows your combo points on your target's plate, as the unit frames' pips."] },
		{ type = "dropdown", key = "resource.colorSource", label = L["Bar colour"], help = L["Where the bar's colour comes from."], options = ACCENT_SOURCES, disableWhen = Off("resource.show") },
		{ type = "color", key = "resource.color", label = L["Custom bar colour"], help = L["The bar's colour when its colour source is custom."],
			showWhen = Is("resource.colorSource", "custom"), disableWhen = Off("resource.show") },
		{ type = "dropdown", key = "resource.place", label = L["Position"], help = L["Puts the points under the plate or above the name."], options = {
			{ value = "BOTTOM", label = L["Under the plate"] }, { value = "TOP", label = L["Above the name"] } }, disableWhen = Off("resource.show") },
		{ type = "slider", key = "resource.scale", label = L["Points size"], help = L["Scales the points."], min = 0.5, max = 3, step = 0.1, disableWhen = Off("resource.show") },
		{ type = "slider", key = "resource.spacing", label = L["Spacing"], help = L["The gap between the points."], min = -2, max = 10, step = 1, disableWhen = Off("resource.show") },
		{ type = "toggle", key = "resource.energy", label = L["Energy bar"], help = L["Adds your energy as a thin bar beside the points."], disableWhen = Off("resource.show") },
		{ type = "slider", key = "resource.energyHeight", label = L["Energy bar height"], help = L["The height of the energy bar, in interface units."], min = 1, max = 12, step = 1, disableWhen = Off("resource.energy") },
		{ type = "dropdown", key = "resource.energyPlace", label = L["Energy bar position"], help = L["Puts the energy bar under or above the points."], options = {
			{ value = "BELOW", label = L["Under the points"] }, { value = "ABOVE", label = L["Above the points"] } }, disableWhen = Off("resource.energy") },
		{ type = "slider", key = "resource.energyWidth", label = L["Energy bar width"], help = L["The energy bar's width against the row of points."], min = 0.5, max = 3, step = 0.1, disableWhen = Off("resource.energy") },
		{ type = "toggle", key = "resource.energyHideFull", label = L["Hide full energy out of combat"], help = L["Hides the energy bar while it is full and you are out of combat."], disableWhen = Off("resource.energy") },
		{ type = "header", label = L["Markers"] },
		{
			type = "toggle", key = "markers.classification", label = L["Elite and rare markers"],
			help = L["A gold diamond marks elites and bosses, a blue one rares."],
		},
		{
			type = "toggle", key = "markers.raid", label = L["Raid markers"],
			help = L["Shows the raid marker a unit carries."],
		},
		{
			type = "slider", key = "markers.raidSize", label = L["Raid marker size"],
			help = L["The size of the raid marker, in interface units."],
			min = 8, max = 32, step = 1, disableWhen = Off("markers.raid"),
		},
		{ type = "toggle", key = "markers.nameRaid", label = L["Raid marker by the name"], help = L["Also shows the raid marker just before the unit's name."] },
		{ type = "slider", key = "markers.nameRaidSize", label = L["Name raid marker size"], help = L["The size of the raid marker by the name, in interface units."], min = 8, max = 32, step = 1, disableWhen = Off("markers.nameRaid") },
		{ type = "toggle", key = "markers.pvp", label = L["PvP flag"], help = L["Shows a faction badge after the names of units flagged for PvP."] },
		{ type = "toggle", key = "markers.pvpEnemyOnly", label = L["Opposite faction only"], help = L["Shows the PvP badge only on the other faction."], disableWhen = Off("markers.pvp") },
		{ type = "toggle", key = "markers.pvpPlayersOnly", label = L["Players only"], help = L["Hides the PvP badge on faction NPCs such as guards."], disableWhen = Off("markers.pvp") },
		{ type = "toggle", key = "markers.instances", label = L["Markers in instances"], help = L["Shows elite and rare rims, quest colours and quest progress in dungeons, raids and battlegrounds."] },
		{ type = "toggle", key = "markers.questText", label = L["Quest progress"], help = L["Writes your quest progress, such as 3/8, after the names of mobs your quests need."], disableWhen = Off("name.show") },
		{ type = "slider", key = "markers.questSize", label = L["Text size"], help = L["The size of this text, in interface units."], min = TEXT_MIN, max = TEXT_MAX, step = 1, disableWhen = Either(Off("name.show"), Off("markers.questText")) },
		{ type = "toggle", key = "markers.questIcon", label = L["Objective type icon"], help = L["Adds a sword for kill objectives, a bag for item objectives and the quest icon for the rest."], disableWhen = Either(Off("name.show"), Off("markers.questText")) },
		{ type = "slider", key = "markers.questIconScale", label = L["Icon scale"], help = L["Scales the objective icon against the text."], min = 0.5, max = 2, step = 0.05, disableWhen = Either(Off("name.show"), Either(Off("markers.questText"), Off("markers.questIcon"))) },
		{ type = "header", label = L["Stacking"] },
		{
			type = "dropdown", key = "stacking.footprint", label = L["Plate size for the game"],
			help = L["The size the game stacks and clicks plates by. KstyleUI's plate keeps stacked plates apart."],
			options = FOOTPRINTS,
		},
		{ type = "slider", key = "stacking.spacing", label = L["Stacked plate spacing"], help = L["Spreads stacked plates further apart, or packs them closer below 1."],
			min = 0.5, max = 2, step = 0.05, disableWhen = Is("stacking.footprint", "game") },
		{ type = "slider", key = "stacking.clickWidth", label = L["Enemy click width"], help = L["Narrows the part of enemy plates that takes clicks. 1 keeps the game's area."], min = 0.25, max = 1, step = 0.05 },
		{ type = "slider", key = "stacking.clickHeight", label = L["Enemy click height"], help = L["Shortens the part of enemy plates that takes clicks. 1 keeps the game's area."], min = 0.25, max = 1, step = 0.05 },
		{ type = "toggle", key = "stacking.friendlyClicks", label = L["Click friendly plates"], help = L["Off, clicks pass through friendly plates, so their names never get in the way."] },
		{ type = "header", label = L["Game nameplate settings"] },
		{
			type = "toggle", key = "cvars.enabled", label = L["Manage these settings"],
			help = L["Applies the settings below out of combat. Off returns them to the game's defaults."],
		},
		{
			type = "slider", key = "cvars.maxDistance", label = L["Distance"],
			help = L["How far away, in yards, plates show."],
			min = 10, max = 60, step = 1, disableWhen = Off("cvars.enabled"), showWhen = HasCVar("nameplateMaxDistance"),
		},
		{
			type = "slider", key = "cvars.verticalDistance", label = L["Height difference"],
			help = L["Hides plates this far above or below you. 0 shows them at any height."],
			min = 0, max = 100, step = 5, disableWhen = Off("cvars.enabled"), showWhen = HasCVar("nameplateMaxVerticalDistance"),
		},
		{
			type = "dropdown", key = "cvars.stacking", label = L["Stacking"],
			help = L["Stacked plates move apart so they never overlap."],
			options = STACKING, disableWhen = Off("cvars.enabled"),
		},
		{
			type = "slider", key = "cvars.selectedScale", label = L["Target plate scale"],
			help = L["How much larger your target's plate is drawn."],
			min = 1, max = 1.6, step = 0.05, disableWhen = Off("cvars.enabled"),
		},
		{
			type = "slider", key = "cvars.minScale", label = L["Distant plate scale"],
			help = L["How small plates shrink with distance."],
			min = 0.5, max = 1, step = 0.05, disableWhen = Off("cvars.enabled"),
		},
		{
			type = "slider", key = "cvars.clickSize", label = L["Click area size"],
			help = L["The game's own plate size, which sets where you can click and how plates stack."],
			min = 1, max = 5, step = 1, disableWhen = Off("cvars.enabled"),
		},
		{ type = "toggle", key = "cvars.lineOfSight", label = L["Line of sight opacity"], help = L["Sets how visible plates behind walls are. Off leaves the game's setting."],
			disableWhen = Off("cvars.enabled"), showWhen = HasCVar("nameplateOccludedAlphaMult") },
		{ type = "slider", key = "cvars.lineOfSightAlpha", label = L["Opacity behind walls"], help = L["How visible plates of units out of sight are."], min = 0, max = 1, step = 0.05,
			disableWhen = Either(Off("cvars.enabled"), Off("cvars.lineOfSight")), showWhen = HasCVar("nameplateOccludedAlphaMult") },
	}
	for _, c in ipairs({
		{ "showEnemies", "nameplateShowEnemies", L["Enemy plates"] },
		{ "showFriends", "nameplateShowFriendlyPlayers", L["Friendly player plates"] },
		{ "enemyMinions", "nameplateShowEnemyMinions", L["Enemy pets and minions"] },
		{ "friendlyMinions", "nameplateShowFriendlyPlayerMinions", L["Friendly pets and minions"] },
		{ "friendlyNpcs", "nameplateShowFriendlyNpcs", L["Friendly NPC plates"] },
		{ "friendlyNameOnly", "nameplateShowOnlyNameForFriendlyPlayerUnits", L["Names only for friendly players in instances"] },
	}) do
		rest[#rest + 1] = { type = "dropdown", key = "cvars." .. c[1], label = c[3], options = GAME_CHOICES,
			help = L["Turns these game plates on or off. The game's setting leaves them alone."], disableWhen = Off("cvars.enabled"), showWhen = HasCVar(c[2]) }
	end
	for _, row in ipairs(rest) do
		schema[#schema + 1] = row
	end

	local filterRows = {}
	K.Options.AuraFilterRows(filterRows, "debuffs", { spellIDs = true, sortKey = "order", sortOptions = ORDERS, disableWhen = Off("debuffs.enabled") })
	for i, row in ipairs(schema) do
		if row.key == "debuffs.enabled" then
			for j = #filterRows, 1, -1 do table.insert(schema, i + 1, filterRows[j]) end
			break
		end
	end
	Settings.schema = schema

	rows = {}
	for _, row in ipairs(schema) do
		if row.key then
			rows[row.key] = row
		end
	end
	Settings.rows = rows
	Settings.schema.preview = ns.Preview.Build
	return Settings.schema
end

local function Lookup(root, key)
	local node = root
	for part in key:gmatch("[^%.]+") do
		if type(node) ~= "table" then
			return nil
		end
		node = node[part]
	end
	return node
end

local function IsUnit(v)
	return not ns.Logic.IsSecret(v) and type(v) == "number" and v >= 0 and v <= 1
end

local function Allowed(row, value)
	if ns.Logic.IsSecret(value) then
		return nil
	end
	local kind = row.type
	if kind == "toggle" then
		if type(value) == "boolean" then
			return value
		end
		return nil
	elseif kind == "slider" then
		if type(value) ~= "number" or value ~= value then
			return nil
		end
		return math.min(row.max, math.max(row.min, value))
	elseif kind == "dropdown" then
		local options = row.options
		if type(options) == "function" then
			options = options()
		end
		for _, option in ipairs(options) do
			if option.value == value then
				return value
			end
		end
		return nil
	elseif kind == "color" then
		if type(value) == "table" and IsUnit(value.r) and IsUnit(value.g) and IsUnit(value.b) then
			return value
		end
		return nil
	end
	return type(value) == "string" and (kind == "font" or kind == "text" or value ~= "") and value or nil
end

local cache = {}
local logged = {}

local function Read(key)
	local default = Lookup(Settings.defaults, key)
	if default == nil then
		error("KstyleUI_Nameplates: unknown setting " .. tostring(key), 3)
	end
	local Store = K.Store
	if not Store.IsLoaded() then
		return default
	end
	local stored = Lookup(Store.Module(MODULE), key)
	if not ns.Logic.IsSecret(stored) and stored == default then return stored end
	if type(default) == "table" and default.textFormat then return type(stored) == "table" and stored or default end
	if not rows then Settings.Schema() end
	local row = rows[key]
	if row then
		local value = Allowed(row, stored)
		if value ~= nil then
			return value
		end
	elseif not ns.Logic.IsSecret(stored) and type(stored) == type(default) then
		if type(default) ~= "table" or Allowed({ type = "color" }, stored) then return stored end
	end
	if stored ~= nil and not logged[key] then
		logged[key] = true
		K.DevTest.Log(MODULE, "the saved value of " .. key .. " is not allowed; using the default")
	end
	return default
end

function Settings.Get(key, role)
	local value = cache[key]
	if value == nil then
		value = Read(key)
		cache[key] = value
	end
	if key == "font" and K.Theme.FollowsKit(value) then
		return (Tokens.Font(role or "body"))
	end
	return value
end

function Settings.Invalidate()
	for key in pairs(cache) do
		cache[key] = nil
	end
end

function Settings.Row(key)
	if not rows then Settings.Schema() end
	return rows[key]
end
