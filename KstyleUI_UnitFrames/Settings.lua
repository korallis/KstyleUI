-- Settings.lua: the unit frames' defaults, the choices each setting allows, and the settings page rows.
local _, ns = ...

local K = KstyleUI
local Tokens, L = K.Tokens, K.L

local Settings = {}
ns.Settings = Settings

local MODULE = "UnitFrames"
local THEME_FONT = "theme"
local FONT_SIZE_MIN, FONT_SIZE_MAX, FONT_SIZE_STEP = 6, 32, 1
local POWER_HEIGHT_MIN, POWER_HEIGHT_MAX = 2, 24

Settings.MODULE = MODULE
Settings.THEME_FONT = THEME_FONT

local KINDS = { "player", "target", "targettarget", "focus", "focustarget", "pet", "boss" }
Settings.KINDS = KINDS

Settings.LABELS = {
	player = L["Player"],
	target = L["Target"],
	targettarget = L["Target of target"],
	focus = L["Focus"],
	focustarget = L["Focus target"],
	pet = L["Pet"],
	boss = L["Boss"],
}

Settings.ELEMENTS = {
	player = "unitframes.player",
	target = "unitframes.target",
	targettarget = "unitframes.targettarget",
	focus = "unitframes.focus",
	focustarget = "unitframes.focustarget",
	pet = "unitframes.pet",
	boss = "unitframes.boss",
}

Settings.TEXTS = { "name", "health", "power", "level" }

local function Color(token)
	local r, g, b = Tokens.Color(token)
	return { r = r, g = g, b = b }
end

local BAR_TEXTURE = Tokens.MediaList("statusbar")[1].path

local function TextStyle(size)
	return { font = THEME_FONT, size = size, outline = "NONE" }
end

local function Kind(full, overrides)
	local d = {
		enabled = true,
		portrait = full,
		portraitStyle = "portrait",
		portraitSide = "LEFT",
		level = full,
		name = true,
		nameCaps = true,
		healthTexture = BAR_TEXTURE,
		healthColor = "class",
		healthCustom = Color("friendly"),
		healthOrientation = "RIGHT",
		healthText = "percent",
		healPrediction = true,
		power = full,
		powerHeight = full and 5 or 3,
		powerTexture = BAR_TEXTURE,
		powerColor = "power",
		powerCustom = Color("rare"),
		powerOrientation = "RIGHT",
		powerText = full and "currentMax" or "none",
		fonts = {
			name = TextStyle(full and 11 or 9),
			health = TextStyle(full and 11 or 9),
			power = TextStyle(9),
			level = TextStyle(9),
		},
	}
	for key, value in pairs(overrides or {}) do
		d[key] = value
	end
	return d
end

Settings.defaults = {
	hideBlizzard = true,
	accent = "class",
	accentColor = Color("accentDefault"),
	edit = "player",
	player = Kind(true),
	target = Kind(true, { portraitSide = "RIGHT" }),
	targettarget = Kind(false),
	focus = Kind(true, { powerText = "none" }),
	focustarget = Kind(false),
	pet = Kind(false),
	boss = Kind(true, { powerText = "none" }),
}

local function Options(list)
	local out = {}
	for i, item in ipairs(list) do
		out[i] = { value = item[1], label = item[2] }
	end
	return out
end

Settings.CHOICES = {
	portraitStyle = Options({ { "portrait", L["Character portrait"] }, { "class", L["Class icon"] } }),
	portraitSide = Options({ { "LEFT", L["Left"] }, { "RIGHT", L["Right"] } }),
	healthColor = Options({ { "class", L["Class, or reaction for NPCs"] }, { "reaction", L["Reaction"] }, { "custom", L["Custom colour"] } }),
	powerColor = Options({ { "power", L["Power type"] }, { "class", L["Class, or reaction for NPCs"] }, { "reaction", L["Reaction"] }, { "custom", L["Custom colour"] } }),
	orientation = Options({ { "RIGHT", L["Left to right"] }, { "LEFT", L["Right to left"] }, { "UP", L["Bottom to top"] }, { "DOWN", L["Top to bottom"] } }),
	text = Options({
		{ "percent", L["Percentage"] }, { "current", L["Current"] }, { "currentMax", L["Current and max"] },
		{ "both", L["Current, max and percentage"] }, { "none", L["None"] },
	}),
	outline = Options({ { "NONE", L["None (soft shadow)"] }, { "OUTLINE", L["Thin outline"] }, { "THICKOUTLINE", L["Thick outline"] } }),
	accent = Options({ { "class", L["Class colour"] }, { "custom", L["Custom colour"] } }),
}
local CHOICES = Settings.CHOICES

