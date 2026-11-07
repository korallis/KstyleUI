-- Appearance.lua: the accent, font, size and motion settings that drive Theme, Scale and Motion, and LibSharedMedia registration.
local addonName, ns = ...

local Appearance = {}
ns.Appearance = Appearance

local Tokens, Theme, Scale, Motion, Store, L = ns.Tokens, ns.Theme, ns.Scale, ns.Motion, ns.Store, ns.L

local SECTION = "Appearance"
local SIZE_STEP = 0.05
local FONT_SCALE_STEP = 0.05
local MOTION_LEVELS = { full = true, reduced = true, off = true }
local LSM_MAJOR = "LibSharedMedia-3.0"
local LSM_PREFIX = "KstyleUI "

local accentR, accentG, accentB = Tokens.Color("accentDefault")

Appearance.defaults = {
	accentSource = "class",
	accentColor = { r = accentR, g = accentG, b = accentB },
	font = Tokens.DEFAULT_FONT_FACE,
	fontScale = 1,
	uiScale = 1,
	motion = "full",
}

local function Log(message)
	ns.DevTest.Log(SECTION, message)
end

local function IsUnit(v)
	return not (issecretvalue and issecretvalue(v)) and type(v) == "number" and v >= 0 and v <= 1
end

local CLEAN = {
	accentSource = function(v)
		if v == "class" or v == "custom" then
			return v
		end
	end,
	accentColor = function(v)
		if type(v) == "table" and IsUnit(v.r) and IsUnit(v.g) and IsUnit(v.b) then
			return v
		end
	end,
	font = function(v)
		if type(v) == "string" and (Tokens.FontPath(v) or Theme.IsFontPath(v)) then
			return v
		end
	end,
	fontScale = function(v)
		if not (issecretvalue and issecretvalue(v)) and type(v) == "number" and v == v then
			return math.min(Theme.MAX_FONT_SCALE, math.max(Theme.MIN_FONT_SCALE, v))
		end
	end,
	uiScale = function(v)
		if type(v) == "number" and v == v then
			return math.min(Scale.MAX_USER_SCALE, math.max(Scale.MIN_USER_SCALE, v))
		end
	end,
	motion = function(v)
		if MOTION_LEVELS[v] then
			return v
		end
	end,
}

local APPLY = {
	accentColor = function(c)
		Theme.SetCustomAccent(c.r, c.g, c.b)
	end,
	accentSource = Theme.SetAccentSource,
	font = Theme.SetFontFace,
	fontScale = Theme.SetFontScale,
	uiScale = Scale.SetUserScale,
	motion = Motion.SetLevel,
}
local ORDER = { "accentColor", "accentSource", "font", "fontScale", "uiScale", "motion" }

function Appearance.Get(key)
	local clean = CLEAN[key]
	if not clean then
		error("KstyleUI.Appearance.Get: unknown setting " .. tostring(key), 2)
	end
	if Store.IsLoaded() then
		local value = Store.Module(SECTION)[key]
		local ok = clean(value)
		if ok ~= nil then
			return ok
		end
		Log("ignored the saved " .. key .. ", which is not allowed; using the default")
	end
	return Appearance.defaults[key]
end

local function ApplyKey(key)
	APPLY[key](Appearance.Get(key))
end

function Appearance.Apply()
	for _, key in ipairs(ORDER) do
		ApplyKey(key)
	end
end

local function PathKey(path)
	return (path:lower():gsub("/", "\\"))
end

