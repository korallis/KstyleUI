-- Style.lua: the look every skin shares: the text font, size and outline, the bar texture, colour and fill, and the accent.
local _, ns = ...

local K = KstyleUI
local Tokens, Theme, Widgets, L = K.Tokens, K.Theme, K.Widgets, K.L

local Style = {}
ns.Style = Style

local MODULE = "Skins"
local FOLLOW = "appearance"
local SIZE_MIN, SIZE_MAX, SIZE_STEP = 0.8, 1.5, 0.05
local OUTLINES = { shadow = "", outline = "OUTLINE", thick = "THICKOUTLINE" }
local BAR_SOURCES = { reaction = true, class = true, custom = true }
local FILLS = { left = true, right = true }
local ACCENTS = { appearance = true, class = true, custom = true }
local GROUPS = { text = true, bars = true, accent = true }
local FALLBACK_FONT = "GameFontHighlight"

local WEAK = { __mode = "k" }
local roles = setmetatable({}, WEAK)
local bars = setmetatable({}, WEAK)
local tracked = setmetatable({}, WEAK)
local painting = false

local function IsSecret(value)
	return issecretvalue ~= nil and issecretvalue(value) == true
end

local function IsUnit(value)
	return not IsSecret(value) and type(value) == "number" and value == value and value >= 0 and value <= 1
end

local function IsColor(value)
	return type(value) == "table" and IsUnit(value.r) and IsUnit(value.g) and IsUnit(value.b)
end

local barList = Tokens.MediaList("statusbar")
local accentR, accentG, accentB = Tokens.Color("accentDefault")

Style.FOLLOW = FOLLOW
Style.GROUPS = GROUPS
Style.defaults = {
	text = { font = FOLLOW, size = 1, outline = "shadow" },
	bars = { texture = barList[1].path, color = "reaction", customColor = { r = accentR, g = accentG, b = accentB }, fill = "left" },
	accent = { source = FOLLOW, color = { r = accentR, g = accentG, b = accentB } },
}

local VALID = {
	text = {
		font = function(v)
			return v == FOLLOW or Theme.IsFontPath(v)
		end,
		size = function(v)
			return not IsSecret(v) and type(v) == "number" and v >= SIZE_MIN and v <= SIZE_MAX
		end,
		outline = function(v)
			return type(v) == "string" and OUTLINES[v] ~= nil
		end,
	},
	bars = {
		texture = function(v)
			return not IsSecret(v) and ((type(v) == "string" and v ~= "") or type(v) == "number")
		end,
		color = function(v)
			return type(v) == "string" and BAR_SOURCES[v] == true
		end,
		customColor = IsColor,
		fill = function(v)
			return type(v) == "string" and FILLS[v] == true
		end,
	},
	accent = {
		source = function(v)
			return type(v) == "string" and ACCENTS[v] == true
		end,
		color = IsColor,
	},
}

function Style.Setting(group, key)
	local valid = VALID[group] and VALID[group][key]
	if not valid then
		error("KstyleUI_Skins Style.Setting: unknown setting " .. tostring(group) .. "." .. tostring(key), 2)
	end
	local Store = K.Store
	if Store.IsLoaded() then
		local values = Store.Module(MODULE)[group]
		local value
		if type(values) == "table" then
			value = values[key]
		end
		if valid(value) then
			return value
		end
	end
	return Style.defaults[group][key]
end

local function Log(message)
	K.DevTest.Log(MODULE, message)
end

local loggedFonts = {}

local function LogFont(path, outcome)
	local message = "the font " .. tostring(path) .. " did not load; " .. outcome
	if not loggedFonts[message] then
		loggedFonts[message] = true
		Log(message)
	end
end

function Style.Font(role)
	local path, size = Tokens.Font(role)
	local face = Style.Setting("text", "font")
	if face ~= FOLLOW then
		path = face
	end
	return path, size * Style.Setting("text", "size"), OUTLINES[Style.Setting("text", "outline")]
end

local function SetFace(object, path, role, size, flags)
	if object:SetFont(path, size, flags) ~= false then
		return true
	end
	local kitPath = Tokens.Font(role)
	if kitPath ~= path and object:SetFont(kitPath, size, flags) ~= false then
		LogFont(path, "skinned text uses the KstyleUI face")
		return true
	end
	local fallback = _G[FALLBACK_FONT]
	local face = type(fallback) == "table" and type(fallback.GetFont) == "function" and fallback:GetFont()
	if not IsSecret(face) and type(face) == "string" and object:SetFont(face, size, flags) ~= false then
		LogFont(path, "skinned text uses the face of " .. FALLBACK_FONT)
		return true
	end
	LogFont(path, "no fallback face loaded either")
	return false
end

function Style.ApplyFont(object, role, size)
	local path, roleSize, flags = Style.Font(role)
	local ok = SetFace(object, path, role, size or roleSize, flags)
	if flags == "" then
		object:SetShadowColor(Tokens.Color("textShadow"))
		local offset = Tokens.Size("textShadowOffset")
		object:SetShadowOffset(offset, -offset)
	else
		object:SetShadowOffset(0, 0)
	end
	return ok
end

function Style.Text(text, role, colorName)
	role = role or roles[text] or "body"
	roles[text] = role
	if not Style.ApplyFont(text, role) then
		text:SetFontObject(FALLBACK_FONT)
	end
	if colorName then
		Widgets.TextColor(text, colorName)
	end
	return text
end

function Style.Accent()
	local source = Style.Setting("accent", "source")
	if source == "custom" then
		local c = Style.Setting("accent", "color")
		return c.r, c.g, c.b
	elseif source == "class" then
		local class = Theme.Class()
		if class then
			return Theme.ClassColor(class)
		end
	end
	return Theme.Accent()
