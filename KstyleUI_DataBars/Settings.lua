-- Settings.lua: the data bars' defaults, their rows in the settings window and the live preview the window shows.
local _, ns = ...

local K, L = ns.K, ns.L
local Tokens, Widgets = K.Tokens, K.Widgets
local Format, Font, Bars, Strip = ns.Format, ns.Font, ns.Bars, ns.Strip
local max, format = math.max, string.format

local FONT_SIZE = Tokens.Size("caption")
local SEGMENTS = 0
local XP_SEGMENTS = 10
local XP_RESTED_ALPHA = 0.55
local MAX_SEGMENTS = 20
local PREVIEW_BAR = 8
local PREVIEW_GAP = 22
local PREVIEW_TOP = 32
local PREVIEW_STRIP = 36
local PREVIEW_STRIP_PAD = 12
local STRIP_FONT_SIZE = 12
local STRIP_SPACING = 16
local MAX_SPACING = 32
local MICRO_SIZE = 26
local BAG_SIZE = 26
local MENU_SPACING = 4
local MENU_SIZE_MIN, MENU_SIZE_MAX = 12, 48
local MENU_SPACING_MAX = 12

local function Rgb(name, alpha)
	local r, g, b = Tokens.Color(name)
	return { r = r, g = g, b = b, a = alpha }
end

local function BarDefaults(colorSource, colorToken, text)
	return {
		texture = Tokens.MediaList("statusbar")[1].path,
		colorSource = colorSource,
		color = Rgb(colorToken),
		orientation = "HORIZONTAL",
		reverse = false,
		segments = SEGMENTS,
		border = true,
		text = text,
		textHover = true,
		textPosition = "CENTER",
		font = Font.DEFAULT,
		fontSize = FONT_SIZE,
		outline = "OUTLINE",
	}
end

local defaults = ns.defaults
defaults.fadeBlizzard = true
defaults.accentSource = "class"
defaults.accentColor = Rgb("accentDefault")
defaults.xp = BarDefaults("custom", "epic", "percentRested")
defaults.xp.textHover = false
defaults.xp.textPosition = "BOTTOM"
defaults.xp.outline = Font.WORLD
defaults.xp.segments = XP_SEGMENTS
defaults.xp.fontSize = 11
defaults.xp.instrumentText = true
defaults.xp.rested = true
defaults.xp.restedColor = Rgb(Bars.TOKENS.cool, XP_RESTED_ALPHA)
defaults.xp.questXP = false
defaults.xp.questColor = Rgb("friendly", XP_RESTED_ALPHA)
defaults.rep = BarDefaults("reaction", "friendly", "labelPercent")
defaults.rep.rewardMarker = true
defaults.honor = BarDefaults("custom", "legendary", "labelPercent")
defaults.honor.show = "pvp"
defaults.strip = {
	enabled = true, placement = "dock", height = 14, background = 85, artwork = "forged",
	dockMeter = true,
	line = true, labels = "inline", menus = true, valueColor = "plain", accentEdge = false, backdrop = false, separators = false,
	spacing = STRIP_SPACING, orientation = "HORIZONTAL",
	font = Font.DEFAULT, fontSize = STRIP_FONT_SIZE, outline = Font.WORLD,
	itemLevelSource = "equipped", itemLevelDecimals = 0,
	money = "full", latency = "home", timeSource = "local", clock24 = true,
	hover = true, align = "CENTER", padding = 0, valueCustom = Rgb("text"), labelCustom = false, labelColor = Rgb("text"),
	goldSession = true, goldCharacters = true, goldHistory = false, itemLevelPrefix = "none",
	specUpper = false, specLoadout = false, spec1Text = "", spec2Text = "", hearthOthers = false, clockMail = false, clockRest = false,
	locationWidth = "auto", locationMaxWidth = 160, bagsDisplay = "free", bagsReagent = false, bagsLow = 0,
	xpMode = "auto", xpText = "percent", xpFormat = "plain", coordsDecimals = 1, combatOnly = false, playedTotal = false,
	audioChannel = "Master", professionText = "name", brokerPlugin = "", brokerWidth = 0, brokerLabel = true,
	icons = "off", iconColor = "label", iconCustom = Rgb("text"), fill = "none", currencyIcons = false, reagentsShown = "all", reagentsLabel = false,
	socialList = 0, guildNotes = false, friendNotes = false, hearthText = "both", hearthLeft = "", hearthRight = "", hearthMiddle = "",
	hearthLeftText = "none", hearthRightText = "none", hearthMiddleText = "none", second = false, blocks = {},
}
local TEXT = Rgb("text")
for id in pairs(Strip.GLYPH_CELLS) do defaults.strip.blocks[id] = { show = "bar", iconColor = "bar", iconCustom = TEXT } end
defaults.micro = { enabled = true, shown = true, size = MICRO_SIZE, spacing = MENU_SPACING, rows = 1, backdrop = true, tint = "none", shape = "round", set = "compact", align = "LEFT" }
defaults.bags = { enabled = true, shown = true, size = BAG_SIZE, spacing = MENU_SPACING, rows = 1, backdrop = true, freeSlots = true, shape = "round", align = "LEFT" }
defaults.menus = { always = false }

