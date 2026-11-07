-- Kit.lua: part C's helpers: missing-part logs, quality-rimmed item buttons, accent washes and highlights, mirrored bars, tri-state checks and preview samples.
local _, ns = ...

local K = KstyleUI
local Skin, Theme, Tokens, Widgets, L = K.Skin, K.Theme, K.Tokens, K.Widgets, K.L
local Style, Parts, Skins, PartB = ns.Style, ns.Parts, ns.Skins, ns.PartBKit

local Kit = {}
ns.PartC = Kit

local max = math.max

local MODULE = "Skins"
local ICON_CROP = 0.07
local WASH_ALPHA = 0.12
local HIGHLIGHT_ALPHA = 0.18
local LEVEL_ABOVE = 1
local NEUTRAL_SPREAD = 0.05
local QUALITY_POOR, QUALITY_COMMON, QUALITY_UNCOMMON, QUALITY_RARE, QUALITY_EPIC = 0, 1, 2, 3, 4
local ITEM_KEEP = { "icon", "Icon", "searchOverlay", "ItemContextOverlay", "IconOverlay", "IconOverlay2", "IconQuestTexture", "JunkIcon" }
local FOLLOW = { "Show", "Hide", "SetShown" }

local WEAK = { __mode = "k" }
local items = setmetatable({}, WEAK)
local washes = setmetatable({}, WEAK)
local highlights = setmetatable({}, WEAK)
local mirrors = setmetatable({}, WEAK)
local triStates = setmetatable({}, WEAK)
local logged = {}

ns.previewParts = ns.previewParts or {}

local function IsSecret(value)
	return issecretvalue ~= nil and issecretvalue(value) == true
end

Kit.IsSecret = IsSecret

function Kit.Log(key, message)
	K.DevTest.Log(MODULE, key .. ": " .. message)
end

function Kit.LogOnce(key, message)
	local id = key .. ": " .. message
	if logged[id] then
		return
	end
	logged[id] = true
	Kit.Log(key, message)
end

function Kit.Frame(key, name)
	local frame = _G[name]
	if type(frame) ~= "table" then
		Kit.LogOnce(key, name .. " is missing on this client; skipped")
		return nil
	end
	return frame
end

function Kit.Child(key, frame, path)
	local node = frame
	for part in path:gmatch("[^%.]+") do
		if type(node) ~= "table" then
			node = nil
			break
		end
		node = node[part]
	end
	if type(node) ~= "table" then
		Kit.LogOnce(key, path .. " is missing on this client; skipped")
		return nil
	end
	return node
end

function Kit.Each(key, frame, paths, fn)
	local count = 0
	for _, path in ipairs(paths) do
		local child = Kit.Child(key, frame, path)
		if child then
			fn(child)
			count = count + 1
		end
	end
	return count
end

function Kit.Texts(frame, role, colorName)
	if type(frame) ~= "table" or type(frame.GetRegions) ~= "function" then
		return 0
	end
	local count = 0
	for _, region in ipairs({ frame:GetRegions() }) do
		if type(region.GetObjectType) == "function" and region:GetObjectType() == "FontString" then
			Style.Text(region, role, colorName)
			count = count + 1
		end
	end
	return count
end

function Kit.Accent(frame)
	if PartB and type(PartB.Accent) == "function" then
		PartB.Accent(frame)
	end
end

local function Accented(skin)
	return function(frame, ...)
		local made = skin(frame, ...)
		Kit.Accent(frame)
		return made
	end
end

function Kit.Button(button)
	local backdrop = Skin.Button(button)
	Kit.Accent(button)
	local label = type(button) == "table" and type(button.GetFontString) == "function" and button:GetFontString() or nil
	if type(label) == "table" and type(label.SetFont) == "function" then
		Style.Text(label, "body")
	end
	return backdrop
end

Kit.CheckBox = Accented(Skin.CheckBox)
Kit.ScrollBar = Accented(Skin.ScrollBar)
Kit.Tab = Accented(Skin.Tab)

