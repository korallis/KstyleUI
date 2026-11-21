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
		portrait = false, portraitZoom = 0, portraitRingAlpha = 1, roleRing = false, classLine = false, power = true, powerHeight = 3,
		textLayout = "ABOVE", nameSize = 13, nameChars = 0, nameFormat = "FULL", healthText = "PERCENT", healthTextSize = 11, healthTextPlace = "ROW",
		iconSize = 14,
		auraSize = 18, auraCount = 6, auraDispelCount = 1, auraColumns = 3, auraRows = 2, auraSpacing = 2,
		auraPosition = "OUTSIDE_RIGHT", auraGrowth = "RIGHT", auraWrap = "DOWN",
		buffSize = 11, buffCount = 3,
	},
	raid = {
		extra1 = ExtraText(), extra2 = ExtraText(),
		width = 116, height = 36, spacing = 9, growth = "DOWN", card = true,
		groupGrowth = "RIGHT", groupSpacing = 13, groupsPerRow = 8,
		sortBy = "GROUP", unitsPerColumn = 5, merge = false,
		roleRing = false, classLine = false, power = true, powerHeight = 2,
		textLayout = "ABOVE", nameSize = 12, nameChars = 0, nameFormat = "FULL", healthText = "PERCENT", healthTextSize = 10, healthTextPlace = "ROW",
		iconSize = 10,
		auraSize = 12, auraCount = 3, auraDispelCount = 1, auraColumns = 3, auraRows = 1, auraSpacing = 1,
		auraPosition = "BOTTOMRIGHT", auraGrowth = "RIGHT", auraWrap = "DOWN",
		buffSize = 10, buffCount = 3,
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
	},
	range = { fade = true, alpha = 0.4 },
	icons = {
		role = true, roleShapes = true, statuses = true, afk = true, resurrection = true, summon = true, leader = true, marker = true, readyCheck = true,
		roleTank = true, roleHealer = true, roleDamager = true, roleInCombat = true, leaderInCombat = true,
		roleText = false, readyPlace = "AUTO", readySize = 0, markerPlace = "AUTO", combat = false, combatPlace = "LEFT", combatSize = 14, combatClass = false,
	},
	threat = { enabled = true, shapes = true, edge = false },
	tooltip = { mode = "ALWAYS" },
	groups = { show1 = true, show2 = true, show3 = true, show4 = true, show5 = true, show6 = true, show7 = true, show8 = true, mythicBench = true, hideEmpty = false },
	auras = {
		enabled = true, onlyMine = false, sort = "", typeLetters = true, stacks = true, timers = false, filter = "ALL", swipe = true, dispelHighlight = true, dispelFilter = "PLAYER",
		magic = true, curse = true, poison = true, disease = true, bleed = true, lasting = true, dispelAlpha = 0.16, dispelLines = 2,
		zoom = 0.07, tooltips = true, typeMode = "HIDE", source = "ANY", canApply = false, timerSize = 0,
		priority1 = "DISPEL", priority2 = "BOSS", priority3 = "IMPORTANT", priority4 = "OTHER", glow = true,
	},
	buffs = { enabled = true, tooltips = true },
	clickCast = { hint = true },
	presets = { raid = "Compact" },
	prediction = {
		heals = true, absorbs = true, shield = true, shieldLines = 2, healAbsorbs = true,
		shieldPlace = "BOTTOM", shieldGrow = "UP", absorbPlace = "FILL", overshield = false, healAbsorbLine = false, healAbsorbLines = 0,
		absorbStyle = "SOLID", healAbsorbStyle = "SOLID", backing = 1, glow = false, maxLoss = "OFF", maxLossColor = Rgb("black", 0.6),
		healColor = Rgb("friendly", HEAL_ALPHA), absorbColor = Rgb("white", ABSORB_ALPHA), healAbsorbColor = Rgb("hostile", HEAL_ABSORB_ALPHA),
	},
	auto = { size = true, role = true, smallMost = 10, largeLeast = 26, shownOnly = false, icons = false, heals = false,
		smallWidth = 0, smallHeight = 0, smallX = 0, smallY = 0, largeWidth = 0, largeHeight = 0, largeX = 0, largeY = 0 },
	accent = { source = "class", color = Rgb("accentDefault"), hover = true, hoverLines = 1, target = true, targetLines = 2 },
}

local INDICATOR_DEFAULTS = {
	{ category = "EXTERNAL", position = "CENTER" },
	{ category = "CROWD_CONTROL", position = "CENTER" },
	{ category = "BIG_DEFENSIVE", position = "BOTTOMRIGHT" },
}
for i = 1, INDICATOR_SLOTS do
	local preset = INDICATOR_DEFAULTS[i] or {}
	Settings.defaults["indicator" .. i] = { category = preset.category or "OFF", position = preset.position or "TOPLEFT", spells = "", mine = false, size = 14 }
end

local rows

local textRows = false
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
		local index
		for i, row in ipairs(schema) do if row.key == kind .. ".healthTextPlace" then index = i; break end end
		for i, row in ipairs(additions) do
			table.insert(schema, index + i, row)
			if rows and row.key then rows[row.key] = row end
		end
	end
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

	local function Slider(key, label, help, low, high, step)
		return { type = "slider", key = key, label = label, help = help, min = low, max = high, step = step }
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
			schema[#schema].showWhen = function(settings) return Is(p .. "portrait", true)(settings) or Is(p .. "roleRing", true)(settings) or ns.Medallions.Active() end
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
		add(Slider(p .. "buffSize", L["Your heal icon size"], L["The size of each of your heals over time and shields on the frame."], 6, 24, 1))
		add(Slider(p .. "buffCount", L["Your heal icon count"], L["The most of your heals over time and shields each frame shows."], 1, 6, 1))
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
		add({ type = "header", label = L["Status icons"] })
		add(Toggle("layout.tidyLanes", L["Tidy Medallions lanes"], L["Separates names, indicators and percentages, with metal role pips. Off restores the earlier layout."]))
		add(Toggle("icons.role", L["Role icons"], L["Shows whether each member is a tank, healer or damage dealer."]))
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
			add(Slider(p .. "size", L["Size"], L["The indicator's icon size."], 6, 32, 1))
			schema[#schema].showWhen = on
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
	local stored = K.Store.IsLoaded() and K.Store.Module(MODULE) or Settings.defaults
	for section, out in pairs(current) do
		local own = stored[section]
		for name, default in pairs(Settings.defaults[section]) do
			local value = type(own) == "table" and own[name]
			if not (section == "blizzard" and name == "manager") and type(default) ~= "table" and not (issecretvalue and issecretvalue(value)) and value == default then
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
