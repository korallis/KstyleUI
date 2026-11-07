-- Preview.lua: the settings window's live preview: sample damage, heals and a dodge rising through a field in the current settings.
local _, ns = ...

local K = KstyleUI
local Widgets, Tokens, L = K.Widgets, K.Tokens, K.L
local Settings, Pool, Display = ns.Settings, ns.Pool, ns.Display

local Preview = {}
ns.Preview = Preview

local CAPACITY = 8
local INTERVAL = 0.45
local FIELD_KEY = "combattext.player"
local FIELD_BOTTOM = 40
local SAMPLES = {
	{ kind = "damage", emphasis = "none", amount = 1274, school = 1 },
	{ kind = "heal", emphasis = "none", amount = 438 },
	{ kind = "damage", emphasis = "crit", amount = 2431, school = 4 },
	{ kind = "miss", emphasis = "none", word = "DODGE" },
	{ kind = "heal", emphasis = "crit", amount = 612 },
	{ kind = "damage", emphasis = "none", amount = 842, school = 32 },
}

function Preview.Build(parent)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetAllPoints(parent)
	local footprint = K.Setup.Layouts.Element(FIELD_KEY)
	local field = CreateFrame("Frame", nil, frame)
	field:SetSize(footprint.width, footprint.height)
	field:SetPoint("BOTTOM", frame, "BOTTOM", 0, FIELD_BOTTOM)
	local base = frame:CreateTexture(nil, "ARTWORK")
	base:SetTexture((Tokens.Texture("divider")))
	base:SetPoint("TOPLEFT", field, "BOTTOMLEFT", 0, 0)
	base:SetPoint("TOPRIGHT", field, "BOTTOMRIGHT", 0, 0)
	base:SetHeight(Widgets.Border(frame))
	Widgets.Tint(base, "accent")
	local caption = Widgets.Text(frame, "caption", "text")
	caption:SetPoint("TOP", field, "BOTTOM", 0, -Tokens.Size("gapMedium"))
	Widgets.SetText(caption, L["Your combat text"])

	local pool = Pool.New(frame, CAPACITY)
	local emitter = Display.NewEmitter(field, "field", "BOTTOM")
	local cfg = {}
	local elapsed, nextSample = 0, 1
	frame.pool, frame.cfg, frame.field = pool, cfg, field

	function frame.Refresh()
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
		Display.Spawn(pool, emitter, cfg, sample.kind, sample.emphasis, sample.amount, sample.word, sample.school)
	end)
	frame:SetScript("OnHide", function()
		pool:ReleaseAll()
	end)
	frame.Refresh()
	return frame
end
