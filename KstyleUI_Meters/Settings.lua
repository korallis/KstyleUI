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
ns.SESSIONS = {
	{ value = "Current", label = L["Current fight"] },
	{ value = "Previous", label = L["Previous fight"] },
	{ value = "Overall", label = L["Overall"] },
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
			if section ~= "swing" then
				if section == "damage" then return not ns.MeterShown("damage") and not ns.MeterShown("threat") end
				return not ns.MeterShown(section)
			end
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
			help = L["The current fight, the one before it, or every fight. Right-click the meter to switch."], options = ns.SESSIONS,
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
	}
	ListRows("damage", schema)
	schema[#schema + 1] = { type = "toggle", key = "damage.alwaysPlayer", label = L["Always show player"], disableWhen = Off("damage"), showWhen = WindowStyle,
		help = L["Keep your row visible when it falls outside the meter's visible rows."] }
	schema[#schema + 1] = { type = "toggle", key = "damage.hover", label = L["Show breakdown on hover"], disableWhen = Off("damage"), showWhen = WindowStyle,
		help = L["Open the spell breakdown when you point at a player's row."] }
	schema[#schema + 1] = { type = "dropdown", key = "damage.format", label = L["Number format"], disableWhen = Off("damage"), showWhen = WindowStyle,
		help = L["Use short or full numbers for damage and healing amounts."], options = {
		{ value = "short", label = L["Short, such as 12.3K"] }, { value = "full", label = L["Full, such as 12,345"] },
	} }

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

local warned = {}

function ns.Get(key)
	local settings = K.Store.IsLoaded() and K.Store.Module(ns.MODULE)
	local styled = not settings or settings.nameplateRows ~= false
	if styled then key = SHARED_ROWS[key] or key end
	local default = Lookup(ns.defaults, key)
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

function ns.ApplyFont(text, section, sizeKey, role)
	local path = ns.FontPath(section, role)
	local size = ns.Get(section .. "." .. (sizeKey or "fontSize")) * Theme.FontScale()
	local flags = ns.Get(section .. ".outline")
	if not K.Widgets.ApplyFont(text, path, size, flags) then
		local fallback, _, fallbackFlags = Tokens.Font("body")
		K.Widgets.ApplyFont(text, fallback, size, fallbackFlags)
		ns.LogOnce("font:" .. tostring(path), "the font " .. tostring(path) .. " did not load; the meters use the interface font")
	end
end
