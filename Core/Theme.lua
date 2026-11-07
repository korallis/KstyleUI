-- Theme.lua: resolves tokens to the current accent: the class colour or the player's fixed colour.
local _, ns = ...

local Theme = {}
ns.Theme = Theme

local Tokens = ns.Tokens

local MIN_LUMINANCE = 0.3
Theme.MIN_LUMINANCE = MIN_LUMINANCE

local REACTION_HOSTILE_MAX = 3
local REACTION_NEUTRAL = 4
local THREAT_LOW, THREAT_INSECURE, THREAT_SECURE = 1, 2, 3
local THREAT_MIX = 0.5
local QUALITY_RARE, QUALITY_EPIC = 3, 4

local SOURCES = { class = true, custom = true }
local MIN_FONT_SCALE, MAX_FONT_SCALE = 0.8, 1.3
local MAX_PATH = 260
Theme.MIN_FONT_SCALE, Theme.MAX_FONT_SCALE = MIN_FONT_SCALE, MAX_FONT_SCALE

local state = {
	source = "class",
	face = Tokens.DEFAULT_FONT_FACE,
	fontScale = 1,
	class = nil,
	announced = nil,
	resolved = false,
}
local custom = { Tokens.Color("accentDefault") }
local accent = {}

local function Fire(event, ...)
	local callbacks = ns.Callbacks
	if callbacks and callbacks.Fire then
		callbacks.Fire(event, ...)
	end
end

local function Log(message)
	local devtest = ns.DevTest
	if devtest and devtest.Log then
		pcall(devtest.Log, "Theme", message)
	end
end

local function IsSecret(v)
	return issecretvalue ~= nil and issecretvalue(v) == true
end

local function IsPlainNumber(v)
	if IsSecret(v) or type(v) ~= "number" then
		return false
	end
	return v == v
end

local function IsUnit(v)
	return IsPlainNumber(v) and v >= 0 and v <= 1
end

local function Rgb(name)
	local r, g, b = Tokens.Color(name)
	return r, g, b
end

local function Unpack(color)
	if type(color) ~= "table" then
		return nil
	end
	local r, g, b = color.r, color.g, color.b
	if IsPlainNumber(r) and IsPlainNumber(g) and IsPlainNumber(b) then
		return r, g, b
	end
	return nil
end

local function LookupClassColor(file)
	if C_ClassColor and C_ClassColor.GetClassColor then
		local r, g, b = Unpack(C_ClassColor.GetClassColor(file))
		if r then
			return r, g, b
		end
	end
	if type(RAID_CLASS_COLORS) == "table" then
		return Unpack(RAID_CLASS_COLORS[file])
	end
	return nil
end

local function PlayerClass()
	if not UnitClass then
		return nil
	end
	local _, file = UnitClass("player")
	if IsSecret(file) then
		Log("the player's class is secret; the accent uses the default colour")
		return nil
	end
	if type(file) ~= "string" then
		return nil
	end
	return file
end

local function ResolveAccent()
	if state.source == "custom" then
		return custom[1], custom[2], custom[3]
	end
	if state.class then
		local r, g, b = LookupClassColor(state.class)
		if r then
			return r, g, b
		end
		Log("no colour for class " .. state.class .. "; the accent uses the default colour")
	end
	return Rgb("accentDefault")
end

local function Update()
	if not state.resolved then
		state.class = PlayerClass()
		state.resolved = true
	end
	local r, g, b = ResolveAccent()
	local changed = r ~= accent[1] or g ~= accent[2] or b ~= accent[3]
	accent[1], accent[2], accent[3] = r, g, b
	return changed
end

function Theme.Accent()
	if not state.resolved then
		Update()
	end
	return accent[1], accent[2], accent[3]
end

function Theme.Class()
	if not state.resolved then
		Update()
	end
	return state.class
end

function Theme.AccentSource()
	return state.source
end

function Theme.SetAccentSource(source)
	if type(source) ~= "string" or not SOURCES[source] then
		return false
	end
	if state.source ~= source then
		state.source = source
		if Update() then
			Fire("ThemeChanged")
		end
	end
	return true
end

function Theme.CustomAccent()
	return custom[1], custom[2], custom[3]
end

function Theme.SetCustomAccent(r, g, b)
	if not (IsUnit(r) and IsUnit(g) and IsUnit(b)) then
		return false
	end
	custom[1], custom[2], custom[3] = r, g, b
	if state.source == "custom" and Update() then
		Fire("ThemeChanged")
	end
	return true