local CHOICE_OF = {
	portraitStyle = "portraitStyle",
	portraitSide = "portraitSide",
	healthColor = "healthColor",
	powerColor = "powerColor",
	healthOrientation = "orientation",
	powerOrientation = "orientation",
	healthText = "text",
	powerText = "text",
}

local function Allowed(list, value)
	for _, option in ipairs(list) do
		if option.value == value then
			return true
		end
	end
	return false
end

local function FontOptions()
	local out = { { value = THEME_FONT, label = L["KstyleUI font"] } }
	local media = K.Widgets and K.Widgets.MediaOptions and K.Widgets.MediaOptions("font") or {}
	for _, option in ipairs(media) do
		out[#out + 1] = { value = option.value, label = option.label }
	end
	return out
end
Settings.FontOptions = FontOptions

local function Log(message)
	K.DevTest.Log(MODULE, message)
end

local logged = {}
local function LogOnce(key, message)
	if not logged[key] then
		logged[key] = true
		Log(message)
	end
end

local function Saved()
	local Store = K.Store
	if Store.IsLoaded() then
		return Store.Module(MODULE)
	end
	return nil
end

function Settings.Module()
	return Saved() or Settings.defaults
end

local function Kinds(kind)
	local d = Settings.defaults[kind]
	if not d then
		error("UnitFrames.Settings: unknown frame " .. tostring(kind), 3)
	end
	local s = Saved()
	local own = s and type(s[kind]) == "table" and s[kind] or d
	return own, d
end

local function IsNumber(v)
	return not (issecretvalue and issecretvalue(v)) and type(v) == "number" and v == v
end

function Settings.Value(kind, key)
	local own, d = Kinds(kind)
	local default = d[key]
	if default == nil then
		error("UnitFrames.Settings.Value: unknown setting " .. tostring(key), 2)
	end
	local value = own[key]
	if type(value) ~= type(default) then
		return default
	end
	local choice = CHOICE_OF[key]
	if choice and not Allowed(CHOICES[choice], value) then
		LogOnce(kind .. "." .. key .. "=" .. tostring(value), kind .. "." .. key .. ": " .. tostring(value) .. " is not a choice; using " .. tostring(default))
		return default
	end
	if key == "powerHeight" and not (IsNumber(value) and value >= POWER_HEIGHT_MIN and value <= POWER_HEIGHT_MAX) then
		LogOnce(kind .. ".powerHeight", kind .. ".powerHeight is out of range; using " .. default)
		return default
	end
	return value
end

local function OutlineFlags(outline)
	if outline == "OUTLINE" or outline == "THICKOUTLINE" then
		return outline
	end
	return ""
end

function Settings.Font(kind, element)
	local own, d = Kinds(kind)
	local default = d.fonts[element]
	if not default then
		error("UnitFrames.Settings.Font: unknown text " .. tostring(element), 2)
	end
	local style = type(own.fonts) == "table" and type(own.fonts[element]) == "table" and own.fonts[element] or default
	local themePath = Tokens.Font("body")
	local path = themePath
	local font = style.font
	if type(font) == "string" and font ~= THEME_FONT then
		if K.Theme.IsFontPath(font) then
			path = font
		else
			LogOnce("font:" .. font, kind .. " " .. element .. " font " .. font .. " is not a font file; using KstyleUI's font")
		end
	end
	local size = style.size
	if not (IsNumber(size) and size >= FONT_SIZE_MIN and size <= FONT_SIZE_MAX) then
		size = default.size
	end
	return path, size * K.Theme.FontScale(), OutlineFlags(style.outline)
end

function Settings.FontSize(kind, element)
	local _, size = Settings.Font(kind, element)
	return size
end

function Settings.Accent()
	local s = Settings.Module()
	if s.accent == "custom" then
		local c = s.accentColor
		if type(c) == "table" and IsNumber(c.r) and IsNumber(c.g) and IsNumber(c.b) then
			return c.r, c.g, c.b
		end
	end
	return K.Theme.Accent()
end

function Settings.Snapshot(kind)
	local fonts = {}
	for _, element in ipairs(Settings.TEXTS) do
		fonts[element] = { size = Settings.FontSize(kind, element) / K.Theme.FontScale() }
	end
	local s = { fonts = fonts }
	for key in pairs(Settings.defaults[kind]) do
		if key ~= "fonts" then
			s[key] = Settings.Value(kind, key)
		end
	end
	return s
end

local function Shows(kind, extra)
	return function(settings)
		if settings.edit ~= kind then
			return false
		end
		return extra == nil or extra(settings[kind] or Settings.defaults[kind]) ~= false
	end
end

local function Header(kind, label)
	return { type = "header", label = Settings.LABELS[kind] .. ": " .. label, showWhen = Shows(kind) }
end

local function Row(kind, row, extra)
	row.key = kind .. "." .. row.key
	row.showWhen = Shows(kind, extra)
	return row
end

local function BarRows(schema, kind, bar)
	local function on(s)
		return bar == "health" or s.power ~= false
	end
	local custom = function(s)
		return on(s) and s[bar .. "Color"] == "custom"
	end
	schema[#schema + 1] = Row(kind, {
		type = "texture", key = bar .. "Texture", label = L["Bar texture"],
		help = L["The texture the bar is filled with."],
	}, on)
	schema[#schema + 1] = Row(kind, {
		type = "dropdown", key = bar .. "Color", label = L["Bar colour"],
		help = L["Where the bar's colour comes from."],
		options = bar == "health" and CHOICES.healthColor or CHOICES.powerColor,
	}, on)
	schema[#schema + 1] = Row(kind, {
		type = "color", key = bar .. "Custom", label = L["Custom bar colour"],
		help = L["The bar's colour when its colour source is custom."],
	}, custom)
	schema[#schema + 1] = Row(kind, {
		type = "dropdown", key = bar .. "Orientation", label = L["Fill direction"],
		help = L["Which way the bar fills."], options = CHOICES.orientation,
	}, on)
	schema[#schema + 1] = Row(kind, {
		type = "dropdown", key = bar .. "Text", label = L["Text"],
		help = bar == "health" and L["How the health text reads."] or L["How the power text reads."],
		options = CHOICES.text,
	}, on)
