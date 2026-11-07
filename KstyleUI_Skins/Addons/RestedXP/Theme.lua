-- Theme.lua: the KstyleUI theme for RestedXP Guides, built from KstyleUI's tokens and accent, registered through RestedXP's theme API, made RestedXP's active theme while the RestedXP switch is on, and the player's own theme given back when it turns off.
local _, ns = ...

local K = KstyleUI
local Tokens, Widgets = K.Tokens, K.Widgets
local Style = ns.Style

local RestedXP = ns.RestedXP or {}
ns.RestedXP = RestedXP

local Theme = {}
RestedXP.Theme = Theme

local MODULE = "Skins"
local ADDON = "RXPGuides"
local NAME = "KstyleUI"
local MEMORY = "restedXPTheme"
local DEFAULT_THEME = "RXP Blue"
local BASE_V1, DARK_V1, BASE_V2 = "RXP Blue", "DarkMode", "RXP Blue V2"
local FLAT = "Interface\\Buttons\\WHITE8X8"
local V2_VERSION = 2
local HIGHLIGHT_ALPHA = 0.5
local BORDER_ALPHA = 0.6
local EDGES = { "edge", "guideName" }
local BORDER_ART = "rxp-borders"
local BYTE = 255

Theme.NAME = NAME

local state = {
	v1 = nil,
	v2 = nil,
	key = nil,
	want = false,
	startup = false,
	queued = false,
	redrawing = false,
	hooked = false,
}
local logged = {}

local function IsSecret(value)
	return issecretvalue ~= nil and issecretvalue(value) == true
end

local function IsText(value)
	return not IsSecret(value) and type(value) == "string" and value ~= ""
end

function RestedXP.LogOnce(id, message)
	if logged[id] then
		return
	end
	logged[id] = true
	K.DevTest.Log(MODULE, "restedXP: " .. message)
end

local LogOnce = RestedXP.LogOnce