function Kit.Window(frame, opts)
	opts = opts or {}
	local panel = Skin.Window(frame, { inset = opts.inset, tabs = opts.tabs, title = false })
	local container = frame.TitleContainer
	local title = type(container) == "table" and container.TitleText or nil
	if not title and type(frame.GetTitleText) == "function" then
		title = frame:GetTitleText()
	end
	if type(title) == "table" and type(title.SetFont) == "function" then
		Style.Text(title, "heading", "textEmphasis")
	end
	if opts.tabs ~= false and type(frame.Tabs) == "table" then
		for _, tab in ipairs(frame.Tabs) do
			Kit.Accent(tab)
		end
	end
	return panel
end

function Kit.Crop(icon)
	if Parts.IsTexture(icon) then
		icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
	end
end

function Kit.Item(button)
	if type(button) ~= "table" or type(button.GetRegions) ~= "function" then
		return nil
	end
	if items[button] then
		return items[button]
	end
	local keep = {}
	for _, key in ipairs(ITEM_KEEP) do
		if Parts.IsTexture(button[key]) then
			keep[button[key]] = true
		end
	end
	local name = type(button.GetName) == "function" and button:GetName()
	local named = name and _G[name .. "IconTexture"]
	if Parts.IsTexture(named) then
		keep[named] = true
	end
	Skin.Strip(button, { keep = keep })
	Kit.Crop(button.icon or button.Icon or named)
	if button.Count then
		Style.Text(button.Count, "number", "textEmphasis")
	end
	local rim = Parts.Rim(button, { outset = Tokens.Size("gapTiny") })
	items[button] = rim
	return rim
end

function Kit.Quality(key, rim, quality)
	if not rim then
		return
	end
	if not Skins.Setting(key, "qualityBorders") or IsSecret(quality) or type(quality) ~= "number" or quality < Skins.Setting(key, "qualityFrom") then
		rim:SetRimColor(nil)
		return
	end
	rim:SetRimColor(Theme.QualityColor(quality))
end

function Kit.ColorRim(rim, r, g, b)
	if not rim then
		return
	end
	if IsSecret(r) or IsSecret(g) or IsSecret(b) or type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
		rim:SetRimColor(nil)
		return
	end
	if math.abs(r - g) < NEUTRAL_SPREAD and math.abs(g - b) < NEUTRAL_SPREAD then
		rim:SetRimColor(nil)
		return
	end
	rim:SetRimColor(Theme.Brighten(r, g, b))
end

function Kit.QualityDefaults()
	return { qualityBorders = true, qualityFrom = QUALITY_UNCOMMON }
end

function Kit.QualityRows(help)
	return {
		{ type = "toggle", key = "qualityBorders", label = L["Quality borders"], help = help },
		{
			type = "dropdown", key = "qualityFrom", label = L["Colour borders from"],
			options = {
				{ value = QUALITY_POOR, label = L["Poor and better"] },
				{ value = QUALITY_COMMON, label = L["Common and better"] },
				{ value = QUALITY_UNCOMMON, label = L["Uncommon and better"] },
				{ value = QUALITY_RARE, label = L["Rare and better"] },
				{ value = QUALITY_EPIC, label = L["Epic and better"] },
			},
			help = L["The lowest item quality that colours a border."],
			disableWhen = function(settings)
				return settings.qualityBorders ~= true
			end,
		},
	}
end

local function TintWash(wash)
	Style.TintAccent(wash, wash.alpha)
end

function Kit.Wash(texture, alpha)
	if not Parts.IsTexture(texture) then
		return nil
	end
	if washes[texture] then
		return washes[texture]
	end
	local owner = texture:GetParent()
	local layer = CreateFrame("Frame", nil, owner)
	layer:SetAllPoints(owner)
	local wash = layer:CreateTexture(nil, "BACKGROUND")
	wash:SetAllPoints(texture)
	wash:SetColorTexture(Tokens.Color("white"))
	wash.alpha = alpha or WASH_ALPHA
	wash.Restyle = TintWash
	TintWash(wash)
	Style.Track(wash)
	local function Follow()
		local shown = texture:IsShown()
		wash:SetShown(not IsSecret(shown) and shown == true)
	end
	for _, method in ipairs(FOLLOW) do
		hooksecurefunc(texture, method, Follow)
	end
	Parts.Hush(texture)
	Follow()
	washes[texture] = wash
	return wash
end

