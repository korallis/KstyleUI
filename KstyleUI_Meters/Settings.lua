-- Settings.lua: the Meters module's defaults, its settings schema, checked setting reads, and the colour and font rules every meter shares.
local _, ns = ...

local K = KstyleUI
local L, Tokens, Theme = K.L, K.Tokens, K.Theme

ns.MODULE = "Meters"

local MIN_TEXT, MAX_TEXT = 6, 24
local MIN_ROW, MAX_ROW = 10, 40
local MAX_SPACING = 12
local MIN_WARN, MAX_WARN, WARN_STEP = 50, 100, 5
local NO_OUTLINE = ""
local CHANNELS = { "r", "g", "b" }
local SHARED_ROWS = {}
for _, key in ipairs({ "texture", "fill", "colorSource", "color", "font", "fontSize", "outline", "rowHeight", "spacing", "title", "titleSize" }) do
	SHARED_ROWS["threat." .. key] = "damage." .. key
end
local HISTORY_ROWS = {}
for _, key in ipairs({ "texture", "fill", "font", "fontSize", "outline", "rowHeight", "spacing", "titleSize" }) do
	HISTORY_ROWS["history." .. key] = "damage." .. key
end

local function Rgb(name)
	local r, g, b = Tokens.Color(name)
	return { r = r, g = g, b = b }
end

local function Bars(fill, texture, colorSource)
	return {
		texture = texture or Tokens.Texture("barGlass"),
		colorSource = colorSource or "class",
		color = Rgb("accentDefault"),
		fill = fill,
	}
end

local function Text(size)
	return { font = "", fontSize = size, outline = NO_OUTLINE }
end

local function Merge(...)
	local out = {}
	for i = 1, select("#", ...) do
		for k, v in pairs((select(i, ...))) do
			out[k] = v
		end
	end
	return out
end

local CAPTION = Tokens.Size("caption")
local ROW, ROW_TEXT = 18, Tokens.Size("number")
local DAMAGE_SPACING = 3

ns.defaults = {
	nameplateRows = true,
	followRole = true,
	roles = { TANK = "threat", HEALER = "damage", DAMAGER = "damage" },
	fitCards = true,
	instrumentNames = true,
	accent = "class",
	accentColor = Rgb("accentDefault"),
	damage = Merge(Bars("left", Tokens.Texture("barFlat"), "school"), Text(ROW_TEXT), {
		shown = true,
		group = false,
		mode = "auto",
		meter = "DamageDone",
		session = "Current",
		rowHeight = ROW,
		spacing = DAMAGE_SPACING,
		title = true,
		titleSize = CAPTION,
		percent = true,
		icons = true,
		alwaysPlayer = true,
		hover = true,
		format = "short",
		refresh = 0.5,
		hoverSpells = 3,
		hideRank = false,
		iconZoom = 0.08,
		spellTooltips = false,
		panelAlpha = 1,
		capAlpha = 1,
		headerHeight = 0,
		titleX = 0,
		titleY = 0,
		resetButton = false,
		resetHover = false,
		resetSize = 12,
		nameScale = 1,
		valueScale = 1,
		playerMarker = false,
	}),
	threat = Merge(Bars("left"), Text(12), {
		followGuide = true,
		shown = true,
		group = true,
		pets = true,
		value = "both",
		rowHeight = 18,
		spacing = 2,
		title = true,
		titleSize = CAPTION,
		warnings = true,
		tankAlarm = true,
		warnAt = 80,
		dangerAt = 95,
	}),
	swing = Merge(Bars(nil), Text(CAPTION), {
		shown = true,
		mainHand = true,
		offHand = true,
		ranged = true,
		hideIdle = true,
		range = true,
		orientation = "HORIZONTAL",
		reverse = false,
		spacing = 1,
		time = true,
	}),
	timer = Merge(Text(16), { shown = false, color = Rgb("textEmphasis"), align = "CENTER", decimal = false, ooc = false, desat = false, toggle = false }),
	history = {
		icons = false, size = 28, count = 5, gap = 2, grow = "LEFT", anim = "slide", fade = 0, toggle = false,
		hideDungeon = false, hideRaid = false, hideDelve = false, hidePvP = false, hideWorld = false,
		bars = false, barCount = 5, title = true, colorSource = "class", color = Rgb("accentDefault"),
	},
}

