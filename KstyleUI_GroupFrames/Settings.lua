-- Settings.lua: the group frames' defaults, their settings schema and checked reads of the saved values.
local _, ns = ...

local K = KstyleUI
local Tokens, L = K.Tokens, K.L

local Settings = {}
ns.Settings = Settings

local MODULE = "GroupFrames"
Settings.MODULE = MODULE

local function Rgb(token)
	local r, g, b = Tokens.Color(token)
	return { r = r, g = g, b = b }
end

local function DefaultTexture()
	for _, item in ipairs(Tokens.MediaList("statusbar")) do
		if item.key == "Glass" then
			return item.path
		end
	end
	return Tokens.MediaList("statusbar")[1].path
end

local DEFAULT_FONT = Tokens.FontPath(Tokens.DEFAULT_FONT_FACE)
local NUMBER_FONT = (Tokens.Font("number"))

Settings.defaults = {
	blizzard = { party = true, raid = true, manager = true },
	party = {
		width = 230, height = 46, spacing = 10, growth = "DOWN",
		showPlayer = true, showSolo = false, sortBy = "INDEX",
		portrait = true, power = true, powerHeight = 4,
		textLayout = "ABOVE", nameSize = 11, healthText = "PERCENT", healthTextSize = 11,
	},
	raid = {
		width = 72, height = 40, spacing = 3, growth = "DOWN",
		groupGrowth = "RIGHT", groupSpacing = 3, groupsPerRow = 8,
		sortBy = "GROUP", unitsPerColumn = 5,
		power = false, powerHeight = 3,
		textLayout = "INSIDE", nameSize = 10, healthText = "NONE", healthTextSize = 9,
	},
	health = { texture = DefaultTexture(), colorSource = "class", color = Rgb("friendly"), orientation = "HORIZONTAL" },
	power = { colorSource = "power", color = Rgb("rare") },
	text = {
		nameFont = DEFAULT_FONT, nameOutline = "NONE", nameColorSource = "text", nameColor = Rgb("textEmphasis"),
		healthFont = NUMBER_FONT, healthOutline = "NONE",
	},
	range = { fade = true, alpha = 0.4 },
	accent = { source = "class", color = Rgb("accentDefault") },
}

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
local OUTLINE = Options({ { "NONE", L["Soft shadow"] }, { "OUTLINE", L["Thin outline"] }, { "THICKOUTLINE", L["Thick outline"] } })
local HEALTH_COLOR = Options({ { "class", L["Class colour"] }, { "reaction", L["Reaction colour"] }, { "custom", L["Custom colour"] } })
local POWER_COLOR = Options({ { "power", L["Power type colour"] }, { "class", L["Class colour"] }, { "custom", L["Custom colour"] } })
local NAME_COLOR = Options({ { "text", L["Text colour"] }, { "class", L["Class colour"] }, { "custom", L["Custom colour"] } })
local ORIENTATION = Options({ { "HORIZONTAL", L["Horizontal"] }, { "VERTICAL", L["Vertical"] } })
local ACCENT = Options({ { "class", L["Class colour"] }, { "custom", L["Custom colour"] } })

Settings.OPTIONS = {
	growth = GROWTH, partySort = PARTY_SORT, raidSort = RAID_SORT, textLayout = TEXT_LAYOUT, healthText = HEALTH_TEXT,
	outline = OUTLINE, healthColor = HEALTH_COLOR, powerColor = POWER_COLOR, nameColor = NAME_COLOR,
	orientation = ORIENTATION, accent = ACCENT,
}

