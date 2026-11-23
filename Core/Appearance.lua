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

local function IsUnit(v)
	return not (issecretvalue and issecretvalue(v)) and type(v) == "number" and v >= 0 and v <= 1
end

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
	uiScaleAuto = true,
	snapEdges = true,
	motion = "full",
	calmLists = true,
	auraEndings = true,
	readableBars = true, worldText = true, chatTabs = true, barColors = true, litBars = true,
	textFloor = true, sectionHeadings = true, oneVoice = true, softBacking = true,
}
for _, role in ipairs(ROLES) do
	Appearance.defaults[ROLE_KEY[role]] = ""
end

local CLASSES = { WARRIOR = { 0.78, 0.61, 0.43 }, PALADIN = { 0.96, 0.55, 0.73 }, HUNTER = { 0.67, 0.83, 0.45 }, ROGUE = { 1, 0.96, 0.41 },
	PRIEST = { 1, 1, 1 }, SHAMAN = { 0, 0.44, 0.87 }, MAGE = { 0.25, 0.78, 0.92 }, WARLOCK = { 0.53, 0.53, 0.93 }, DRUID = { 1, 0.49, 0.04 } }
local POWERS = { MANA = { 0, 0, 1 }, RAGE = { 1, 0, 0 }, ENERGY = { 1, 1, 0 }, FOCUS = { 1, 0.5, 0.25 } }
local CLASS_ORDER = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
local POWER_ORDER = { "MANA", "RAGE", "ENERGY", "FOCUS" }
local function Native(list, source)
	local out = {}
	for key, rgb in pairs(list) do
		local c = type(source) == "table" and source[key]
		local plain = type(c) == "table" and IsUnit(c.r) and IsUnit(c.g) and IsUnit(c.b)
		out[key] = plain and { r = c.r, g = c.g, b = c.b } or { r = rgb[1], g = rgb[2], b = rgb[3] }
	end
	return out
end
Appearance.defaults.classColors = Native(CLASSES, rawget(_G, "RAID_CLASS_COLORS"))
Appearance.defaults.powerColors = Native(POWERS, rawget(_G, "PowerBarColor"))
Appearance.defaults.paletteDarken = 0
Appearance.defaults.outline = ""
local PALETTE = { "classColors", "powerColors", "paletteDarken" }

local function Log(message)
	ns.DevTest.Log(SECTION, message)
end

