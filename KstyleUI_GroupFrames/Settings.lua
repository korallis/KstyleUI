-- Settings.lua: the group frames' defaults, their settings schema and checked reads of the saved values.
local _, ns = ...

local K = KstyleUI
local Tokens, L = K.Tokens, K.L

local Settings = {}
ns.Settings = Settings

local MODULE = "GroupFrames"
Settings.MODULE = MODULE

local function Rgb(token, alpha)
	local r, g, b = Tokens.Color(token)
	return { r = r, g = g, b = b, a = alpha }
end

local HEAL_ALPHA = 0.5
local ABSORB_ALPHA = 0.45
local HEAL_ABSORB_ALPHA = 0.7
local INDICATOR_SLOTS = 6
Settings.INDICATOR_SLOTS = INDICATOR_SLOTS

local THEME_FONT = "theme"
Settings.THEME_FONT = THEME_FONT
Settings.COMPACT_NAME_FONT = Tokens.FontPath("AlegreyaSansRegular")

local function ExtraText()
	return { font = "", size = 12, outline = "OUTLINE", colorMode = "", color = Rgb("textEmphasis"),
		textFormat = "", position = "CENTER", x = 0, y = 0 }
end

Settings.defaults = {
	layout = { tidyLanes = true },
	blizzard = { party = true, raid = true, manager = false, keepManager = true },
	party = {
		extra1 = ExtraText(), extra2 = ExtraText(),
		width = 259, height = 39, spacing = 13, growth = "DOWN", card = false,
		showPlayer = true, showSolo = false, sortBy = "INDEX", centerSolo = false, smallRaid = false,
		portrait = true, portraitZoom = 0, portraitRingAlpha = 1, roleRing = false, classLine = false, power = true, powerHeight = 3,
		textLayout = "ABOVE", nameSize = 13, nameChars = 0, nameFormat = "FULL", healthText = "PERCENT", healthTextSize = 11, healthTextPlace = "ROW",
		iconSize = 14,
		auraSize = 18, auraCount = 6, auraDispelCount = 1, auraColumns = 3, auraRows = 2, auraSpacing = 2,
		auraPosition = "OUTSIDE_RIGHT", auraGrowth = "RIGHT", auraWrap = "DOWN",
		buffSize = 11, buffCount = 3,
		auraX = 0, auraY = 0, buffX = 0, buffY = 0,
	},
	raid = {
		extra1 = ExtraText(), extra2 = ExtraText(),
		width = 116, height = 36, spacing = 9, growth = "DOWN", card = true,
		groupGrowth = "RIGHT", groupSpacing = 13, groupsPerRow = 8,
		sortBy = "GROUP", unitsPerColumn = 5, merge = false,
		roleRing = false, classLine = false, power = false, powerHeight = 2,
		textLayout = "INSIDE", nameSize = 12, nameChars = 0, nameFormat = "FULL", healthText = "PERCENT", healthTextSize = 10, healthTextPlace = "ROW",
		iconSize = 10,
		auraSize = 12, auraCount = 3, auraDispelCount = 1, auraColumns = 3, auraRows = 1, auraSpacing = 1,
		auraPosition = "BOTTOMRIGHT", auraGrowth = "RIGHT", auraWrap = "DOWN",
		buffSize = 10, buffCount = 0,
		auraX = 0, auraY = 0, buffX = 0, buffY = 0, center = false,
	},
	health = {
		texture = Tokens.MediaList("statusbar")[1].path, colorSource = "class", color = Rgb("friendly"), orientation = "HORIZONTAL", alpha = 1,
		gradientHigh = Rgb("friendly"), gradientMid = Rgb("neutral"), gradientLow = Rgb("hostile"), gradientLowAt = 0, gradientHighAt = 100,
		statusGrey = true, deadColor = Rgb("textDisabled"), offlineColor = Rgb("textDisabled"), missing = false,
	},
	power = { colorSource = "power", color = Rgb("rare"), tanks = true, healers = true, damagers = true, behind = false, keepRoom = false },
	text = {
		nameFont = THEME_FONT, nameOutline = "NONE", nameColorSource = "class", nameColor = Rgb("textEmphasis"),
		healthFont = THEME_FONT, healthOutline = "NONE",
		above = false, aboveName = true, aboveHealth = true, aboveExtra = true,
	},
	range = { fade = true, alpha = 0.4 },
	icons = {
		role = true, roleShapes = true, statuses = true, afk = true, resurrection = true, summon = true, leader = true, marker = true, readyCheck = true,
		roleTank = true, roleHealer = true, roleDamager = true, roleInCombat = true, leaderInCombat = true,
		roleText = false, readyPlace = "AUTO", readySize = 0, markerPlace = "AUTO", combat = false, combatPlace = "LEFT", combatSize = 14, combatClass = false,
		rolePlace = "AUTO", roleX = 0, roleY = 0, markerX = 0, markerY = 0, readyX = 0, readyY = 0, combatX = 0, combatY = 0,
	leaderX = 0, leaderY = 0, roleBehind = false,
	},
	threat = { enabled = true, shapes = true, edge = false },
	tooltip = { mode = "ALWAYS" },
	groups = { show1 = true, show2 = true, show3 = true, show4 = true, show5 = true, show6 = true, show7 = true, show8 = true, mythicBench = true, hideEmpty = false },
	auras = {
		enabled = true, onlyMine = false, sort = "", typeLetters = true, stacks = true, timers = false, filter = "ALL", swipe = true, dispelHighlight = true, dispelFilter = "PLAYER",
		magic = true, curse = true, poison = true, disease = true, bleed = true, lasting = true, dispelAlpha = 0.16, dispelLines = 2,
		zoom = 0.07, tooltips = true, typeMode = "HIDE", source = "ANY", canApply = false, timerSize = 0,
		zoomEach = false, bossZoom = 0.07, tipCursor = false, countX = 0, countY = 0, timerX = 0, timerY = 0,
		priority1 = "DISPEL", priority2 = "BOSS", priority3 = "IMPORTANT", priority4 = "OTHER", glow = true,
		tipCombat = true, textOutline = "OUTLINE",
	},
	buffs = { enabled = true, tooltips = true, zoom = 0.07 },
	clickCast = { hint = true },
	presets = { raid = "Compact" },
	targets = { enabled = false, self = false, width = 96, height = 24, x = 0, y = 0, nameColor = "text", color = Rgb("textEmphasis") },
	prediction = {
		heals = true, absorbs = true, shield = true, shieldLines = 2, healAbsorbs = true,
		shieldPlace = "BOTTOM", shieldGrow = "UP", absorbPlace = "FILL", overshield = false, healAbsorbLine = false, healAbsorbLines = 0,
		absorbStyle = "SOLID", healAbsorbStyle = "SOLID", backing = 1, glow = false, maxLoss = "OFF", maxLossColor = Rgb("black", 0.6),
		backingOwn = false, healAbsorbBacking = 1, maxLossBacking = 1, edge = false,
		healColor = Rgb("friendly", HEAL_ALPHA), absorbColor = Rgb("white", ABSORB_ALPHA), healAbsorbColor = Rgb("hostile", HEAL_ABSORB_ALPHA),
	},
	auto = { size = true, role = true, smallMost = 10, largeLeast = 26, shownOnly = false, icons = false, heals = false,
		smallWidth = 0, smallHeight = 0, smallX = 0, smallY = 0, largeWidth = 0, largeHeight = 0, largeX = 0, largeY = 0,
		customLeast = 0, customWidth = 0, customHeight = 0, customX = 0, customY = 0 },
	accent = { source = "class", color = Rgb("accentDefault"), hover = true, hoverLines = 1, target = true, targetLines = 2 },
}

local INDICATOR_DEFAULTS = {
	{ category = "EXTERNAL", position = "CENTER" },
	{ category = "CROWD_CONTROL", position = "CENTER" },
	{ category = "BIG_DEFENSIVE", position = "BOTTOMRIGHT" },
}
for i = 1, INDICATOR_SLOTS do
	local preset = INDICATOR_DEFAULTS[i] or {}
	Settings.defaults["indicator" .. i] = { category = preset.category or "OFF", position = preset.position or "TOPLEFT", spells = "", mine = false, size = 14, show = "BOTH", x = 0, y = 0,
		style = "ICON", color = Rgb("friendly"), thick = 4, reverse = false, over = false }
end

local function Plain(r, g, b)
	return { r = r, g = g, b = b }
end
local defaults = Settings.defaults
defaults.reminders = { place = "NONE", size = 14, fortitude = true, wild = true, intellect = true, spirit = true, thorns = true, salvation = true, thornsTank = false, glow = false, x = 0, y = 0 }
defaults.status = { place = "AUTO", size = 0, x = 0, y = 0 }
defaults.dispel = { icon = "NONE", iconSize = 14, iconBorder = true, custom = false, x = 0, y = 0,
	magic = Plain(0.2, 0.6, 1), curse = Plain(0.6, 0, 1), poison = Plain(0, 0.6, 0), disease = Plain(0.6, 0.4, 0), bleed = Plain(0.8, 0.1, 0.1) }
