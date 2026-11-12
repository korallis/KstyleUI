-- Appearance.lua: the accent, font, size and motion settings that drive Theme, Scale and Motion, and LibSharedMedia registration.
local addonName, ns = ...

local Appearance = {}
ns.Appearance = Appearance

local Tokens, Theme, Scale, Motion, Store, L = ns.Tokens, ns.Theme, ns.Scale, ns.Motion, ns.Store, ns.L

local SECTION = "Appearance"
local SIZE_STEP = 0.05
local FONT_SCALE_STEP = 0.05
local MOTION_LEVELS = { full = true, reduced = true, off = true }
local HUD_STYLES = { frames = true, orbs = true }
local LSM_MAJOR = "LibSharedMedia-3.0"
local LSM_PREFIX = "KstyleUI "

local accentR, accentG, accentB = Tokens.Color("accentDefault")

local ROLES = Tokens.FontRoles()
local ROLE_KEY = {}
for _, role in ipairs(ROLES) do
	ROLE_KEY[role] = "roleFont" .. role:sub(1, 1):upper() .. role:sub(2)
end

Appearance.defaults = {
	accentSource = "class",
	accentColor = { r = accentR, g = accentG, b = accentB },
	typeSet = Tokens.DEFAULT_FONT_FACE,
	font = "",
	fontScale = 1,
	uiScale = Scale.DEFAULT_USER_SCALE,
	motion = "full",
	hudStyle = "frames",
}
for _, role in ipairs(ROLES) do
	Appearance.defaults[ROLE_KEY[role]] = ""
end

local function Log(message)
	ns.DevTest.Log(SECTION, message)
end

local function IsUnit(v)
	return not (issecretvalue and issecretvalue(v)) and type(v) == "number" and v >= 0 and v <= 1
end

local CLEAN = {
	typeSet = function(v)
		if Tokens.IsFontSet(v) then
			return v
		end
	end,
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
		if type(v) == "string" and (v == "" or Tokens.FontPath(v) or Theme.IsFontPath(v)) then
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
	hudStyle = function(v)
		if not (issecretvalue and issecretvalue(v)) and HUD_STYLES[v] then
			return v
		end
	end,
}

local function CleanRoleFont(v)
	if type(v) == "string" and (v == "" or not Tokens.IsFontSet(v) and (Tokens.FontPath(v) or Theme.IsFontPath(v))) then
		return v
	end
end
for _, role in ipairs(ROLES) do
	CLEAN[ROLE_KEY[role]] = CleanRoleFont
end

local function ApplyRoleFonts()
	local choices = {}
	for _, role in ipairs(ROLES) do
		choices[role] = Appearance.Get(ROLE_KEY[role])
	end
	Theme.SetRoleFonts(choices)
end

local appliedHud, hudQueued

local function ApplyHudStyle(style)
	if appliedHud == nil or style == appliedHud then
		appliedHud = style
		return
	end
	if InCombatLockdown() then
		if not hudQueued then
			hudQueued = true
			ns.Print(L["Your HUD style changes when combat ends."])
			ns.Combat.Queue(function()
				hudQueued = false
				ApplyHudStyle(Appearance.Get("hudStyle"))
			end)
		end
		return
	end
	appliedHud = style
	Log("HUD style " .. style)
	local errors = ns.ErrorCount()
	ns.Callbacks.Fire("HudStyleChanged", style)
	if ns.ErrorCount() > errors then
		ns.Widgets.ReloadPrompt(L["Your HUD style finishes changing when you reload."])
	end
end

function Appearance.HudStyle()
	return appliedHud or Appearance.Get("hudStyle")
end

local APPLY = {
	accentColor = function(c)
		Theme.SetCustomAccent(c.r, c.g, c.b)
	end,
	accentSource = Theme.SetAccentSource,
	typeSet = Theme.SetTypeSet,
	font = Theme.SetFontFace,
	fontScale = Theme.SetFontScale,
	uiScale = Scale.SetUserScale,
	motion = Motion.SetLevel,
	hudStyle = ApplyHudStyle,
}
for _, role in ipairs(ROLES) do
	APPLY[ROLE_KEY[role]] = ApplyRoleFonts
end
local ORDER = { "accentColor", "accentSource", "typeSet", "font", "fontScale", "uiScale", "motion", "hudStyle" }

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
	ApplyRoleFonts()
end

local function PathKey(path)
	return (path:lower():gsub("/", "\\"))
end

