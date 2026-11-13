-- Preview.lua: the settings window's live preview: sample numbers in your field and on a sample unit frame, in the current settings.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, L = K.Widgets, K.Tokens, K.L
local Settings, Pool, Display = ns.Settings, ns.Pool, ns.Display

local Preview = {}
ns.Preview = Preview

local CAPACITY = 12
local INTERVAL = 0.45
local FIELD_KEY = "combattext.player"
local FRAME_WIDTH, FRAME_HEIGHT = 200, 40
local FRAME_BOTTOM = 28
local BAR_INSET = 6
local BAR_FILL = 0.68
local SAMPLES = {
	{ place = "field", kind = "damage", emphasis = "none", amount = 1274, school = 1 },
	{ place = "frame", kind = "damage", emphasis = "crit", amount = 2431, school = 4 },
	{ place = "field", kind = "heal", emphasis = "none", amount = 438 },
	{ place = "frame", kind = "miss", emphasis = "none", word = "DODGE" },
	{ place = "field", kind = "heal", emphasis = "crit", amount = 612 },
	{ place = "frame", kind = "damage", emphasis = "none", amount = 842, school = 32 },
}

local function Caption(frame, anchor, text)
	local caption = Widgets.Text(frame, "caption", "text")
	Widgets.SetText(caption, text)
	caption.anchor = anchor
	return caption
end

local function SampleFrame(frame)
	local tile = Widgets.Panel(frame, { shape = "tile", fill = "buttonFill", shadow = false, width = FRAME_WIDTH, height = FRAME_HEIGHT })
	tile.bar = Widgets.StatusBar(tile, {
		color = "hostile",
		width = FRAME_WIDTH - 2 * BAR_INSET,
		height = FRAME_HEIGHT - 2 * BAR_INSET,
		min = 0, max = 1, value = BAR_FILL,
	})
	tile.caption = Caption(frame, tile, L["Target frame"])
	return tile
end

local function PlaceCaption(caption)
	caption:ClearAllPoints()
	Widgets.Point(caption, "TOP", caption.anchor, "BOTTOM", 0, -Tokens.Size("gapSmall"))
end

local function Place(frame)
	local field, tile, footprint = frame.field, frame.unitFrame, frame.footprint
	Widgets.Size(field, footprint.width, footprint.height)
	field:ClearAllPoints()
	Widgets.Point(field, "TOP", frame, "TOP")
	frame.base:SetHeight(Widgets.Border(frame))
	Widgets.Size(tile, FRAME_WIDTH, FRAME_HEIGHT)
	tile:ClearAllPoints()
	Widgets.Point(tile, "BOTTOM", frame, "BOTTOM", 0, FRAME_BOTTOM)
	tile.bar:ClearAllPoints()
	Widgets.Point(tile.bar, "CENTER", tile, "CENTER")
	PlaceCaption(frame.caption)
	PlaceCaption(tile.caption)
end

function Preview.Build(parent)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetAllPoints(parent)
	local field = CreateFrame("Frame", nil, frame)
	local base = frame:CreateTexture(nil, "ARTWORK")
	base:SetTexture((Tokens.Texture("divider")))
	base:SetPoint("TOPLEFT", field, "BOTTOMLEFT", 0, 0)
	base:SetPoint("TOPRIGHT", field, "BOTTOMRIGHT", 0, 0)
	Widgets.Tint(base, "accent")
	frame.footprint, frame.base = K.Setup.Layouts.Element(FIELD_KEY), base
	frame.caption = Caption(frame, field, L["Your combat text"])
	local unitFrame = SampleFrame(frame)

	local pool = Pool.New(frame, CAPACITY)
	local emitters = {
		field = Display.NewEmitter(field, "field", pool),
		frame = Display.NewEmitter(unitFrame, "unit", pool),
	}
	local cfg = {}
	local elapsed, nextSample = 0, 1
	frame.pool, frame.cfg, frame.field, frame.unitFrame = pool, cfg, field, unitFrame

	function frame.Refresh()
		Place(frame)
		Settings.Snapshot(Settings.Values(), cfg)
		pool:ReleaseAll()
		elapsed = INTERVAL
	end

	frame:SetScript("OnUpdate", function(_, dt)
		elapsed = elapsed + dt
		if elapsed < INTERVAL then
			return
		end
		elapsed = 0
		local sample = SAMPLES[nextSample]
		nextSample = nextSample % #SAMPLES + 1
		Display.Spawn(emitters[sample.place], cfg, sample.kind, sample.emphasis, sample.amount, sample.word, sample.school)
	end)
	frame:SetScript("OnHide", function()
		pool:ReleaseAll()
	end)
	frame.Refresh()
	return frame
end
