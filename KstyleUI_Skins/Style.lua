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

local HTML_TYPES = { "P", "H1", "H2", "H3" }
local htmls = setmetatable({}, WEAK)

local function PaintHtml(state)
	local html = state.html
	local path, size, flags = Style.Font(state.role)
	local r, g, b = Tokens.Color(state.color)
	for _, kind in ipairs(HTML_TYPES) do
		html:SetFont(kind, path, size, flags)
		html:SetTextColor(kind, r, g, b)
		html:SetJustifyH(kind, "LEFT")
	end
end

function Style.Html(html, role, colorName)
	local state = htmls[html]
	if not state then
		state = { html = html, Restyle = PaintHtml }
		htmls[html] = state
		Style.Track(state)
	end
	state.role, state.color = role or "body", colorName or "text"
	PaintHtml(state)
	return html
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
	if state.accent then
		local r, g, b = Style.Accent()
		bar:SetStatusBarColor(Style.BarColor(r, g, b, 1))
		return
	end
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

function Style.StatusBar(bar, opts)
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
	if type(opts) == "table" and opts.accent ~= nil then
		state.accent = opts.accent == true
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

local SWEEP_DEPTH = 10
local SWEEP_ROLE = "body"
local YELLOW_MIN_R, YELLOW_MIN_G, YELLOW_MAX_G, YELLOW_MAX_B = 0.9, 0.7, 0.95, 0.25
local SWEEP_COLOR = "text"
local swept = setmetatable({}, WEAK)

local function Forbidden(object)
	return type(object.IsForbidden) == "function" and object:IsForbidden() == true
end

local function IsFontString(region)
	return type(region) == "table" and not Forbidden(region) and type(region.GetObjectType) == "function" and region:GetObjectType() == "FontString"
end

local kitFaces

local function IsKitFace(path)
	if type(path) ~= "string" then
		return false
	end
	if not kitFaces then
		kitFaces = {}
		for _, kind in ipairs({ "font", "fontSet" }) do
			for _, face in ipairs(Tokens.MediaList(kind)) do
				kitFaces[face.path] = true
			end
		end
	end
	return kitFaces[path] == true or path == Style.Setting("text", "font")
end

local function IsBlizzardYellow(r, g, b)
	return IsUnit(r) and IsUnit(g) and IsUnit(b) and r >= YELLOW_MIN_R and g >= YELLOW_MIN_G and g <= YELLOW_MAX_G and b <= YELLOW_MAX_B
end

local function PaintSwept(text, entry)
	if entry.busy then
		return
	end
	entry.busy = true
	local _, minimum = Style.Font(SWEEP_ROLE)
	local size = entry.size and entry.size * Style.Setting("text", "size") or nil
	if size == nil or size < minimum then
		size = minimum
	end
	local ok, err = pcall(Style.ApplyFont, text, SWEEP_ROLE, size)
	if ok and err == false then
		pcall(text.SetFontObject, text, FALLBACK_FONT)
	elseif not ok then
		Log("a swept text could not take the skin face: " .. tostring(err))
	end
	entry.busy = false
end

local function RecolorSwept(text, entry, r, g, b)
	if entry.busy then
		return
	end
	if r == nil or IsBlizzardYellow(r, g, b) then
		entry.busy = true
		pcall(Widgets.TextColor, text, SWEEP_COLOR)
		entry.busy = false
	end
end

local function OnSweptFontObject(text)
	local entry = swept[text]
	if entry and not entry.busy then
		PaintSwept(text, entry)
		local r, g, b = text:GetTextColor()
		RecolorSwept(text, entry, r, g, b)
	end
end

local function OnSweptColor(text, r, g, b)
	local entry = swept[text]
	if entry then
		RecolorSwept(text, entry, r, g, b)
	end
end

local function SweepText(text)
	if swept[text] or roles[text] then
		return false
	end
	local path, size = text:GetFont()
	if IsSecret(path) or IsKitFace(path) then
		return false
	end
	if IsSecret(size) or type(size) ~= "number" then
		size = nil
	end
	local entry = { size = size }
	swept[text] = entry
	PaintSwept(text, entry)
	local r, g, b = text:GetTextColor()
	RecolorSwept(text, entry, r, g, b)
	hooksecurefunc(text, "SetFontObject", OnSweptFontObject)
	hooksecurefunc(text, "SetTextColor", OnSweptColor)
	return true
end

local function SweepFrame(frame, skip, depth)
	if depth > SWEEP_DEPTH or (skip and skip[frame]) or Forbidden(frame) then
		return 0
	end
	local count = 0
	if type(frame.GetRegions) == "function" then
		for _, region in ipairs({ frame:GetRegions() }) do
			if IsFontString(region) and SweepText(region) then
				count = count + 1
			end
		end
	end
	if type(frame.GetChildren) == "function" then
		for _, child in ipairs({ frame:GetChildren() }) do
			if type(child) == "table" then
				count = count + SweepFrame(child, skip, depth + 1)
			end
		end
	end
	return count
end

function Style.Sweep(frame, opts)
	if type(frame) ~= "table" then
		return 0
	end
	opts = opts or {}
	local ok, count = pcall(SweepFrame, frame, opts.skip, 1)
	if not ok then
		Log("a text sweep stopped: " .. tostring(count))
		return 0
	end
	if opts.onShow and not Forbidden(frame) and type(frame.HookScript) == "function" and not swept[frame] then
		swept[frame] = { skip = opts.skip }
		frame:HookScript("OnShow", function(shown)
			Style.Sweep(shown, { skip = swept[shown] and swept[shown].skip })
		end)
	end
	return count
end

function Style.IsSwept(text)
	return swept[text] ~= nil
end

function Style.RestyleAll()
	for text in pairs(roles) do
		K.Call(Style.Text, text)
	end
	for text, entry in pairs(swept) do
		if IsFontString(text) then
			K.Call(PaintSwept, text, entry)
		end
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
