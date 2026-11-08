-- Reskin.lua: the fallback path: Blizzard's own Cooldown Manager items restyled in place with the Skin helpers.
local _, ns = ...

local K = KstyleUI
local Skin, Widgets = K.Skin, K.Widgets
local Settings, Style, Viewers = ns.Settings, ns.Style, ns.Viewers

local Reskin = {}
ns.Reskin = Reskin

local ICON_CROP = 0.07
local ICON_OUTSET = 2
local BAR_OUTSET = 1
local CVAR = "cooldownViewerEnabled"

local active = {}
local hinted = false

local function IsTexture(region)
	return type(region) == "table" and type(region.GetObjectType) == "function" and region:GetObjectType() == "Texture"
end

local function Keep(...)
	local keep = {}
	for i = 1, select("#", ...) do
		local region = select(i, ...)
		if IsTexture(region) then
			keep[region] = true
		end
	end
	return keep
end

local function Crop(texture)
	if IsTexture(texture) then
		texture:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
	end
end

local function Text(text, font, size, outline, role)
	if type(text) == "table" and type(text.SetFont) == "function" then
		Style.Font(text, font, size, outline, role)
		Widgets.TextColor(text, "textEmphasis")
	end
end

local function SkinIcon(group, item)
	local cfg, current = Settings.current[group], Settings.current
	local icon = item.Icon
	if IsTexture(icon) then
		Skin.Strip(item, { keep = Keep(icon, item.OutOfRange) })
		Crop(icon)
	end
	local backdrop = Skin.Backdrop(item, { icon = true, inset = -ICON_OUTSET })
	if backdrop and backdrop.chrome and backdrop.chrome.SetRimAccent then
		local r, g, b = Settings.Accent()
		backdrop.chrome:SetRimAccent(r, g, b)
	end
	local cooldown = item.Cooldown
	if type(cooldown) == "table" and type(cooldown.GetCountdownFontString) == "function" then
		Text(cooldown:GetCountdownFontString(), current.timerFont, cfg.timerSize, current.timerOutline)
		if Settings.COOLDOWN_GROUPS[group] then
			Style.Countdown(cooldown)
		end
	end
	local charges = item.ChargeCount
	Text(type(charges) == "table" and charges.Current, current.countFont, cfg.countSize, current.countOutline)
	local applications = item.Applications
	Text(type(applications) == "table" and applications.Applications, current.countFont, cfg.countSize, current.countOutline)
end

local function SkinBar(item)
	local cfg, current = Settings.current.bars, Settings.current
	local bar = item.Bar
	if type(bar) == "table" and type(bar.GetStatusBarTexture) == "function" then
		Skin.Strip(bar, { keep = Keep(bar:GetStatusBarTexture()) })
		bar:SetStatusBarTexture(cfg.texture)
		bar:SetStatusBarColor(Settings.BarColor())
		Skin.Backdrop(bar, { shape = "tile", fill = "surface", inset = -BAR_OUTSET })
		Text(bar.Name, current.nameFont, cfg.nameSize, current.nameOutline, "body")
		Text(bar.Duration, current.timerFont, cfg.timerSize, current.timerOutline)
	end
	local frame = item.Icon
	if type(frame) == "table" and IsTexture(frame.Icon) then
		Skin.Strip(frame, { keep = Keep(frame.Icon) })
		Crop(frame.Icon)
		Skin.Backdrop(frame, { shape = "tile", fill = "buttonFill", inset = -BAR_OUTSET })
		Text(frame.Applications, current.countFont, cfg.countSize, current.countOutline)
	end
end

function Reskin.Item(group, item)
	if not active[group] or type(item) ~= "table" then
		return
	end
	if group == "bars" then
		SkinBar(item)
	else
		SkinIcon(group, item)
	end
end

local function Hint()
	if hinted or not (C_CVar and C_CVar.GetCVarBool) then
		return
	end
	local ok, on = pcall(C_CVar.GetCVarBool, CVAR)
	if ok and on == false then
		hinted = true
		ns.Log("Blizzard's Cooldown Manager is switched off, so the restyled viewers show nothing")
		K.Print(K.L["Turn on the Cooldown Manager in Options > Gameplay > Combat to see the restyled cooldowns."])
	end
end

function Reskin.Start(group)
	if not Viewers.Watch(group, Reskin.Item) then
		return false
	end
	active[group] = true
	Viewers.EachItem(group, Reskin.Item)
	Hint()
	return true
end

function Reskin.Refresh()
	for group in pairs(active) do
		Viewers.EachItem(group, Reskin.Item)
	end
end

function Reskin.Stop()
	for group in pairs(active) do
		active[group] = nil
	end
end

function Reskin.IsActive(group)
	return active[group] == true
end
