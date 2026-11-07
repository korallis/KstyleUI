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
local ICON_SIZE_MIN, ICON_SIZE_MAX = 8, 32
local CAST_HEIGHT_MIN, CAST_HEIGHT_MAX = 6, 40
local AURA_SIZE_MIN, AURA_SIZE_MAX = 12, 48
local AURA_SPACING_MAX = 12
local AURA_ROWS_MAX, AURA_COLUMNS_MAX = 6, 16
local SPACING_MIN, SPACING_MAX = 0, 12

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

Settings.CASTBAR = { player = true, target = true, focus = true, boss = true }
Settings.CAST_ELEMENTS = { player = "unitframes.castbar.player", target = "unitframes.castbar.target" }
Settings.AURAS = { player = true, target = true, focus = true, boss = true }

local function Color(token)
	local r, g, b = Tokens.Color(token)
	return { r = r, g = g, b = b }
end

local BAR_TEXTURE = Tokens.MediaList("statusbar")[1].path

local function TextStyle(size)
	return { font = THEME_FONT, size = size, outline = "NONE" }
end

local COMPACT_TEXT = { 9, 9, 9, 9 }

local function Kind(full, overrides, castHeight, castFont, aura, text)
	text = text or COMPACT_TEXT
	local d = {
		enabled = true,
		portrait = full,
		portraitStyle = "portrait",
		portraitShape = "chamfered",
		portraitSide = "LEFT",
		level = full,
		name = true,
		nameCaps = true,
		healthTexture = BAR_TEXTURE,
		healthColor = "class",
		healthCustom = Color("friendly"),
		healthOrientation = "RIGHT",
		healthText = full and "both" or "percent",
		healPrediction = true,
		power = full,
		powerHeight = 3,
		powerTexture = BAR_TEXTURE,
		powerColor = "power",
		powerCustom = Color("rare"),
		powerOrientation = "RIGHT",
		powerText = "none",
		raidMarker = true,
		leader = full,
		role = full,
		pvp = full,
		combat = false,
		resting = false,
		threat = full,
		iconSize = 14,
		castbar = castHeight ~= nil,
		castbarHeight = castHeight or 20,
		castbarIcon = true,
		castbarText = true,
		castbarTimer = true,
		castbarTexture = BAR_TEXTURE,
		castbarColor = "class",
		castbarCustom = Color("rare"),
		castbarOrientation = "RIGHT",
		auras = aura ~= nil and aura.on or false,
		auraFilter = "mine",
		auraSize = aura and aura.size or 20,
		auraSpacing = 2,
		auraRows = 1,
		auraColumns = aura and aura.columns or 8,
		auraGrowth = "RIGHT_DOWN",
		auraPosition = aura and aura.position or "BELOW",
		auraTimer = true,
		fonts = {
			name = TextStyle(text[1]),
			health = TextStyle(text[2]),
			power = TextStyle(text[3]),
			level = TextStyle(text[4]),
			cast = TextStyle(castFont or 10),
			aura = TextStyle(8),
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
	player = Kind(true, { combat = true, resting = true }, 20, 11, { on = false, size = 22, position = "BELOW" }, { 15, 15, 13, 15 }),
	target = Kind(true, { portraitSide = "RIGHT", healthColor = "reaction" }, 14, 10, { on = false, size = 20, position = "ABOVE" }, { 15, 15, 13, 15 }),
	targettarget = Kind(false),
	focus = Kind(true, nil, 20, 10, { on = true, size = 20, position = "RIGHT" }, { 12, 12, 10, 12 }),
	focustarget = Kind(false),
	pet = Kind(false),
	boss = Kind(true, nil, 10, 9, { on = true, size = 18, columns = 6, position = "RIGHT" }, { 10, 10, 9, 10 }),
	resource = {
		enabled = true,
		comboPoints = true,
		druidMana = true,
		comboColor = "class",
		comboCustom = Color("neutral"),
		manaColor = "power",
		manaCustom = Color("rare"),
		manaTexture = BAR_TEXTURE,
		manaOrientation = "RIGHT",
		spacing = 3,
	},
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
	portraitShape = Options({ { "chamfered", L["Chamfered"] }, { "round", L["Round"] } }),
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
	manaColor = Options({ { "power", L["Power type"] }, { "class", L["Class colour"] }, { "custom", L["Custom colour"] } }),
	castbarColor = Options({ { "class", L["Class colour"] }, { "reaction", L["Reaction"] }, { "custom", L["Custom colour"] } }),
	auraFilter = Options({ { "mine", L["Your debuffs"] }, { "debuffs", L["All debuffs"] }, { "buffs", L["Buffs"] }, { "both", L["Debuffs and buffs"] } }),
	auraGrowth = Options({ { "RIGHT_DOWN", L["Right, then down"] }, { "RIGHT_UP", L["Right, then up"] }, { "LEFT_DOWN", L["Left, then down"] }, { "LEFT_UP", L["Left, then up"] } }),
	auraPosition = Options({ { "BELOW", L["Below the frame"] }, { "ABOVE", L["Above the frame"] }, { "RIGHT", L["Right of the frame"] }, { "LEFT", L["Left of the frame"] } }),
}
local CHOICES = Settings.CHOICES

local CHOICE_OF = {
	portraitStyle = "portraitStyle",
	portraitShape = "portraitShape",
	portraitSide = "portraitSide",
	healthColor = "healthColor",
	powerColor = "powerColor",
	healthOrientation = "orientation",
	powerOrientation = "orientation",
	healthText = "text",
	powerText = "text",
	castbarColor = "castbarColor",
	castbarOrientation = "orientation",
	auraFilter = "auraFilter",
	auraGrowth = "auraGrowth",
	auraPosition = "auraPosition",
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

local RANGES = {
	powerHeight = { POWER_HEIGHT_MIN, POWER_HEIGHT_MAX },
	iconSize = { ICON_SIZE_MIN, ICON_SIZE_MAX },
	castbarHeight = { CAST_HEIGHT_MIN, CAST_HEIGHT_MAX },
	auraSize = { AURA_SIZE_MIN, AURA_SIZE_MAX },
	auraSpacing = { 0, AURA_SPACING_MAX },
	auraRows = { 1, AURA_ROWS_MAX },
	auraColumns = { 1, AURA_COLUMNS_MAX },
}

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
	local range = RANGES[key]
	if range and not (IsNumber(value) and value >= range[1] and value <= range[2]) then
		LogOnce(kind .. "." .. key, kind .. "." .. key .. " is out of range; using " .. default)
		return default
	end
	return value
end

local RESOURCE_CHOICES = { comboColor = "accent", manaColor = "manaColor", manaOrientation = "orientation" }

function Settings.Resource(key)
	local d = Settings.defaults.resource
	local default = d[key]
	if default == nil then
		error("UnitFrames.Settings.Resource: unknown setting " .. tostring(key), 2)
	end
	local s = Saved()
	local own = s and type(s.resource) == "table" and s.resource or d
	local value = own[key]
	if type(value) ~= type(default) then
		return default
	end
	local choice = RESOURCE_CHOICES[key]
	if choice and not Allowed(CHOICES[choice], value) then
		LogOnce("resource." .. key, "resource." .. key .. ": " .. tostring(value) .. " is not a choice; using " .. tostring(default))
		return default
	end
	if key == "spacing" and not (IsNumber(value) and value >= SPACING_MIN and value <= SPACING_MAX) then
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

local IconRows, ResourceRows, CastRows, AuraRows

local function Scope(kind)
	return { key = "edit", value = kind }
end

local function Header(kind, label)
	return { type = "header", label = Settings.LABELS[kind] .. ": " .. label, showWhen = Shows(kind), scope = Scope(kind) }
end

local function Row(kind, row, extra)
	row.key = kind .. "." .. row.key
	row.showWhen = Shows(kind, extra)
	row.scope = Scope(kind)
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
	cast = L["Cast bar text"],
	aura = L["Aura text"],
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

local ICON_ROWS = {
	{ "raidMarker", L["Raid marker"], L["Shows the raid marker set on the unit."] },
	{ "leader", L["Leader icon"], L["Shows a crown when the unit leads the group."] },
	{ "role", L["Role icon"], L["Shows the unit's group role."] },
	{ "pvp", L["PvP icon"], L["Shows the faction badge while the unit is flagged for PvP."] },
	{ "combat", L["Combat icon"], L["Shows crossed swords while the unit is in combat."] },
	{ "resting", L["Resting"], L["Shows Zz while you rest in an inn or a city."], "player" },
	{ "threat", L["Threat glow"], L["Glows in the threat colour when the unit has or causes threat."] },
}

IconRows = function(schema, kind)
	schema[#schema + 1] = Header(kind, L["icons"])
	for _, spec in ipairs(ICON_ROWS) do
		if spec[4] == nil or spec[4] == kind then
			schema[#schema + 1] = Row(kind, { type = "toggle", key = spec[1], label = spec[2], help = spec[3] })
		end
	end
	schema[#schema + 1] = Row(kind, {
		type = "slider", key = "iconSize", label = L["Icon size"],
		help = L["The size of the status icons on the frame's top edge."],
		min = ICON_SIZE_MIN, max = ICON_SIZE_MAX, step = 1,
	})
end

CastRows = function(schema, kind)
	local function on(s)
		return s.castbar ~= false
	end
	schema[#schema + 1] = Header(kind, L["cast bar"])
	schema[#schema + 1] = Row(kind, {
		type = "toggle", key = "castbar", label = L["Cast bar"],
		help = L["Shows the unit's casts and channels."],
	})
	if not Settings.CAST_ELEMENTS[kind] then
		schema[#schema + 1] = Row(kind, {
			type = "slider", key = "castbarHeight", label = L["Cast bar height"],
			help = L["The height of the cast bar under the frame, in units."],
			min = CAST_HEIGHT_MIN, max = CAST_HEIGHT_MAX, step = 1,
		}, on)
	end
	schema[#schema + 1] = Row(kind, {
		type = "toggle", key = "castbarIcon", label = L["Spell icon"],
		help = L["Shows the spell's icon beside the cast bar."],
	}, on)
	schema[#schema + 1] = Row(kind, {
		type = "toggle", key = "castbarText", label = L["Spell name"],
		help = L["Shows the spell's name on the cast bar."],
	}, on)
	schema[#schema + 1] = Row(kind, {
		type = "toggle", key = "castbarTimer", label = L["Timer"],
		help = L["Shows the seconds left on the cast bar."],
	}, on)
	schema[#schema + 1] = Row(kind, {
		type = "texture", key = "castbarTexture", label = L["Cast bar texture"],
		help = L["The texture the cast bar is filled with."],
	}, on)
	schema[#schema + 1] = Row(kind, {
		type = "dropdown", key = "castbarColor", label = L["Cast bar colour"],
		help = L["The class colour, the caster's reaction to you, or a custom colour."], options = CHOICES.castbarColor,
	}, on)
	schema[#schema + 1] = Row(kind, {
		type = "color", key = "castbarCustom", label = L["Custom cast bar colour"],
		help = L["The cast bar's colour when it is custom."],
	}, function(s)
		return on(s) and s.castbarColor == "custom"
	end)
	schema[#schema + 1] = Row(kind, {
		type = "dropdown", key = "castbarOrientation", label = L["Cast bar fill direction"],
		help = L["Which way the cast bar fills. A bar taller than it is wide stacks its icon on top."],
		options = CHOICES.orientation,
	}, on)
	TextRows(schema, kind, "cast")