local function SetOptions()
	local out = {}
	for _, set in ipairs(Tokens.MediaList("fontSet")) do
		out[#out + 1] = { value = set.key, label = set.label }
	end
	return out
end

local function FaceOptions()
	local out, seen = { { value = "", label = L["Use type set"] } }, {}
	for _, face in ipairs(Tokens.MediaList("font")) do
		out[#out + 1] = { value = face.key, label = face.label }
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
		type = "dropdown", key = "typeSet", label = L["Type set"],
		help = L["Changes inherited fonts together; your chosen fonts stay unchanged."],
		options = SetOptions,
	},
	{
		type = "dropdown", key = "font", label = L["Font"],
		help = L["Replaces the type set; Source Sans 3 stays on numbers unless set below."],
		options = function()
			return FaceOptions()
		end,
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
	{ type = "header", label = L["HUD"] },
	{
		type = "dropdown", key = "hudStyle", label = L["HUD style"],
		help = L["Orbs shows health and resource in two orbs beside the main action buttons. Changes out of combat."],
		options = { { value = "frames", label = L["Frames"] }, { value = "orbs", label = L["Orbs"] } },
	},
}

local ROLE_ROWS = {
	{ "display", L["Display font"], L["Large titles, such as window and page titles."] },
	{ "heading", L["Heading font"], L["Headings and marks such as the minimap's N."] },
	{ "title", L["Title font"], L["Tooltip and menu titles."] },
	{ "caps", L["Capitals font"], L["Small capital labels and section titles."] },
	{ "names", L["Names font"], L["Names on plates, chat tabs and the minimap."] },
	{ "unit", L["Unit name font"], L["The large unit name on column unit frames."] },
	{ "body", L["Body font"], L["Most text: lists, chat, menus and quest lines."] },
	{ "prose", L["Prose font"], L["Longer lines of text, such as the experience bar."] },
	{ "caption", L["Caption font"], L["Small descriptive text, such as macro names."] },
	{ "number", L["Number font"], L["Counts, keybinds and values."] },
	{ "time", L["Time font"], L["Clocks and other times."] },
	{ "timer", L["Timer font"], L["Aura and cooldown timers."] },
	{ "world", L["World text font"], L["Text drawn in the game world, such as plate casts."] },
}

local at
for i, row in ipairs(Appearance.schema) do
	if row.key == "fontScale" then
		at = i
	end
end
local function InsertRow(row)
	at = at + 1
	table.insert(Appearance.schema, at, row)
end
InsertRow({ type = "header", label = L["Fonts by role"] })
InsertRow({ type = "note", label = L["A font you choose here may lack some letters or equal-width figures. KstyleUI adds no spacing to it and uses a standard font if it fails to load."] })
for _, spec in ipairs(ROLE_ROWS) do
	InsertRow({
		type = "font", key = ROLE_KEY[spec[1]], label = spec[2], help = spec[3],
		options = function()
			return ns.Widgets.InheritedFontOptions()
		end,
	})
end

Store.RegisterDefaults(SECTION, Appearance.defaults)
ns.Options.Register(SECTION, Appearance.schema)

local mediaDone = {}
local mediaRefused

local function RegisterSharedMedia()
	local libstub = rawget(_G, "LibStub")
	if libstub == nil then
		return true
	end
	local found, lsm = pcall(libstub, LSM_MAJOR, true)
	if not found or type(lsm) ~= "table" or type(lsm.Register) ~= "function" then
		return true
	end
	local refused = 0
	for _, kind in ipairs({ "font", "statusbar" }) do
		for _, item in ipairs(Tokens.MediaList(kind)) do
			local id = kind .. ":" .. PathKey(item.path)
			if not mediaDone[id] then
				local ok, result = pcall(lsm.Register, lsm, kind, LSM_PREFIX .. item.label, item.path)
				if ok and result ~= false then
					mediaDone[id] = true
				else
					refused = refused + 1
				end
			end
		end
	end
	if refused ~= mediaRefused then
		mediaRefused = refused
		if refused == 0 then
			Log("registered KstyleUI's fonts and status bars with LibSharedMedia")
		else
			Log("LibSharedMedia refused " .. refused .. " of KstyleUI's media; trying again when the next loading screen ends")
		end
	end
	return refused == 0
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
	if not RegisterSharedMedia() then
		ns.Events.Register(SECTION, "PLAYER_ENTERING_WORLD", function()
			if RegisterSharedMedia() then
				ns.Events.Unregister(SECTION, "PLAYER_ENTERING_WORLD")
			end
		end)
	end
end)