local CLEAN = {
	auraEndings = function(v)
		if type(v) == "boolean" then return v end
	end,
	calmLists = function(v)
		if type(v) == "boolean" then return v end
	end,
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
	uiScaleAuto = function(v)
		if type(v) == "boolean" then
			return v
		end
	end,
	motion = function(v)
		if MOTION_LEVELS[v] then
			return v
		end
	end,
	outline = function(v)
		if v == "" or v == "SHADOW" or v == "OUTLINE" or v == "THICKOUTLINE" then return v end
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

local READABILITY = { readableBars = true, worldText = true, chatTabs = true, barColors = true, litBars = true, snapEdges = true, textFloor = true, sectionHeadings = true, oneVoice = true, softBacking = true }
for key in pairs(READABILITY) do
	CLEAN[key] = function(value)
		if type(value) == "boolean" then return value end
	end
end

local readability = {}
function Appearance.Readability(key)
	return readability[key] ~= false
end

local readabilityPending
local function ApplyReadability()
	if readabilityPending then return end
	readabilityPending = true
	ns.Combat.Queue(function()
		readabilityPending = nil
		local changed
		for key in pairs(READABILITY) do
			local value = Appearance.Get(key)
			changed = changed or Appearance.Readability(key) ~= value
			readability[key] = value
		end
		if not changed then return end
		local layouts = ns.Setup and ns.Setup.Layouts
		if layouts and layouts.BuildMedallions then layouts.BuildMedallions() end
		ns.Callbacks.Fire("ReadabilityChanged")
		ns.Callbacks.Fire("ThemeChanged")
	end)
end

local function ApplyPalette()
	local settings, colors = Store.IsLoaded() and Store.Module(SECTION) or {}, {}
	for _, group in ipairs({ "classColors", "powerColors" }) do
		local saved = type(settings[group]) == "table" and settings[group] or {}
		for key, d in pairs(Appearance.defaults[group]) do
			local c = saved[key]
			if type(c) == "table" and IsUnit(c.r) and IsUnit(c.g) and IsUnit(c.b) and (c.r ~= d.r or c.g ~= d.g or c.b ~= d.b) then
				colors[key] = { r = c.r, g = c.g, b = c.b }
			end
		end
	end
	Theme.SetPalette(colors, settings.paletteDarken)
end

function Appearance.CopyPalette(from, to)
	local profiles = Store.Data().profiles
	local source = type(profiles[from]) == "table" and profiles[from][SECTION] or {}
	for _, name in ipairs(to and { to } or Store.ListProfiles()) do
		if name ~= from and type(profiles[name]) == "table" then
			local live = name == Store.ProfileName()
			profiles[name][SECTION] = type(profiles[name][SECTION]) == "table" and profiles[name][SECTION] or {}
			for _, key in ipairs(PALETTE) do
				local value = source[key]
				if value == nil and live then value = Appearance.defaults[key] end
				profiles[name][SECTION][key] = ns.Options.Copy(value)
			end
			if live then ns.Callbacks.Fire("SettingChanged", SECTION, "classColors") end
		end
	end
	return true
end

local function ApplyRoleFonts()
	local choices = {}
	for _, role in ipairs(ROLES) do
		choices[role] = Appearance.Get(ROLE_KEY[role])
	end
	Theme.SetRoleFonts(choices)
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
	uiScaleAuto = Scale.SetAuto,
	motion = Motion.SetLevel,
	auraEndings = function() ns.Callbacks.Fire("ThemeChanged") end,
	outline = Theme.SetOutline,
	classColors = ApplyPalette, powerColors = ApplyPalette, paletteDarken = ApplyPalette,
}
CLEAN.paletteDarken = function(v) return IsUnit(v) and v or nil end
for _, role in ipairs(ROLES) do
	APPLY[ROLE_KEY[role]] = ApplyRoleFonts
end
for key in pairs(READABILITY) do APPLY[key] = ApplyReadability end
local ORDER = { "accentColor", "accentSource", "typeSet", "font", "fontScale", "uiScaleAuto", "uiScale", "motion", "outline" }

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
	APPLY[key](CLEAN[key] and Appearance.Get(key))
end

local native, saved

local function Read(font)
	local ok, file, height, flags = pcall(font.GetFont, font)
	if ok and not (issecretvalue and (issecretvalue(file) or issecretvalue(height) or issecretvalue(flags))) and type(file) == "string" and type(height) == "number" then
		return { file, height, flags or "" }
	end
end