end

AuraRows = function(schema, kind)
	local function on(s)
		return s.auras == true
	end
	schema[#schema + 1] = Header(kind, L["auras"])
	schema[#schema + 1] = Row(kind, {
		type = "toggle", key = "auras", label = L["Auras"],
		help = L["Shows the unit's buffs and debuffs beside the frame."],
	})
	schema[#schema + 1] = Row(kind, {
		type = "dropdown", key = "auraFilter", label = L["Which auras"],
		help = L["Your debuffs, all debuffs, buffs, or debuffs and buffs."], options = CHOICES.auraFilter,
	}, on)
	schema[#schema + 1] = Row(kind, {
		type = "dropdown", key = "auraPosition", label = L["Aura position"],
		help = L["Which side of the frame the auras sit on."], options = CHOICES.auraPosition,
	}, on)
	schema[#schema + 1] = Row(kind, {
		type = "dropdown", key = "auraGrowth", label = L["Aura growth"],
		help = L["Which way new aura icons are added."], options = CHOICES.auraGrowth,
	}, on)
	schema[#schema + 1] = Row(kind, {
		type = "slider", key = "auraSize", label = L["Aura icon size"],
		help = L["The size of each aura icon in units."], min = AURA_SIZE_MIN, max = AURA_SIZE_MAX, step = 1,
	}, on)
	schema[#schema + 1] = Row(kind, {
		type = "slider", key = "auraSpacing", label = L["Aura spacing"],
		help = L["The gap between aura icons in units."], min = 0, max = AURA_SPACING_MAX, step = 1,
	}, on)
	schema[#schema + 1] = Row(kind, {
		type = "slider", key = "auraRows", label = L["Aura rows"],
		help = L["How many rows of each kind of aura show."], min = 1, max = AURA_ROWS_MAX, step = 1,
	}, on)
	schema[#schema + 1] = Row(kind, {
		type = "slider", key = "auraColumns", label = L["Aura columns"],
		help = L["How many aura icons fit in a row."], min = 1, max = AURA_COLUMNS_MAX, step = 1,
	}, on)
	schema[#schema + 1] = Row(kind, {
		type = "toggle", key = "auraTimer", label = L["Aura timers"],
		help = L["Shows the time left on each aura."],
	}, on)
	TextRows(schema, kind, "aura")