function RestedXP.Try(name, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		LogOnce("call " .. name, "RestedXP's " .. name .. " failed (" .. tostring(err) .. "); the theme may show after /reload")
	end
	return ok
end

local Try = RestedXP.Try

local function Method(object, name)
	return type(object) == "table" and type(object[name]) == "function"
end

local function Shaped(rxp)
	if not (Method(rxp, "RegisterTheme") and Method(rxp, "LoadActiveTheme") and type(rxp.themes) == "table") then
		return false, "RegisterTheme, LoadActiveTheme or the themes table"
	end
	local settings = rxp.settings
	if type(settings) ~= "table" or type(settings.profile) ~= "table" then
		return false, "settings.profile"
	end
	local v2 = rxp.v2
	if type(v2) ~= "table" or type(v2.themes) ~= "table" or not Method(v2, "IsGuideWindowEnabled") then
		return false, "the v2 themes"
	end
	return true
end

function RestedXP.Addon()
	local stub = rawget(_G, "LibStub")
	if stub == nil then
		LogOnce("libstub", "LibStub is missing, so RestedXP is not loaded; skipped")
		return nil
	end
	local ok, ace = pcall(stub, "AceAddon-3.0", true)
	if not ok or type(ace) ~= "table" or type(ace.GetAddon) ~= "function" then
		LogOnce("ace", "AceAddon-3.0 is missing, so RestedXP is not loaded; skipped")
		return nil
	end
	local found, rxp = pcall(ace.GetAddon, ace, ADDON, true)
	if not found or type(rxp) ~= "table" then
		LogOnce("addon", "RestedXP is not loaded; skipped")
		return nil
	end
	local shaped, missing = Shaped(rxp)
	if not shaped then
		LogOnce("shape", "RestedXP's " .. missing .. " is missing in this version; skipped")
		return nil
	end
	return rxp
end

local function Put(list, r, g, b, a)
	list[1], list[2], list[3], list[4] = r, g, b, a or 1
	return list
end

local function List(holder, key)
	local list = holder[key]
	if type(list) ~= "table" then
		list = {}
		holder[key] = list
	end
	return list
end

local function Token(holder, key, name, alpha)
	local r, g, b, a = Tokens.Color(name)
	return Put(List(holder, key), r, g, b, alpha or a)
end

local function Accent(holder, key, alpha)
	local r, g, b = Style.Accent()
	return Put(List(holder, key), r, g, b, alpha or 1)
end

local function Hex(value)
	local n = math.floor(value * BYTE + 0.5)
	return math.max(0, math.min(BYTE, n))
end

local function Copy(value)
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in pairs(value) do
		out[k] = Copy(v)
	end
	return out
end

local function Opacity()
	return Widgets.Setting("panelOpacity")
end

local function Font()
	return (Style.Font("body"))
end

local function Key()
	local r, g, b = Style.Accent()
	return string.format("%.4f %.4f %.4f %.4f %s", r, g, b, Opacity(), tostring(Font()))
end

local function BuildV1(rxp)
	local v1 = state.v1 or {}
	state.v1 = v1
	local base = type(rxp.themes[BASE_V1]) == "table" and rxp.themes[BASE_V1] or {}
	local dark = type(rxp.themes[DARK_V1]) == "table" and rxp.themes[DARK_V1] or base
	v1.name, v1.displayName, v1.author, v1.applicable = NAME, NAME, NAME, true
	if IsText(dark.texturePath) then
		v1.texturePath = dark.texturePath
	end
	v1.headerTexture = dark.headerTexture or base.headerTexture
	local opacity = Opacity()
	Token(v1, "background", "surface", opacity)
	Token(v1, "bottomFrameBG", "raised", opacity)
	Accent(v1, "bottomFrameHighlight", HIGHLIGHT_ALPHA)
	Accent(v1, "mapPins")
	local r, g, b = Style.Accent()
	v1.tooltip = string.format("|cff%02x%02x%02x", Hex(r), Hex(g), Hex(b))
	v1.font = Font()
	local er, eg, eb = Tokens.Color("textEmphasis")
	v1.textColor = Put(List(v1, "textColor"), er, eg, eb)
	v1.textColor[4] = nil
	v1.bgTextures = v1.bgTextures or {}
	v1.bgTextures.edge, v1.bgTextures.bottom = FLAT, FLAT
	v1.edges = v1.edges or {}
	for _, piece in ipairs(EDGES) do
		local edge = IsText(v1.texturePath) and v1.texturePath .. BORDER_ART or (type(base.edges) == "table" and base.edges[piece])
		v1.edges[piece] = edge or nil
	end
	return v1
end

local function BuildV2(rxp)
	local v2 = state.v2
	if not v2 then
		local base = rxp.v2.themes[BASE_V2]
		v2 = type(base) == "table" and Copy(base) or {}
		state.v2 = v2
	end
	v2.name, v2.displayName, v2.author, v2.applicable = NAME, NAME, NAME, true
	v2.version = math.max(V2_VERSION, tonumber(v2.version) or 0)
	v2.converted = nil
	v2.font = Font()
	Accent(v2, "mapPins")
	local opacity = Opacity()
	local back = List(v2, "backgroundColors")
	Token(back, "common", "raised", opacity)
	Token(back, "guideName", "surface", opacity)
	Token(back, "guideWindow", "surface", opacity)
	Token(back, "scrollbar", "track")
	Token(back, "guideSelector", "raised")
	Token(back, "inactivePartyTab", "surface", opacity)
	Token(back, "activeStepCheckbox", "raised")
	Accent(back, "activeStepCheckboxChecked")
	local border = List(v2, "borderColors")
	Accent(border, "common", BORDER_ALPHA)
	Accent(border, "commonEdge", BORDER_ALPHA)
	Token(border, "inactivePartyTab", "edgeInner")
	Accent(border, "activeStepCheckboxChecked")
	local text = List(v2, "textColor")
	Token(text, "common", "text")
	Accent(text, "title")
	Token(text, "inactivePartyTab", "textDisabled")
	local edge = List(v2, "edge")
	edge.edgeFile = FLAT
	return v2
end

function Theme.Build(rxp)
	BuildV1(rxp)
	BuildV2(rxp)
	local key = Key()
	local changed = key ~= state.key
	state.key = key
	return state.v1, state.v2, changed
end

function Theme.Register(rxp)
	local v1, v2 = Theme.Build(rxp)
	if rxp.themes[NAME] ~= v1 then
		local ok = Try("RegisterTheme", rxp.RegisterTheme, rxp, v1)
		if not ok or rxp.themes[NAME] ~= v1 then
			LogOnce("register", "RestedXP did not take the theme through RegisterTheme; skipped")
			return false
		end
	end
	if rxp.v2.themes[NAME] ~= v2 then
		rxp.v2.themes[NAME] = v2
	end
	return true
end

local function Profile(rxp)
	local profile = rxp.settings.profile
	return type(profile) == "table" and profile or nil
end

local function ProfileKey(rxp)
	local settings = rxp.settings
	if type(settings.GetSettingsDB) == "function" then
		local ok, name = pcall(settings.GetSettingsDB)
		if ok and IsText(name) then
			return name
		end
	end
	return "default"
end

local function Memory(rxp, create)
	if not K.Store.IsLoaded() then
		return nil
	end
	local account = K.Store.Account()
	local all = account[MEMORY]
	if type(all) ~= "table" then
		if not create then
			return nil
		end
		all = {}
		account[MEMORY] = all
	end
	local key = ProfileKey(rxp)
	local memory = all[key]
	if type(memory) ~= "table" then
		if not create then
			return nil
		end
		memory = {}
		all[key] = memory
	end
	return memory, all, key
end

local function Redraw(rxp, startup)
	local profile = Profile(rxp)
	if profile and profile.enableThemeLiveReload and Method(rxp, "ReloadTheme") then
		Try("ReloadTheme", rxp.ReloadTheme, rxp)
		return
	end
	if startup and type(rxp.RenderFrame) == "function" then
		Try("RenderFrame", rxp.RenderFrame, "themeReload")
		if type(rxp.SetupArrow) == "function" then
			Try("SetupArrow", rxp.SetupArrow)
		end
		return
	end
	LogOnce("live", "RestedXP's live theme reload is off, so RestedXP shows a theme change after /reload")
end

local function Activate(rxp)
	if not Theme.Register(rxp) then
		return false
	end
	local profile = Profile(rxp)
	if not profile then
		return false
	end
	local current = profile.activeTheme
	local memory = Memory(rxp, true)
	if current ~= NAME then
		if memory then
			memory.original = IsText(current) and current or nil
			memory.written = NAME
		end
		profile.activeTheme = NAME
		return true
	end
	if memory and memory.written == nil then
		memory.written = NAME
	end
	return false
end

local function Restore(rxp)
	local profile = Profile(rxp)
	local memory, all, key = Memory(rxp, false)
	local changed = false
	if profile and profile.activeTheme == NAME then
		local original = memory and memory.original
		if not IsText(original) or original == NAME then
			original = DEFAULT_THEME
		end
		profile.activeTheme = original
		changed = true
	end
	if all then
		all[key] = nil
	end
	return changed
end

local function Sync()
	state.queued = false
	local startup = state.startup
	state.startup = false
	local rxp = RestedXP.Addon()
	if not rxp then
		return
	end
	local profile = Profile(rxp)
	local saved = profile and profile.activeTheme == NAME
	local changed
	if state.want then
		changed = Activate(rxp)
	else
		changed = Restore(rxp)
	end
	if startup and saved and state.want and rxp.activeTheme ~= state.v1 then
		Redraw(rxp, true)
	elseif changed then
		Redraw(rxp, false)
	end
end

local function Schedule()
	if state.queued then
		return
	end
	state.queued = true
	C_Timer.After(0, function()
		K.Combat.Queue(Sync)
	end)
end

local function Restyle()
	local rxp = RestedXP.Addon()
	if not rxp then
		return
	end
	local _, _, changed = Theme.Build(rxp)
	local profile = Profile(rxp)
	if not changed or not profile or profile.activeTheme ~= NAME or state.redrawing then
		return
	end
	state.redrawing = true
	C_Timer.After(0, function()
		K.Combat.Queue(function()
			state.redrawing = false
			Redraw(rxp, false)
		end)
	end)
end

local tracker = { Restyle = Restyle }

local function HookProfiles(rxp)
	if state.hooked or not Method(rxp.settings, "RefreshProfile") then
		return
	end
	state.hooked = true
	hooksecurefunc(rxp.settings, "RefreshProfile", Schedule)
end

function Theme.Start(rxp)
	state.want = true
	state.startup = true
	if not Theme.Register(rxp) then
		return false
	end
	Style.Track(tracker)
	Widgets.Track(tracker)
	HookProfiles(rxp)
	K.Combat.Queue(Sync)
	return true
end

function Theme.Switch(on)
	state.want = on == true
	Schedule()
end
