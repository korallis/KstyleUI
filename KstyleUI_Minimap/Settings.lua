-- Settings.lua: the minimap's settings: their defaults, the rows of its settings page and checked reads.
local _, ns = ...

local K = KstyleUI
local L, Tokens = K.L, K.Tokens

local Settings = {}
ns.Settings = Settings

local MODULE = "Minimap"
Settings.MODULE = MODULE

local TEXT_MIN, TEXT_MAX, TEXT_STEP = 6, 24, 1
local DELAY_MIN, DELAY_MAX, DELAY_STEP = 3, 30, 1
local BUTTON_MIN, BUTTON_MAX, BUTTON_STEP = 14, 96, 1
local SPACING_MIN, SPACING_MAX, SPACING_STEP = 0, 12, 1
local ICON_MIN, ICON_MAX, ICON_STEP = 16, 128, 1
local COLUMNS_MIN, COLUMNS_MAX, COLUMNS_STEP = 1, 12, 1

local accentR, accentG, accentB = Tokens.Color("accentDefault")

Settings.defaults = {
	enabled = false,
	compactIcons = false,
	clearPlaques = true,
	frame = "medallion",
	accent = { source = "class", color = { r = accentR, g = accentG, b = accentB } },
	rotate = false,
	microMenu = false,
	tooltipScale = 1,
	column = { side = "right", size = 19.5, spacing = 5.5, growth = "down", hover = true, tracking = true, mail = true, calendar = true, queue = true, drawer = true,
		offset = 0, tooltip = "auto", backgrounds = true, free = false, spots = {} },
	mail = { position = "column", x = 0, y = 0 },
	compartment = { shown = false, position = "TOPRIGHT", scale = 1, x = 0, y = 0 },
	drawer = { behaviour = "click", direction = "auto", size = 24, spacing = 4, columns = 6, autoClose = true, compartment = true, hideEmpty = false, edgePins = false, list = false,
		button = "", place = "drawer", places = {} },
	zoom = { wheel = true, slider = true, reset = false, delay = 10 },
	zone = { shown = true, subzone = true, color = "plain", font = "", size = 12, outline = "world", position = "", x = 0, y = 0 },
	clock = { shown = true, mode = "game", font = "", size = 12.5, outline = "world", position = "", x = 0, y = 0, accent = false, hover = "none" },
	coords = { shown = true, hover = false, precision = 1, font = "", size = 11.5, outline = "world", position = "", x = 0, y = 0 },
	difficulty = { shown = false, position = "TOPLEFT", x = 0, y = 0, font = "", size = 12, outline = "world", accent = false },
	perf = { shown = false, position = "BOTTOMLEFT", x = 0, y = 0, font = "", size = 12, outline = "world", interval = 3, latency = "home", accent = true, hover = "none" },
}

local rows

function Settings.BarClock()
	if K.Store.IsLoaded() and K.Modules.IsEnabled("DataBars") then
		local strip = K.Store.Module("DataBars").strip or {}
		if strip.enabled ~= false then
			for _, entry in ipairs((strip.placement == "rail" and strip.railModules or strip.dockModules) or {}) do
				if entry.id == "time" and entry.shown then
					local element = K.Layout.Get("databars.strip")
					if not element or element.shown ~= "never" then return true end
				end
			end
		end
	end
	return false
end

function Settings.MailMoved(v)
	return v.column.mail and v.mail.position ~= "column"
end