end

ResourceRows = function(schema)
	local function shows(extra)
		return function(settings)
			if settings.edit ~= "player" then
				return false
			end
			local r = type(settings.resource) == "table" and settings.resource or Settings.defaults.resource
			return extra == nil or extra(r) ~= false
		end
	end
	local function on(r)
		return r.enabled ~= false
	end
	local first = #schema + 1
	schema[#schema + 1] = { type = "header", label = Settings.LABELS.player .. ": " .. L["class resource"], showWhen = shows() }
	schema[#schema + 1] = {
		type = "toggle", key = "resource.enabled", label = L["Class resource"], showWhen = shows(),
		help = L["Shows combo points and the druid's mana under the player frame."],
	}
	schema[#schema + 1] = {
		type = "toggle", key = "resource.comboPoints", label = L["Combo points"], showWhen = shows(on),
		help = L["Shows rogue and cat form combo points as pips."],
	}
	schema[#schema + 1] = {
		type = "dropdown", key = "resource.comboColor", label = L["Combo point colour"], showWhen = shows(on),
		help = L["The pips follow the class colour or a custom colour."], options = CHOICES.accent,
	}
	schema[#schema + 1] = {
		type = "color", key = "resource.comboCustom", label = L["Custom combo point colour"],
		help = L["The pips' colour when it is custom."],
		showWhen = shows(function(r)
			return on(r) and r.comboColor == "custom"
		end),
	}
	schema[#schema + 1] = {
		type = "slider", key = "resource.spacing", label = L["Pip spacing"], showWhen = shows(on),
		help = L["The gap between combo point pips in units."], min = SPACING_MIN, max = SPACING_MAX, step = 1,
	}
	schema[#schema + 1] = {
		type = "toggle", key = "resource.druidMana", label = L["Druid mana"], showWhen = shows(on),
		help = L["Shows your mana in bear and cat form."],
	}
	schema[#schema + 1] = {
		type = "texture", key = "resource.manaTexture", label = L["Mana bar texture"], showWhen = shows(on),
		help = L["The texture the druid mana bar is filled with."],
	}
	schema[#schema + 1] = {
		type = "dropdown", key = "resource.manaColor", label = L["Mana bar colour"], showWhen = shows(on),
		help = L["Where the druid mana bar's colour comes from."], options = CHOICES.manaColor,
	}
	schema[#schema + 1] = {
		type = "color", key = "resource.manaCustom", label = L["Custom mana colour"],
		help = L["The mana bar's colour when it is custom."],
		showWhen = shows(function(r)
			return on(r) and r.manaColor == "custom"
		end),
	}
	schema[#schema + 1] = {
		type = "dropdown", key = "resource.manaOrientation", label = L["Mana bar fill direction"], showWhen = shows(on),
		help = L["Which way the druid mana bar fills."], options = CHOICES.orientation,
	}
	for i = first, #schema do
		schema[i].scope = Scope("player")
	end
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
		help = L["Shows a portrait beside the bars."],
	})
	schema[#schema + 1] = Row(kind, {
		type = "dropdown", key = "portraitStyle", label = L["Portrait style"],
		help = L["A 2D character portrait or the unit's class icon."], options = CHOICES.portraitStyle,
	}, portraitOn)
	schema[#schema + 1] = Row(kind, {
		type = "dropdown", key = "portraitShape", label = L["Portrait shape"],
		help = L["A chamfered frame, as on the KstyleUI kit, or a round ring. The level badge follows it."],
		options = CHOICES.portraitShape,
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
	IconRows(schema, kind)
	if Settings.CASTBAR[kind] then
		CastRows(schema, kind)
	end
	if Settings.AURAS[kind] then
		AuraRows(schema, kind)
	end
	if kind == "player" then
		ResourceRows(schema)
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
			help = L["The colour of the portrait frames, and of the badges on round portraits."], options = CHOICES.accent,
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