end

function Style.TintAccent(region, alpha)
	local r, g, b = Style.Accent()
	region:SetVertexColor(r, g, b, alpha or 1)
end

function Style.BarTexture()
	return Style.Setting("bars", "texture")
end

function Style.ReverseFill()
	return Style.Setting("bars", "fill") == "right"
end

function Style.BarColor(r, g, b, a)
	if IsSecret(r) or IsSecret(g) or IsSecret(b) or IsSecret(a) then
		return r, g, b, a
	end
	local source = Style.Setting("bars", "color")
	if source == "custom" then
		local c = Style.Setting("bars", "customColor")
		return c.r, c.g, c.b, a
	elseif source == "class" then
		local class = Theme.Class()
		local cr, cg, cb
		if class then
			cr, cg, cb = Theme.ClassColor(class)
		else
			cr, cg, cb = Theme.Accent()
		end
		return cr, cg, cb, a
	end
	if IsUnit(r) and IsUnit(g) and IsUnit(b) then
		local br, bg, bb = Theme.Brighten(r, g, b)
		return br, bg, bb, a
	end
	if r == nil then
		local nr, ng, nb = Tokens.Color("neutral")
		return nr, ng, nb, a
	end
	return r, g, b, a
end

local function SetColor(bar, state)
	bar:SetStatusBarColor(Style.BarColor(state.r, state.g, state.b, state.a))
end

local function PaintBar(bar, state)
	painting = true
	local ok, err = pcall(SetColor, bar, state)
	painting = false
	if not ok then
		Log("a bar colour could not be set: " .. tostring(err))
	end
end

function Style.StatusBar(bar)
	local state = bars[bar]
	if not state then
		state = {}
		bars[bar] = state
		if type(bar.GetStatusBarColor) == "function" then
			state.r, state.g, state.b, state.a = bar:GetStatusBarColor()
		end
		hooksecurefunc(bar, "SetStatusBarColor", function(self, r, g, b, a)
			if painting then
				return
			end
			state.r, state.g, state.b, state.a = r, g, b, a
			PaintBar(self, state)
		end)
	end
	bar:SetStatusBarTexture(Style.BarTexture())
	bar:SetReverseFill(Style.ReverseFill())
	PaintBar(bar, state)
	return bar
end

function Style.Track(object)
	tracked[object] = true
	return object
end

function Style.RestyleAll()
	for text in pairs(roles) do
		K.Call(Style.Text, text)
	end
	for bar in pairs(bars) do
		K.Call(Style.StatusBar, bar)
	end
	for object in pairs(tracked) do
		K.Call(object.Restyle, object)
	end
end

local function FontOptions()
	local list = { { value = FOLLOW, label = L["Interface font"] } }
	for _, option in ipairs(Widgets.MediaOptions("font")) do
		list[#list + 1] = option
	end
	return list
end

Style.SIZE_MIN, Style.SIZE_MAX, Style.SIZE_STEP = SIZE_MIN, SIZE_MAX, SIZE_STEP

Style.rows = {
	{ type = "header", label = L["Text"] },
	{
		type = "dropdown", key = "text.font", label = L["Font"], options = FontOptions,
		help = L["The font of skinned window titles, headers and lists."],
	},
	{
		type = "slider", key = "text.size", label = L["Text size"], min = SIZE_MIN, max = SIZE_MAX, step = SIZE_STEP,
		help = L["Makes the text in skinned windows larger or smaller."],
	},
	{
		type = "dropdown", key = "text.outline", label = L["Text edge"],
		options = {
			{ value = "shadow", label = L["Soft shadow"] },
			{ value = "outline", label = L["Thin outline"] },
			{ value = "thick", label = L["Thick outline"] },
		},
		help = L["A soft shadow or an outline behind skinned text."],
	},
	{ type = "header", label = L["Bars"] },
	{
		type = "texture", key = "bars.texture", label = L["Bar texture"],
		help = L["The fill of reputation, currency and quest progress bars."],
	},
	{
		type = "dropdown", key = "bars.color", label = L["Bar colour"],
		options = {
			{ value = "reaction", label = L["Standing or reaction"] },
			{ value = "class", label = L["Class colour"] },
			{ value = "custom", label = L["Custom colour"] },
		},
		help = L["Colours bars by their standing, by your class, or with one colour."],
	},
	{
		type = "color", key = "bars.customColor", label = L["Custom bar colour"],
		help = L["The bar colour when Bar colour is set to custom."],
		showWhen = function(s)
			return type(s.bars) == "table" and s.bars.color == "custom"
		end,
	},
	{
		type = "dropdown", key = "bars.fill", label = L["Bar fill direction"],
		options = {
			{ value = "left", label = L["Left to right"] },
			{ value = "right", label = L["Right to left"] },
		},
		help = L["Which end skinned bars fill from."],
	},
	{ type = "header", label = L["Accent"] },
	{
		type = "dropdown", key = "accent.source", label = L["Accent colour"],
		options = {
			{ value = FOLLOW, label = L["Interface accent"] },
			{ value = "class", label = L["Class colour"] },
			{ value = "custom", label = L["Custom colour"] },
		},
		help = L["The colour of selected tabs, headers and hairlines in skinned windows."],
	},
	{
		type = "color", key = "accent.color", label = L["Custom accent"],
		help = L["The accent when Accent colour is set to custom."],
		showWhen = function(s)
			return type(s.accent) == "table" and s.accent.source == "custom"
		end,
	},
}
