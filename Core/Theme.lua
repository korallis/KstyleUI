-- Theme.lua: resolves tokens to the current accent: the class colour or the player's fixed colour.
local _, ns = ...

local Theme = {}
ns.Theme = Theme

local Tokens = ns.Tokens

-- Colours darker than this relative luminance are lifted toward white so they read on dark glass.
local MIN_LUMINANCE = 0.3
Theme.MIN_LUMINANCE = MIN_LUMINANCE

-- UnitReaction runs from 1 (hated) to 8 (exalted).
local REACTION_HOSTILE_MAX = 3
local REACTION_NEUTRAL = 4
local QUALITY_RARE, QUALITY_EPIC = 3, 4

local SOURCES = { class = true, custom = true }

local state = {
	source = "class", -- "class" or "custom"
	face = Tokens.DEFAULT_FONT_FACE,
	class = nil, -- the player's class file name, once known
	announced = nil, -- the class the last ClassChanged named
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

-- A number Lua may compare: not secret and not NaN.
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

-- r, g, b of a ColorMixin or { r, g, b } table, when all three are plain numbers.
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

-- Re-resolves the accent and reports whether it changed.
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

-- Accent() -> r, g, b: the class colour of the player, or the custom colour.
function Theme.Accent()
	if not state.resolved then
		Update()
	end
	return accent[1], accent[2], accent[3]
end

-- Class() -> the player's class file name, such as "MAGE", or nil while it is unknown.
function Theme.Class()
	if not state.resolved then
		Update()
	end
	return state.class
end

function Theme.AccentSource()
	return state.source
end

-- SetAccentSource("class" | "custom") -> ok. Fires ThemeChanged when the accent changes.
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

-- SetCustomAccent(r, g, b) -> ok. Each channel is a number from 0 to 1.
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

-- FontFace() -> the key of the UI font face, from Tokens.MediaList("font").
function Theme.FontFace()
	return state.face
end

function Theme.SetFontFace(key)
	if type(key) ~= "string" or not Tokens.FontPath(key) then
		return false
	end
	if state.face ~= key then
		state.face = key
		Fire("ThemeChanged")
	end
	return true
end

-- Brighten(r, g, b) -> r, g, b, mixed toward white until the luminance reaches MIN_LUMINANCE.
function Theme.Brighten(r, g, b)
	local lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
	if lum >= MIN_LUMINANCE then
		return r, g, b
	end
	local t = (MIN_LUMINANCE - lum) / (1 - lum)
	return r + (1 - r) * t, g + (1 - g) * t, b + (1 - b) * t
end

-- ClassColor(classFile) -> r, g, b for any unit's class, or the text colour when it is unknown.
function Theme.ClassColor(file)
	local r, g, b
	if IsSecret(file) then
		-- The game accepts a secret class name; Lua must not use it as a key.
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

-- QualityColor(quality) -> r, g, b. Rare and epic come from Tokens; the rest from the game, brightened.
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

-- ReactionColor(reaction) -> r, g, b from the hostile, neutral and friendly tokens.
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

-- At login the player's class is known. A login on another class gives a new accent at once.
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