local function FaceOptions()
	local out, seen = {}, {}
	for i, face in ipairs(Tokens.MediaList("font")) do
		out[i] = { value = face.key, label = face.label }
		seen[PathKey(face.path)] = true
	end
	local media = ns.Widgets and ns.Widgets.MediaOptions
	if media then
		local ok, list = pcall(media, "font")
		if ok and type(list) == "table" then
			for _, option in ipairs(list) do
				local path = option.value
				if Theme.IsFontPath(path) and not seen[PathKey(path)] then
					seen[PathKey(path)] = true
					out[#out + 1] = { value = path, label = tostring(option.label) }
				end
			end
		end
	end
	return out
end

Appearance.schema = {
	{ type = "header", label = L["Accent"] },
	{
		type = "dropdown", key = "accentSource", label = L["Accent colour"],
		help = L["Use your class colour, or a colour you pick, for lines, fills and glows."],
		options = { { value = "class", label = L["Class colour"] }, { value = "custom", label = L["Custom colour"] } },
	},
	{
		type = "color", key = "accentColor", label = L["Custom accent"],
		help = L["The accent KstyleUI uses when the accent colour is set to custom."],
		showWhen = function(settings)
			return settings.accentSource == "custom"
		end,
	},
	{ type = "header", label = L["Text"] },
	{
		type = "dropdown", key = "font", label = L["Font"],
		help = L["KstyleUI's typeface, or a LibSharedMedia font; numbers keep Source Sans 3."],
		options = FaceOptions,
	},
	{
		type = "slider", key = "fontScale", label = L["Text size"],
		help = L["Makes KstyleUI's text larger or smaller without changing anything else."],
		min = Theme.MIN_FONT_SCALE, max = Theme.MAX_FONT_SCALE, step = FONT_SCALE_STEP,
	},
	{ type = "header", label = L["Size"] },
	{
		type = "slider", key = "uiScale", label = L["Interface size"],
		help = L["Makes every KstyleUI element larger or smaller."],
		min = Scale.MIN_USER_SCALE, max = Scale.MAX_USER_SCALE, step = SIZE_STEP,
	},
	{ type = "header", label = L["Motion"] },
	{
		type = "dropdown", key = "motion", label = L["Motion"],
		help = L["Full animation, reduced to fades without slides, or off so everything appears at once."],
		options = {
			{ value = "full", label = L["Full"] },
			{ value = "reduced", label = L["Reduced"] },
			{ value = "off", label = L["Off"] },
		},
	},
}

Store.RegisterDefaults(SECTION, Appearance.defaults)
ns.Options.Register(SECTION, Appearance.schema)

local mediaRegistered = false

local function RegisterSharedMedia()
	if mediaRegistered then
		return
	end
	local libstub = rawget(_G, "LibStub")
	if libstub == nil then
		return
	end
	local found, lsm = pcall(libstub, LSM_MAJOR, true)
	if not found or type(lsm) ~= "table" or type(lsm.Register) ~= "function" then
		return
	end
	mediaRegistered = true
	local refused = 0
	for _, kind in ipairs({ "font", "statusbar" }) do
		for _, item in ipairs(Tokens.MediaList(kind)) do
			if not pcall(lsm.Register, lsm, kind, LSM_PREFIX .. item.label, item.path) then
				refused = refused + 1
			end
		end
	end
	if refused == 0 then
		Log("registered KstyleUI's fonts and status bars with LibSharedMedia")
	else
		Log("LibSharedMedia refused " .. refused .. " of KstyleUI's media")
	end
end

ns.Callbacks.Register("SettingChanged", SECTION, function(_, module, key)
	if module == SECTION and APPLY[key] then
		ApplyKey(key)
	end
end)
ns.Callbacks.Register("ProfileChanged", SECTION, Appearance.Apply)

ns.Events.Register(SECTION, "ADDON_LOADED", function(_, name)
	if name == addonName and Store.IsLoaded() then
		ns.Events.Unregister(SECTION, "ADDON_LOADED")
		Appearance.Apply()
	end
end)
ns.Events.Register(SECTION, "PLAYER_LOGIN", function()
	ns.Events.Unregister(SECTION, "PLAYER_LOGIN")
	if Store.IsLoaded() then
		Appearance.Apply()
	end
	RegisterSharedMedia()
end)