local function TintHighlight(state)
	Style.TintAccent(state.texture, HIGHLIGHT_ALPHA)
end

function Kit.Highlight(button)
	if type(button) ~= "table" or type(button.GetHighlightTexture) ~= "function" then
		return nil
	end
	local texture = button:GetHighlightTexture()
	if not Parts.IsTexture(texture) then
		return nil
	end
	if highlights[texture] then
		return texture
	end
	texture:SetColorTexture(Tokens.Color("white"))
	texture:SetBlendMode("BLEND")
	local state = { texture = texture, Restyle = TintHighlight }
	TintHighlight(state)
	Style.Track(state)
	highlights[texture] = state
	return texture
end

local function PaintMirror(state)
	local bar = state.bar
	bar:SetBarTexture(Style.BarTexture())
	bar:SetReverseFill(Style.ReverseFill())
	bar:SetBarColor(Style.BarColor(state.r, state.g, state.b, state.a))
end

function Kit.MirrorBar(source, parent, width, height)
	if type(source) ~= "table" or type(source.GetMinMaxValues) ~= "function" or type(parent) ~= "table" then
		return nil
	end
	if mirrors[source] then
		return mirrors[source].bar
	end
	local state = { Restyle = PaintMirror }
	if type(source.GetStatusBarColor) == "function" then
		state.r, state.g, state.b, state.a = source:GetStatusBarColor()
	end
	Skin.Strip(source)
	Parts.Hush(source:GetStatusBarTexture())
	local bar = Widgets.StatusBar(parent, { width = width, height = height, border = true })
	bar:SetPoint("TOPLEFT", source, "TOPLEFT")
	bar:SetFrameLevel(parent:GetFrameLevel() + LEVEL_ABOVE)
	state.bar = bar
	local low, high = source:GetMinMaxValues()
	if low ~= nil and high ~= nil then
		bar:SetBarRange(low, high)
	end
	local value = source:GetValue()
	if value ~= nil then
		bar:SetBarValue(value)
	end
	hooksecurefunc(source, "SetMinMaxValues", function(_, newLow, newHigh)
		bar:SetBarRange(newLow, newHigh)
	end)
	hooksecurefunc(source, "SetValue", function(_, newValue)
		bar:SetBarValue(newValue)
	end)
	hooksecurefunc(source, "SetStatusBarColor", function(_, r, g, b, a)
		state.r, state.g, state.b, state.a = r, g, b, a
		PaintMirror(state)
	end)
	PaintMirror(state)
	Style.Track(state)
	mirrors[source] = state
	return bar
end

function Kit.Below(panel, frame, levels)
	if panel then
		panel:SetFrameLevel(max(0, frame:GetFrameLevel() - levels))
	end
end

function Kit.EditBox(box, keepKeys)
	if type(box) ~= "table" or type(box.GetRegions) ~= "function" then
		return nil
	end
	local keep = {}
	for _, key in ipairs(keepKeys or {}) do
		if Parts.IsTexture(box[key]) then
			keep[box[key]] = true
		end
	end
	Skin.Strip(box, { keep = keep, children = { "NineSlice" } })
	if PartB and type(PartB.EditBox) == "function" then
		return PartB.EditBox(box)
	end
	return Skin.EditBox(box)
end

local function Desaturated(texture)
	if type(texture.IsDesaturated) ~= "function" then
		return false
	end
	local some = texture:IsDesaturated()
	return not IsSecret(some) and some == true
end

function Kit.TriState(check)
	local parts = Skin.Parts(check)
	local checked = type(check) == "table" and check.CheckedTexture
	if not (parts and parts.mark and type(parts.Paint) == "function" and Parts.IsTexture(checked)) or triStates[check] then
		return false
	end
	local state = { some = Desaturated(checked) }
	triStates[check] = state
	local paint = parts.Paint
	parts.Paint = function(self)
		paint(self)
		if self.checked and state.some then
			Widgets.Tint(self.mark, "text")
		end
	end
	hooksecurefunc(checked, "SetDesaturated", function(_, desaturated)
		state.some = not IsSecret(desaturated) and desaturated == true
		parts:Paint()
	end)
	parts:Paint()
	return true
end

function Kit.Preview(builder)
	local list = ns.previewParts
	list[#list + 1] = builder
end