defaults.names = { align = "AUTO", divider = false, dividerAccent = false, height = 0, x = 0, y = 0 }
defaults.numbers = { show = false, size = 8, x = 0, y = 0 }
defaults.mana = { mode = "NONE", size = 12, spacing = 2, align = "LEFT", growth = "DOWN", names = true, colorSource = "power", color = Rgb("rare") }
Settings.CLASSES = type(CLASS_SORT_ORDER) == "table" and #CLASS_SORT_ORDER > 0 and CLASS_SORT_ORDER or { "WARRIOR", "PALADIN", "PRIEST", "SHAMAN", "DRUID", "ROGUE", "MAGE", "WARLOCK", "HUNTER" }
defaults.sort = { classFirst = false, classFirstIn = "BOTH", partyOwn = false }
for i, class in ipairs(Settings.CLASSES) do defaults.sort["class" .. i], defaults.sort["partyClass" .. i] = class, class end
defaults.label = { enabled = false, format = "FULL", size = 14, padding = 4, color = Rgb("textEmphasis") }
defaults.pets = { enabled = false, nameColor = "raid", color = Rgb("textEmphasis"), width = 0, height = 0 }
defaults.tanks = { enabled = false, growth = "DOWN", wrap = "RIGHT", wrapAfter = 0, width = 0, height = 0, excludeSelf = false }
defaults.follow = { text = false, auras = false, heals = false, icons = false, power = false }
Settings.FOLLOW = {
	text = { "textLayout", "nameSize", "nameChars", "nameFormat", "healthText", "healthTextSize", "healthTextPlace" },
	auras = { "auraSize", "auraCount", "auraDispelCount", "auraColumns", "auraRows", "auraSpacing", "auraPosition", "auraGrowth", "auraWrap", "auraX", "auraY" },
	heals = { "buffSize", "buffCount", "buffX", "buffY" },
	icons = { "iconSize" },
	power = { "power", "powerHeight" },
}
defaults.boss = { display = "NEVER", dungeons = false, colorSource = "reaction", width = 0, height = 0 }

local rows

local function After(schema, key, additions)
	for i, row in ipairs(schema) do
		if row.key == key then
			for j, new in ipairs(additions) do
				table.insert(schema, i + j, new)
				if rows and new.key then rows[new.key] = new end
			end
			return
		end
	end
end