function Settings.AddonButtons()
	local out, drawer = { { value = "", label = L["Choose a button"] } }, ns.Map and ns.Map.drawer
	for _, button in ipairs(drawer and drawer.order or {}) do
		local name = drawer.adopted[button].name
		out[#out + 1] = { value = name, label = ns.Drawer.Label(name) }
	end
	return out
end

function Settings.Mirror(key, value)
	local places, name = Settings.Get("drawer.places"), Settings.Get("drawer.button")
	if key == "drawer.button" and value ~= "" then
		local place = (places[value] == "column" or places[value] == "hidden") and places[value] or "drawer"
		if Settings.Get("drawer.place") == place then return end
		K.Options.Write(MODULE, "drawer.place", place)
		return true
	elseif key == "drawer.place" and name == "" then
		if next(places) == nil then return end
		K.Options.Write(MODULE, "drawer.places", {})
		return true
	elseif key == "drawer.place" then
		local want, copy = value ~= "drawer" and value or nil, {}
		if places[name] == want then return end
		for k, v in pairs(places) do copy[k] = v end
		copy[name] = want
		K.Options.Write(MODULE, "drawer.places", copy)
		return true
	end
end

function Settings.TooltipsPlace()
	return K.Store.IsLoaded() and K.Modules.IsRunning("Tooltips") and K.Store.Module("Tooltips").minimapAnchor ~= false
end

function Settings.Schema()
	if Settings.schema then return Settings.schema end
	local FRAME_OPTIONS = {
		{ value = "medallion", label = L["Crest medallion"] },
		{ value = "ring", label = L["Crest ring"] },
		{ value = "classic", label = L["Classic"] },
	}
	local ACCENT_OPTIONS = {
		{ value = "class", label = L["Class colour"] },
		{ value = "custom", label = L["Custom colour"] },
	}
	local SIDE_OPTIONS = {
		{ value = "right", label = L["Inside the right edge"] },
		{ value = "left", label = L["Inside the left edge"] },
		{ value = "inside", label = L["Inside the right edge"] },
	}
	local BEHAVIOUR_OPTIONS = {
		{ value = "click", label = L["Open on click"] },
		{ value = "hover", label = L["Open on mouseover"] },
		{ value = "open", label = L["Always open"] },
	}
	local DIRECTION_OPTIONS = {
		{ value = "auto", label = L["Away from the map"] },
		{ value = "left", label = L["Left"] },
		{ value = "right", label = L["Right"] },
		{ value = "up", label = L["Up"] },
		{ value = "down", label = L["Down"] },
	}
	local GROWTH_OPTIONS = {
		{ value = "down", label = L["From the top, downward"] },
		{ value = "up", label = L["From the bottom, upward"] },
	}
	local ZONE_COLOR_OPTIONS = {
		{ value = "plain", label = L["Plain"] },
		{ value = "pvp", label = L["By PvP status"] },
		{ value = "accent", label = L["Accent colour"] },
	}
	local CLOCK_OPTIONS = {
		{ value = "game", label = L["Game clock settings"] },
		{ value = "local24", label = L["Local time, 24-hour"] },
		{ value = "local12", label = L["Local time, 12-hour"] },
		{ value = "realm24", label = L["Realm time, 24-hour"] },
		{ value = "realm12", label = L["Realm time, 12-hour"] },
	}
	local PRECISION_OPTIONS = {
		{ value = 0, label = L["Whole numbers (45, 62)"] },
		{ value = 1, label = L["Tenths (45.3, 62.1)"] },
		{ value = 2, label = L["Hundredths (45.32, 62.18)"] },
	}
	local OUTLINE_OPTIONS = {
		{ value = "world", label = L["Outline with a soft shadow"] },
		{ value = "", label = L["None, with a soft shadow"] },
		{ value = "OUTLINE", label = L["Thin outline"] },
		{ value = "THICKOUTLINE", label = L["Thick outline"] },
	}

	function Settings.FontOptions()
		local out = { { value = "", label = L["Interface font"] } }
		local Widgets = K.Widgets
		if Widgets and Widgets.MediaOptions then
			for _, option in ipairs(Widgets.MediaOptions("font")) do
				out[#out + 1] = option
			end
		end
		return out
	end

	local POINTS = {
		{ value = "TOPLEFT", label = L["Top left"] }, { value = "TOP", label = L["Top"] }, { value = "TOPRIGHT", label = L["Top right"] },
		{ value = "LEFT", label = L["Left"] }, { value = "RIGHT", label = L["Right"] },
		{ value = "BOTTOMLEFT", label = L["Bottom left"] }, { value = "BOTTOM", label = L["Bottom"] }, { value = "BOTTOMRIGHT", label = L["Bottom right"] },
	}
	local CAPTION_POINTS = { { value = "", label = L["Usual place"] } }
	for _, point in ipairs(POINTS) do CAPTION_POINTS[#CAPTION_POINTS + 1] = point end
	local CORNERS = { POINTS[1], POINTS[3], POINTS[6], POINTS[8] }
	local MAIL_POINTS = { { value = "column", label = L["In the button column"] }, POINTS[1], POINTS[3], POINTS[6], POINTS[8] }
	local BUTTON_PLACES = { { value = "drawer", label = L["In the drawer"] }, { value = "column", label = L["In the button column"] }, { value = "hidden", label = L["Hidden"] } }
	local TOOLTIP_OPTIONS = {
		{ value = "auto", label = L["Away from the map"] }, { value = "up", label = L["Up"] }, { value = "down", label = L["Down"] },
		{ value = "left", label = L["Left"] }, { value = "right", label = L["Right"] },
	}
	local HOVER_OPTIONS = { { value = "none", label = L["None"] }, { value = "lockouts", label = L["Instance lockouts"] } }
	local LATENCY_OPTIONS = { { value = "home", label = L["Home"] }, { value = "world", label = L["World"] } }

	local function Custom(settings)
		return settings.accent.source == "custom"
	end

	local function Place(prefix, name, points, showWhen)
		return {
			{ type = "dropdown", key = prefix .. ".position", label = L["%s place"]:format(name), options = points, showWhen = showWhen,
				help = points == CAPTION_POINTS and L["Its usual place, or inside the map's edge."] or L["Where it sits inside the map's edge."] },
			{ type = "slider", key = prefix .. ".x", label = L["%s horizontal offset"]:format(name), min = -200, max = 200, step = 1, showWhen = showWhen, help = L["Moves it left or right."] },
			{ type = "slider", key = prefix .. ".y", label = L["%s vertical offset"]:format(name), min = -200, max = 200, step = 1, showWhen = showWhen, help = L["Moves it up or down."] },
		}
	end

	local function TextRows(prefix, labels, name, showWhen)
		return {
			{
				type = "dropdown", key = prefix .. ".font", label = labels[1], options = Settings.FontOptions, showWhen = showWhen,
				help = L["The typeface of the %s."]:format(name),
			},
			{
				type = "slider", key = prefix .. ".size", label = labels[2], showWhen = showWhen,
				min = TEXT_MIN, max = TEXT_MAX, step = TEXT_STEP,
				help = L["The size of the %s, before the interface text size."]:format(name),
			},
			{
				type = "dropdown", key = prefix .. ".outline", label = labels[3], options = OUTLINE_OPTIONS, showWhen = showWhen,
				help = L["An outline helps the %s read over bright terrain."]:format(name),
			},
		}
	end

	local schema = {
		{ type = "header", label = L["Frame"] },
		{ type = "dropdown", key = "frame", label = L["Minimap frame"], options = FRAME_OPTIONS,
			help = L["Medallions only: crest medallion, crest ring with classic labels, or the classic frame."] },
		{ type = "toggle", key = "compactIcons", label = L["Compact map icons"], help = L["Shrink map pins, tracking and drawer icons. Off by default keeps at least their native size."] },
		{ type = "toggle", key = "clearPlaques", label = L["Keep map plaques clear"], help = L["Keep round-map labels below the screen edge and clear of the ring. Off uses the old positions."] },
		{ type = "toggle", key = "rotate", label = L["Rotate the map"], help = L["Turns the map so you always face up, and hides the N. Off leaves the game's own setting alone."] },
		{ type = "toggle", key = "microMenu", label = L["Micro menu on middle-click"], help = L["Middle-click the map for a list of the game's menus, out of combat."] },
		{ type = "slider", key = "tooltipScale", label = L["Tooltip size"], min = 0.5, max = 2, step = 0.05,
			help = L["Scales the tooltips of the map's buttons, zone, clock and readouts."] },
		{
			type = "dropdown", key = "accent.source", label = L["Accent colour"], options = ACCENT_OPTIONS,
			help = L["The zoom slider's fill and the active buttons follow your class colour or your own colour."],
		},
		{
			type = "color", key = "accent.color", label = L["Custom colour"], showWhen = Custom,
			help = L["The hairline colour when it does not follow your class."],
		},
		{ type = "header", label = L["Button column"] },
		{
			type = "dropdown", key = "column.side", label = L["Button column side"], options = SIDE_OPTIONS,
			help = L["Which edge of the map the small buttons line."],
		},
		{
			type = "toggle", key = "column.hover", label = L["Buttons only on hover"],
			help = L["Shows the tracking, calendar and addon buttons only while the pointer is over the map."],
		},
		{
			type = "dropdown", key = "column.growth", label = L["Button order"], options = GROWTH_OPTIONS,
			help = L["Whether the buttons start at the top or the bottom of the column."],
		},
		{
			type = "slider", key = "column.size", label = L["Button size"],
			min = BUTTON_MIN, max = BUTTON_MAX, step = BUTTON_STEP,
			help = L["The width and height of each button in the column."],
		},
		{
			type = "slider", key = "column.spacing", label = L["Button spacing"],
			min = SPACING_MIN, max = SPACING_MAX, step = SPACING_STEP,
			help = L["The gap between the buttons in the column."],
		},
		{ type = "slider", key = "column.offset", label = L["Distance from the edge"], min = -40, max = 40, step = 1,
			help = L["Moves the column in from the map's edge, or out past it."] },
		{ type = "dropdown", key = "column.tooltip", label = L["Button tooltips open"], options = TOOLTIP_OPTIONS, disableWhen = Settings.TooltipsPlace,
			help = L["Which way button tooltips open. Tooltips > Keep minimap clear places them while it is on."] },
		{ type = "toggle", key = "column.backgrounds", label = L["Button backgrounds"], help = L["The crystal disc behind each button. Off shows the bare symbols."] },
		{ type = "toggle", key = "column.free", label = L["Move buttons freely"],
			help = L["Shift-drag a button anywhere on the map, out of combat. Off returns every button to the column."] },
		{
			type = "toggle", key = "column.tracking", label = L["Tracking button"],
			help = L["Picks what the map tracks, such as herbs or the nearest innkeeper."],
		},
		{
			type = "toggle", key = "column.mail", label = L["Mail indicator"],
			help = L["Shows an envelope while you have unread mail."],
		},
		{ type = "dropdown", key = "mail.position", label = L["Mail place"], options = MAIL_POINTS, showWhen = function(v) return v.column.mail end,
			help = L["Keep the envelope in the column, or in a corner of the map."] },
		{ type = "slider", key = "mail.x", label = L["Mail horizontal offset"], min = -100, max = 100, step = 1, help = L["Moves it left or right."],
			showWhen = Settings.MailMoved },
		{ type = "slider", key = "mail.y", label = L["Mail vertical offset"], min = -100, max = 100, step = 1, help = L["Moves it up or down."],
			showWhen = Settings.MailMoved },
		{
			type = "toggle", key = "column.calendar", label = L["Calendar button"],
			help = L["Opens the calendar; right-click for the clock options."],
		},
		{
			type = "toggle", key = "column.queue", label = L["Group finder status"],
			help = L["Shows an eye while you are queued, in place of Blizzard's queue eye."],
		},
		{
			type = "toggle", key = "column.drawer", label = L["Addon drawer button"],
			help = L["Gathers minimap buttons from other addons into a drawer."],
		},
		{ type = "toggle", key = "compartment.shown", label = L["Compartment button"],
			help = L["A button in a corner of the map that lists the addon compartment."] },
		{ type = "slider", key = "compartment.scale", label = L["Compartment size"], min = 0.5, max = 1.5, step = 0.05,
			showWhen = function(v) return v.compartment.shown end, help = L["Its size next to the other buttons."] },
		{ type = "header", label = L["Addon drawer"] },
		{
			type = "dropdown", key = "drawer.behaviour", label = L["Drawer opens"], options = BEHAVIOUR_OPTIONS,
			help = L["Open the drawer with a click, on mouseover, or keep it open."],
		},
		{
			type = "dropdown", key = "drawer.direction", label = L["Drawer direction"], options = DIRECTION_OPTIONS,
			help = L["Which way the drawer opens from its button."],
		},
		{
			type = "slider", key = "drawer.size", label = L["Drawer icon size"],
			min = ICON_MIN, max = ICON_MAX, step = ICON_STEP,
			help = L["The size of each addon button in the drawer."],
		},
		{
			type = "slider", key = "drawer.spacing", label = L["Drawer spacing"],
			min = SPACING_MIN, max = SPACING_MAX, step = SPACING_STEP,
			help = L["The gap between addon buttons in the drawer."],
		},
		{
			type = "slider", key = "drawer.columns", label = L["Drawer columns"],
			min = COLUMNS_MIN, max = COLUMNS_MAX, step = COLUMNS_STEP,
			help = L["How many addon buttons sit in each row before a new row starts."],
		},
		{
			type = "toggle", key = "drawer.autoClose", label = L["Close after a click"],
			help = L["Closes the drawer when you click one of its buttons."],
		},
		{
			type = "toggle", key = "drawer.compartment", label = L["Addon compartment"],
			help = L["Right-click the drawer button for Blizzard's addon compartment list."],
		},
		{
			type = "toggle", key = "drawer.hideEmpty", label = L["Hide when empty"],
			help = L["Hides the drawer button while no addon has a button to show."],
		},
		{
			type = "toggle", key = "drawer.edgePins", label = L["Addon pins on the map's edge"],
			help = L["Shows the pins addons such as guides park on the map's edge for places off the map."],
		},
		{ type = "toggle", key = "drawer.list", label = L["Show as a list"], help = L["One column with each addon's name beside its button."] },
		{ type = "dropdown", key = "drawer.button", label = L["Addon button"], options = Settings.AddonButtons, showWhen = function(v) return v.column.drawer end,
			help = L["Pick an addon's button, then choose where it sits."] },
		{ type = "dropdown", key = "drawer.place", label = L["Its place"], options = BUTTON_PLACES,
			showWhen = function(v) return v.column.drawer and v.drawer.button ~= "" end,
			help = L["In the drawer, in the button column, or hidden."] },
		{ type = "header", label = L["Zoom"] },
		{
			type = "toggle", key = "zoom.wheel", label = L["Zoom with the mouse wheel"],
			help = L["Scroll over the map to zoom in and out."],
		},
		{
			type = "toggle", key = "zoom.slider", label = L["Zoom slider"],
			help = L["A thin slider inside the map's left edge while the pointer is over it. Click or drag it to zoom."],
		},
		{
			type = "toggle", key = "zoom.reset", label = L["Zoom back out"],
			help = L["Returns the map to its widest view a few seconds after you zoom."],
		},
		{
			type = "slider", key = "zoom.delay", label = L["Zoom-out delay"],
			min = DELAY_MIN, max = DELAY_MAX, step = DELAY_STEP,
			showWhen = function(settings)
				return settings.zoom.reset == true
			end,
			help = L["Seconds before the map zooms back out."],
		},
		{ type = "header", label = L["Zone and clock"] },
		{
			type = "toggle", key = "zone.shown", label = L["Zone name"],
			help = L["Shows the zone name under the map's left edge."],
		},
		{
			type = "toggle", key = "zone.subzone", label = L["Display subzone"], help = L["Use the minimap's local area name. Off shows the whole zone."],
		},
		{
			type = "dropdown", key = "zone.color", label = L["Zone colour"], options = ZONE_COLOR_OPTIONS,
			help = L["Colours the zone name plainly, by PvP status or with the accent."],
		},
	}
	local function Add(list, at)
		for i, row in ipairs(list) do table.insert(schema, at and at + i or #schema + 1, row) end
	end
	for i, row in ipairs(schema) do
		if row.key == "compartment.scale" then Add(Place("compartment", L["Compartment"], CORNERS, function(v) return v.compartment.shown end), i) break end
	end
	Add(TextRows("zone", { L["Zone font"], L["Zone text size"], L["Zone outline"] }, L["zone name"]))
	Add(Place("zone", L["Zone"], CAPTION_POINTS))
	Add({
		{ type = "toggle", key = "clock.shown", label = L["Clock"], help = L["Hidden while the data bar shows the clock."],
			disableWhen = Settings.BarClock, shown = function(value) return value and not Settings.BarClock() end },
		{ type = "dropdown", key = "clock.mode", label = L["Clock format"], options = CLOCK_OPTIONS,
			help = L["Follow the game's clock settings, or pick local or realm time."] },
	})
	Add(TextRows("clock", { L["Clock font"], L["Clock text size"], L["Clock outline"] }, L["clock"]))
	Add(Place("clock", L["Clock"], CAPTION_POINTS))
	Add({
		{ type = "toggle", key = "clock.accent", label = L["Accent AM and PM"], help = L["Colours the clock's AM or PM with the accent."] },
		{ type = "dropdown", key = "clock.hover", label = L["Clock tooltip adds"], options = HOVER_OPTIONS,
			help = L["Adds your saved instances and their resets to the clock's tooltip."] },
		{ type = "header", label = L["Coordinates"] },
		{ type = "toggle", key = "coords.shown", label = L["Coordinates"], help = L["Shows your position on the zone map, under the zone name."] },
		{ type = "toggle", key = "coords.hover", label = L["Coordinates only on hover"], help = L["Show coordinates only while the pointer is over the map."],
			showWhen = function(v) return v.coords.shown end },
		{ type = "dropdown", key = "coords.precision", label = L["Coordinate format"], options = PRECISION_OPTIONS,
			help = L["How many decimals the coordinates show."] },
	})
	Add(TextRows("coords", { L["Coordinate font"], L["Coordinate text size"], L["Coordinate outline"] }, L["coordinates"]))
	Add(Place("coords", L["Coordinates"], CAPTION_POINTS))
	local function Difficulty(v) return v.difficulty.shown end
	Add({
		{ type = "header", label = L["Instance difficulty"] },
		{ type = "toggle", key = "difficulty.shown", label = L["Instance difficulty"],
			help = L["Shows the group size and difficulty, such as 25H, while you are in a dungeon or raid."] },
		{ type = "toggle", key = "difficulty.accent", label = L["Accent the difficulty"], showWhen = Difficulty, help = L["Colours the difficulty with the accent."] },
	})
	Add(Place("difficulty", L["Difficulty"], POINTS, Difficulty))
	Add(TextRows("difficulty", { L["Difficulty font"], L["Difficulty text size"], L["Difficulty outline"] }, L["difficulty"], Difficulty))
	local function Perf(v) return v.perf.shown end
	Add({
		{ type = "header", label = L["Frame rate and latency"] },
		{ type = "toggle", key = "perf.shown", label = L["Frame rate and latency"], help = L["Shows frames per second and latency on the map."] },
		{ type = "dropdown", key = "perf.latency", label = L["Latency shown"], options = LATENCY_OPTIONS, showWhen = Perf,
			help = L["Home latency for chat and logins, or world latency for combat."] },
		{ type = "slider", key = "perf.interval", label = L["Update every"], min = 1, max = 5, step = 1, showWhen = Perf,
			help = L["Seconds between readings."] },
		{ type = "toggle", key = "perf.accent", label = L["Accent fps and ms"], showWhen = Perf, help = L["Colours the fps and ms labels with the accent."] },
		{ type = "dropdown", key = "perf.hover", label = L["Tooltip on hover"], options = HOVER_OPTIONS, showWhen = Perf,
			help = L["Shows your saved instances and their resets while the pointer is over the readout."] },
	})
	Add(Place("perf", L["Readout"], POINTS, Perf))
	Add(TextRows("perf", { L["Readout font"], L["Readout text size"], L["Readout outline"] }, L["readout"], Perf))
	Settings.schema = schema

	rows = {}
	for _, row in ipairs(schema) do
		if row.key then rows[row.key] = row end
	end

	Settings.schema.preview = ns.Preview.Build
	return Settings.schema
end

function Settings.IconSize(frame, key, minimum)
	local size = Settings.Get(key)
	if not Settings.Get("compactIcons") then
		local pixel = K.Scale.Pixel(1) / K.Widgets.ScaleFactor(frame)
		size = math.max(size, minimum * K.Widgets.ScaleFactor(UIParent) / K.Widgets.ScaleFactor(frame))
		return math.ceil(size / pixel - 0.000001) * pixel
	end
	return K.Widgets.Snap(frame, size)
end

local cache = {}
local function Split(key)
	local parts = cache[key]
	if not parts then
		parts = {}
		for part in key:gmatch("[^%.]+") do
			parts[#parts + 1] = part
		end
		cache[key] = parts
	end
	return parts
end

local function Lookup(root, key)
	local node = root
	for _, part in ipairs(Split(key)) do
		if type(node) ~= "table" then
			return nil
		end
		node = node[part]
	end
	return node
end

local function IsSecret(value)
	return issecretvalue ~= nil and issecretvalue(value) == true
end

local function IsChannel(value)
	return not IsSecret(value) and type(value) == "number" and value >= 0 and value <= 1
end

local function InOptions(options, value)
	for _, option in ipairs(options) do
		if option.value == value then
			return true
		end
	end
	return false
end

local function Valid(row, value, default)
	if IsSecret(value) or type(value) ~= type(default) then
		return false
	end
	if not row then
		return true
	end
	if row.type == "slider" then
		return value == value and value >= row.min and value <= row.max
	elseif row.type == "dropdown" and type(row.options) == "table" then
		return InOptions(row.options, value)
	elseif row.options == Settings.FontOptions then
		return K.Theme.FollowsKit(value) or K.Theme.IsFontPath(value)
	elseif row.type == "color" then
		return IsChannel(value.r) and IsChannel(value.g) and IsChannel(value.b)
	end
	return true
end

local logged = {}

function Settings.Get(key)
	local default = Lookup(Settings.defaults, key)
	if default == nil then
		error("KstyleUI_Minimap Settings.Get: unknown setting " .. tostring(key), 2)
	end
	local Store = K.Store
	if not Store.IsLoaded() then
		return default
	end
	if key == "clock.shown" and Settings.BarClock() then return false end
	local value = Lookup(Store.Module(MODULE), key)
	if not IsSecret(value) and value == default then return value end
	if not rows then Settings.Schema() end
	if value == nil or Valid(rows[key], value, default) then
		return value == nil and default or value
	end
	if not logged[key] then
		logged[key] = true
		K.DevTest.Log(MODULE, "ignored the saved " .. key .. ", which is not allowed; using the default")
	end
	return default
end