local function Is(key, value)
	return function(settings)
		local node = settings
		for part in key:gmatch("[^%.]+") do
			node = type(node) == "table" and node[part] or nil
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
	if kind == "party" then
		add(Dropdown(p .. "sortBy", L["Sort by"], L["The order of the party frames."], PARTY_SORT))
		add(Toggle(p .. "showPlayer", L["Show yourself"], L["Includes your own frame with the party."]))
		add(Toggle(p .. "showSolo", L["Show when solo"], L["Shows your frame even when you are not in a group."]))
		add(Toggle(p .. "portrait", L["Portraits"], L["Shows each member's portrait beside the bar."]))
	else
		add(Dropdown(p .. "sortBy", L["Sort by"], L["Groups side by side, or everyone in role or class order."], RAID_SORT))
		add(Dropdown(p .. "groupGrowth", L["Group growth"], L["Which way the next group or column goes."], GROWTH))
		add(Slider(p .. "groupSpacing", L["Group spacing"], L["The gap between groups or columns."], 0, 40, 1))
		add(Slider(p .. "groupsPerRow", L["Groups per row"], L["How many groups sit side by side before a new row."], 1, 8, 1))
		schema[#schema].showWhen = Is(p .. "sortBy", "GROUP")
		add(Slider(p .. "unitsPerColumn", L["Frames per column"], L["How many frames fill a column before the next."], 1, 40, 1))
		schema[#schema].showWhen = IsNot(p .. "sortBy", "GROUP")
	end
	add(Toggle(p .. "power", L["Power bar"], L["Shows a thin mana, rage or energy bar under the health bar."]))
	add(Slider(p .. "powerHeight", L["Power bar height"], L["How tall the power bar is."], 1, 12, 1))
	schema[#schema].showWhen = Is(p .. "power", true)
	add(Dropdown(p .. "textLayout", L["Name position"], L["Puts the name above the health bar or on it."], TEXT_LAYOUT))
	add(Slider(p .. "nameSize", L["Name size"], L["The size of the name text."], 6, 24, 1))
	add(Dropdown(p .. "healthText", L["Health text"], L["What the health text shows."], HEALTH_TEXT))
	add(Slider(p .. "healthTextSize", L["Health text size"], L["The size of the health text."], 6, 24, 1))
	schema[#schema].showWhen = IsNot(p .. "healthText", "NONE")
end

local function BuildSchema()
	local schema = {}
	local function add(row)
		schema[#schema + 1] = row
	end
	add({ type = "header", label = L["Blizzard frames"] })
	add(Toggle("blizzard.party", L["Hide Blizzard party frames"], L["Hides the game's own party frames while these are on."]))
	add(Toggle("blizzard.raid", L["Hide Blizzard raid frames"], L["Hides the game's own raid frames while these are on."]))
	add(Toggle("blizzard.manager", L["Hide the raid manager"], L["Hides the game's raid manager tab at the screen's left edge."]))
	KindRows(schema, "party", L["Party frames"])
	KindRows(schema, "raid", L["Raid frames"])
	add({ type = "header", label = L["Health bar"] })
	add({ type = "texture", key = "health.texture", label = L["Bar texture"], help = L["The texture of the health and power bars."] })
	add(Dropdown("health.colorSource", L["Health colour"], L["Colours the health bar by class, by reaction or in one colour."], HEALTH_COLOR))
	add({ type = "color", key = "health.color", label = L["Custom health colour"], help = L["The health bar's colour when it uses a custom colour."], showWhen = Is("health.colorSource", "custom") })
	add(Dropdown("health.orientation", L["Fill direction"], L["Fills the health bar from left to right or from the bottom up."], ORIENTATION))
	add({ type = "header", label = L["Power bar"] })
	add(Dropdown("power.colorSource", L["Power colour"], L["Colours the power bar by power type, by class or in one colour."], POWER_COLOR))
	add({ type = "color", key = "power.color", label = L["Custom power colour"], help = L["The power bar's colour when it uses a custom colour."], showWhen = Is("power.colorSource", "custom") })
	add({ type = "header", label = L["Text"] })
	add({ type = "font", key = "text.nameFont", label = L["Name font"], help = L["The font of the names."] })
	add(Dropdown("text.nameOutline", L["Name outline"], L["A soft shadow, or an outline for busy backgrounds."], OUTLINE))
	add(Dropdown("text.nameColorSource", L["Name colour"], L["Colours names in the text colour, by class or in one colour."], NAME_COLOR))
	add({ type = "color", key = "text.nameColor", label = L["Custom name colour"], help = L["The names' colour when they use a custom colour."], showWhen = Is("text.nameColorSource", "custom") })
	add({ type = "font", key = "text.healthFont", label = L["Health text font"], help = L["The font of the health text."] })
	add(Dropdown("text.healthOutline", L["Health text outline"], L["A soft shadow, or an outline for busy backgrounds."], OUTLINE))
	add({ type = "header", label = L["Range and highlight"] })
	add(Toggle("range.fade", L["Fade out of range"], L["Fades members who are too far away to heal."]))
	add(Slider("range.alpha", L["Out of range opacity"], L["How faint a member out of range looks."], 0.1, 1, 0.05))
	schema[#schema].showWhen = Is("range.fade", true)
	add(Dropdown("accent.source", L["Highlight colour"], L["The colour that marks your target and the frame under the mouse."], ACCENT))
	add({ type = "color", key = "accent.color", label = L["Custom highlight colour"], help = L["The highlight colour when it uses a custom colour."], showWhen = Is("accent.source", "custom") })
	schema.preview = function(parent)
		return ns.Preview.Build(parent)
	end
	return schema
end

Settings.schema = BuildSchema()

local rows = {}
for _, row in ipairs(Settings.schema) do
	if row.key then
		rows[row.key] = row
	end
end
Settings.rows = rows

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
		if type(v) == "table" and Channel(v.r) and Channel(v.g) and Channel(v.b) then
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
	local row = rows[key]
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
for section in pairs(Settings.defaults) do
	current[section] = {}
end
Settings.current = current

function Settings.Refresh()
	for section, out in pairs(current) do
		for name in pairs(Settings.defaults[section]) do
			out[name] = Settings.Get(section .. "." .. name)
		end
	end
	return current
end
Settings.Refresh()