function Appearance.ApplyGameText()
	if not Store.IsLoaded() then return end
	local account = Store.Account()
	local on, combat, nameFont = account.gameFont == true, account.combatFont == true, account.nameFont == true
	local function Size(v)
		return not (issecretvalue and issecretvalue(v)) and type(v) == "number" and v == v and math.min(1.5, math.max(0.8, v)) or 1
	end
	local scale, combatScale = Size(account.gameTextScale), Size(account.combatTextScale)
	if not (native or saved or on or combat or nameFont or scale ~= 1 or combatScale ~= 1) then return end
	saved = saved or {}
	for name, role in pairs({ STANDARD_TEXT_FONT = on and "body", UNIT_NAME_FONT = (on or nameFont) and "names", DAMAGE_TEXT_FONT = combat and "number" }) do
		if role then
			if saved[name] == nil then saved[name] = rawget(_G, name) or false end
			rawset(_G, name, (Tokens.Font(role)))
		elseif saved[name] ~= nil then
			rawset(_G, name, saved[name] or nil)
			saved[name] = nil
		end
	end
	saved = next(saved) and saved or nil
	if not (native or on or scale ~= 1 or combatScale ~= 1) or type(GetFonts) ~= "function" then return end
	native = native or {}
	local ok, names = pcall(GetFonts)
	local path, live = Tokens.Font("body"), {}
	for _, name in ipairs(ok and type(names) == "table" and names or {}) do
		local font = type(name) == "string" and not name:find("^KstyleUI") and rawget(_G, name)
		local now = type(font) == "table" and type(font.GetFont) == "function" and Read(font)
		local state = now and (native[name] or now[1]:lower():find("^fonts[\\/]") and { font, {}, {}, combat = name:find("^CombatTextFont") ~= nil })
		if state then
			for i = 1, 3 do
				if now[i] ~= state[3][i] then state[2][i] = now[i] end
			end
			native[name], live[#live + 1] = state, state
		end
	end
	for _, state in ipairs(live) do
		local font, original = state[1], state[2]
		local size = state.combat and scale * combatScale or scale
		local want, now = { on and path or original[1], original[2] * size, original[3] }, Read(font) or {}
		if now[1] ~= want[1] or now[2] ~= want[2] or now[3] ~= want[3] then pcall(font.SetFont, font, want[1], want[2], want[3]) end
		state[3] = Read(font) or want
	end
	if not on and scale == 1 and combatScale == 1 then native = nil end
end

function Appearance.Apply()
	for _, key in ipairs(ORDER) do
		ApplyKey(key)
	end
	ApplyRoleFonts()
	ApplyPalette()
	ApplyReadability()
	Appearance.ApplyGameText()
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
	for _, entry in ipairs({ { "GameFontNormal", L["Blizzard Default"] }, { "ChatFontNormal", L["Blizzard Chat"] }, { "SystemFont_Med1", L["System Default"] } }) do
		local object = rawget(_G, entry[1])
		if object and type(object.GetFont) == "function" then
			local ok, path = pcall(object.GetFont, object)
			if native and native[entry[1]] then path = native[entry[1]][2][1] end
			if ok and not (issecretvalue and issecretvalue(path)) and Theme.IsFontPath(path) and not seen[PathKey(path)] then
				out[#out + 1] = { value = path, label = entry[2] }
				seen[PathKey(path)] = true
			end
		end
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

function Appearance.Schema()
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
		{ type = "dropdown", key = "outline", label = L["Text outline"], help = L["A thin or thick outline, or a soft shadow, around the text."], options = {
			{ value = "", label = L["Current style"] }, { value = "SHADOW", label = L["Soft shadow"] },
			{ value = "OUTLINE", label = L["Thin outline"] }, { value = "THICKOUTLINE", label = L["Thick outline"] },
		} },
		{
			type = "slider", key = "fontScale", label = L["Text size"],
			help = L["Makes KstyleUI's text larger or smaller without changing anything else."],
			min = Theme.MIN_FONT_SCALE, max = Theme.MAX_FONT_SCALE, step = FONT_SCALE_STEP,
		},
		{ type = "header", label = L["Size"] },
		{ type = "toggle", key = "snapEdges", label = L["Snap hard edges"],
			help = L["Keep window borders and chat tab underlines on whole pixels. Off restores their original placement."] },
		{
			type = "toggle", key = "uiScaleAuto", label = L["Interface size: Auto (pixel perfect)"],
			help = L["Sizes KstyleUI for your screen so every edge lands on a whole pixel."],
		},
		{
			type = "slider", key = "uiScale", label = L["Interface size"],
			help = L["Makes every KstyleUI element larger or smaller, in whole-pixel steps."],
			min = Scale.MIN_USER_SCALE, max = Scale.MAX_USER_SCALE, step = SIZE_STEP,
			showWhen = function(settings)
				return settings.uiScaleAuto == false
			end,
		},
		{ type = "header", label = L["Readability"] },
		{ type = "toggle", key = "textFloor", label = L["Text follows interface size"],
			help = L["Size small text with your interface. Off uses the original screen-height minimum."] },
		{ type = "toggle", key = "sectionHeadings", label = L["Consistent section headings"],
			help = L["Gold section caps and tabs, with smaller option help. Off restores the original headings."] },
		{ type = "toggle", key = "readableBars", label = L["Readable text on bars"],
			help = L["Clearer bar ink, outside skin captions and spaced casts. Off restores the original look."] },
		{ type = "toggle", key = "worldText", label = L["Backing for text over the world"],
			help = L["Stronger name shadows, thin unit and aura outlines, and soft backing for exposed text."] },
		{ type = "toggle", key = "softBacking", label = L["Soft glow behind world text"],
			help = L["A soft dark glow behind nameplate names and a drop shadow under outlined timers and counts."] },
		{ type = "toggle", key = "oneVoice", label = L["One typeface voice"],
			help = L["Medallions names, levels and cast names share the number face. Off restores the original faces."] },
		{ type = "toggle", key = "chatTabs", label = L["Chat tabs always readable"],
			help = L["Keep chat tabs visible, underline their names and leave room above the first message."] },
		{ type = "toggle", key = "barColors", label = L["Bar colour refinements"],
			help = L["Tint lost health from its bar and make mana a darker step below health."] },
		{ type = "toggle", key = "litBars", label = L["Lit glass bars"],
			help = L["A soft light, thin inner edge and depth on KstyleUI's own bars. Off restores each bar's old finish."] },
		{ type = "header", label = L["Motion"] },
		{ type = "toggle", key = "auraEndings", label = L["Quiet aura endings"],
			help = L["Round up aura timers and hide the finishing flash on aura swipes. Off restores the old endings."] },
		{ type = "toggle", key = "calmLists", label = L["Calmer settings lists"],
			help = L["Search appears at once; page lists and previews fade briefly. Off restores the original motion."] },
		{
			type = "dropdown", key = "motion", label = L["Motion"],
			help = L["Full animates; Calm keeps short fades and flashes without slides or loops; Off is still."],
			options = {
				{ value = "full", label = L["Full"] },
				{ value = "reduced", label = L["Calm"] },
				{ value = "off", label = L["Off"] },
			},
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

	local classNames = rawget(_G, "LOCALIZED_CLASS_NAMES_MALE")
	local function Colour(group, key, label, help)
		local schema = Appearance.schema
		schema[#schema + 1] = { type = "color", key = group .. "." .. key, label = type(label) == "string" and label or key:sub(1, 1) .. key:sub(2):lower(), help = help }
	end
	Appearance.schema[#Appearance.schema + 1] = { type = "header", label = L["Class and power colours"] }
	for _, file in ipairs(CLASS_ORDER) do
		Colour("classColors", file, type(classNames) == "table" and classNames[file], L["Wherever KstyleUI shows this class colour; the accent keeps its own setting."])
	end
	for _, token in ipairs(POWER_ORDER) do
		Colour("powerColors", token, rawget(_G, token), L["Unit and group frame bars that show this power use this colour."])
	end
	Appearance.schema[#Appearance.schema + 1] = { type = "slider", key = "paletteDarken", label = L["Darken class and power colours"], min = 0, max = 0.6, step = 0.05,
		help = L["Darkens class and power colours by this share; zero keeps them as they are."] }

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
	return Appearance.schema
end

Store.RegisterDefaults(SECTION, Appearance.defaults)
ns.Options.Register(SECTION, Appearance.Schema)

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
	key = module == SECTION and type(key) == "string" and key:match("^[^%.]+") or key
	if module == SECTION and APPLY[key] then
		ApplyKey(key)
		if native or saved then Appearance.ApplyGameText() end
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