ns.METER_TYPES = {
	{ value = "DamageDone", label = L["Damage done"], cap = L["Damage"], rate = "dps" },
	{ value = "Dps", label = L["Damage per second"], cap = L["Damage"], perSecond = true, rate = "dps" },
	{ value = "HealingDone", label = L["Healing done"], rate = "hps" },
	{ value = "Hps", label = L["Healing per second"], perSecond = true, rate = "hps" },
	{ value = "Absorbs", label = L["Absorbs"] },
	{ value = "Interrupts", label = L["Interrupts"] },
	{ value = "Dispels", label = L["Dispels"] },
	{ value = "DamageTaken", label = L["Damage taken"] },
	{ value = "AvoidableDamageTaken", label = L["Avoidable damage taken"] },
	{ value = "Deaths", label = L["Deaths"], deaths = true },
	{ value = "EnemyDamageTaken", label = L["Enemy damage taken"] },
}
local byKey

function ns.Schema()
	if ns.schema then return ns.schema end
	local COLOR_SOURCES = {
		{ value = "class", label = L["Class colour"] },
		{ value = "reaction", label = L["Reaction colour"] },
		{ value = "custom", label = L["Custom colour"] },
	}
	local OUTLINES = {
		{ value = NO_OUTLINE, label = L["Soft shadow"] },
		{ value = "OUTLINE", label = L["Thin outline"] },
		{ value = "THICKOUTLINE", label = L["Thick outline"] },
	}
	local DAMAGE_COLOR_SOURCES = {
		{ value = "school", label = L["By spell school"] },
		{ value = "class", label = L["Class colour"] },
		{ value = "reaction", label = L["Reaction colour"] },
		{ value = "custom", label = L["Custom colour"] },
	}
	local FILLS = {
		{ value = "left", label = L["From the left"] },
		{ value = "right", label = L["From the right"] },
	}
	local ORIENTATIONS = {
		{ value = "HORIZONTAL", label = L["Horizontal"] },
		{ value = "VERTICAL", label = L["Vertical"] },
	}

	local function FontOptions()
		local out = { { value = "", label = L["Interface font"] } }
		for _, item in ipairs(K.Widgets.MediaOptions("font")) do
			out[#out + 1] = item
		end
		return out
	end

	local function Is(path, value)
		local section, key = path:match("^(%w+)%.(%w+)$")
		return function(settings)
			local node = section and settings[section] or settings
			return type(node) == "table" and node[key or path] == value
		end
	end

	local function WindowStyle(settings)
		local node = settings.damage
		local mode = type(node) == "table" and node.mode or nil
		return ns.ResolveMode(mode) == "window"
	end

	local function StyleOptions()
		local auto = ns.ResolveMode("auto") == "window" and L["Automatic: KstyleUI window"] or L["Automatic: Blizzard's, restyled"]
		return {
			{ value = "auto", label = auto },
			{ value = "window", label = L["KstyleUI window"] },
			{ value = "skin", label = L["Restyle Blizzard's window"] },
		}
	end

	local function Off(section)
		return function(settings)
			if section == "damage" then return not ns.MeterShown("damage") and not ns.MeterShown("threat") end
			if section == "threat" then return not ns.MeterShown(section) end
			return type(settings[section]) == "table" and settings[section].shown == false
		end
	end

	local function TextRows(section, rows)
		local off = Off(section)
		rows[#rows + 1] = {
			type = "dropdown", key = section .. ".font", label = L["Font"], disableWhen = off,
			help = L["The typeface of the text. The interface font follows the Appearance page."], options = FontOptions,
		}
		rows[#rows + 1] = {
			type = "slider", key = section .. ".fontSize", label = L["Text size"], disableWhen = off,
			help = L["How large the text is, in units at the 1080 reference."], min = MIN_TEXT, max = MAX_TEXT, step = 1,
		}
		rows[#rows + 1] = {
			type = "dropdown", key = section .. ".outline", label = L["Text outline"], disableWhen = off,
			help = L["A soft shadow, or an outline for text over bright scenes."], options = OUTLINES,
		}
	end

	local function BarRows(section, rows)
		K.Widgets.BarRows(rows, section, {
			options = section == "damage" and DAMAGE_COLOR_SOURCES or COLOR_SOURCES,
			custom = Is(section .. ".colorSource", "custom"), disableWhen = Off(section),
			height = section ~= "swing" and { MIN_ROW, MAX_ROW, 1, key = "rowHeight" } or nil,
		})
	end

	local function ListRows(section, rows)
		local first = #rows + 1
		local off = Off(section)
		BarRows(section, rows)
		rows[#rows + 1] = {
			type = "dropdown", key = section .. ".fill", label = L["Bar direction"], disableWhen = off,
			help = L["The side the bars grow from."], options = FILLS,
		}
		rows[#rows + 1] = {
			type = "slider", key = section .. ".spacing", label = L["Row spacing"], disableWhen = off,
			help = L["The gap between rows."], min = 0, max = MAX_SPACING, step = 1,
		}
		rows[#rows + 1] = {
			type = "toggle", key = section .. ".title", label = L["Show the title"], disableWhen = off,
			help = L["Shows the meter's name and column heading above the rows."],
		}
		rows[#rows + 1] = {
			type = "slider", key = section .. ".titleSize", label = L["Title size"], disableWhen = off,
			help = L["How large the title and column heading are."], min = MIN_TEXT, max = MAX_TEXT, step = 1,
		}
		TextRows(section, rows)
		if section == "threat" then
			for i = first, #rows do
				local previous = rows[i].showWhen
				rows[i].showWhen = function(settings) return settings.nameplateRows == false and (not previous or previous(settings)) end
			end
		end
	end

	local schema = {
		{ type = "toggle", key = "nameplateRows", label = L["Nameplate-style meter rows"],
			help = L["Match meter rows to nameplates. Off restores the previous rows and separate threat appearance."] },
		{
			type = "toggle", key = "followRole", label = L["Show the meter for my role"],
			help = L["Follows your group role, then spec role, after combat. Off restores the manual show switches."],
		},
		{
			type = "dropdown", key = "roles.TANK", label = L["Tank"],
			help = L["The meter to show while tanking. This overrides the manual show switches."], disableWhen = Is("followRole", false),
			options = { { value = "damage", label = L["Damage"] }, { value = "threat", label = L["Threat"] }, { value = "both", label = L["Both"] } },
		},
		{
			type = "dropdown", key = "roles.HEALER", label = L["Healer"],
			help = L["The meter to show while healing. This overrides the manual show switches."], disableWhen = Is("followRole", false),
			options = { { value = "damage", label = L["Damage"] }, { value = "threat", label = L["Threat"] }, { value = "both", label = L["Both"] } },
		},
		{
			type = "dropdown", key = "roles.DAMAGER", label = L["Meter while dealing damage"],
			help = L["Both shows a threat card next to the damage meter."], disableWhen = Is("followRole", false),
			options = { { value = "damage", label = L["Damage"] }, { value = "threat", label = L["Threat"] }, { value = "both", label = L["Both"] } },
		},
		{ type = "toggle", key = "fitCards", label = L["Fit meter cards to rows"], help = L["Fit cards to their rows, with a three-row minimum. Off restores the previous card heights."] },
		{ type = "toggle", key = "instrumentNames", label = L["Instrument row names"],
			help = L["Use compact sans capitals for Medallions meter names. Off restores the original face."] },
		{ type = "header", label = L["Accent"] },
		{
			type = "dropdown", key = "accent", label = L["Accent colour"],
			help = L["The colour of the meters' title marks: the class colour or one you pick."],
			options = { { value = "class", label = L["Class colour"] }, { value = "custom", label = L["Custom colour"] } },
		},
		{
			type = "color", key = "accentColor", label = L["Custom accent"], showWhen = Is("accent", "custom"),
			help = L["The accent colour the meters use when the accent is custom."],
		},
		{ type = "header", label = L["Damage meter"] },
		{ type = "toggle", key = "damage.shown", label = L["Show the damage meter"], disableWhen = function(settings) return settings.followRole and #K.Setup.Integrations.Detected(ns.MODULE) == 0 end, help = L["Shows the Damage Meter in KstyleUI's style when role-based meters are off, or overrides Details."] },
		{
			type = "dropdown", key = "damage.mode", label = L["Style"], disableWhen = Off("damage"),
			help = L["Automatic picks once, at login, the window that shows numbers in combat on this client."],
			options = StyleOptions,
		},
		{
			type = "dropdown", key = "damage.meter", label = L["Show"], disableWhen = Off("damage"), showWhen = WindowStyle,
			help = L["What the window measures. Click its title to switch between damage and healing in game."], options = ns.METER_TYPES,
		},
		{
			type = "dropdown", key = "damage.session", label = L["Fight"], disableWhen = Off("damage"), showWhen = WindowStyle,
			help = L["The current fight, the one before it, or every fight. Right-click the meter to switch."], options = {
				{ value = "Current", label = L["Current fight"] },
				{ value = "Previous", label = L["Previous fight"] },
				{ value = "Overall", label = L["Overall"] },
			},
		},
		{
			type = "toggle", key = "damage.group", label = L["Only in a group"], disableWhen = Off("damage"),
			help = L["Hides the damage meter while you play alone, in either style."],
		},
		{
			type = "toggle", key = "damage.percent", label = L["Show percentages"], disableWhen = Off("damage"), showWhen = WindowStyle,
			help = L["Shows each share of the total, when the game lets addons read it."],
		},
		{
			type = "toggle", key = "damage.icons", label = L["Show icons"], disableWhen = Off("damage"), showWhen = WindowStyle,
			help = L["Shows each player's class or each spell's icon at the start of its row."],
		},
		{
			type = "slider", key = "damage.iconZoom", label = L["Icon zoom"], disableWhen = Off("damage"), showWhen = WindowStyle,
			help = L["How much of the icon's edge is cropped."], min = 0, max = 0.2, step = 0.01,
		},
	}
	ListRows("damage", schema)
	schema[#schema + 1] = { type = "slider", key = "damage.refresh", label = L["Refresh interval"], disableWhen = Off("damage"), showWhen = WindowStyle,
		help = L["Seconds between grouped meter updates. Lower values refresh sooner."], min = 0.1, max = 2, step = 0.1 }
	schema[#schema + 1] = { type = "slider", key = "damage.hoverSpells", label = L["Spells on hover"], disableWhen = Off("damage"), showWhen = WindowStyle,
		help = L["The maximum number of spells in a row's hover breakdown."], min = 1, max = 10, step = 1 }
	schema[#schema + 1] = { type = "toggle", key = "damage.hideRank", label = L["Hide pinned rank"], disableWhen = Off("damage"), showWhen = WindowStyle,
		help = L["Hide the rank number beside your pinned row."] }
	schema[#schema + 1] = { type = "toggle", key = "damage.alwaysPlayer", label = L["Always show player"], disableWhen = Off("damage"), showWhen = WindowStyle,
		help = L["Keep your row visible when it falls outside the meter's visible rows."] }
	schema[#schema + 1] = { type = "toggle", key = "damage.hover", label = L["Show breakdown on hover"], disableWhen = Off("damage"), showWhen = WindowStyle,
		help = L["Open the spell breakdown when you point at a player's row."] }
	schema[#schema + 1] = { type = "toggle", key = "damage.spellTooltips", label = L["Spell tooltips"], disableWhen = Off("damage"), showWhen = WindowStyle,
		help = L["Show a spell's tooltip when you point at it in a player's spell list."] }
	schema[#schema + 1] = { type = "dropdown", key = "damage.format", label = L["Number format"], disableWhen = Off("damage"), showWhen = WindowStyle,
		help = L["Use short or full numbers for damage and healing amounts."], options = {
		{ value = "short", label = L["Short, such as 12.3K"] }, { value = "full", label = L["Full, such as 12,345"] },
	} }
	local meters = Off("damage")
	local function cards(settings) return meters(settings) and not settings.history.bars end
	local function Slider(key, label, help, low, high, step, extra)
		local row = { type = "slider", key = key, label = label, help = help, min = low, max = high, step = step, disableWhen = cards }
		for k, v in pairs(extra or {}) do row[k] = v end
		schema[#schema + 1] = row
	end
	Slider("damage.panelAlpha", L["Background opacity"], L["How solid the meter cards' background is."], 0, 1, 0.05)
	Slider("damage.capAlpha", L["Title opacity"], L["How solid the meter cards' title is."], 0, 1, 0.05)
	Slider("damage.headerHeight", L["Header height"], L["Adds or removes room between the title and the rows."], -8, 16, 1)
	Slider("damage.titleX", L["Title X offset"], L["Moves the title to the right."], 0, 20, 1)
	Slider("damage.titleY", L["Title Y offset"], L["Moves the title and rows up or down."], -4, 8, 1)
	Slider("damage.nameScale", L["Name size"], L["Scales the names on meter rows."], 0.5, 2, 0.05)
	Slider("damage.valueScale", L["Number size"], L["Scales the numbers on meter rows."], 0.5, 2, 0.05)
	schema[#schema + 1] = { type = "toggle", key = "damage.playerMarker", label = L["Mark your bar"], disableWhen = meters,
		help = L["Draws a white stripe on your own meter bar."] }
	local noReset = function(settings) return meters(settings) or not settings.damage.resetButton end
	schema[#schema + 1] = { type = "toggle", key = "damage.resetButton", label = L["Reset button"], disableWhen = meters, showWhen = WindowStyle,
		help = L["Shows a button on the damage meter's title that clears every fight, after combat."] }
	schema[#schema + 1] = { type = "toggle", key = "damage.resetHover", label = L["Reset button on mouseover"], disableWhen = noReset, showWhen = WindowStyle,
		help = L["Shows the reset button only while you point at the meter."] }
	Slider("damage.resetSize", L["Reset button size"], L["How large the reset button is."], 8, 20, 1, { disableWhen = noReset, showWhen = WindowStyle })

	schema[#schema + 1] = { type = "header", label = L["Threat meter"] }
	schema[#schema + 1] = { type = "toggle", key = "threat.followGuide", label = L["Follow the guide card"], help = L["Place threat below the guide and its controls. Off keeps the threat card's own position."] }
	schema[#schema + 1] = { type = "toggle", key = "threat.tankAlarm", label = L["Tank threat alarm"], help = L["Flashes when another player passes 90 percent of your threat. Off keeps the usual warnings."] }
	schema[#schema + 1] = { type = "toggle", key = "threat.shown", label = L["Show the threat meter"], disableWhen = Is("followRole", true), help = L["Shows your group's threat on your target when role-based meters are off."] }
	schema[#schema + 1] = {
		type = "toggle", key = "threat.group", label = L["Only in a group"], disableWhen = Off("threat"),
		help = L["Hides the meter while you play alone."],
	}
	schema[#schema + 1] = {
		type = "toggle", key = "threat.pets", label = L["Include pets"], disableWhen = Off("threat"),
		help = L["Lists the group's pets as well as its players."],
	}
	schema[#schema + 1] = {
		type = "dropdown", key = "threat.value", label = L["Numbers"], disableWhen = Off("threat"),
		help = L["Threat as a percentage of pulling aggro, as threat points, or both."],
		options = { { value = "both", label = L["Threat and percentage"] }, { value = "percent", label = L["Percentage"] }, { value = "threat", label = L["Threat"] } },
	}
	schema[#schema + 1] = {
		type = "toggle", key = "threat.warnings", label = L["Threat warnings"], disableWhen = Off("threat"),
		help = L["Lights the meter when you near aggro, or when a tank is about to lose it."],
	}
	schema[#schema + 1] = {
		type = "slider", key = "threat.warnAt", label = L["Warn at"], disableWhen = Off("threat"), showWhen = Is("threat.warnings", true),
		help = L["The threat percentage that turns the meter yellow."], min = MIN_WARN, max = MAX_WARN, step = WARN_STEP,
	}
	schema[#schema + 1] = {
		type = "slider", key = "threat.dangerAt", label = L["Danger at"], disableWhen = Off("threat"), showWhen = Is("threat.warnings", true),
		help = L["The threat percentage that turns the meter red and makes it pulse."], min = MIN_WARN, max = MAX_WARN, step = WARN_STEP,
	}

	ListRows("threat", schema)

	schema[#schema + 1] = { type = "header", label = L["Swing timer"] }
	schema[#schema + 1] = {
		type = "toggle", key = "swing.shown", label = L["Show the swing timer"],
		help = L["Replaces Blizzard's swing timer with KstyleUI's bars."],
	}
	for _, slot in ipairs({
		{ "mainHand", L["Main hand"], L["Shows a bar for your main-hand swings."] },
		{ "offHand", L["Off hand"], L["Shows a bar for your off-hand swings."] },
		{ "ranged", L["Ranged"], L["Shows a bar for your ranged attacks."] },
	}) do
		schema[#schema + 1] = { type = "toggle", key = "swing." .. slot[1], label = slot[2], help = slot[3], disableWhen = Off("swing") }
	end
	schema[#schema + 1] = {
		type = "toggle", key = "swing.hideIdle", label = L["Hide when idle"], disableWhen = Off("swing"),
		help = L["Hides the bars while no swing is running, in combat too."],
	}
	schema[#schema + 1] = {
		type = "toggle", key = "swing.range", label = L["Dim out of range"], disableWhen = Off("swing"),
		help = L["Dims a bar while your target is out of reach of that attack."],
	}
	BarRows("swing", schema)
	schema[#schema + 1] = {
		type = "dropdown", key = "swing.orientation", label = L["Orientation"], disableWhen = Off("swing"),
		help = L["Bars that fill across, or bars that fill upward side by side."], options = ORIENTATIONS,
	}
	schema[#schema + 1] = {
		type = "toggle", key = "swing.reverse", label = L["Reverse fill"], disableWhen = Off("swing"),
		help = L["Fills the bars from the other end."],
	}
	schema[#schema + 1] = {
		type = "slider", key = "swing.spacing", label = L["Bar spacing"], disableWhen = Off("swing"),
		help = L["The gap between the main-hand, off-hand and ranged bars."], min = 0, max = MAX_SPACING, step = 1,
	}
	schema[#schema + 1] = {
		type = "toggle", key = "swing.time", label = L["Show the time"], disableWhen = Off("swing"),
		help = L["Shows the seconds left until the next swing."],
	}
	TextRows("swing", schema)

	local timerOff = Off("timer")
	schema[#schema + 1] = { type = "header", label = L["Combat timer"] }
	schema[#schema + 1] = { type = "toggle", key = "timer.shown", label = L["Show the combat timer"], help = L["Shows how long you have been in combat. Move it in Layout Mode."] }
	schema[#schema + 1] = { type = "color", key = "timer.color", label = L["Timer colour"], disableWhen = timerOff, help = L["The colour of the combat timer."] }
	schema[#schema + 1] = { type = "dropdown", key = "timer.align", label = L["Alignment"], disableWhen = timerOff, help = L["Where the time sits in its frame."],
		options = { { value = "LEFT", label = L["Left"] }, { value = "CENTER", label = L["Centre"] }, { value = "RIGHT", label = L["Right"] } } }
	schema[#schema + 1] = { type = "toggle", key = "timer.decimal", label = L["Show tenths"], disableWhen = timerOff, help = L["Shows tenths of a second."] }
	schema[#schema + 1] = { type = "toggle", key = "timer.ooc", label = L["Show out of combat"], disableWhen = timerOff, help = L["Keeps the last fight's time on screen after combat."] }
	schema[#schema + 1] = { type = "toggle", key = "timer.desat", label = L["Grey out of combat"], help = L["Greys the time while you are out of combat."],
		disableWhen = function(settings) return timerOff(settings) or not settings.timer.ooc end }
	TextRows("timer", schema)
	schema[#schema + 1] = { type = "toggle", key = "timer.toggle", label = L["Meters key hides the timer"], disableWhen = timerOff,
		help = L["The Show or hide meters key in Key Bindings also hides the combat timer."] }

	local iconsOff = function(settings) return not settings.history.icons end
	local barsOff = function(settings) return not settings.history.bars end
	local noHistory = function(settings) return iconsOff(settings) and barsOff(settings) end
	local function History(row)
		row.key = "history." .. row.key
		if row.disableWhen == nil then row.disableWhen = iconsOff elseif row.disableWhen == false then row.disableWhen = nil end
		schema[#schema + 1] = row
	end
	schema[#schema + 1] = { type = "header", label = L["Spell history"] }
	History({ type = "toggle", key = "icons", label = L["Spell history icons"], disableWhen = false,
		help = L["Shows a strip of the spells you cast last. Move it in Layout Mode."] })
	History({ type = "dropdown", key = "grow", label = L["Grow direction"], help = L["The side new spells push the strip towards."], options = {
		{ value = "LEFT", label = L["Left"] }, { value = "RIGHT", label = L["Right"] }, { value = "UP", label = L["Up"] }, { value = "DOWN", label = L["Down"] } } })
	History({ type = "slider", key = "size", label = L["Icon size"], help = L["How large each spell icon is."], min = 16, max = 48, step = 1 })
	History({ type = "slider", key = "count", label = L["Most icons"], help = L["How many spells the strip keeps."], min = 1, max = 10, step = 1 })
	History({ type = "slider", key = "gap", label = L["Icon spacing"], help = L["The gap between spell icons."], min = 0, max = 10, step = 1 })
	History({ type = "dropdown", key = "anim", label = L["Animation"], help = L["How a new spell enters the strip."], options = {
		{ value = "none", label = L["None"] }, { value = "slide", label = L["Slide in"] }, { value = "fly", label = L["Fly in"] } } })
	History({ type = "slider", key = "fade", label = L["Fade after"], help = L["Seconds out of combat before the strip fades. 0 keeps it."], min = 0, max = 60, step = 1 })
	History({ type = "toggle", key = "bars", label = L["Spell history bars"], disableWhen = false,
		help = L["Shows a card of the spells you cast last, like the damage meter. Move it in Layout Mode."] })
	History({ type = "slider", key = "barCount", label = L["Most bars"], help = L["How many spells the card lists."], min = 1, max = 10, step = 1, disableWhen = barsOff })
	History({ type = "toggle", key = "title", label = L["Show the title"], help = L["Shows the card's title above the bars."], disableWhen = barsOff })
	History({ type = "dropdown", key = "colorSource", label = L["Bar colour"], help = L["Your class colour or one you pick."], disableWhen = barsOff,
		options = { { value = "class", label = L["Class colour"] }, { value = "custom", label = L["Custom colour"] } } })
	History({ type = "color", key = "color", label = L["Custom colour"], help = L["The bar colour when it is custom."], disableWhen = barsOff, showWhen = Is("history.colorSource", "custom") })
	for _, place in ipairs({ { "hideDungeon", L["Hide in dungeons"] }, { "hideRaid", L["Hide in raids"] }, { "hideDelve", L["Hide in delves"] }, { "hidePvP", L["Hide in battlegrounds and arenas"] }, { "hideWorld", L["Hide outside instances"] } }) do
		History({ type = "toggle", key = place[1], label = place[2], help = L["Applies to the spell history icons and bars."], disableWhen = noHistory })
	end
	History({ type = "toggle", key = "toggle", label = L["Meters key hides spell history"], disableWhen = noHistory,
		help = L["The Show or hide meters key in Key Bindings also hides spell history."] })

	table.insert(schema, { type = "toggle", key = "swing.attached", label = K.L["Swing timer matches the HUD"], help = K.L["Use the HUD's bar finish and placement. Turn off for the previous swing timer."] })
	ns.schema = schema

	byKey = {}
	for _, row in ipairs(schema) do
		if row.key then
			byKey[row.key] = row
		end
	end
	ns.schema.preview = ns.Preview.Build
	return ns.schema
end

local paths = {}

local function Lookup(root, key)
	local path = paths[key]
	if not path then
		path = {}
		for part in key:gmatch("[^%.]+") do
			path[#path + 1] = part
		end
		paths[key] = path
	end
	local node = root
	for i = 1, #path do
		if type(node) ~= "table" then
			return nil
		end
		node = node[path[i]]
	end
	return node
end

local function Allowed(row, value)
	if row.type == "slider" then
		if type(value) ~= "number" or value ~= value then
			return false
		end
		return value >= row.min and value <= row.max
	elseif row.type == "dropdown" and type(row.options) == "table" then
		for _, option in ipairs(row.options) do
			if option.value == value then
				return true
			end
		end
		return false
	elseif row.type == "color" then
		if type(value) ~= "table" then
			return false
		end
		for i = 1, #CHANNELS do
			local v = value[CHANNELS[i]]
			if type(v) ~= "number" or v ~= v or v < 0 or v > 1 then
				return false
			end
		end
		return true
	end
	return type(value) == type((Lookup(ns.defaults, row.key)))
end

local warned, defaultsByKey = {}, {}

function ns.Get(key)
	local settings = K.Store.IsLoaded() and K.Store.Module(ns.MODULE)
	local styled = not settings or settings.nameplateRows ~= false
	if styled then key = SHARED_ROWS[key] or key end
	key = HISTORY_ROWS[key] or key
	local default = defaultsByKey[key]
	if default == nil then default = Lookup(ns.defaults, key); defaultsByKey[key] = default end
	if default == nil then
		error("KstyleUI_Meters: unknown setting " .. tostring(key), 2)
	end
	if not K.Store.IsLoaded() then
		return default
	end
	local value = Lookup(settings, key)
	if not ns.Logic.IsSecret(value) and value == default then return value end
	if not byKey then ns.Schema() end
	local row = byKey[key]
	if value == nil or (row and not Allowed(row, value)) or (not row and type(value) ~= type(default)) then
		if value ~= nil and not warned[key] then
			warned[key] = true
			ns.Log("the saved value of " .. key .. " is not allowed; using the default")
		end
		return default
	end
	return value
end

function ns.Log(message)
	K.DevTest.Log(ns.MODULE, message)
end

function ns.MeterShown(section)
	if section == "damage" and ns.damageOverlap then return ns.Get("damage.shown") end
	if not ns.Get("followRole") then
		return ns.Get(section .. ".shown")
	end
	local choice = ns.Get("roles." .. K.Specialization.Role())
	return choice == "both" or choice == section
end

local logged = {}
function ns.LogOnce(id, message)
	if not logged[id] then
		logged[id] = true
		ns.Log(message)
	end
end

local function Custom(color)
	return color.r, color.g, color.b
end

function ns.Accent()
	if ns.Get("accent") == "custom" then
		return Custom(ns.Get("accentColor"))
	end
	return Theme.Accent()
end

function ns.BarColor(section, classFile, reaction, schoolToken, muted)
	local source = ns.Get(section .. ".colorSource")
	if source == "custom" then
		return Custom(ns.Get(section .. ".color"))
	end
	if source == "school" and schoolToken then
		return Tokens.Color(schoolToken)
	end
	if source ~= "reaction" and not ns.Logic.IsSecret(classFile) and type(classFile) == "string" and classFile ~= "" then
		local r, g, b = Theme.ClassColor(classFile)
		if muted and not ns.Get("nameplateRows") then return r * 0.62, g * 0.62, b * 0.62 end
		return r, g, b
	end
	return Tokens.Color(reaction or "friendly")
end

function ns.FontPath(section, role)
	local font = ns.Get(section .. ".font")
	if K.Theme.FollowsKit(font) then
		return (Tokens.Font(role or "body"))
	end
	return font
end

function ns.ApplyFont(text, section, sizeKey, role, scale)
	local path = ns.FontPath(section, role)
	local size = ns.Get(section .. "." .. (sizeKey or "fontSize")) * Theme.FontScale() * (scale or 1)
	local flags = ns.Get(section .. ".outline")
	if not K.Widgets.ApplyFont(text, path, size, flags) then
		local fallback, _, fallbackFlags = Tokens.Font("body")
		K.Widgets.ApplyFont(text, fallback, size, fallbackFlags)
		ns.LogOnce("font:" .. tostring(path), "the font " .. tostring(path) .. " did not load; the meters use the interface font")
	end
end