local textRows = false
local moreRows
local function TextSlotRows(schema)
	if textRows then return end
	textRows = true
	for _, kind in ipairs({ "party", "raid" }) do
		local label = kind == "party" and L["Party"] or L["Raid"]
		local additions = {}
		for i = 1, 2 do
			additions[#additions + 1] = { type = "header", label = label .. ": " .. L["Extra text"] .. " " .. i }
			K.Widgets.TextRows(additions, kind .. ".extra" .. i, { outlines = {
				{ value = "NONE", label = L["None, soft shadow"] }, { value = "OUTLINE", label = L["Thin outline"] },
				{ value = "THICKOUTLINE", label = L["Thick outline"] },
			}, tags = true, placement = true })
		end
		additions[#additions + 1] = { type = "header", label = label .. ": " .. L["icons"] }
		After(schema, kind .. ".healthTextPlace", additions)
	end
	moreRows(schema)
end

function Settings.Schema(includeText)
	if Settings.schema then
		if includeText then TextSlotRows(Settings.schema) end
		return Settings.schema
	end
	local function Options(list)
		local out = {}
		for i, item in ipairs(list) do
			out[i] = { value = item[1], label = item[2] }
		end
		return out
	end

	local GROWTH = Options({ { "DOWN", L["Down"] }, { "UP", L["Up"] }, { "RIGHT", L["Right"] }, { "LEFT", L["Left"] } })
	local PARTY_SORT = Options({ { "INDEX", L["Group order"] }, { "NAME", L["Name"] }, { "ROLE", L["Role"] } })
	local RAID_SORT = Options({ { "GROUP", L["Group"] }, { "ROLE", L["Role"] }, { "CLASS", L["Class"] } })
	local TEXT_LAYOUT = Options({ { "ABOVE", L["Name above the bar"] }, { "INSIDE", L["Name on the bar"] } })
	local HEALTH_TEXT = Options({
		{ "NONE", L["None"] }, { "PERCENT", L["Percent"] }, { "CURRENT", L["Current"] }, { "DEFICIT", L["Missing"] },
		{ "CURRENT_MAX", L["Current and maximum"] }, { "CURRENT_PERCENT", L["Current and percent"] },
	})
	local TEXT_PLACE = Options({ { "ROW", L["Beside the name"] }, { "BAR", L["On the bar"] } })
	local OUTLINE = Options({ { "NONE", L["Soft shadow"] }, { "OUTLINE", L["Thin outline"] }, { "THICKOUTLINE", L["Thick outline"] } })
	local HEALTH_COLOR = Options({ { "class", L["Class colour"] }, { "reaction", L["Reaction colour"] }, { "custom", L["Custom colour"] }, { "gradient", L["By health"] } })
	local TOOLTIP = Options({ { "ALWAYS", L["Always"] }, { "COMBAT", L["Out of combat"] }, { "BOSS", L["Out of boss fights"] }, { "NEVER", L["Never"] } })
	local POWER_COLOR = Options({ { "power", L["Power type colour"] }, { "class", L["Class colour"] }, { "custom", L["Custom colour"] } })
	local NAME_COLOR = Options({ { "text", L["Text colour"] }, { "class", L["Class colour"] }, { "custom", L["Custom colour"] } })
	local ORIENTATION = Options({ { "HORIZONTAL", L["Horizontal"] }, { "VERTICAL", L["Vertical"] } })
	local ACCENT = Options({ { "class", L["Class colour"] }, { "custom", L["Custom colour"] } })
	local AURA_POSITION = Options({
		{ "BOTTOMLEFT", L["Inside, bottom left"] }, { "BOTTOMRIGHT", L["Inside, bottom right"] },
		{ "TOPLEFT", L["Inside, top left"] }, { "TOPRIGHT", L["Inside, top right"] },
		{ "OUTSIDE_RIGHT", L["Outside, right"] }, { "OUTSIDE_LEFT", L["Outside, left"] },
	})
	local AURA_GROWTH = Options({ { "RIGHT", L["Right"] }, { "LEFT", L["Left"] } })
	local AURA_WRAP = Options({ { "DOWN", L["Down"] }, { "UP", L["Up"] } })
	local AURA_FILTER = Options({
		{ "ALL", L["All debuffs"] }, { "RAID", L["Debuffs Blizzard's raid frames show"] }, { "DISPELLABLE", L["Debuffs you can dispel"] },
		{ "BOSS", L["Boss debuffs"] }, { "ROLE", L["Role debuffs"] }, { "CROWD_CONTROL", L["Crowd control"] },
		{ "IMPORTANT", L["Important debuffs"] },
	})
	local TYPE_MODE = Options({ { "HIDE", L["Leave out the types switched off"] }, { "ONLY", L["Only the types switched on"] } })
	local SOURCE = Options({ { "ANY", L["Anyone"] }, { "NPC", L["Enemies, not players"] }, { "PLAYERS", L["Players and their pets"] } })
	local SHIELD_PLACE = Options({ { "BOTTOM", L["Bottom"] }, { "TOP", L["Top"] }, { "LEFT", L["Left"] }, { "RIGHT", L["Right"] } })
	local ABSORB_PLACE = Options({ { "FILL", L["After the health"] }, { "END", L["Back from the bar's end"] } })
	local DISPEL_FILTER = Options({ { "PLAYER", L["Debuffs you can dispel"] }, { "GROUP", L["Debuffs anyone in the group can dispel"] } })
	local PRIORITY = Options({
		{ "BOSS", L["Boss debuffs"] }, { "IMPORTANT", L["Important debuffs"] }, { "DISPEL", L["Debuffs you can dispel"] }, { "OTHER", L["Other debuffs"] },
	})
	local INDICATOR_CATEGORY = Options({
		{ "OFF", L["Off"] }, { "EXTERNAL", L["External defensives"] }, { "BIG_DEFENSIVE", L["Big defensives"] },
		{ "HOTS", L["Your heals over time"] }, { "IMPORTANT", L["Important buffs"] }, { "CROWD_CONTROL", L["Crowd control"] },
		{ "BOSS", L["Boss debuffs"] }, { "DISPEL", L["Debuffs anyone in the group can dispel"] }, { "SPELLS", L["Buffs you choose by spell ID"] },
	})
	local INDICATOR_POSITION = Options({
		{ "TOPLEFT", L["Top left"] }, { "TOP", L["Top"] }, { "TOPRIGHT", L["Top right"] },
		{ "LEFT", L["Left"] }, { "CENTER", L["Centre"] }, { "RIGHT", L["Right"] },
		{ "BOTTOMLEFT", L["Bottom left"] }, { "BOTTOM", L["Bottom"] }, { "BOTTOMRIGHT", L["Bottom right"] },
	})
	local ICON_PLACE = { { value = "AUTO", label = L["Automatic"] } }
	local FILL_STYLE = Options({ { "SOLID", L["Solid"] }, { "STRIPES", L["Patterned"] } })
	local NAME_FORMAT = Options({ { "FULL", L["Whole name"] }, { "FIRST", L["First word"] }, { "LAST", L["Last word"] }, { "ABBR", L["Initials and last word"] } })
	for _, option in ipairs(INDICATOR_POSITION) do ICON_PLACE[#ICON_PLACE + 1] = option end
	local SHOW_ON = Options({ { "BOTH", L["Party and raid frames"] }, { "PARTY", L["Party frames"] }, { "RAID", L["Raid frames"] } })

	Settings.OPTIONS = {
		growth = GROWTH, partySort = PARTY_SORT, raidSort = RAID_SORT, textLayout = TEXT_LAYOUT, healthText = HEALTH_TEXT,
		outline = OUTLINE, healthColor = HEALTH_COLOR, powerColor = POWER_COLOR, nameColor = NAME_COLOR,
		orientation = ORIENTATION, accent = ACCENT,
	}

	local function Is(key, value)
		return function(settings)
			local node = settings
			for part in key:gmatch("[^%.]+") do
				if type(node) == "table" then node = node[part] else node = nil end
			end
			return node == value
		end
	end

	local function IsNot(key, value)
		local test = Is(key, value)
		return function(settings)
			return not test(settings)
		end
	end

	local function Slider(key, label, help, low, high, step, showWhen)
		return { type = "slider", key = key, label = label, help = help, min = low, max = high, step = step, showWhen = showWhen }
	end

	local function Dropdown(key, label, help, options, extra)
		local row = { type = "dropdown", key = key, label = label, help = help, options = options }
		for k, v in pairs(extra or {}) do
			row[k] = v
		end
		return row
	end

	local function Toggle(key, label, help, extra)
		local row = { type = "toggle", key = key, label = label, help = help }
		for k, v in pairs(extra or {}) do
			row[k] = v
		end
		return row
	end

	local function Separate(settings)
		return Is("raid.sortBy", "GROUP")(settings) and not Is("raid.merge", true)(settings)
	end

	local function Portraits(kind)
		local portrait = Is(kind .. ".portrait", true)
		return function(settings)
			return kind == "party" and portrait(settings)
		end
	end

	local function KindRows(schema, kind, label)
		local function add(row)
			schema[#schema + 1] = row
		end
		local p = kind .. "."
		add({ type = "header", label = label })
		add(Slider(p .. "width", L["Frame width"], L["How wide each frame is."], 40, 400, 1))
		add(Slider(p .. "height", L["Frame height"], L["How tall each frame is."], 16, 120, 1))
		add(Slider(p .. "spacing", L["Spacing"], L["The gap between frames."], 0, 40, 1))
		add(Dropdown(p .. "growth", L["Growth"], L["Which way the next frame goes."], GROWTH))
		add(Toggle(p .. "card", L["Card"], L["Seats the frames in a card with a title, as the quest tracker is."]))
		add(Toggle(p .. "roleRing", L["Role rings"], L["A ring in the class colour with the role's letter where the portrait would be."]))
		add(Toggle(p .. "classLine", L["Class and level"], L["A small caption with the member's class and level at the right."]))
		schema[#schema].showWhen = Portraits(kind)
		if kind == "party" then
			add(Dropdown(p .. "sortBy", L["Sort by"], L["The order of the party frames."], PARTY_SORT))
			add(Toggle(p .. "showPlayer", L["Show yourself"], L["Includes your own frame with the party."]))
			add(Toggle(p .. "showSolo", L["Show when solo"], L["Shows your frame even when you are not in a group."]))
			add(Toggle(p .. "centerSolo", L["Centre when solo"], L["Centres your own frame in the party frames' space while you are not in a group."], { showWhen = Is(p .. "showSolo", true) }))
			add(Toggle(p .. "smallRaid", L["Party frames in small raids"], L["In a raid of under 10 players, shows group 1 as party frames. Not in battlegrounds."]))
			add(Toggle(p .. "portrait", L["Portraits"], L["Shows each member's portrait beside the bar."]))
			add(Slider(p .. "portraitZoom", L["Portrait zoom"], L["Crops into each portrait so the face fills more of it."], 0, 0.3, 0.05))
			schema[#schema].showWhen = Is(p .. "portrait", true)
			add(Slider(p .. "portraitRingAlpha", L["Ring opacity"], L["How solid the class ring round each portrait or role ring is."], 0, 1, 0.05))
		else
			add(Dropdown(p .. "sortBy", L["Sort by"], L["Groups side by side, or everyone in role or class order."], RAID_SORT))
			add(Toggle(p .. "merge", L["Merge groups"], L["Runs the groups on in one block, in group order, with no gap between them."], { showWhen = Is(p .. "sortBy", "GROUP") }))
			add(Dropdown(p .. "groupGrowth", L["Group growth"], L["Which way the next group or column goes."], GROWTH))
			add(Slider(p .. "groupSpacing", L["Group spacing"], L["The gap between groups or columns."], 0, 40, 1))
			add(Slider(p .. "groupsPerRow", L["Groups per row"], L["How many groups sit side by side before a new row."], 1, 8, 1))
			schema[#schema].showWhen = Separate
			add(Slider(p .. "unitsPerColumn", L["Frames per column"], L["How many frames fill a column before the next."], 1, 40, 1))
			schema[#schema].showWhen = function(settings) return not Separate(settings) end
			for g = 1, 8 do
				add(Toggle("groups.show" .. g, L["Show group %d"]:format(g), L["Shows this raid group's members. The groups shown close up, in order."]))
			end
			add(Toggle("groups.mythicBench", L["Groups 5 to 8 in Mythic raids"], L["Off hides groups 5 to 8 in a Mythic raid, where only groups 1 to 4 fight."]))
			add(Toggle("groups.hideEmpty", L["Close up empty groups"], L["Moves empty raid groups to the end, so the groups with members sit side by side."], { showWhen = Is(p .. "sortBy", "GROUP") }))
		end
		add(Toggle(p .. "power", L["Power bar"], L["Shows a thin mana, rage or energy bar under the health bar."]))
		add(Slider(p .. "powerHeight", L["Power bar height"], L["The height of the power bar in interface units."], 1, 12, 1))
		schema[#schema].showWhen = Is(p .. "power", true)
		add(Dropdown(p .. "textLayout", L["Name position"], L["Puts the name above the health bar or on it."], TEXT_LAYOUT))
		add(Slider(p .. "nameSize", L["Name size"], L["The size of the name text."], 6, 24, 1))
		add(Slider(p .. "nameChars", L["Name letters"], L["Shortens names to this many letters. 0 keeps whole names."], 0, 20, 1))
		add(Dropdown(p .. "nameFormat", L["Name format"], L["Shows the whole name, its first or last word, or the first words as initials."], NAME_FORMAT))
		add(Dropdown(p .. "healthText", L["Health text"], L["What the health text shows."], HEALTH_TEXT))
		add(Slider(p .. "healthTextSize", L["Health text size"], L["The size of the health text."], 6, 24, 1))
		schema[#schema].showWhen = IsNot(p .. "healthText", "NONE")
		add(Dropdown(p .. "healthTextPlace", L["Health text place"], L["Beside the name, or on the bar so a narrow frame keeps the whole name."], TEXT_PLACE))
		schema[#schema].showWhen = function(settings)
			return IsNot(p .. "healthText", "NONE")(settings) and Is(p .. "textLayout", "ABOVE")(settings) and Portraits(kind)(settings)
		end
		add(Slider(p .. "iconSize", L["Status icon size"], L["The size of the role, leader, marker and ready-check icons."], 6, 32, 1))
		add(Slider(p .. "auraSize", L["Debuff icon size"], L["The size of each debuff icon."], 8, 40, 1))
		add(Slider(p .. "auraCount", L["Debuff count"], L["The most debuffs each frame shows."], 1, 10, 1))
		add(Slider(p .. "auraDispelCount", L["Dispellable debuff count"], L["How many dispellable debuffs show first, before the others."], 0, 4, 1))
		add(Slider(p .. "auraColumns", L["Debuffs per row"], L["How many debuff icons sit in a row."], 1, 10, 1))
		add(Slider(p .. "auraRows", L["Debuff rows"], L["How many rows of debuff icons a frame may show."], 1, 4, 1))
		add(Slider(p .. "auraSpacing", L["Debuff spacing"], L["The gap between debuff icons."], 0, 10, 1))
		add(Dropdown(p .. "auraPosition", L["Debuff position"], L["Where the debuff icons sit on or beside the frame."], AURA_POSITION))
		add(Dropdown(p .. "auraGrowth", L["Debuff growth"], L["Which way the next debuff icon goes."], AURA_GROWTH))
		add(Dropdown(p .. "auraWrap", L["Debuff row growth"], L["Which way a new row of debuff icons goes."], AURA_WRAP))
		add(Slider(p .. "auraX", L["Debuff offset across"], L["Moves the debuff icons left or right from their place."], -60, 60, 1))
		add(Slider(p .. "auraY", L["Debuff offset up"], L["Moves the debuff icons up or down from their place."], -60, 60, 1))
		add(Slider(p .. "buffSize", L["Your heal icon size"], L["The size of each of your heals over time and shields on the frame."], 6, 24, 1))
		add(Slider(p .. "buffCount", L["Your heal icon count"], L["The most of your heals over time and shields each frame shows."], kind == "raid" and 0 or 1, 6, 1))
	end

	local MISFITS = {
		{ "party", L["No room for this indicator on party frames at their size: make party frames taller, give it a smaller size, or turn another indicator off."] },
		{ "raid", L["No room for this indicator on raid frames at their size: make raid frames wider or taller, give it a smaller size, or turn another indicator off."] },
	}

	local function FontOptions()
		local choices = { { value = THEME_FONT, label = L["KstyleUI font"] } }
		for _, choice in ipairs(K.Widgets.MediaOptions("font")) do
			if choice.value ~= THEME_FONT then
				choices[#choices + 1] = choice
			end
		end
		return choices
	end

	moreRows = function(schema)
		local function add(row)
			schema[#schema + 1] = row
			if rows and row.key then rows[row.key] = row end
		end
		local PLACES, AUTO_PLACES = { { value = "NONE", label = L["Off"] } }, { { value = "AUTO", label = L["With the health text"] } }
		for _, option in ipairs(INDICATOR_POSITION) do
			PLACES[#PLACES + 1], AUTO_PLACES[#AUTO_PLACES + 1] = option, option
		end
		local ALIGN = Options({ { "LEFT", L["Left"] }, { "CENTER", L["Centre"] }, { "RIGHT", L["Right"] } })
		local LOOKS = Options({ { "ICON", L["Icon"] }, { "SQUARE", L["Square"] }, { "BAR", L["Bar"] } })
		local function Nudge(key, across, up, showWhen)
			add(Slider(key .. "x", across, L["Moves it left or right from its place."], -50, 50, 1, showWhen))
			add(Slider(key .. "y", up, L["Moves it up or down from its place."], -50, 50, 1, showWhen))
		end
		local placed = Is("icons.role", true)
		After(schema, "icons.roleText", { Dropdown("icons.rolePlace", L["Role icon place"], L["Where on the health bar the role icon sits; Automatic keeps today's place."], ICON_PLACE, { showWhen = placed }),
			Slider("icons.roleX", L["Role icon offset across"], L["Moves it left or right from its place."], -50, 50, 1, placed),
			Slider("icons.roleY", L["Role icon offset up"], L["Moves it up or down from its place."], -50, 50, 1, placed) })
		local marked = function(settings) return settings.icons.marker and settings.icons.markerPlace ~= "AUTO" end
		After(schema, "icons.markerPlace", { Slider("icons.markerX", L["Raid marker offset across"], L["Moves it left or right from its place."], -50, 50, 1, marked),
			Slider("icons.markerY", L["Raid marker offset up"], L["Moves it up or down from its place."], -50, 50, 1, marked) })
		local readied = function(settings) return (settings.icons.readyCheck or settings.icons.statuses) and settings.icons.readyPlace ~= "AUTO" end
		After(schema, "icons.readySize", { Slider("icons.readyX", L["Ready check offset across"], L["Moves it left or right from its place."], -50, 50, 1, readied),
			Slider("icons.readyY", L["Ready check offset up"], L["Moves it up or down from its place."], -50, 50, 1, readied) })
		After(schema, "icons.leaderInCombat", { Slider("icons.leaderX", L["Leader icon offset across"], L["Moves it left or right from its place."], -50, 50, 1, Is("icons.leader", true)),
			Slider("icons.leaderY", L["Leader icon offset up"], L["Moves it up or down from its place."], -50, 50, 1, Is("icons.leader", true)) })
		local combat = function(settings) return settings.icons.combat end
		After(schema, "icons.combatSize", { Slider("icons.combatX", L["Combat icon offset across"], L["Moves it left or right from its place."], -50, 50, 1, combat),
			Slider("icons.combatY", L["Combat icon offset up"], L["Moves it up or down from its place."], -50, 50, 1, combat) })
		for _, kind in ipairs({ "party", "raid" }) do
			After(schema, kind .. ".buffCount", { Slider(kind .. ".buffX", L["Heal icon offset across"], L["Moves your heal icons left or right from their place."], -100, 100, 1),
				Slider(kind .. ".buffY", L["Heal icon offset up"], L["Moves your heal icons up or down from their place."], -100, 100, 1) })
		end
		local above = Is("text.above", true)
		After(schema, "text.above", { Toggle("text.aboveName", L["Names above icons"], L["Draws names over the icons while Text above icons is on."], { showWhen = above }),
			Toggle("text.aboveHealth", L["Health text above icons"], L["Draws the health text over the icons while Text above icons is on."], { showWhen = above }),
			Toggle("text.aboveExtra", L["Extra texts above icons"], L["Draws extra texts 1 and 2 over the icons while Text above icons is on."], { showWhen = above }) })
		local striped = function(settings) return settings.prediction.healAbsorbStyle == "STRIPES" or settings.prediction.maxLoss == "STRIPES" end
		After(schema, "prediction.backing", { Toggle("prediction.backingOwn", L["Own backings"], L["Gives heal absorbs and lost maximum health a backing opacity each."], { showWhen = striped }),
			Slider("prediction.healAbsorbBacking", L["Heal absorb backing"], L["How solid the fill under patterned heal absorbs is."], 0, 1, 0.05,
				function(settings) return settings.prediction.backingOwn and settings.prediction.healAbsorbStyle == "STRIPES" end),
			Slider("prediction.maxLossBacking", L["Lost maximum health backing"], L["How solid the fill under patterned lost maximum health is."], 0, 1, 0.05,
				function(settings) return settings.prediction.backingOwn and settings.prediction.maxLoss == "STRIPES" end) })
		local each = Is("auras.zoomEach", true)
		After(schema, "auras.zoom", { Toggle("auras.zoomEach", L["Zoom for each kind"], L["Gives boss debuff and heal icons a zoom of their own."]),
			Slider("auras.bossZoom", L["Boss debuff zoom"], L["How far into its artwork the boss debuff icon crops."], 0, 0.2, 0.01, each),
			Slider("buffs.zoom", L["Heal icon zoom"], L["How far into its artwork each heal icon crops."], 0, 0.2, 0.01, each) })
		After(schema, "auras.tipCombat", { Toggle("auras.tipCursor", L["Aura tooltips at the cursor"], L["Shows debuff, heal and indicator tooltips at the mouse pointer."]) })
		local stacked, timed = Is("auras.stacks", true), Is("auras.timers", true)
		After(schema, "auras.stacks", { Slider("auras.countX", L["Stack offset across"], L["Moves it left or right from its place."], -20, 20, 1, stacked),
			Slider("auras.countY", L["Stack offset up"], L["Moves it up or down from its place."], -20, 20, 1, stacked) })
		After(schema, "auras.timerSize", { Slider("auras.timerX", L["Time left offset across"], L["Moves it left or right from its place."], -20, 20, 1, timed),
			Slider("auras.timerY", L["Time left offset up"], L["Moves it up or down from its place."], -20, 20, 1, timed) })
		for i = 1, INDICATOR_SLOTS do
			local p, key, on = "indicator" .. i .. ".", "indicator" .. i, IsNot("indicator" .. i .. ".category", "OFF")
			local styled, barred = function(s) return on(s) and s[key].style ~= "ICON" end, function(s) return on(s) and s[key].style == "BAR" end
			After(schema, p .. "mine", { Slider(p .. "x", L["Offset across"], L["Moves it left or right from its place."], -50, 50, 1, on),
				Slider(p .. "y", L["Offset up"], L["Moves it up or down from its place."], -50, 50, 1, on),
				Dropdown(p .. "style", L["Look"], L["The aura's icon, a square in one colour, or a bar on the health bar's edge that drains as it ends."], LOOKS, { showWhen = on }),
				{ type = "color", key = p .. "color", label = L["Colour"], help = L["The colour of the square or bar."], showWhen = styled },
				Slider(p .. "thick", L["Bar thickness"], L["How thick the bar is, never thicker than the health bar."], 1, 20, 1, barred),
				Toggle(p .. "reverse", L["Reverse fill"], L["The bar fills from the other end."], { showWhen = barred }),
				Toggle(p .. "over", L["Bar over the debuff icons"], L["Draws the bar over debuff and heal icons. Off, it sits under them, over the health bar."], { showWhen = barred }) })
		end
		After(schema, "raid.groupsPerRow", { Toggle("raid.center", L["Centre groups"], L["Centres the raid groups with members along their row, out of combat."], { showWhen = Separate }) })
		local reminding = IsNot("reminders.place", "NONE")
		add({ type = "header", label = L["Missing buffs"] })
		add(Dropdown("reminders.place", L["Missing buffs"], L["Shows a buff you can cast on members who lack it, except while the game hides auras."], PLACES))
		add(Slider("reminders.size", L["Missing buff size"], L["The missing buff icon's size."], 8, 40, 1, reminding))
		for _, buff in ipairs({ { "fortitude", L["Fortitude"] }, { "wild", L["Mark of the Wild"] }, { "intellect", L["Arcane Intellect"] },
			{ "spirit", L["Divine Spirit"] }, { "thorns", L["Thorns"] }, { "salvation", L["Salvation"] } }) do
			add(Toggle("reminders." .. buff[1], buff[2], L["Reminds you of this buff; only buffs you know show."], { showWhen = reminding }))
		end
		add(Toggle("reminders.thornsTank", L["Thorns only on tanks"], L["Thorns shows on tanks, or on you when the group has no tank."], { showWhen = reminding }))
		add(Toggle("reminders.glow", L["Missing buff glow"], L["A soft glow round the missing buff icon, so it catches the eye."], { showWhen = reminding }))
		Nudge("reminders.", L["Missing buff offset across"], L["Missing buff offset up"], reminding)
		add({ type = "header", label = L["Status text"] })
		add(Dropdown("status.place", L["Status text place"], L["Where Dead, Ghost and Offline sit on the health bar."], AUTO_PLACES))
		add(Slider("status.size", L["Status text size"], L["The size of Dead, Ghost and Offline; 0 uses the health text's size."], 0, 30, 1))
		Nudge("status.", L["Status text offset across"], L["Status text offset up"], IsNot("status.place", "AUTO"))
		add({ type = "header", label = L["Dispel type"] })
		add(Dropdown("dispel.icon", L["Dispel type icon"], L["Shows the type icon of a debuff you can dispel on the health bar. Off shows none."], PLACES))
		add(Slider("dispel.iconSize", L["Dispel type icon size"], L["The dispel type icon's size."], 8, 40, 1, IsNot("dispel.icon", "NONE")))
		Nudge("dispel.", L["Dispel type icon offset across"], L["Dispel type icon offset up"], IsNot("dispel.icon", "NONE"))
		add(Toggle("dispel.iconBorder", L["Debuff type border"], L["Outlines each debuff icon in its type's colour. Off keeps the plain border."]))
		add(Toggle("dispel.custom", L["Own dispel colours"], L["Colours the highlight, the debuff borders and the type icon in the colours below."]))
		for _, kind in ipairs({ { "magic", L["Magic colour"] }, { "curse", L["Curse colour"] }, { "poison", L["Poison colour"] }, { "disease", L["Disease colour"] }, { "bleed", L["Bleed colour"] } }) do
			add({ type = "color", key = "dispel." .. kind[1], label = kind[2], help = L["The colour of this debuff type."], showWhen = Is("dispel.custom", true) })
		end
		add({ type = "header", label = L["Names above the bar"] })
		add(Dropdown("names.align", L["Name alignment"], L["Lines names above the bar up at the left, centre or right; Automatic keeps today's place."],
			{ { value = "AUTO", label = L["Automatic"] }, ALIGN[1], ALIGN[2], ALIGN[3] }))
		add(Toggle("names.divider", L["Name divider"], L["A thin line between the name and the health bar."]))
		add(Toggle("names.dividerAccent", L["Divider in the highlight colour"], L["Draws the divider in the hover and target highlight colour."], { showWhen = Is("names.divider", true) }))
		add(Slider("names.height", L["Name line height"], L["The height of the name line above the bar; 0 sizes it to the name."], 0, 40, 1))
		Nudge("names.", L["Name offset across"], L["Name offset up"])
		add({ type = "header", label = L["Group numbers"] })
		add(Toggle("numbers.show", L["Group numbers"], L["Numbers each raid group above its frames while raid frames sit in groups."]))
		add(Slider("numbers.size", L["Group number size"], L["The size of the group numbers."], 6, 30, 1, Is("numbers.show", true)))
		Nudge("numbers.", L["Group number offset across"], L["Group number offset up"], Is("numbers.show", true))
		local mana = IsNot("mana.mode", "NONE")
		add({ type = "header", label = L["Healer mana"] })
		add(Dropdown("mana.mode", L["Healer mana"], L["A movable list of your group's healers and their mana. Place it in Layout Mode."],
			Options({ { "NONE", L["Off"] }, { "PARTY", L["In a party"] }, { "RAID", L["In a raid"] }, { "BOTH", L["In a party or raid"] } })))
		add(Slider("mana.size", L["Healer mana text size"], L["The size of each healer's line."], 8, 24, 1, mana))
		add(Slider("mana.spacing", L["Healer mana spacing"], L["The gap between healers' lines."], 0, 12, 1, mana))
		add(Dropdown("mana.align", L["Healer mana alignment"], L["Lines the healers' lines up at the left, centre or right."], ALIGN, { showWhen = mana }))
		add(Dropdown("mana.growth", L["Healer mana growth"], L["Which way the list grows as healers join."], Options({ { "DOWN", L["Down"] }, { "UP", L["Up"] } }), { showWhen = mana }))
		add(Toggle("mana.names", L["Healer names in a raid"], L["Puts each healer's name before the mana in a raid; a party shows the mana alone."], { showWhen = mana }))
		add(Dropdown("mana.colorSource", L["Healer mana colour"], L["Colours the mana in the mana colour or in one colour."], Options({ { "power", L["Power type colour"] }, { "custom", L["Custom colour"] } }), { showWhen = mana }))
		add({ type = "color", key = "mana.color", label = L["Custom healer mana colour"], help = L["The mana's colour when it uses a custom colour."], showWhen = function(settings)
			return mana(settings) and Is("mana.colorSource", "custom")(settings)
		end })
		local label = Is("label.enabled", true)
		add({ type = "header", label = L["Your group label"] })
		add(Toggle("label.enabled", L["Your group label"], L["A movable label with your raid group's number. Place it in Layout Mode."]))
		add(Dropdown("label.format", L["Label text"], L["The number alone, or the word Group with it."], Options({ { "NUMBER", "3" }, { "FULL", GROUP_NUMBER and GROUP_NUMBER:format(3) or "3" } }), { showWhen = label }))
		add(Slider("label.size", L["Label text size"], L["The size of the label's text."], 6, 40, 1, label))
		add(Slider("label.padding", L["Label padding"], L["The room between the label's text and its plate."], 0, 20, 1, label))
		add({ type = "color", key = "label.color", label = L["Label text colour"], help = L["The colour of the label's text."], showWhen = label })
		local function Extra(p, on)
			add(Slider(p .. "width", L["Extra width"], L["Widens these frames from the raid frames' width, or narrows them below 0."], -50, 100, 1, on))
			add(Slider(p .. "height", L["Extra height"], L["Makes these frames taller than the raid frames, or shorter below 0."], -20, 100, 1, on))
		end
		local pets = Is("pets.enabled", true)
		add({ type = "header", label = L["Pet frames"] })
		add(Toggle("pets.enabled", L["Pet frames"], L["Your group's pets in frames of their own. Place them in Layout Mode, or attach them to a side."]))
		add(Dropdown("pets.nameColor", L["Pet name colour"], L["Colours pet names like the raid frames' names, in the text colour or in one colour."],
			Options({ { "raid", L["Like the raid frames"] }, { "text", L["Text colour"] }, { "custom", L["Custom colour"] } }), { showWhen = pets }))
		add({ type = "color", key = "pets.color", label = L["Custom pet name colour"], help = L["The pet names' colour when they use a custom colour."], showWhen = function(s) return pets(s) and s.pets.nameColor == "custom" end })
		Extra("pets.", pets)
		local tanks = Is("tanks.enabled", true)
		add({ type = "header", label = L["Tank frames"] })
		add(Toggle("tanks.enabled", L["Tank frames"], L["The raid's tanks again in frames of their own, in a raid. Place them in Layout Mode."]))
		add(Dropdown("tanks.growth", L["Growth"], L["Which way the next frame goes."], GROWTH, { showWhen = tanks }))
		add(Dropdown("tanks.wrap", L["Wrap direction"], L["Which way a new column or row goes once Wrap after is set."], GROWTH, { showWhen = tanks }))
		add(Slider("tanks.wrapAfter", L["Wrap after"], L["How many frames fill a line before the next; 0 keeps them in one line."], 0, 8, 1, tanks))
		Extra("tanks.", tanks)
		local boss = IsNot("boss.display", "NEVER")
		add({ type = "header", label = L["Friendly boss frames"] })
		add(Dropdown("boss.display", L["Friendly boss frames"], L["Frames for bosses you can help, such as one to heal, in a raid. Place them in Layout Mode."],
			Options({ { "NEVER", L["Never"] }, { "HEALERS", L["While you heal"] }, { "ALWAYS", L["Always"] } })))
		add(Toggle("boss.dungeons", L["Show in dungeons"], L["Also shows friendly bosses in a party, not only in a raid."], { showWhen = boss }))
		add(Dropdown("boss.colorSource", L["Boss bar colour"], L["Colours the bars in the friendly colour, or like the raid frames' bars."],
			Options({ { "reaction", L["Friendly colour"] }, { "raid", L["Like the raid frames"] } }), { showWhen = boss }))
		Extra("boss.", boss)
		add({ type = "header", label = L["Class order"] })
		add(Toggle("sort.classFirst", L["Sort by class first"], L["Sorts each group's members by the class order below; role order still comes first."]))
		local classes, names = {}, type(LOCALIZED_CLASS_NAMES_MALE) == "table" and LOCALIZED_CLASS_NAMES_MALE or {}
		for i, class in ipairs(Settings.CLASSES) do classes[i] = { value = class, label = names[class] or class } end
		add(Dropdown("sort.classFirstIn", L["Sort by class first in"], L["Sorts party frames, raid frames or both by class first."], SHOW_ON, { showWhen = Is("sort.classFirst", true) }))
		local ordered = function(settings) return settings.sort.classFirst or settings.raid.sortBy == "CLASS" end
		for i = 1, #classes do
			add(Dropdown("sort.class" .. i, L["Class %d"]:format(i), L["Which class takes this place; a repeat's place goes to the class the list leaves out."], classes, { showWhen = ordered }))
		end
		local partyFirst = function(settings) return settings.sort.classFirst and settings.sort.classFirstIn ~= "RAID" end
		add(Toggle("sort.partyOwn", L["Own party class order"], L["Party frames follow a class order of their own; off, they follow the list above."], { showWhen = partyFirst }))
		for i = 1, #classes do
			add(Dropdown("sort.partyClass" .. i, L["Party class %d"]:format(i), L["The class in this place on party frames; a repeat's place goes to the one left out."], classes,
				{ showWhen = function(settings) return partyFirst(settings) and settings.sort.partyOwn end }))
		end
		After(schema, "prediction.glow", { Toggle("prediction.edge", L["Shield edge"], L["A bright line where a shield meets the health."], { showWhen = Is("prediction.absorbs", true) }) })
		After(schema, "icons.roleText", { Toggle("icons.roleBehind", L["Role icons under the highlights"], L["Draws role icons under the hover line, the names and the target ring."], { showWhen = placed }) })
		After(schema, "tanks.wrapAfter", { Toggle("tanks.excludeSelf", L["Leave yourself out"], L["Keeps your own frame out of the tank frames. Changes in combat follow when it ends."], { showWhen = tanks }) })
		local custom = function(settings) return settings.auto.size and settings.auto.customLeast > 0 end
		After(schema, "auto.largeLeast", { Slider("auto.customLeast", L["Own size from"], L["From this many players, raid frames take the size below; 0 turns it off. Compact frames still win."], 0, 40, 1, Is("auto.size", true)),
			Slider("auto.customWidth", L["Own size: width"], L["The frames' width at this raid size; 0 sizes them automatically."], 0, 400, 1, custom),
			Slider("auto.customHeight", L["Own size: height"], L["The frames' height at this raid size; 0 sizes them automatically."], 0, 120, 1, custom),
			Slider("auto.customX", L["Own size: X offset"], L["Moves the raid frames right, or left below 0, at this raid size."], -400, 400, 1, custom),
			Slider("auto.customY", L["Own size: Y offset"], L["Moves the raid frames up, or down below 0, at this raid size."], -400, 400, 1, custom) })
		local follows = {}
		for section, keys in pairs(Settings.FOLLOW) do
			for _, key in ipairs(keys) do follows[key] = section end
		end
		for _, row in ipairs(schema) do
			local section = row.key and follows[row.key:match("^party%.(%w+)$")]
			if section then
				local own = row.showWhen
				row.showWhen = function(settings) return not (settings.follow and settings.follow[section]) and (not own or own(settings)) end
			end
		end
		After(schema, "party.showPlayer", { Toggle("follow.text", L["Use the raid's text"], L["Party frames take the raid frames' name and health text settings."]),
			Toggle("follow.auras", L["Use the raid's debuffs"], L["Party frames take the raid frames' debuff icon settings."]),
			Toggle("follow.heals", L["Use the raid's heal icons"], L["Party frames take the raid frames' heal icon settings."]),
			Toggle("follow.icons", L["Use the raid's status icon size"], L["Party frames take the raid frames' status icon size."]),
			Toggle("follow.power", L["Use the raid's power bar"], L["Party frames take the raid frames' power bar settings."]) })
	end

	local function BuildSchema()
		local schema = {}
		local function add(row)
			schema[#schema + 1] = row
		end
		add({ type = "header", label = L["Group preset"] })
		add(Dropdown("presets.raid", L["Raid preset"], L["Healer keeps missing health and priority indicators visible in a full raid."], Options({ { "Compact", L["Compact"] }, { "Healer", L["Healer"] } })))
		add({ type = "header", label = L["Blizzard frames"] })
		add(Toggle("blizzard.party", L["Hide Blizzard party frames"], L["Hides the game's own party frames while these are on."]))
		add(Toggle("blizzard.raid", L["Hide Blizzard raid frames"], L["Hides the game's own raid frames while these are on."]))
		add(Toggle("blizzard.keepManager", L["Keep raid tools available"], L["Keeps the game's raid controls available. Off restores the previous hidden raid manager."]))
		KindRows(schema, "party", L["Party frames"])
		add({ type = "header", label = L["Party targets"] })
		local targets = Is("targets.enabled", true)
		add(Toggle("targets.enabled", L["Party targets"], L["A small frame beside each party member for what they target; click it to target that too."]))
		add(Toggle("targets.self", L["Include your own target"], L["Also shows your own target beside your frame."], { showWhen = targets }))
		add(Slider("targets.width", L["Target width"], L["How wide each target frame is."], 30, 200, 1))
		add(Slider("targets.height", L["Target height"], L["How tall each target frame is."], 12, 60, 1))
		add(Slider("targets.x", L["Target offset across"], L["Moves the target frames left or right from their place."], -100, 100, 1))
		add(Slider("targets.y", L["Target offset up"], L["Moves the target frames up or down from their place."], -100, 100, 1))
		for i = #schema - 3, #schema do schema[i].showWhen = targets end
		add(Dropdown("targets.nameColor", L["Target name colour"], L["Colours target names in the text colour, by class for players or in one colour."], NAME_COLOR, { showWhen = targets }))
		add({ type = "color", key = "targets.color", label = L["Custom target name colour"], help = L["The target names' colour when they use a custom colour."], showWhen = function(s) return targets(s) and s.targets.nameColor == "custom" end })
		KindRows(schema, "raid", L["Raid frames"])
		add({ type = "header", label = L["Health bar"] })
		K.Widgets.BarRows(schema, "health", { options = HEALTH_COLOR, custom = Is("health.colorSource", "custom"),
			help = { texture = L["The texture of the health and power bars."] } })
		local gradient = Is("health.colorSource", "gradient")
		add({ type = "color", key = "health.gradientHigh", label = L["Full health colour"], help = L["The bar's colour at full health; it blends toward the half health colour as health falls."], showWhen = gradient })
		add({ type = "color", key = "health.gradientMid", label = L["Half health colour"], help = L["The bar's colour at half health."], showWhen = gradient })
		add({ type = "color", key = "health.gradientLow", label = L["Low health colour"], help = L["The bar's colour as health runs out."], showWhen = gradient })
		add(Slider("health.gradientLowAt", L["Low threshold"], L["At or below this health percentage the low health colour holds."], 0, 20, 1))
		schema[#schema].showWhen = gradient
		add(Slider("health.gradientHighAt", L["High threshold"], L["At or above this health percentage the full health colour holds."], 80, 100, 1))
		schema[#schema].showWhen = gradient
		add(Slider("health.alpha", L["Fill opacity"], L["How solid the health fill is."], 0.1, 1, 0.05))
		add(Dropdown("health.orientation", L["Fill direction"], L["Fills the health bar from left to right or from the bottom up."], ORIENTATION))
		add(Toggle("health.missing", L["Fill missing health"], L["The bar fills with the health a member has lost, growing as they take damage."]))
		add(Toggle("health.statusGrey", L["Grey dead and offline bars"], L["Off paints the bars of dead and offline members in colours you choose."]))
		add({ type = "color", key = "health.deadColor", label = L["Dead colour"], help = L["The bar's colour while a member is dead or a ghost."], showWhen = Is("health.statusGrey", false) })
		add({ type = "color", key = "health.offlineColor", label = L["Offline colour"], help = L["The bar's colour while a member is offline."], showWhen = Is("health.statusGrey", false) })
		add({ type = "header", label = L["Power bar"] })
		K.Widgets.BarRows(schema, "power", { texture = false, options = POWER_COLOR, custom = Is("power.colorSource", "custom") })
		add(Toggle("power.tanks", L["Power bar for tanks"], L["Shows the power bar on tanks' frames; off gives their health bar the room."]))
		add(Toggle("power.healers", L["Power bar for healers"], L["Shows the power bar on healers' frames; off gives their health bar the room."]))
		add(Toggle("power.damagers", L["Power bar for damage dealers"], L["Shows the power bar on damage dealers' frames; off gives their health bar the room."]))
		add(Toggle("power.keepRoom", L["Keep the power bar's room"], L["Frames without a power bar keep its room, so every frame's bar, icons and text line up."]))
		add(Toggle("power.behind", L["Health bar behind the power bar"], L["The health bar runs the frame's full height and the power bar lies over its foot."]))
		add({ type = "header", label = L["Text"] })
		add({ type = "font", key = "text.nameFont", label = L["Name font"], help = L["The font of the names."], options = FontOptions })
		add(Dropdown("text.nameOutline", L["Name outline"], L["A soft shadow, or an outline for busy backgrounds."], OUTLINE))
		add(Dropdown("text.nameColorSource", L["Name colour"], L["Colours names in the text colour, by class or in one colour."], NAME_COLOR))
		add({ type = "color", key = "text.nameColor", label = L["Custom name colour"], help = L["The names' colour when they use a custom colour."], showWhen = Is("text.nameColorSource", "custom") })
		add({ type = "font", key = "text.healthFont", label = L["Health text font"], help = L["The font of the health text."], options = FontOptions })
		add(Dropdown("text.healthOutline", L["Health text outline"], L["A soft shadow, or an outline for busy backgrounds."], OUTLINE))
		add(Toggle("text.above", L["Text above icons"], L["Draws names and health text over the debuff and indicator icons, not under them."]))
		add({ type = "header", label = L["Status icons"] })
		add(Toggle("layout.tidyLanes", L["Tidy Medallions lanes"], L["Separates names, indicators and percentages, with metal role pips. Off restores the earlier layout."]))
		add(Toggle("icons.role", L["Role icons"], L["Shows whether each party member is a tank, healer or damage dealer. Raid tiles leave it out."]))
		add(Toggle("icons.roleShapes", L["Role shapes"], L["Uses distinct role symbols on compact frames. Off restores the coloured pips."]))
		local roles = Is("icons.role", true)
		add(Toggle("icons.roleTank", L["Tank role icons"], L["Shows the role icon on tanks."], { showWhen = roles }))
		add(Toggle("icons.roleHealer", L["Healer role icons"], L["Shows the role icon on healers."], { showWhen = roles }))
		add(Toggle("icons.roleDamager", L["Damage role icons"], L["Shows the role icon on damage dealers."], { showWhen = roles }))
		add(Toggle("icons.roleInCombat", L["Role icons in combat"], L["Off hides role icons while you are in combat."], { showWhen = roles }))
		add(Toggle("icons.roleText", L["Role letters"], L["Shows T, H or D in the role's colour instead of the role icon."], { showWhen = roles }))
		add(Toggle("icons.leader", L["Leader icons"], L["Marks the group leader and raid assistants."]))
		add(Toggle("icons.leaderInCombat", L["Leader icons in combat"], L["Off hides leader and assistant icons while you are in combat."], { showWhen = Is("icons.leader", true) }))
		add(Toggle("icons.marker", L["Raid markers"], L["Shows the raid marker, such as a skull, set on a member."]))
		add(Dropdown("icons.markerPlace", L["Raid marker place"], L["Where on the health bar the raid marker sits; Automatic keeps today's place."], ICON_PLACE, { showWhen = Is("icons.marker", true) }))
		add(Toggle("icons.readyCheck", L["Ready checks"], L["Shows each member's answer during a ready check."]))
		add(Toggle("icons.statuses", L["Resurrection, summon and AFK"], L["Shows these states in the ready-check space. Off leaves only ready checks."]))
		add(Toggle("icons.afk", L["AFK indicator"], L["Marks members who are away from their keyboard."], { showWhen = Is("icons.statuses", true) }))
		add(Toggle("icons.resurrection", L["Incoming resurrection"], L["Marks members with a resurrection on the way."], { showWhen = Is("icons.statuses", true) }))
		add(Toggle("icons.summon", L["Incoming summon"], L["Marks members with a summon on the way."], { showWhen = Is("icons.statuses", true) }))
		local readySpace = function(settings) return Is("icons.readyCheck", true)(settings) or Is("icons.statuses", true)(settings) end
		add(Dropdown("icons.readyPlace", L["Ready check place"], L["Where on the health bar the ready check, resurrection, summon and AFK icons sit."], ICON_PLACE, { showWhen = readySpace }))
		add(Slider("icons.readySize", L["Ready check size"], L["The size of those icons; 0 sizes them to the bar."], 0, 40, 1))
		schema[#schema].showWhen = readySpace
		add(Toggle("icons.combat", L["Combat icon"], L["Shows crossed swords on members who are in combat."]))
		local combat = Is("icons.combat", true)
		add(Dropdown("icons.combatPlace", L["Combat icon place"], L["Where on the health bar the combat icon sits."], INDICATOR_POSITION, { showWhen = combat }))
		add(Slider("icons.combatSize", L["Combat icon size"], L["The size of the combat icon."], 8, 40, 1))
		schema[#schema].showWhen = combat
		add(Toggle("icons.combatClass", L["Class-coloured combat icon"], L["Tints the combat icon in the member's class colour."], { showWhen = combat }))
		add(Toggle("threat.enabled", L["Threat border"], L["Draws a border in the threat colour around members with aggro."]))
		add(Toggle("threat.shapes", L["Threat shapes"], L["Adds a tick, triangle or square beside the threat border. Off keeps the border alone."]))
		add(Toggle("threat.edge", L["Threat edge"], L["Colours a tiled frame's own edge in the threat colour; rows without a tile keep the border."], { showWhen = Is("threat.enabled", true) }))
		add({ type = "header", label = L["Debuffs"] })
		add(Toggle("auras.enabled", L["Debuff icons"], L["Shows a few debuffs on each frame."]))
		add(Toggle("auras.typeLetters", L["Debuff type letters"], L["Adds M, C, D, P or E when the game knows the debuff type. Off keeps the usual border."]))
		add(Toggle("auras.stacks", L["Stacks"], L["Shows how many times a debuff has stacked."]))
		add(Toggle("auras.timers", L["Time left"], L["Shows the time left on each aura."]))
		add(Slider("auras.timerSize", L["Time left size"], L["The size of the time left; 0 sizes it to the icon."], 0, 24, 1))
		schema[#schema].showWhen = Is("auras.timers", true)
		add(Dropdown("auras.filter", L["Which debuffs"], L["All debuffs, the ones raid frames show, the ones you can dispel, or one kind."], AURA_FILTER))
		K.Options.AuraFilterRows(schema, "auras", { dispellable = false, disableWhen = Is("auras.enabled", false) })
		add(Dropdown("auras.source", L["Debuffs from"], L["Debuffs from anyone, only from enemies, or only from players and their pets."], SOURCE, { disableWhen = Is("auras.enabled", false) }))
		add(Toggle("auras.canApply", L["Only debuffs you can apply"], L["Shows only debuffs your class can put on a target."], { disableWhen = Is("auras.enabled", false) }))
		for _, kind in ipairs({ { "magic", L["Magic debuffs"] }, { "curse", L["Curse debuffs"] }, { "poison", L["Poison debuffs"] }, { "disease", L["Disease debuffs"] }, { "bleed", L["Bleed debuffs"] } }) do
			add(Toggle("auras." .. kind[1], kind[2], L["Shows debuffs of this type; off leaves them out of every debuff row."], { disableWhen = Is("auras.enabled", false) }))
		end
		add(Dropdown("auras.typeMode", L["Debuff types"], L["Leaves out the types switched off, or shows only debuffs of the types switched on."], TYPE_MODE, { disableWhen = Is("auras.enabled", false) }))
		add(Toggle("auras.lasting", L["Debuffs that last until removed"], L["Shows debuffs that never expire; off leaves them out of every debuff row."], { disableWhen = Is("auras.enabled", false) }))
		add(Toggle("auras.swipe", L["Duration swipe"], L["Darkens each debuff icon as it runs out."]))
		add(Slider("auras.zoom", L["Icon zoom"], L["How far into its artwork each debuff and heal icon crops."], 0, 0.2, 0.01))
		add(Toggle("auras.tooltips", L["Debuff tooltips"], L["Shows a debuff's tooltip when you point at its icon."]))
		add(Toggle("auras.tipCombat", L["Aura tooltips in combat"], L["Off keeps debuff, heal and indicator tooltips hidden while you are in combat."]))
		add(Dropdown("auras.textOutline", L["Icon text outline"], L["The outline of the stack count and time left on debuff, heal and indicator icons."], OUTLINE))
		add(Toggle("auras.dispelHighlight", L["Dispel highlight"], L["Outlines a frame in the debuff type's colour when it can be dispelled."]))
		add(Dropdown("auras.dispelFilter", L["Highlight debuffs"], L["Highlights debuffs you can dispel, or ones anyone in the group can."], DISPEL_FILTER))
		schema[#schema].showWhen = Is("auras.dispelHighlight", true)
		add(Slider("auras.dispelAlpha", L["Highlight fill opacity"], L["How strongly the debuff type's colour tints the frame."], 0, 0.5, 0.02))
		schema[#schema].showWhen = Is("auras.dispelHighlight", true)
		add(Slider("auras.dispelLines", L["Highlight outline"], L["The highlight's outline: two lines, one, or none for the tint alone."], 0, 2, 1))
		schema[#schema].showWhen = Is("auras.dispelHighlight", true)
		add({ type = "header", label = L["Debuff priority"] })
		for i = 1, #PRIORITY do
			add(Dropdown("auras.priority" .. i, L["Priority"] .. " " .. i, L["Which debuffs take this place in the row; a repeat counts once."], PRIORITY))
		end
		add(Toggle("auras.glow", L["Glow on boss and important debuffs"], L["A red glow around a member with a boss or important debuff."]))
		add({ type = "header", label = L["Indicators"] })
		for i = 1, INDICATOR_SLOTS do
			local p = "indicator" .. i .. "."
			local on = IsNot(p .. "category", "OFF")
			add(Dropdown(p .. "category", L["Indicator"] .. " " .. i, L["What this indicator shows; slots sharing a place sit side by side."], INDICATOR_CATEGORY))
			add(Dropdown(p .. "position", L["Place"], L["Where on the frame the indicator sits."], INDICATOR_POSITION, { showWhen = on }))
			add(Dropdown(p .. "show", L["Show on"], L["Shows this indicator on party and raid frames, or on one kind only."], SHOW_ON, { showWhen = on }))
			add(Slider(p .. "size", L["Size"], L["The indicator's icon size."], 6, 32, 1))
			schema[#schema].showWhen = function(s) return on(s) and s["indicator" .. i].style ~= "BAR" end
			add(Toggle(p .. "mine", L["Only yours"], L["Shows only auras you cast."], { showWhen = on }))
			add({ type = "text", key = p .. "spells", label = L["Spell IDs"], help = L["Buff spell IDs, separated by commas, such as 774, 139."], maxLetters = 120, showWhen = Is(p .. "category", "SPELLS") })
			for _, misfit in ipairs(MISFITS) do
				local kind = misfit[1]
				add({ type = "note", label = misfit[2], showWhen = function()
					return ns.Slots ~= nil and ns.Slots.Misfit(kind, i) == true
				end })
			end
		end
		add({ type = "header", label = L["Your heals over time"] })
		add(Toggle("buffs.enabled", L["Your heals over time"], L["Shows your own heals over time and shields beside or under the health bar, never on it."]))
		add(Toggle("buffs.tooltips", L["Heal icon tooltips"], L["Shows a heal's tooltip when you point at its icon."], { showWhen = Is("buffs.enabled", true) }))
		add({ type = "header", label = L["Automatic layout"] })
		add(Toggle("auto.size", L["Size by raid size"], L["Larger raid frames up to 10 players; over 25, shorter ones without power bars or health text."]))
		local sized = Is("auto.size", true)
		add(Slider("auto.smallMost", L["Larger frames up to"], L["The most players a raid may have and still get the larger frames."], 5, 14, 1))
		schema[#schema].showWhen = sized
		add(Slider("auto.largeLeast", L["Compact frames from"], L["The fewest players a raid needs for the compact frames."], 21, 40, 1))
		schema[#schema].showWhen = sized
		add(Toggle("auto.shownOnly", L["Count only shown groups"], L["Sizes the raid by the members in the groups you show, not by everyone."], { showWhen = sized }))
		add(Toggle("auto.icons", L["Resize icons with the frames"], L["Debuff icons and indicators grow and shrink with the larger and compact frames."], { showWhen = sized }))
		add(Toggle("auto.heals", L["Resize heal icons with the frames"], L["Your heal icons grow and shrink with the larger and compact frames."], { showWhen = sized }))
		for _, size in ipairs({ { "small", L["Larger frames: width"], L["Larger frames: height"], L["Larger frames: X offset"], L["Larger frames: Y offset"] },
			{ "large", L["Compact frames: width"], L["Compact frames: height"], L["Compact frames: X offset"], L["Compact frames: Y offset"] } }) do
			add(Slider("auto." .. size[1] .. "Width", size[2], L["The frames' width at this raid size; 0 sizes them automatically."], 0, 400, 1))
			schema[#schema].showWhen = sized
			add(Slider("auto." .. size[1] .. "Height", size[3], L["The frames' height at this raid size; 0 sizes them automatically."], 0, 120, 1))
			schema[#schema].showWhen = sized
			add(Slider("auto." .. size[1] .. "X", size[4], L["Moves the raid frames right, or left below 0, at this raid size."], -400, 400, 1))
			schema[#schema].showWhen = sized
			add(Slider("auto." .. size[1] .. "Y", size[5], L["Moves the raid frames up, or down below 0, at this raid size."], -400, 400, 1))
			schema[#schema].showWhen = sized
		end
		add(Toggle("auto.role", L["Healer frames when you heal"], L["As a healer: two dispellable debuffs first and three of your heals, on wider raid frames."]))
		add({ type = "header", label = L["Click casting"] })
		add(Toggle("clickCast.hint", L["Click casting reminder"], L["Points the tooltip to the game's Click Casting, which these frames use, until you bind a spell."]))
		add(Dropdown("tooltip.mode", L["Member tooltips"], L["When the member's tooltip shows as you point at a frame."], TOOLTIP))
		add({ type = "header", label = L["Incoming heals and absorbs"] })
		add(Toggle("prediction.heals", L["Incoming heals"], L["Extends the health bar with heals on the way."]))
		add({ type = "color", key = "prediction.healColor", label = L["Incoming heal colour"], help = L["The colour of incoming heals on the health bar."], hasAlpha = true, showWhen = Is("prediction.heals", true) })
		add(Toggle("prediction.absorbs", L["Absorbs"], L["Shows shields, such as Power Word: Shield, after the health."]))
		add({ type = "color", key = "prediction.absorbColor", label = L["Absorb colour"], help = L["The colour of shields on the health bar."], hasAlpha = true, showWhen = Is("prediction.absorbs", true) })
		add(Dropdown("prediction.absorbPlace", L["Absorb place"], L["Draws shields after the health, or back from the bar's end."], ABSORB_PLACE, { showWhen = Is("prediction.absorbs", true) }))
		add(Dropdown("prediction.absorbStyle", L["Absorb style"], L["Draws shields as a solid fill or in the game's shield pattern."], FILL_STYLE, { showWhen = Is("prediction.absorbs", true) }))
		add(Toggle("prediction.overshield", L["Overshield"], L["Draws the part of a shield larger than the missing health back over the health, from the bar's end."]))
		add(Toggle("prediction.glow", L["Shield glow"], L["A bright line at the bar's end when a shield is bigger than the missing health."]))
		add(Toggle("prediction.shield", L["Shield line"], L["A thin line under the health bar for the whole shield, seen even at full health."]))
		local line = Is("prediction.shield", true)
		add(Slider("prediction.shieldLines", L["Shield line thickness"], L["How many pixels thick the shield line is."], 1, 20, 1))
		schema[#schema].showWhen = line
		add(Dropdown("prediction.shieldPlace", L["Shield line place"], L["Which edge of the health bar the shield line runs along."], SHIELD_PLACE, { showWhen = line }))
		add(Dropdown("prediction.shieldGrow", L["Shield line growth"], L["Which way a shield line on the left or right edge grows."], Options({ { "UP", L["Up"] }, { "DOWN", L["Down"] } })))
		schema[#schema].showWhen = function(settings) return line(settings) and not Is("prediction.shieldPlace", "BOTTOM")(settings) and not Is("prediction.shieldPlace", "TOP")(settings) end
		add(Toggle("prediction.healAbsorbs", L["Heal absorbs"], L["Marks the health that heal-absorbing debuffs will eat, from the fill's end."]))
		add({ type = "color", key = "prediction.healAbsorbColor", label = L["Heal absorb colour"], help = L["The colour of heal absorbs on the health bar."], hasAlpha = true, showWhen = Is("prediction.healAbsorbs", true) })
		add(Dropdown("prediction.healAbsorbStyle", L["Heal absorb style"], L["Draws heal absorbs as a solid fill or in the game's heal absorb pattern."], FILL_STYLE, { showWhen = Is("prediction.healAbsorbs", true) }))
		add(Toggle("prediction.healAbsorbLine", L["Heal absorb line"], L["A thin line for the whole heal absorb on the edge across from the shield line."]))
		add(Slider("prediction.healAbsorbLines", L["Heal absorb line thickness"], L["How many pixels thick the heal absorb line is; 0 matches the shield line."], 0, 20, 1))
		schema[#schema].showWhen = Is("prediction.healAbsorbLine", true)
		add(Dropdown("prediction.maxLoss", L["Lost maximum health"], L["Marks the maximum health a debuff has taken away, at the bar's end."], Options({ { "OFF", L["Off"] }, { "SOLID", L["Solid"] }, { "STRIPES", L["Patterned"] } })))
		add({ type = "color", key = "prediction.maxLossColor", label = L["Lost maximum health colour"], help = L["The colour and opacity of lost maximum health."], hasAlpha = true, showWhen = IsNot("prediction.maxLoss", "OFF") })
		add(Slider("prediction.backing", L["Backing opacity"], L["How solid the fill under patterned shields, heal absorbs and lost maximum health is."], 0, 1, 0.05))
		schema[#schema].showWhen = function(settings)
			return Is("prediction.absorbStyle", "STRIPES")(settings) or Is("prediction.healAbsorbStyle", "STRIPES")(settings) or Is("prediction.maxLoss", "STRIPES")(settings)
		end
		add({ type = "header", label = L["Range and highlight"] })
		add(Toggle("range.fade", L["Fade out of range"], L["Fades members who are too far away to heal."]))
		add(Slider("range.alpha", L["Out of range opacity"], L["How faint a member out of range looks."], 0.1, 1, 0.05))
		schema[#schema].showWhen = Is("range.fade", true)
		add(Dropdown("accent.source", L["Highlight colour"], L["The colour that marks your target and the frame under the mouse."], ACCENT))
		add({ type = "color", key = "accent.color", label = L["Custom highlight colour"], help = L["The highlight colour when it uses a custom colour."], showWhen = Is("accent.source", "custom") })
		add(Toggle("accent.hover", L["Hover highlight"], L["Lights the frame's edge under the mouse."]))
		add(Slider("accent.hoverLines", L["Hover highlight lines"], L["The hover highlight's thickness: one line or two."], 1, 2, 1))
		schema[#schema].showWhen = Is("accent.hover", true)
		add(Toggle("accent.target", L["Highlight the target"], L["Rings the frame of the member you target."]))
		add(Slider("accent.targetLines", L["Target ring lines"], L["The target ring's thickness: two lines or one."], 1, 2, 1))
		schema[#schema].showWhen = Is("accent.target", true)
		schema.preview = function(parent)
			return ns.Preview.Build(parent)
		end
		return schema
	end

	local schema = BuildSchema()
	Settings.schema = schema
	if includeText then TextSlotRows(schema) end

	rows = {}
	for _, row in ipairs(schema) do
		if row.key then
			rows[row.key] = row
		end
	end
	Settings.rows = rows
	return Settings.schema
end

local function Default(key)
	local node = Settings.defaults
	for part in key:gmatch("[^%.]+") do
		node = node[part]
	end
	return node
end

local function Saved(key)
	local Store = K.Store
	if not Store.IsLoaded() then
		return nil
	end
	local node = Store.Module(MODULE)
	for part in key:gmatch("[^%.]+") do
		if type(node) ~= "table" then
			return nil
		end
		node = node[part]
	end
	return node
end

local function IsNumber(v)
	return type(v) == "number" and v == v and not (issecretvalue and issecretvalue(v))
end

local function Channel(v)
	return IsNumber(v) and v >= 0 and v <= 1
end

local CHECK = {
	text = function(row, v)
		if type(v) == "string" and #v <= (row.maxLetters or #v) then
			return v
		end
	end,
	slider = function(row, v)
		if not IsNumber(v) then
			return nil
		end
		return math.min(math.max(v, row.min), row.max)
	end,
	dropdown = function(row, v)
		for _, option in ipairs(row.options) do
			if option.value == v then
				return v
			end
		end
	end,
	toggle = function(_, v)
		if type(v) == "boolean" then
			return v
		end
	end,
	color = function(_, v)
		if type(v) == "table" and Channel(v.r) and Channel(v.g) and Channel(v.b) and (v.a == nil or Channel(v.a)) then
			return v
		end
	end,
	font = function(_, v)
		if type(v) == "string" and v ~= "" then
			return v
		end
	end,
}
CHECK.texture = function(_, v)
	if (type(v) == "string" and v ~= "") or IsNumber(v) then
		return v
	end
end

function Settings.Get(key)
	if key:match("%.extra[12]$") then
		local value = Saved(key)
		return type(value) == "table" and value or Default(key)
	end
	if not rows then Settings.Schema() end
	if key == "blizzard.manager" then return not Settings.Get("blizzard.keepManager") end
	local row = rows[key]
	if not row then
		Settings.Schema(true)
		row = rows[key]
	end
	if not row then
		error("KstyleUI_GroupFrames: unknown setting " .. tostring(key), 2)
	end
	local value = CHECK[row.type](row, Saved(key))
	if value == nil then
		return Default(key)
	end
	return value
end

local kinds = { party = {}, raid = {} }

function Settings.Kind(kind)
	local out = kinds[kind]
	if not out then
		error("KstyleUI_GroupFrames: unknown frame kind " .. tostring(kind), 2)
	end
	for name in pairs(Settings.defaults[kind]) do
		out[name] = Settings.Get(kind .. "." .. name)
	end
	return out
end

function Settings.Section(section)
	local out = {}
	for name in pairs(Settings.defaults[section]) do
		out[name] = Settings.Get(section .. "." .. name)
	end
	return out
end

local current = {}
for section, values in pairs(Settings.defaults) do
	current[section] = {}
	for key, value in pairs(values) do current[section][key] = value end
end
Settings.current = current

function Settings.Refresh()
	Settings.generation = (Settings.generation or 0) + 1
	local stored = K.Store.IsLoaded() and K.Store.Module(MODULE) or Settings.defaults
	for section, out in pairs(current) do
		local own = stored[section]
		own = type(own) == "table" and own or nil
		local blizzard = section == "blizzard"
		for name, default in pairs(Settings.defaults[section]) do
			local value = own and own[name]
			if value == nil and not (blizzard and name == "manager") then
				out[name] = default
			elseif type(default) ~= "table" and not (blizzard and name == "manager") and not (issecretvalue and issecretvalue(value)) and value == default then
				out[name] = value
			elseif type(default) == "table" then
				if default.textFormat then out[name] = type(value) == "table" and value or default
				else out[name] = CHECK.color(nil, value) or default end
			else
				out[name] = Settings.Get(section .. "." .. name)
			end
		end
	end
	return current
end

function Settings.ClassFirst(kind)
	local sort = current.sort
	return sort.classFirst and (sort.classFirstIn == "BOTH" or sort.classFirstIn == kind:upper())
end

function Settings.ClassList(kind)
	return kind == "party" and current.sort.partyOwn and "partyClass" or "class"
end

K.Callbacks.Register("SettingChanged", MODULE .. ":classOrder", function(_, module, key, value)
	local list, at = nil, nil
	if module == MODULE and type(key) == "string" then list, at = key:match("^sort%.(%a+)(%d+)$") end
	at = (list == "class" or list == "partyClass") and tonumber(at)
	if not at then return end
	local free = {}
	for _, class in ipairs(Settings.CLASSES) do free[class] = true end
	for i = 1, #Settings.CLASSES do free[Settings.Get("sort." .. list .. i)] = nil end
	for i = 1, #Settings.CLASSES do
		if i ~= at and Settings.Get("sort." .. list .. i) == value then
			for _, class in ipairs(Settings.CLASSES) do
				if free[class] then return K.Options.Write(MODULE, "sort." .. list .. i, class) end
			end
		end
	end
end)