local MODULES = {
	{ "micro", L["Micro menu"], "left" },
	{ "spec", L["Specialization"], "left", L["Switch dual specialization out of combat, or open talents."] },
	{ "hearth", L["Hearthstone"], "left", L["Shows the bind location and Hearthstone cooldown."] },
	{ "time", L["Clock"], "centre" },
	{ "guild", L["Guild"], "right", L["Shows guild members online. Hidden when you have no guild."] },
	{ "friends", L["Friends"], "right", L["Shows online Warcraft and Battle.net friends."] },
	{ "durability", L["Durability"], "right", L["Shows your lowest equipped durability."] },
	{ "bags", L["Bag space"], "right", L["Shows the free slots in your bags."] },
	{ "fps", L["Frame rate"], "right", L["Click: open the data bar settings."] },
	{ "latency", L["Latency"], "right" },
	{ "gold", L["Gold"], "right" },
	{ "currencies", L["Currencies"], "right", L["Shows up to three currencies tracked in your backpack."] },
	{ "xp", L["Experience and reputation"], "right", L["Shows experience, or watched reputation at the level cap."] },
	{ "location", L["Location"], "left", L["Shows your current zone."] },
	{ "itemLevel", L["Item level"], "right", L["Shows the average item level of equipped gear."] },
	{ "coords", L["Coordinates"], "left", L["Shows your map coordinates."] },
	{ "combat", L["Combat"], "right", L["Shows how long the current or last fight lasted."] },
	{ "played", L["Time played"], "right", L["Click: ask the server for your time played. Blizzard also prints it in chat."] },
	{ "audio", L["Audio"], "right", L["Shows the volume. Click: mute or unmute all sound."] },
	{ "prof1", L["Profession 1"], "left" },
	{ "prof2", L["Profession 2"], "left" },
	{ "broker", L["DataBroker"], "right", L["Shows a LibDataBroker plugin from another addon."] },
	{ "spacer", L["Spacer"], "right", L["Adds room between readouts."] },
	{ "reagents", L["Class resources"], "right", L["Shows the class reagents and ammunition you carry."] },
}
defaults.strip.modules, defaults.strip.secondModules = {}, {}
for i, def in ipairs(MODULES) do
	defaults.strip.modules[i] = { id = def[1], shown = i <= 12, zone = def[3] }
	if def[1] ~= "micro" then defaults.strip.secondModules[#defaults.strip.secondModules + 1] = { id = def[1], shown = false, zone = "right" } end
end

defaults.strip.dockModules = {}
for i, id in ipairs({ "fps", "latency", "gold", "durability", "time", "micro", "spec", "hearth", "guild", "friends", "bags", "currencies", "xp", "location", "itemLevel",
	"coords", "combat", "played", "audio", "prof1", "prof2", "broker", "spacer", "reagents" }) do
	defaults.strip.dockModules[#defaults.strip.dockModules + 1] = { id = id, shown = i <= 6, zone = id == "time" and "centre" or (id == "spec" or id == "hearth" or id == "micro") and "left" or "right" }
end

defaults.strip.railModules = {}
for i, entry in ipairs(defaults.strip.dockModules) do
	defaults.strip.railModules[i] = { id = entry.id, shown = i <= 3 or entry.id == "micro", zone = "right" }
end

function ns.FillModules(s)
	for _, key in ipairs({ "modules", "dockModules", "railModules", "secondModules" }) do
		local list, seen = s[key], {}
		for _, entry in ipairs(list) do seen[entry.id] = true end
		for _, entry in ipairs(defaults.strip[key]) do
			if not seen[entry.id] then list[#list + 1] = { id = entry.id, shown = entry.id == "micro", zone = entry.zone } end
		end
	end
end

local function Cells(settings)
	return not Strip.OneLine(settings.strip)
end

local function Docked()
	local view = Strip.view
	return view ~= nil and (view.slab or view.docked) ~= nil
end

local function SecondLine(settings)
	return settings.strip.second == true and Strip.LineMode(Strip.SecondSettings(settings.strip))
end

local function NoLine(settings)
	return (Cells(settings) or Strip.view ~= nil and Strip.view.deco == true) and not SecondLine(settings)
end

local function Plain(settings)
	return (Cells(settings) or Docked()) and not SecondLine(settings)
end

local function NoIcons(settings)
	if Plain(settings) then return true end
	for id in pairs(Strip.GLYPH_CELLS) do
		if Strip.Shows(settings.strip, id) and settings.strip.blocks[id].iconColor == "bar" then return false end
	end
	return true
end

function ns.Schema()
	ns.schema = {}
	ns.FillModules(ns.Settings().strip)
	local SOURCES_PLAIN = {
		{ value = "class", label = L["Class colour"] },
		{ value = "custom", label = L["Custom colour"] },
	}
	local SOURCES_XP = {
		{ value = "gilt", label = L["Gilt filament"] },
		{ value = "class", label = L["Class colour"] },
		{ value = "custom", label = L["Custom colour"] },
	}
	local SOURCES_REACTION = {
		{ value = "class", label = L["Class colour"] },
		{ value = "reaction", label = L["Reaction colour"] },
		{ value = "custom", label = L["Custom colour"] },
	}
	local ORIENTATIONS = {
		{ value = "HORIZONTAL", label = L["Sideways"] },
		{ value = "VERTICAL", label = L["Upright"] },
	}
	local TEXT_POSITIONS = {
		{ value = "CENTER", label = L["On the bar"] },
		{ value = "TOP", label = L["Above the bar"] },
		{ value = "BOTTOM", label = L["Below the bar"] },
		{ value = "LEFT", label = L["Left of the bar"] },
		{ value = "RIGHT", label = L["Right of the bar"] },
	}
	local HONOR_SHOW = {
		{ value = "pvp", label = L["In battlegrounds and world PvP"] },
		{ value = "always", label = L["Always"] },
	}

	local function Get(settings, id)
		return settings[id] or {}
	end

	local function BarRows(id, title, sources)
		local function noText(settings)
			return Get(settings, id).text == "none"
		end
		local rows = { { type = "header", label = title } }
		Widgets.BarRows(rows, id, { options = sources, custom = function(settings) return Get(settings, id).colorSource == "custom" end,
			help = sources == SOURCES_REACTION and { colorSource = L["Fill the bar with the class colour, your standing's colour or your own colour."] } or nil })
		rows[#rows + 1] = { type = "dropdown", key = id .. ".orientation", label = L["Orientation"], help = L["A bar that fills sideways, or one that stands upright."], options = ORIENTATIONS }
		rows[#rows + 1] = { type = "toggle", key = id .. ".reverse", label = L["Fill from the other end"], help = L["Fills from right to left, or from top to bottom."] }
		rows[#rows + 1] = { type = "slider", key = id .. ".segments", label = L["Segments"], help = L["Ticks that split the bar into equal parts. 0 draws none."], min = 0, max = MAX_SEGMENTS, step = 1 }
		rows[#rows + 1] = { type = "toggle", key = id .. ".border", label = L["Frame"], help = L["Draws the chamfered frame around the bar."] }
		if id == "xp" then
			rows[#rows + 1] = { type = "toggle", key = "xp.instrumentText", label = L["Instrument experience text"], help = L["Use small muted capitals under the Medallions sockets. Off restores the original face."] }
			rows[#rows + 1] = { type = "toggle", key = "xp.rested", label = L["Rested overlay"], help = L["Shows how far your rested experience reaches past your current experience."] }
			rows[#rows + 1] = { type = "color", key = "xp.restedColor", label = L["Rested colour"], help = L["The colour of the rested overlay."], hasAlpha = true, showWhen = function(settings)
				return Get(settings, "xp").rested == true
			end }
			rows[#rows + 1] = { type = "toggle", key = "xp.questXP", label = L["Quest experience"], help = L["Marks the experience your finished quests give when you hand them in."] }
			rows[#rows + 1] = { type = "color", key = "xp.questColor", label = L["Quest colour"], help = L["The colour of the quest experience mark."], hasAlpha = true, showWhen = function(settings)
				return Get(settings, "xp").questXP == true
			end }
		elseif id == "rep" then
			rows[#rows + 1] = { type = "toggle", key = "rep.rewardMarker", label = L["Paragon reward marker"], help = L["Marks a waiting paragon reward with an asterisk in the caption."] }
		elseif id == "honor" then
			rows[#rows + 1] = { type = "dropdown", key = "honor.show", label = L["Show"], help = L["Shows honour only in battlegrounds and world PvP, or all the time."], options = HONOR_SHOW }
		end
		local textRows = {
			{ type = "dropdown", key = id .. ".text", label = L["Text"], help = L["What the text on the bar says."], options = Format.BAR_TEXTS },
			{ type = "toggle", key = id .. ".textHover", label = L["Text on hover only"], help = L["Shows the text only while the pointer is over the bar."], disableWhen = noText },
			{ type = "dropdown", key = id .. ".textPosition", label = L["Text position"], help = L["Where the text sits around the bar."], options = TEXT_POSITIONS, disableWhen = noText },
			{ type = "dropdown", key = id .. ".font", label = L["Font"], help = L["The font of the bar's text."], options = Font.Faces, disableWhen = noText },
			{ type = "slider", key = id .. ".fontSize", label = L["Font size"], help = L["The size of the bar's text."], min = Font.MIN_SIZE, max = Font.MAX_SIZE, step = Font.STEP, disableWhen = noText },
			{ type = "dropdown", key = id .. ".outline", label = L["Outline"], help = L["A thin or thick outline, or a soft shadow, around the text."], options = Font.OUTLINES, disableWhen = noText },
		}
		for _, row in ipairs(textRows) do
			rows[#rows + 1] = row
		end
		return rows
	end

	local ACCENT_SOURCES = {
		{ value = "class", label = L["Class colour"] },
		{ value = "custom", label = L["Custom colour"] },
	}

	ns.AddRows({
		{ type = "header", label = L["General"] },
		{ type = "toggle", key = "fadeBlizzard", label = L["Fade Blizzard's bars"], help = L["Fades Blizzard's experience and reputation bars while KstyleUI shows its own."] },
		{ type = "dropdown", key = "accentSource", label = L["Accent"], help = L["The colour of the strip's accent touches: your class colour or your own."], options = ACCENT_SOURCES },
		{ type = "color", key = "accentColor", label = L["Accent colour"], help = L["The accent colour when the accent is set to custom."], showWhen = function(settings)
			return settings.accentSource == "custom"
		end },
	})
	ns.AddRows(BarRows("xp", L["Experience bar"], SOURCES_XP))
	ns.AddRows(BarRows("rep", L["Reputation bar"], SOURCES_REACTION))
	ns.AddRows(BarRows("honor", L["Honour bar"], SOURCES_PLAIN))

	local SHAPES = {
		{ value = "round", label = L["Round crystal"] },
		{ value = "tile", label = L["Chamfered tile"] },
	}
	local STRIP_LABELS = {
		{ value = "inline", label = L["Units after the value: 179 fps, 55% armour"] },
		{ value = "full", label = L["Full: Frame rate, Durability"] },
		{ value = "short", label = L["Short: FPS, MS, DUR"] },
		{ value = "none", label = L["None"] },
	}
	local VALUE_COLORS = {
		{ value = "highlight", label = L["Highlight and warnings"] },
		{ value = "threshold", label = L["Good, fair or poor"] },
		{ value = "accent", label = L["Accent colour"] },
		{ value = "plain", label = L["Plain"] },
		{ value = "custom", label = L["Custom colour"] },
	}
	local MONEY_STYLES = {
		{ value = "full", label = L["Gold, silver and copper"] },
		{ value = "gold", label = L["Gold only"] },
		{ value = "short", label = L["Short gold"] },
		{ value = "icons", label = L["Coin icons"] },
	}
	local LATENCIES = {
		{ value = "home", label = L["Home"] },
		{ value = "world", label = L["World"] },
	}
	local TIME_SOURCES = {
		{ value = "local", label = L["Local time"] },
		{ value = "realm", label = L["Realm time"] },
	}

	local moduleOptions, fillOptions, secondOptions = {}, { { value = "none", label = L["None"] } }, { zones = false }
	for i, def in ipairs(MODULES) do
		moduleOptions[i] = { value = def[1], label = def[2], rows = def[4] and { { type = "note", label = def[4] } } or {} }
		fillOptions[i + 1] = { value = def[1], label = def[2] }
		if def[1] ~= "micro" then secondOptions[#secondOptions + 1] = moduleOptions[i] end
	end
	local placements = { { value = "top", label = L["Top"] }, { value = "dock", label = L["Docked under the action bars"] }, { value = "rail", label = L["Right rail"] } }
	local stripRows = {
		{ type = "header", label = L["Data bar"] },
		{ type = "toggle", key = "strip.enabled", label = L["Show the data bar"], help = L["Show the data bar and its readouts."] },
		{ type = "dropdown", key = "strip.placement", label = L["Position"], help = L["Docked sits under the action bars. Right rail is the old readout."], options = function(all)
			return not all and Widgets.Medallions() and { placements[2], placements[3] } or placements
		end },
		{ type = "slider", key = "strip.height", label = L["Height"], help = L["The height of the top data bar."], min = 12, max = 32, step = 1, showWhen = function() return not Widgets.Medallions() end },
		{ type = "dropdown", key = "strip.artwork", label = L["Data bar artwork"], help = L["Forged trim and a crest gem, or a plain glass plate."], showWhen = function(settings) return settings.strip.placement == "top" or Widgets.Medallions() and settings.strip.placement ~= "rail" end, options = {
			{ value = "forged", label = L["Forged"] }, { value = "plain", label = L["Plain"] },
		} },
		{ type = "slider", key = "strip.background", label = L["Background"], help = L["The opacity of the top bar's background and the Medallions dock's plates."], min = 0, max = 100, step = 1 },
	}
	stripRows[#stripRows + 1] = { type = "toggle", key = "strip.dockMeter", label = L["Dock readouts to the meter"], help = L["Place the data strip beside the damage meter title. Off returns it to its own position."] }
	for _, key in ipairs({ "modules", "dockModules", "railModules" }) do
		local dock = key == "dockModules"
		stripRows[#stripRows + 1] = { type = "order", key = "strip." .. key, label = L["Modules"], help = L["Switch modules on, choose their zones and move them up or down."], options = moduleOptions, showWhen = function(settings)
			return settings.strip.placement == "rail" and key == "railModules" or settings.strip.placement ~= "rail" and key ~= "railModules" and dock == Widgets.Medallions()
		end }
	end
	for _, row in ipairs({
		{ type = "toggle", key = "strip.line", label = L["One line"], help = L["Items run together on one line at the right, joined by middle dots. Off, each sits in its own cell."] },
		{ type = "dropdown", key = "strip.labels", label = L["Labels"], help = L["Full labels, short ones like the dungeon mockup, or values alone."], options = STRIP_LABELS },
		{ type = "dropdown", key = "strip.valueColor", label = L["Value colour"], help = L["Frame rate in the accent and warnings in theirs, every value by grade, all in the accent, or plain."], options = VALUE_COLORS },
		{ type = "color", key = "strip.valueCustom", label = L["Custom value colour"], help = L["The colour of every value when the value colour is custom."], showWhen = function(settings) return settings.strip.valueColor == "custom" end, disableWhen = Docked },
		{ type = "toggle", key = "strip.labelCustom", label = L["Custom label colour"], help = L["Draws every label and unit in your own colour."], disableWhen = Docked },
		{ type = "color", key = "strip.labelColor", label = L["Label colour"], help = L["The colour of the labels and units."], showWhen = function(settings) return settings.strip.labelCustom == true end, disableWhen = Docked },
		{ type = "toggle", key = "strip.hover", label = L["Hover highlight"], help = L["Brightens a readout's label under the pointer."] },
		{ type = "dropdown", key = "strip.icons", label = L["Icons"], help = L["A glyph before each value, or the glyph alone with the value in its tooltip. On one line."], options = {
			{ value = "off", label = L["Off"] }, { value = "beside", label = L["Beside the value"] }, { value = "only", label = L["Icons only"] },
		}, disableWhen = NoLine },
		{ type = "dropdown", key = "strip.iconColor", label = L["Icon colour"], help = L["Icons in the label colour, the accent colour or your own."], options = {
			{ value = "label", label = L["Label colour"] }, { value = "accent", label = L["Accent colour"] }, { value = "custom", label = L["Custom colour"] },
		}, disableWhen = NoIcons },
		{ type = "color", key = "strip.iconCustom", label = L["Custom icon colour"], help = L["The colour of every icon when the icon colour is custom."], showWhen = function(settings) return settings.strip.iconColor == "custom" end, disableWhen = NoIcons },
		{ type = "toggle", key = "strip.menus", label = L["Menu and bag buttons in the card"], help = L["Docks the micro menu and the bag bar under the readout, in the same card, when they are shown."] },
		{ type = "toggle", key = "strip.accentEdge", label = L["Accent edge"], help = L["Draws the strip's inner edge in the accent colour."] },
		{ type = "toggle", key = "strip.backdrop", label = L["Glass"], help = L["Draws the strip on smoked glass."] },
		{ type = "toggle", key = "strip.separators", label = L["Separators"], help = L["Draws a thin line between the cells."] },
		{ type = "slider", key = "strip.spacing", label = L["Spacing"], help = L["The room inside each cell, split between its sides."], min = 0, max = MAX_SPACING, step = 1 },
		{ type = "dropdown", key = "strip.align", label = L["Text align"], help = L["Where each value sits in its cell. One line sizes each readout to its text."], options = {
			{ value = "LEFT", label = L["Left"] }, { value = "CENTER", label = L["Centre"] }, { value = "RIGHT", label = L["Right"] },
		}, disableWhen = function(settings) return Strip.OneLine(settings.strip) or settings.strip.orientation == "VERTICAL" end },
		{ type = "dropdown", key = "strip.fill", label = L["Fill the rest"], help = L["One readout's cell takes the room the others leave; the others keep their own width."], options = fillOptions,
			disableWhen = function(settings) return Strip.OneLine(settings.strip) or settings.strip.orientation == "VERTICAL" end },
		{ type = "slider", key = "strip.padding", label = L["Readout padding"], help = L["Extra room on each side of the dots between readouts."], min = 0, max = 16, step = 1 },
		{ type = "dropdown", key = "strip.orientation", label = L["Direction"], help = L["Items in a row, or stacked in a column."], options = {
			{ value = "HORIZONTAL", label = L["In a row"] }, { value = "VERTICAL", label = L["In a column"] },
		} },
		{ type = "dropdown", key = "strip.font", label = L["Font"], help = L["The font of the strip's text."], options = Font.Faces },
		{ type = "slider", key = "strip.fontSize", label = L["Font size"], help = L["The size of the strip's text."], min = Font.MIN_SIZE, max = Font.MAX_SIZE, step = Font.STEP },
		{ type = "dropdown", key = "strip.outline", label = L["Outline"], help = L["A thin or thick outline, or a soft shadow, around the text."], options = Font.OUTLINES },
	}) do
		stripRows[#stripRows + 1] = row
	end
	ns.AddRows(stripRows)
	local SHOWS = {
		{ value = "bar", label = L["Data bar's choice"] }, { value = "both", label = L["Icon and value"] }, { value = "value", label = L["Value only"] }, { value = "icon", label = L["Icon only"] },
	}
	local BLOCK_COLORS = {
		{ value = "bar", label = L["Data bar's colour"] }, { value = "label", label = L["Label colour"] }, { value = "accent", label = L["Accent colour"] }, { value = "custom", label = L["Custom colour"] },
	}
	local blockRows = { { type = "header", label = L["Readout text and icons"] } }
	for _, def in ipairs(MODULES) do
		local id, key = def[1], "strip.blocks." .. def[1] .. "."
		if Strip.GLYPH_CELLS[id] then
			local function listed(settings)
				local strip = settings.strip
				for _, list in ipairs({ Strip.Modules(strip), strip.second and strip.secondModules or {} }) do
					for _, entry in ipairs(list) do if entry.id == id and entry.shown then return true end end
				end
				return false
			end
			local function noIcon(settings) return Plain(settings) or not Strip.Shows(settings.strip, id) end
			blockRows[#blockRows + 1] = { type = "dropdown", key = key .. "show", label = def[2], help = L["What this readout shows on one line. Data bar's choice follows Icons."], options = SHOWS, showWhen = listed, disableWhen = NoLine }
			blockRows[#blockRows + 1] = { type = "dropdown", key = key .. "iconColor", label = format(L["%s icon colour"], def[2]), help = L["This readout's icon colour. Data bar's colour follows Icon colour."], options = BLOCK_COLORS, showWhen = listed, disableWhen = noIcon }
			blockRows[#blockRows + 1] = { type = "color", key = key .. "iconCustom", label = format(L["%s custom icon colour"], def[2]), help = L["The colour of this readout's icon when its colour is custom."], showWhen = function(settings)
				return listed(settings) and settings.strip.blocks[id].iconColor == "custom"
			end, disableWhen = noIcon }
		end
	end
	ns.AddRows(blockRows)
	ns.AddRows({
		{ type = "header", label = L["Second data bar"] },
		{ type = "toggle", key = "strip.second", label = L["Show a second data bar"], help = L["A second line of readouts you place in Layout Mode, in this bar's style. It starts as a copy."] },
		{ type = "order", key = "strip.secondModules", label = L["Modules"], help = L["Switch modules on and move them up or down."], options = secondOptions, showWhen = function(settings)
			return settings.strip.second == true
		end },
	})
	local TRAVEL_TEXT = {
		{ value = "none", label = L["None"] }, { value = "both", label = L["Cooldown and destination"] }, { value = "location", label = L["Destination"] }, { value = "cooldown", label = L["Cooldown"] }, { value = "smart", label = L["Cooldown, or destination when ready"] },
	}
	ns.AddRows({
		{ type = "header", label = L["Clock"] },
		{ type = "dropdown", key = "strip.timeSource", label = L["Clock"], help = L["Your computer's time or the realm's time."], options = TIME_SOURCES },
		{ type = "toggle", key = "strip.clock24", label = L["24-hour clock"], help = L["Shows 14:32 instead of 2:32 PM."] },
		{ type = "toggle", key = "strip.clockMail", label = L["Mail alert"], help = L["Adds \"mail\" after the time while mail waits for you."] },
		{ type = "toggle", key = "strip.clockRest", label = L["Resting alert"], help = L["Adds \"resting\" after the time while you rest in an inn or city."] },
		{ type = "header", label = L["Latency"] },
		{ type = "dropdown", key = "strip.latency", label = L["Latency shown"], help = L["Home latency for chat and logins, or world latency for combat."], options = LATENCIES },
		{ type = "header", label = L["Item level"] },
		{ type = "dropdown", key = "strip.itemLevelSource", label = L["Item level shown"], help = L["Use equipped gear or your best owned gear for the item level readout."], options = {
			{ value = "equipped", label = L["Equipped gear"] }, { value = "overall", label = L["All owned gear"] },
		} },
		{ type = "slider", key = "strip.itemLevelDecimals", label = L["Item level decimals"], help = L["How many decimal places the item level readout shows."], min = 0, max = 2, step = 1 },
		{ type = "dropdown", key = "strip.itemLevelPrefix", label = L["Prefix"], help = L["Writes a label before the item level."], options = {
			{ value = "none", label = L["None"] }, { value = "short", label = L["ilvl"] }, { value = "long", label = L["Item level"] },
		} },
		{ type = "header", label = L["Gold"] },
		{ type = "dropdown", key = "strip.money", label = L["Gold format"], help = L["How the strip writes your money."], options = MONEY_STYLES },
		{ type = "toggle", key = "strip.goldSession", label = L["Session in the tooltip"], help = L["Shows the money earned or spent this session in the gold tooltip."] },
		{ type = "toggle", key = "strip.goldCharacters", label = L["Characters in the tooltip"], help = L["Lists your characters' gold in the gold tooltip."] },
		{ type = "toggle", key = "strip.goldHistory", label = L["Gold history"], help = L["Keeps your account's gold for the last seven days you played and shows the change in the tooltip."] },
		{ type = "header", label = L["Location"] },
		{ type = "dropdown", key = "strip.locationWidth", label = L["Width"], help = L["Automatic follows the zone name. Fixed holds the width and clips longer names."], options = {
			{ value = "auto", label = L["Automatic"] }, { value = "manual", label = L["Fixed"] },
		}, disableWhen = Cells },
		{ type = "slider", key = "strip.locationMaxWidth", label = L["Fixed width"], help = L["The width the location keeps when it is fixed."], min = 60, max = 400, step = 5, disableWhen = function(settings) return settings.strip.locationWidth ~= "manual" or Cells(settings) end },
		{ type = "header", label = L["Bag space"] },
		{ type = "dropdown", key = "strip.bagsDisplay", label = L["Bag count"], help = L["Which slot count the bag readout shows."], options = {
			{ value = "free", label = L["Free"] }, { value = "used", label = L["Used"] }, { value = "freeTotal", label = L["Free / total"] }, { value = "usedTotal", label = L["Used / total"] },
		} },
		{ type = "toggle", key = "strip.bagsReagent", label = L["Include the reagent bag"], help = L["Counts the reagent bag's slots with your other bags."] },
		{ type = "slider", key = "strip.bagsLow", label = L["Low space warning"], help = L["Colours the count red below this many free slots. 0 turns it off."], min = 0, max = 50, step = 1 },
		{ type = "header", label = L["Specialization"] },
		{ type = "toggle", key = "strip.specUpper", label = L["Uppercase"], help = L["Writes the specialization in capitals."] },
		{ type = "toggle", key = "strip.specLoadout", label = L["Loadout name"], help = L["Adds the active talent loadout's name."] },
		{ type = "text", key = "strip.spec1Text", label = L["Group 1 text"], help = L["Shown in place of the specialization name. Empty uses the name."], maxLetters = 24 },
		{ type = "text", key = "strip.spec2Text", label = L["Group 2 text"], help = L["Shown in place of the specialization name. Empty uses the name."], maxLetters = 24 },
		{ type = "header", label = L["Hearthstone"] },
		{ type = "toggle", key = "strip.hearthOthers", label = L["Other characters"], help = L["Lists your other characters' homes in the Hearthstone tooltip."] },
		{ type = "dropdown", key = "strip.hearthText", label = L["Text"], help = L["What the Hearthstone readout shows."], options = {
			{ value = "both", label = L["Cooldown and home"] }, { value = "location", label = L["Home"] }, { value = "cooldown", label = L["Cooldown"] }, { value = "smart", label = L["Cooldown, or home when ready"] },
		} },
		{ type = "dropdown", key = "strip.hearthLeft", label = L["Left click"], help = L["The travel spell or item a left click uses, out of combat."], options = function() return ns.Readouts.TravelChoices("hearthLeft") end },
		{ type = "dropdown", key = "strip.hearthLeftText", label = L["Left click text"], help = L["What the readout adds for the left click. Needs a left click other than the Hearthstone."], options = TRAVEL_TEXT,
			disableWhen = function(settings) return settings.strip.hearthLeft == "" end },
		{ type = "dropdown", key = "strip.hearthRight", label = L["Right click"], help = L["The travel spell or item a right click uses, out of combat."], options = function() return ns.Readouts.TravelChoices("hearthRight") end },
		{ type = "dropdown", key = "strip.hearthRightText", label = L["Right click text"], help = L["What the readout adds for the right click. Needs a right click other than None."], options = TRAVEL_TEXT,
			disableWhen = function(settings) return settings.strip.hearthRight == "" end },
		{ type = "dropdown", key = "strip.hearthMiddle", label = L["Middle click"], help = L["The travel spell or item a middle click uses, out of combat."], options = function() return ns.Readouts.TravelChoices("hearthMiddle") end },
		{ type = "dropdown", key = "strip.hearthMiddleText", label = L["Middle click text"], help = L["What the readout adds for the middle click. Needs a middle click other than None."], options = TRAVEL_TEXT,
			disableWhen = function(settings) return settings.strip.hearthMiddle == "" end },
		{ type = "header", label = L["Guild and friends"] },
		{ type = "slider", key = "strip.socialList", label = L["Names in the tooltip"], help = L["Lists up to this many online guild members and friends in their tooltips. 0 shows the counts alone."], min = 0, max = 40, step = 1 },
		{ type = "toggle", key = "strip.guildNotes", label = L["Guild notes"], help = L["Writes each listed guild member's note under the name."], disableWhen = function(settings) return settings.strip.socialList == 0 end },
		{ type = "toggle", key = "strip.friendNotes", label = L["Friend notes"], help = L["Writes each listed friend's note under the name."], disableWhen = function(settings) return settings.strip.socialList == 0 end },
		{ type = "header", label = L["Currencies"] },
		{ type = "toggle", key = "strip.currencyIcons", label = L["Currency icons"], help = L["Shows each currency's icon in place of its name."] },
		{ type = "header", label = L["Class resources"] },
		{ type = "dropdown", key = "strip.reagentsShown", label = L["Items shown"], help = L["Class reagents, your equipped ammunition, or both."], options = {
			{ value = "all", label = L["Reagents and ammunition"] }, { value = "reagents", label = L["Reagents"] }, { value = "ammo", label = L["Ammunition"] },
		} },
		{ type = "toggle", key = "strip.reagentsLabel", label = L["Show names"], help = L["Writes each item's name after its count."] },
		{ type = "header", label = L["Experience and reputation"] },
		{ type = "dropdown", key = "strip.xpMode", label = L["Mode"], help = L["Automatic shows experience while levelling and reputation at the level cap."], options = {
			{ value = "auto", label = L["Automatic"] }, { value = "xp", label = L["Experience"] }, { value = "rep", label = L["Reputation"] },
		} },
		{ type = "dropdown", key = "strip.xpText", label = L["Text display"], help = L["A percentage, or the value and the total."], options = {
			{ value = "percent", label = L["Percent"] }, { value = "values", label = L["Value"] },
		} },
		{ type = "dropdown", key = "strip.xpFormat", label = L["Text format"], help = L["The value alone, or with your level or the faction."], options = {
			{ value = "plain", label = L["Value only"] }, { value = "context", label = L["With level or faction"] },
		} },
		{ type = "header", label = L["Coordinates"] },
		{ type = "slider", key = "strip.coordsDecimals", label = L["Decimals"], help = L["How precise the coordinates read."], min = 0, max = 2, step = 1 },
		{ type = "header", label = L["Combat"] },
		{ type = "toggle", key = "strip.combatOnly", label = L["Only in combat"], help = L["Shows the combat timer only while you fight."] },
		{ type = "header", label = L["Time played"] },
		{ type = "toggle", key = "strip.playedTotal", label = L["Always show total"], help = L["Shows your total time played instead of the time at this level."] },
		{ type = "header", label = L["Audio"] },
		{ type = "dropdown", key = "strip.audioChannel", label = L["Audio channel"], help = L["Which volume the audio readout shows."], options = {
			{ value = "Master", label = L["Master"] }, { value = "SFX", label = L["Effects"] }, { value = "Music", label = L["Music"] }, { value = "Ambience", label = L["Ambience"] }, { value = "Dialog", label = L["Dialog"] },
		} },
		{ type = "header", label = L["Professions"] },
		{ type = "dropdown", key = "strip.professionText", label = L["Profession text"], help = L["The profession's name, or its name and skill."], options = {
			{ value = "name", label = L["Name"] }, { value = "values", label = L["Name and skill"] },
		} },
		{ type = "header", label = L["DataBroker"] },
		{ type = "text", key = "strip.brokerPlugin", label = L["Plugin"], help = L["The LibDataBroker plugin's name, as its addon registers it."], maxLetters = 64 },
		{ type = "slider", key = "strip.brokerWidth", label = L["Fixed width"], help = L["Holds the plugin at this width and clips longer text. 0 follows the text."], min = 0, max = 400, step = 5, disableWhen = Cells },
		{ type = "toggle", key = "strip.brokerLabel", label = L["Show label"], help = L["Writes the plugin's label before its text."] },
	})

	local TINTS = {
		{ value = "none", label = L["Blizzard's colours"] },
		{ value = "accent", label = L["Accent colour"] },
		{ value = "white", label = L["White"] },
	}

	local SETS = {
		{ value = "compact", label = L["The eight you reach for"] },
		{ value = "full", label = L["Every button"] },
	}

	local function MenuRows(id, title, enabledHelp, shownLabel, shownHelp)
		local function replaced(settings)
			return settings[id] ~= nil and settings[id].enabled == true
		end
		local function off(settings)
			return not (replaced(settings) and settings[id].shown == true)
		end
		local count = #ns.Menus.GROUPS[id].buttons
		local rows = {
			{ type = "header", label = title },
			{ type = "toggle", key = id .. ".enabled", label = L["Replace Blizzard's"], help = enabledHelp },
			{ type = "toggle", key = id .. ".shown", label = shownLabel, help = shownHelp, disableWhen = function(settings)
				return not replaced(settings)
			end },
			{ type = "slider", key = id .. ".size", label = L["Button size"], help = L["The height of each button. Layout Mode moves and scales the bar."], min = MENU_SIZE_MIN, max = MENU_SIZE_MAX, step = 1, disableWhen = off },
			{ type = "slider", key = id .. ".spacing", label = L["Spacing"], help = L["The gap between buttons."], min = 0, max = MENU_SPACING_MAX, step = 1, disableWhen = off },
			{ type = "slider", key = id .. ".rows", label = L["Rows"], help = L["How many rows the buttons fill; the columns follow."], min = 1, max = count, step = 1, disableWhen = off },
			{ type = "dropdown", key = id .. ".shape", label = L["Button shape"], help = L["Round crystal discs, or the chamfered tiles the action buttons wear."], options = SHAPES, disableWhen = off },
			{ type = "toggle", key = id .. ".backdrop", label = L["Glass"], help = L["Draws smoked glass behind the buttons."], disableWhen = off },
			{ type = "dropdown", key = id .. ".align", label = L["Align"], help = L["Where a shorter last row of buttons sits."], options = {
				{ value = "LEFT", label = L["Left"] }, { value = "CENTER", label = L["Centre"] }, { value = "RIGHT", label = L["Right"] },
			}, disableWhen = off },
		}
		if id == "micro" then
			rows[#rows + 1] = { type = "dropdown", key = "micro.set", label = L["Buttons"], help = L["Eight buttons: character, professions, spells, talents, quests, guild, finder, menu. Or all."], options = SETS, disableWhen = off }
			rows[#rows + 1] = { type = "dropdown", key = "micro.tint", label = L["Icon colour"], help = L["Keeps Blizzard's icon colours, or tints the icons in the accent colour or white."], options = TINTS, disableWhen = off }
		else
			rows[#rows + 1] = { type = "toggle", key = "bags.freeSlots", label = L["Free slots"], help = L["Shows on the backpack how many slots are free in all your bags."], disableWhen = off }
		end
		return rows
	end

	ns.AddRows(MenuRows("micro", L["Micro menu"], L["Shows KstyleUI's micro menu in place of Blizzard's. Off, Blizzard's returns."],
		L["Show the micro menu"], L["The system buttons under the readout. Off, the card is one line; keybinds and Escape still work."]))
	ns.AddRows(MenuRows("bags", L["Bag bar"], L["Shows KstyleUI's bag bar in place of Blizzard's. Off, Blizzard's returns."],
		L["Show the bag bar"], L["Your bags under the readout. Off, the card is one line; B and the gold still open your bags."]))
	ns.AddRows({
		{ type = "toggle", key = "menus.always", label = L["Always show the menu and bag bars"], help = L["Off, both stay hidden until you point at them, open a bag or use Edit Mode."] },
	})
	ns.schema.preview = ns.Preview
	return ns.schema
end

local build
function ns.Preview(...)
	if build then return build(...) end
	local SAMPLES = {
		xp = { current = 12345, max = 50000, rested = 8000, level = 38, label = L["Level 38"], kind = "xp", quest = 6000 },
		rep = { current = 3600, max = 6000, reaction = 5, kind = "faction", name = L["Stormwind"], label = L["Stormwind"], standing = L["Friendly"] },
		honor = { current = 400, max = 1000, level = 3, kind = "rank", label = L["Rank 3"] },
	}

	local function PreviewSettings(s)
		return setmetatable({ orientation = "HORIZONTAL", textHover = false, textPosition = "TOP" }, { __index = s })
	end

	local SAMPLE_FPS, SAMPLE_MS, SAMPLE_MONEY, SAMPLE_DURABILITY = 144, 34, 1438217, 96
	local SAMPLE_HOUR, SAMPLE_MINUTE = 14, 32

	local PREVIEW_FALLBACK_WIDTH = 248

	local function Width(frame)
		local w = frame:GetWidth()
		if ns.IsNumber(w) and w > 0 then
			return w
		end
		return nil
	end

	local function Travel(value)
		if value == "" or value == "item:6948" then return L["Stormwind"], L["ready"] end
		return ns.Readouts.Travel(value)
	end

	local function StripSamples(s)
		local R = ns.Readouts
		return {
			fps = { tostring(SAMPLE_FPS), "good" },
			latency = { (s.labels == "short" or s.labels == "inline" or (s.labels ~= "none" and Strip.LineMode(s))) and tostring(SAMPLE_MS) or string.format(L["%d ms"], SAMPLE_MS), "good" },
			gold = { Format.Money(SAMPLE_MONEY, s.money) },
			durability = { SAMPLE_DURABILITY .. "%", "good" },
			time = { R.ClockText(s, Format.Clock(SAMPLE_HOUR, SAMPLE_MINUTE, s.clock24), true, true) },
			spec = { R.SpecText(s, L["Specialization"], 1, L["Loadout name"]) }, hearth = { R.HearthValue(s, Travel) }, bags = { R.BagText(s, s.bagsReagent and 30 or 22, s.bagsReagent and 116 or 80) },
			location = { L["Stormwind"] }, itemLevel = { R.ItemLevelText(s, 58.3) },
			guild = { "17" }, friends = { "7" }, currencies = { s.currencyIcons and "1250 |TInterface\\Icons\\INV_Misc_Coin_02:0|t" or "1250" }, xp = { R.XPText(s, s.xpMode == "rep" and { current = 4200, max = 6000, label = L["Stormwind"] } or { current = 16000, max = 50000, label = L["Level 38"] }) },
			coords = { R.CoordsText(s, 0.4532, 0.6218) }, combat = { "1:24" }, played = { R.Played(s.playedTotal and 900000 or 5000) },
			audio = { R.AudioText(false, ({ SFX = 0.7, Music = 0.35, Ambience = 0.6, Dialog = 1 })[s.audioChannel] or 0.8) }, prof1 = { R.ProfessionText(s, L["Profession 1"], 225, 300) }, prof2 = { R.ProfessionText(s, L["Profession 2"], 150, 300) },
			broker = { R.BrokerText(s, s.brokerPlugin, "42") }, spacer = { "" },
			reagents = { R.SupplyText(s, { { ammo = true, name = L["Ammunition"], count = 200 }, { name = L["Reagents"], count = 12 } }) },
		}
	end

	build = function(parent)
		local frame = CreateFrame("Frame", nil, parent)
		frame:SetAllPoints(parent)
		frame.bars, frame.captions = {}, {}
		local y = PREVIEW_TOP
		for _, def in ipairs(Bars.DEFS) do
			local caption = Widgets.Text(frame, "caption", "text")
			Widgets.SetText(caption, def.title)
			local view = Bars.NewView(frame, def)
			Widgets.Point(view.holder, "TOPLEFT", frame, "TOPLEFT", 0, -y)
			Widgets.Point(view.holder, "TOPRIGHT", frame, "TOPRIGHT", 0, -y)
			view.holder:SetHeight(Widgets.Snap(view.holder, PREVIEW_BAR))
			frame.bars[def.id], frame.captions[def.id] = view, caption
			y = y + PREVIEW_BAR + PREVIEW_GAP + PREVIEW_TOP
		end
		local caption = Widgets.Text(frame, "caption", "text")
		Widgets.Point(caption, "TOPLEFT", frame, "TOPLEFT", 0, -(y - PREVIEW_TOP))
		Widgets.SetText(caption, L["Data bar"])
		local strip = Strip.NewView(frame)
		strip.bind = function(item)
			item.button:HookScript("OnEnter", function() Strip.ShowTooltip(item) end)
			item.button:HookScript("OnLeave", function() Strip.HideTooltip(item) end)
		end
		strip.top = y
		frame.strip, frame.captions.strip = strip, caption
		function frame.Refresh(self)
			local settings = ns.Settings()
			for id, view in pairs(self.bars) do
				Bars.Paint(view, PreviewSettings(settings[id]), SAMPLES[id], true)
				Widgets.Point(self.captions[id], "BOTTOMLEFT", view.holder, "TOPLEFT", 0, Tokens.Size("gapSmall"))
				view.text:ClearAllPoints()
				Widgets.Point(view.text, "BOTTOMRIGHT", view.holder, "TOPRIGHT", 0, Tokens.Size("gapSmall"))
			end
			local s = setmetatable({ orientation = "HORIZONTAL" }, { __index = settings.strip })
			local sample, samples = self.strip, StripSamples(s)
			local height = s.placement == "top" and not Widgets.Medallions() and s.height or PREVIEW_STRIP
			local available = Width(self) or Width(parent) or PREVIEW_FALLBACK_WIDTH
			sample.paintColor = nil
			sample.frame:SetScale(1)
			sample.frame:SetSize(available, height)
			sample.deco = Widgets.Medallions() and K.Setup.Layouts.DataBarDock() ~= nil
			Strip.Paint(sample, s, samples)
			local needed = Widgets.Snap(sample.frame, (sample.contentWidth or 0) + 2 * PREVIEW_STRIP_PAD)
			local scale = needed > available and available / needed or 1
			sample.frame:SetScale(scale)
			sample.frame:SetSize(max(needed, available / scale), height)
			sample.frame:ClearAllPoints()
			Widgets.Point(sample.frame, "TOPLEFT", self, "TOPLEFT", 0, -sample.top / scale)
			Strip.Paint(sample, s, samples)
			local second = self.second
			if s.second and not second then
				second = Strip.NewView(self)
				second.bind, self.second = sample.bind, second
			end
			if not second then return end
			second.frame:SetShown(s.second == true)
			if not s.second then return end
			second.paintColor = nil
			second.frame:SetScale(scale)
			second.frame:SetSize(available / scale, Strip.LINE)
			second.frame:ClearAllPoints()
			Widgets.Point(second.frame, "TOPLEFT", self, "TOPLEFT", 0, -(sample.top + height) / scale)
			Strip.Paint(second, Strip.SecondSettings(s), samples)
		end
		frame:Refresh()
		return frame
	end
	return build(...)
end