end

local TEXT_LABELS = {
	name = L["Name text"],
	health = L["Health text"],
	power = L["Power text"],
	level = L["Level text"],
}

local function TextRows(schema, kind, element)
	local prefix = "fonts." .. element .. "."
	local label = TEXT_LABELS[element]
	schema[#schema + 1] = Row(kind, {
		type = "dropdown", key = prefix .. "font", label = label .. ": " .. L["font"],
		help = L["The font of this text. KstyleUI font follows the Appearance page."], options = FontOptions,
	})
	schema[#schema + 1] = Row(kind, {
		type = "slider", key = prefix .. "size", label = label .. ": " .. L["size"],
		help = L["The text size in units at the 1080 reference."],
		min = FONT_SIZE_MIN, max = FONT_SIZE_MAX, step = FONT_SIZE_STEP,
	})
	schema[#schema + 1] = Row(kind, {
		type = "dropdown", key = prefix .. "outline", label = label .. ": " .. L["outline"],
		help = L["A soft shadow, or an outline for text over busy scenes."], options = CHOICES.outline,
	})
end

local function KindRows(schema, kind)
	local function portraitOn(s)
		return s.portrait ~= false
	end
	schema[#schema + 1] = Header(kind, L["frame"])
	schema[#schema + 1] = Row(kind, {
		type = "toggle", key = "enabled", label = L["Show this frame"],
		help = L["Turn this frame off to leave its unit without a KstyleUI frame."],
	})
	schema[#schema + 1] = Row(kind, {
		type = "toggle", key = "portrait", label = L["Portrait"],
		help = L["Shows a round portrait beside the bars."],
	})
	schema[#schema + 1] = Row(kind, {
		type = "dropdown", key = "portraitStyle", label = L["Portrait style"],
		help = L["A 2D character portrait or the unit's class icon."], options = CHOICES.portraitStyle,
	}, portraitOn)
	schema[#schema + 1] = Row(kind, {
		type = "dropdown", key = "portraitSide", label = L["Portrait side"],
		help = L["Which side of the bars the portrait sits on."], options = CHOICES.portraitSide,
	}, portraitOn)
	schema[#schema + 1] = Row(kind, {
		type = "toggle", key = "name", label = L["Name"],
		help = L["Shows the unit's name."],
	})
	schema[#schema + 1] = Row(kind, {
		type = "toggle", key = "nameCaps", label = L["Capital letters"],
		help = L["Writes the name in capital letters, as the KstyleUI captions do."],
	}, function(s)
		return s.name ~= false
	end)
	schema[#schema + 1] = Row(kind, {
		type = "toggle", key = "level", label = L["Level"],
		help = L["Shows the unit's level in a badge on the portrait, or after the name."],
	})
	schema[#schema + 1] = Header(kind, L["health bar"])
	BarRows(schema, kind, "health")
	schema[#schema + 1] = Row(kind, {
		type = "toggle", key = "healPrediction", label = L["Incoming heals"],
		help = L["Shows incoming heals and absorb shields on the health bar."],
	})
	schema[#schema + 1] = Header(kind, L["power bar"])
	schema[#schema + 1] = Row(kind, {
		type = "toggle", key = "power", label = L["Power bar"],
		help = L["Shows the unit's mana, rage, energy or focus under its health."],
	})
	schema[#schema + 1] = Row(kind, {
		type = "slider", key = "powerHeight", label = L["Power bar height"],
		help = L["The height of the power bar in units."],
		min = POWER_HEIGHT_MIN, max = POWER_HEIGHT_MAX, step = 1,
	}, function(s)
		return s.power ~= false
	end)
	BarRows(schema, kind, "power")
	schema[#schema + 1] = Header(kind, L["text"])
	for _, element in ipairs(Settings.TEXTS) do
		TextRows(schema, kind, element)
	end
end

function Settings.Schema()
	local schema = {
		{ type = "header", label = L["Unit frames"] },
		{
			type = "toggle", key = "hideBlizzard", label = L["Hide Blizzard's unit frames"],
			help = L["Hides Blizzard's player, target, focus, pet and boss frames that KstyleUI replaces."],
		},
		{
			type = "dropdown", key = "accent", label = L["Accent"],
			help = L["The colour of the portrait rings and level badges."], options = CHOICES.accent,
		},
		{
			type = "color", key = "accentColor", label = L["Custom accent"],
			help = L["The accent colour when the accent is custom."],
			showWhen = function(s)
				return s.accent == "custom"
			end,
		},
		{ type = "header", label = L["Customise"] },
	}
	local frames = {}
	for i, kind in ipairs(KINDS) do
		frames[i] = { value = kind, label = Settings.LABELS[kind] }
	end
	schema[#schema + 1] = {
		type = "dropdown", key = "edit", label = L["Frame to customise"],
		help = L["Pick a frame to show its settings below."], options = frames,
	}
	for _, kind in ipairs(KINDS) do
		KindRows(schema, kind)
	end
	return schema
end
