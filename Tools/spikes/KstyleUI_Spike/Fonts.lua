-- Fonts.lua: the fonts spike renders each candidate body font at the spec's sizes, with and without SLUG.
local _, ns = ...

local MEDIA = "Interface\\AddOns\\KstyleUI_Spike\\Media\\"
local SAMPLE = "The quick brown fox 0123456789"
local FALLBACK = "GameFontHighlight"
local FONTS = {
	{ key = "SourceSans3-Semibold", id = "SS3Semibold" },
	{ key = "SourceSans3-Regular", id = "SS3Regular" },
	{ key = "Inter-SemiBold", id = "InterSemiBold" },
}
local SIZES = { 9, 11, 16, 24 }
local VARIANTS = {
	{ key = "plain", label = "flags \"\"", flags = "" },
	{ key = "SLUG", label = "flags \"SLUG\"", flags = "SLUG" },
	{ key = "xmlSlug", label = "XML slug=\"true\"" },
}
local PAD = 16
local HEADER = 64
local LABEL_WIDTH = 200
local COLUMN_WIDTH = 400
local ROW_GAP = 10
local FONT_GAP = 14
local SHOT_DELAY = 1

local function Apply(fontString, font, size, variant)
	local setReturn, object
	if variant.flags then
		setReturn = fontString:SetFont(MEDIA .. font.key .. ".ttf", size, variant.flags)
	else
		object = _G["KstyleUISpike_" .. font.id .. "_" .. size]
		if object then
			fontString:SetFontObject(object)
		end
	end
	local path, height, flags = fontString:GetFont()
	if not path and object then
		path, height, flags = object:GetFont()
	end
	if not path then
		fontString:SetFontObject(FALLBACK)
	end
	return {
		font = font.key,
		size = size,
		variant = variant.key,
		ok = path ~= nil,
		setReturn = tostring(setReturn),
		xmlObject = variant.flags == nil and object ~= nil or nil,
		path = ns.Describe(path),
		height = ns.Describe(height),
		flags = ns.Describe(flags),
	}
end

local function Build(panel)
	panel.samples = {}
	local y = -HEADER
	for column, variant in ipairs(VARIANTS) do
		local head = ns.Text(panel, "GameFontNormal")
		head:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD + LABEL_WIDTH + (column - 1) * COLUMN_WIDTH, y + 24)
		head:SetText(variant.label)
	end
	for _, font in ipairs(FONTS) do
		for _, size in ipairs(SIZES) do
			local label = ns.Text(panel, "GameFontNormalSmall")
			label:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, y)
			label:SetText(font.key .. " " .. size)
			for column, variant in ipairs(VARIANTS) do
				local text = panel:CreateFontString(nil, "OVERLAY")
				text:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD + LABEL_WIDTH + (column - 1) * COLUMN_WIDTH, y)
				panel.samples[#panel.samples + 1] = { text = text, font = font, size = size, variant = variant }
			end
			y = y - size - ROW_GAP
		end
		y = y - FONT_GAP
	end
	panel.contentHeight = -y + PAD
end

ns.Register("fonts", {
	group = "basic",
	summary = "shows Source Sans 3 and Inter at 9, 11, 16 and 24 units, with and without SLUG, and takes a screenshot.",
	Run = function(run)
		local panel = ns.Panel("fonts", "Fonts: plain, SLUG flag, XML slug", PAD * 2 + LABEL_WIDTH + #VARIANTS * COLUMN_WIDTH, 600)
		if not panel.samples then
			Build(panel)
			panel:SetHeight(panel.contentHeight)
		end
		for _, sample in ipairs(panel.samples) do
			local result = Apply(sample.text, sample.font, sample.size, sample.variant)
			sample.text:SetText(SAMPLE)
			sample.text:SetTextColor(0.92, 0.92, 0.92)
			run:Add("samples", result)
		end
		run:Set("rootEffectiveScale", ns.Root():GetEffectiveScale())
		local width, height = GetPhysicalScreenSize()
		run:Set("physicalWidth", width)
		run:Set("physicalHeight", height)
		ns.Later(SHOT_DELAY, function() ns.Screenshot(run) end)
		run:Note("panel open. It takes a screenshot in " .. SHOT_DELAY .. " s. Then type /kspike hide.")
	end,
})
