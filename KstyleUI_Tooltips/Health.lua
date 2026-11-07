-- Health.lua: GameTooltip's unit health on a KstyleUI status bar, fed by Blizzard's own bar so secret values pass through untouched.
local _, ns = ...

local K = KstyleUI
local Widgets, Skin = K.Widgets, K.Skin
local Settings, Style = ns.Settings, ns.Style

local Health = {}
ns.Health = Health

local BAR_GAP = 4
local BAR_INSET = 2
local LENGTH = 100

local bar, owner, source

function Health.Bar()
	return bar
end

local function Wanted()
	return ns.active == true and Settings.Get("healthBar") and source ~= nil and source:IsShown()
end

local function Place()
	local gap = Widgets.Snap(bar, BAR_GAP)
	local inset = Widgets.Snap(bar, BAR_INSET)
	local size = Settings.Get("bar.size")
	local opts = bar.opts
	bar:ClearAllPoints()
	if Settings.Get("bar.orientation") == "VERTICAL" then
		opts.width, opts.height = size, LENGTH
		bar:SetPoint("TOPLEFT", owner, "TOPRIGHT", gap, -inset)
		bar:SetPoint("BOTTOMLEFT", owner, "BOTTOMRIGHT", gap, inset)
	else
		opts.width, opts.height = LENGTH, size
		bar:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", inset, -gap)
		bar:SetPoint("TOPRIGHT", owner, "BOTTOMRIGHT", -inset, -gap)
	end
end

function Health.Restyle()
	if not bar then
		return
	end
	bar:SetOrientation(Settings.Get("bar.orientation"))
	bar:SetReverseFill(Settings.Get("bar.reverse"))
	bar:SetBarTexture(Settings.Get("bar.texture"))
	Place()
	bar:Restyle()
	bar:SetShown(Wanted())
end

function Health.SetColor(r, g, b)
	if bar and r then
		bar:SetBarColor(r, g, b, 1)
	end
end

local function Mirror(_, value)
	if bar and ns.active then
		bar:SetBarValue(value)
	end
end

local function Sync()
	if bar then
		bar:SetShown(Wanted())
	end
end

function Health.Build(tooltip)
	if bar then
		return bar
	end
	local glass = Style.Glass(tooltip)
	local blizzard = type(tooltip) == "table" and tooltip.StatusBar
	if not glass or type(blizzard) ~= "table" or type(blizzard.SetValue) ~= "function" then
		Settings.Log("GameTooltip has no StatusBar; unit tooltips show no health bar")
		return nil
	end
	owner, source = tooltip, blizzard
	bar = Widgets.StatusBar(glass, {
		texture = Settings.Get("bar.texture"),
		background = "track",
		border = true,
		smooth = true,
		min = 0,
		max = 1,
		value = 0,
		orientation = Settings.Get("bar.orientation"),
		reverse = Settings.Get("bar.reverse"),
	})
	bar:SetBarColor(Settings.Accent())
	local art = type(blizzard.GetStatusBarTexture) == "function" and blizzard:GetStatusBarTexture() or nil
	Skin.Strip(blizzard, { children = { art } })
	hooksecurefunc(blizzard, "SetValue", Mirror)
	blizzard:HookScript("OnShow", Sync)
	blizzard:HookScript("OnHide", Sync)
	Health.Restyle()
	Settings.Log("GameTooltip's health bar is mirrored on a KstyleUI bar")
	return bar
end

function Health.Hide()
	if bar then
		bar:Hide()
	end
end
