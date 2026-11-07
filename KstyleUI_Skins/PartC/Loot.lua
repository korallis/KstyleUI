-- Loot.lua: the loot window skin: a glass panel, the close glyph and a slim scroll bar, and each loot row as a raised tile with a quality-rimmed icon.
local _, ns = ...

local K = KstyleUI
local Skin, Theme, L = K.Skin, K.Theme, K.L
local Style, Parts, Skins, Kit = ns.Style, ns.Parts, ns.Skins, ns.PartC

local KEY = "loot"
local ROW_ART = { "NameFrame", "BorderFrame", "QualityStripe", "PushedNameFrame" }
local SHADOWS = { "GetUpperShadowTexture", "GetLowerShadowTexture" }
local TILE_BELOW = 2

local rows = setmetatable({}, { __mode = "k" })

local function Quality(row, elementData)
	local data = elementData
	if type(data) ~= "table" and type(row.GetElementData) == "function" then
		local ok, value = pcall(row.GetElementData, row)
		data = ok and value or nil
	end
	if type(data) ~= "table" then
		return nil
	end
	return data.quality
end

local function Paint(row, state)
	Kit.Quality(KEY, state.rim, state.quality)
	local label = row.QualityText
	if label then
		local quality = state.quality
		if Kit.IsSecret(quality) or type(quality) ~= "number" then
			Style.Text(label, "caption", "text")
		else
			Style.Text(label, "caption")
			label:SetTextColor(Theme.QualityColor(quality))
		end
	end
end

local function Row(row, elementData)
	if type(row.Item) ~= "table" then
		return
	end
	local state = rows[row]
	if not state then
		state = {}
		rows[row] = state
		for _, key in ipairs(ROW_ART) do
			Parts.Hush(row[key])
		end
		Kit.Wash(row.HighlightNameFrame)
		Kit.Below(Skin.Backdrop(row, { shape = "tile", fill = "raised", shadow = false }), row, TILE_BELOW)
		state.rim = Kit.Item(row.Item)
	end
	if row.Text then
		Style.Text(row.Text, "body")
	end
	state.quality = Quality(row, elementData)
	Paint(row, state)
end

local function HushShadows(box)
	for _, getter in ipairs(SHADOWS) do
		if type(box[getter]) == "function" then
			local ok, shadow = pcall(box[getter], box)
			if ok then
				Parts.Hush(shadow)
			end
		end
	end
end

local function Apply()
	local frame = Kit.Frame(KEY, "LootFrame")
	if not frame then
		return
	end
	Kit.Window(frame)
	local close = Kit.Child(KEY, frame, "ClosePanelButton")
	if close then
		Skin.CloseButton(close)
	end
	local bar = Kit.Child(KEY, frame, "ScrollBar")
	if bar then
		Kit.ScrollBar(bar)
	end
	local box = Kit.Child(KEY, frame, "ScrollBox")
	if box then
		HushShadows(box)
		Parts.EachRow(box, Row)
	end
end

local function OnSetting(_, field)
	if field == nil or field == "qualityBorders" or field == "qualityFrom" then
		for row, state in pairs(rows) do
			Paint(row, state)
		end
	end
end

Skins.Add({
	key = KEY,
	label = L["Loot window"],
	help = L["Restyles the loot window: a glass panel and a tile for each item."],
	frame = "LootFrame",
	defaults = Kit.QualityDefaults(),
	rows = Kit.QualityRows(L["Colours each loot icon's border by its item's quality."]),
	Apply = Apply,
	OnSetting = OnSetting,
})
