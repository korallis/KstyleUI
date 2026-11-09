-- Health.lua: GameTooltip's unit health on a KstyleUI status bar docked inside the tooltip's glass, fed by Blizzard's own bar so secret values pass through untouched; the tooltip grows by the bar through its padding.
local _, ns = ...

local K = KstyleUI
local Widgets, Skin = K.Widgets, K.Skin
local Settings, Style = ns.Settings, ns.Style

local Health = {}
ns.Health = Health

local BAR_GAP = 4
local BAR_EDGE = 8
local BAR_SIDE = 10
local LENGTH = 100

Health.GAP = BAR_GAP

local bar, owner, source
local docked = false

function Health.Bar()
	return bar
end

local function Wanted()
	return ns.active == true and Settings.Get("healthBar") and source ~= nil and source:IsShown()
end

local function Vertical()
	return Settings.Get("bar.orientation") == "VERTICAL"
end

local function Reserve()
	local size = Settings.Get("bar.size")
	local room = Wanted() and size + BAR_GAP or 0
	if Vertical() then
		docked = Style.Reserve(owner, room, 0)
	else
		docked = Style.Reserve(owner, 0, room)
	end
	return docked
end

local function Place()
	local gap = Widgets.Snap(bar, BAR_GAP)
	local edge = Widgets.Snap(bar, BAR_EDGE)
	local side = Widgets.Snap(bar, BAR_SIDE)
	local size = Settings.Get("bar.size")
	local opts = bar.opts
	bar:ClearAllPoints()
	if Vertical() then
		opts.width, opts.height = size, LENGTH
		if docked then
			bar:SetPoint("TOPRIGHT", owner, "TOPRIGHT", -edge, -side)
			bar:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT", -edge, side)
		else
			bar:SetPoint("TOPLEFT", owner, "TOPRIGHT", gap, -gap)
			bar:SetPoint("BOTTOMLEFT", owner, "BOTTOMRIGHT", gap, gap)
		end
	else
		opts.width, opts.height = LENGTH, size
		if docked then
			bar:SetPoint("BOTTOMLEFT", owner, "BOTTOMLEFT", side, edge)
			bar:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT", -side, edge)
		else
			bar:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", gap, -gap)
			bar:SetPoint("TOPRIGHT", owner, "BOTTOMRIGHT", -gap, -gap)
		end
	end
end

function Health.Restyle()
	if not bar then
		return
	end
	bar:SetOrientation(Settings.Get("bar.orientation"))
	bar:SetReverseFill(Settings.Get("bar.reverse"))
	bar:SetBarTexture(Settings.Get("bar.texture"))
	Reserve()
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
		local was = docked
		Reserve()
		if docked ~= was then
			Place()
		end
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
		Reserve()
	end
end