end

function Theme.FontFace()
	return state.face
end

function Theme.IsFontPath(path)
	if type(path) ~= "string" or #path > MAX_PATH or path:find("[%c|]") or not path:find("[\\/]") then
		return false
	end
	local ext = path:lower():match("%.(%a+)$")
	return ext == "ttf" or ext == "otf"
end

function Theme.SetFontFace(key)
	if type(key) ~= "string" or not (Tokens.FontPath(key) or Theme.IsFontPath(key)) then
		return false
	end
	if state.face ~= key then
		state.face = key
		Fire("ThemeChanged")
	end
	return true
end

function Theme.FontScale()
	return state.fontScale
end

function Theme.SetFontScale(scale)
	if IsSecret(scale) or type(scale) ~= "number" or scale ~= scale or scale < MIN_FONT_SCALE or scale > MAX_FONT_SCALE then
		return false
	end
	if state.fontScale ~= scale then
		state.fontScale = scale
		Fire("ThemeChanged")
	end
	return true
end

function Theme.Brighten(r, g, b)
	local lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
	if lum >= MIN_LUMINANCE then
		return r, g, b
	end
	local t = (MIN_LUMINANCE - lum) / (1 - lum)
	return r + (1 - r) * t, g + (1 - g) * t, b + (1 - b) * t
end

function Theme.ClassColor(file)
	local r, g, b
	if IsSecret(file) then
		if C_ClassColor and C_ClassColor.GetClassColor then
			r, g, b = Unpack(C_ClassColor.GetClassColor(file))
		end
	elseif type(file) == "string" then
		r, g, b = LookupClassColor(file)
	end
	if r then
		return r, g, b
	end
	return Rgb("text")
end

local function SecretClassRgb(file)
	return C_ClassColor.GetClassColor(file):GetRGB()
end

function Theme.ClassColorForWidget(file)
	if IsSecret(file) and C_ClassColor and C_ClassColor.GetClassColor then
		local ok, r, g, b = pcall(SecretClassRgb, file)
		if ok and type(r) == "number" then
			return r, g, b
		end
		return Rgb("text")
	end
	return Theme.ClassColor(file)
end

function Theme.ThreatColor(status)
	if not IsPlainNumber(status) then
		return nil
	end
	if status == THREAT_SECURE then
		return Rgb("hostile")
	elseif status == THREAT_INSECURE then
		local nr, ng, nb = Rgb("neutral")
		local hr, hg, hb = Rgb("hostile")
		return nr + (hr - nr) * THREAT_MIX, ng + (hg - ng) * THREAT_MIX, nb + (hb - nb) * THREAT_MIX
	elseif status == THREAT_LOW then
		return Rgb("neutral")
	end
	return nil
end

function Theme.QualityColor(quality)
	if not IsPlainNumber(quality) then
		return Rgb("text")
	end
	local enum = Enum and Enum.ItemQuality
	if quality == (enum and enum.Rare or QUALITY_RARE) then
		return Rgb("rare")
	elseif quality == (enum and enum.Epic or QUALITY_EPIC) then
		return Rgb("epic")
	end
	local r, g, b
	if C_Item and C_Item.GetItemQualityColor then
		local ok, cr, cg, cb = pcall(C_Item.GetItemQualityColor, quality)
		if ok and IsPlainNumber(cr) and IsPlainNumber(cg) and IsPlainNumber(cb) then
			r, g, b = cr, cg, cb
		end
	end
	if not r and type(ITEM_QUALITY_COLORS) == "table" then
		r, g, b = Unpack(ITEM_QUALITY_COLORS[quality])
	end
	if r then
		return Theme.Brighten(r, g, b)
	end
	return Rgb("text")
end

function Theme.ReactionColor(reaction)
	if not IsPlainNumber(reaction) then
		return Rgb("neutral")
	end
	if reaction <= REACTION_HOSTILE_MAX then
		return Rgb("hostile")
	elseif reaction == REACTION_NEUTRAL then
		return Rgb("neutral")
	end
	return Rgb("friendly")
end

local function OnLogin()
	state.class = PlayerClass()
	state.resolved = true
	local themeChanged = Update()
	local previous = state.announced
	if state.class ~= previous then
		state.announced = state.class
		Fire("ClassChanged", state.class, previous)
	end
	if themeChanged then
		Fire("ThemeChanged")
	end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", OnLogin)
