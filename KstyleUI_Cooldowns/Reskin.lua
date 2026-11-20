-- Reskin.lua: Blizzard's own Cooldown Manager items restyled in place with the Skin helpers, their text set against the item scale Edit Mode's IconSize gives them, the tracked buff row stopped at the grid by Cap.
local _, ns = ...

local K = KstyleUI
local Skin, Widgets = K.Skin, K.Widgets
local Cap, Settings, Style, Viewers = ns.Cap, ns.Settings, ns.Style, ns.Viewers

local Reskin = {}
ns.Reskin = Reskin

local ICON_OUTSET = 0
local CVAR = "cooldownViewerEnabled"

local active = {}
local watchedItems = setmetatable({}, { __mode = "k" })
local watchedViewers = setmetatable({}, { __mode = "k" })
local nativeBars = setmetatable({}, { __mode = "k" })

local function LayoutBars()
	local viewer = Viewers.Frame("bars")
	if viewer and type(viewer.Layout) == "function" then viewer:Layout() end
end

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

local function Crop(texture, crop)
	if IsTexture(texture) then
		texture:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
	end
end

local function Text(text, font, size, outline, role, shown)
	if type(text) == "table" and type(text.SetFont) == "function" then
		Style.Font(text, font, size, outline, role)
		Widgets.TextColor(text, "textEmphasis")
		if shown ~= nil then text:SetAlpha(shown == false and 0 or 1) end
	end
end

local function ItemScale(item)
	local ok, scale = pcall(item.GetScale, item)
	if ok and type(scale) == "number" and not ns.IsSecret(scale) and scale > 0 then
		return scale
	end
	return 1
end

local function Outset(backdrop, outset)
	if backdrop then
		local pixel = K.Scale.Pixel(1) / Widgets.ScaleFactor(backdrop)
		local farX, farY = Widgets.Remainder(backdrop.target or backdrop:GetParent())
		local fraction = farX .. ":" .. farY
		if backdrop.inset ~= -outset or backdrop.reskinPixel ~= pixel or backdrop.reskinFraction ~= fraction then
			backdrop.inset, backdrop.reskinPixel, backdrop.reskinFraction = -outset, pixel, fraction
			backdrop:Restyle()
			backdrop.chrome:Restyle()
		end
	end
	return backdrop
end

local function Toggle(cooldown, group, method, key, off, native)
	if type(cooldown[method]) ~= "function" then return end
	local side = K.Safe.Side(cooldown)
	local state = side[method]
	if not state then
		state = { native = native }
		side[method] = state
		hooksecurefunc(cooldown, method, function(frame, value)
			if state.busy then return end
			state.native = value
			if active[group] and not Settings.current[group][key] then
				state.busy = true
				frame[method](frame, off)
				state.busy = nil
			end
		end)
	end
	local disabled = not Settings.current[group][key]
	if disabled or state.disabled then
		state.busy = true
		local value = state.native
		if disabled then value = off end
		cooldown[method](cooldown, value)
		state.busy = nil
	end
	state.disabled = disabled
end

local function SkinIcon(group, item)
	local cfg, current = Settings.current[group], Settings.current
	local scale = ItemScale(item)
	local icon = item.Icon
	if IsTexture(icon) then
		Skin.Strip(item, { keep = Keep(icon, item.OutOfRange) })
		Crop(icon, cfg.iconZoom)
	end
	local backdrop = Outset(Skin.Backdrop(item, { icon = true, inset = -ICON_OUTSET / scale }), ICON_OUTSET / scale)
	if backdrop and backdrop.chrome and backdrop.chrome.SetRimAccent then
		if current.accent == "quiet" then
			backdrop.chrome:SetRim(Widgets.Rgba("edgeInner"))
		else
			local r, g, b = Settings.Accent()
			backdrop.chrome:SetRimAccent(r, g, b)
		end
	end
	if backdrop and backdrop.chrome then
		backdrop.chrome:SetShadow(false)
		local dress = current.medallionsIcons and K.HudStyle.Current() == "medallions"
		if dress and not backdrop.medOverlay then
			backdrop.medOverlay = CreateFrame("Frame", nil, item)
			backdrop.medOverlay:SetFrameLevel(item:GetFrameLevel() + 1)
			Widgets.Cover(backdrop.medOverlay, item)
		end
		Widgets.MedallionsFrame(backdrop, dress, backdrop.medOverlay)
	end
	local cooldown = item.Cooldown
	if type(cooldown) == "table" and type(cooldown.GetCountdownFontString) == "function" then
		Toggle(cooldown, group, "SetHideCountdownNumbers", "timer", true, not Viewers.Frame(group).timerShown)
		Toggle(cooldown, group, "SetDrawSwipe", "swipe", false, item.cooldownShowSwipe)
		if group ~= "buffs" then Toggle(cooldown, group, "SetDrawEdge", "edge", false, item.cooldownShowDrawEdge) end
		local text = cooldown:GetCountdownFontString()
		Text(text, current.timerFont, cfg.timerSize / scale, current.timerOutline, group ~= "essential" and "timer" or nil)
		Style.Countdown(cooldown, group == "essential")
		if text and (group == "essential" or group == "buffs") then
			if group == "buffs" then
				text:ClearAllPoints()
				text:SetPoint("TOP", item, "BOTTOM", 0, -Widgets.Snap(item, 2 / scale))
				text:SetJustifyH("CENTER")
			else
				Style.PlaceEssential(text, item, scale)
			end
		end
	end
	local charges = item.ChargeCount
	Text(type(charges) == "table" and charges.Current, current.countFont, cfg.countSize / scale, current.countOutline, nil, cfg.showCount)
	local applications = item.Applications
	Text(type(applications) == "table" and applications.Applications, current.countFont, cfg.countSize / scale, current.countOutline, nil, cfg.showCount)
end

local function SkinBar(item)
	local cfg, current = Settings.current.bars, Settings.current
	local scale = ItemScale(item)
	if not nativeBars[item] then
		nativeBars[item] = { item:GetHeight(), item.Bar:GetHeight(), item.Icon:GetWidth(), item.Icon:GetHeight() }
	end
	local height = Widgets.Snap(item, cfg.height / Widgets.ScaleFactor(item))
	item:SetHeight(height)
	local bar = item.Bar
	if type(bar) == "table" and type(bar.GetStatusBarTexture) == "function" then
		bar:SetHeight(math.max(1, height - 2 * Widgets.Border(bar)))
		local keep = Keep(bar:GetStatusBarTexture())
		for region in pairs(Widgets.BarEdge(bar).regions) do
			keep[region] = true
		end
		Skin.Strip(bar, { keep = keep })
		bar:SetStatusBarTexture(cfg.texture)
		bar:SetStatusBarColor(Settings.BarColor())
		Text(bar.Name, current.nameFont, cfg.nameSize / scale, current.nameOutline, "body")
		Text(bar.Duration, current.timerFont, cfg.timerSize / scale, current.timerOutline, "timer")
	end
	local frame = item.Icon
	if type(frame) == "table" and IsTexture(frame.Icon) then
		frame:SetWidth(height)
		frame:SetHeight(height)
		Skin.Strip(frame, { keep = Keep(frame.Icon) })
		Crop(frame.Icon, cfg.iconZoom)
		Outset(Skin.Backdrop(frame, { shape = "tile", fill = "buttonFill", inset = -ICON_OUTSET / scale }), ICON_OUTSET / scale)
		Text(frame.Applications, current.countFont, cfg.countSize / scale, current.countOutline, nil, cfg.showCount)
	end
end

function Reskin.Item(group, item)
	if not active[group] or type(item) ~= "table" then
		return
	end
	if not watchedItems[item] and type(item.SetScale) == "function" then
		watchedItems[item] = group
		hooksecurefunc(item, "SetScale", function(frame)
			Reskin.Item(watchedItems[frame], frame)
		end)
	else
		watchedItems[item] = group
	end
	if group == "bars" then
		SkinBar(item)
	else
		SkinIcon(group, item)
	end
	if group == "buffs" then
		Cap.Watch(item)
	end
end

local function Hint()
	local account = K.Store.Account()
	if account.cooldownViewerHinted or not (C_CVar and C_CVar.GetCVarBool) then
		return
	end
	local ok, on = pcall(C_CVar.GetCVarBool, CVAR)
	if ok and not ns.IsSecret(on) and on == false then
		account.cooldownViewerHinted = true
		ns.Log("Blizzard's Cooldown Manager is switched off, so the restyled viewers show nothing")
		local path = K.Locale.Path(GAMEMENU_OPTIONS, "Options", SETTING_GROUP_GAMEPLAY, "Gameplay", ADVANCED_OPTIONS_LABEL, "Advanced Options")
		K.Print(K.L["Turn on the Cooldown Manager in %s to see the restyled cooldowns."]:format(path))
	end
end

function Reskin.Start(group)
	if not Viewers.Watch(group, Reskin.Item) then
		return false
	end
	active[group] = true
	local frame = Viewers.Frame(group)
	if not watchedViewers[frame] and type(frame.SetScale) == "function" then
		watchedViewers[frame] = group
		hooksecurefunc(frame, "SetScale", function(viewer)
			local current = watchedViewers[viewer]
			if active[current] then
				Viewers.EachItem(current, Reskin.Item)
				if current == "bars" then LayoutBars() end
			end
		end)
	end
	Viewers.EachItem(group, Reskin.Item)
	if group == "bars" then LayoutBars() end
	if group == "buffs" then
		Cap.Start()
	end
	Hint()
	return true
end

function Reskin.Refresh()
	for group in pairs(active) do
		Viewers.EachItem(group, Reskin.Item)
	end
	if active.bars then LayoutBars() end
	if active.buffs then
		Cap.Queue()
	end
end

function Reskin.Stop()
	local capped, bars = active.buffs, active.bars
	for group in pairs(active) do
		active[group] = nil
	end
	for item, native in pairs(nativeBars) do
		item:SetHeight(native[1])
		item.Bar:SetHeight(native[2])
		item.Icon:SetWidth(native[3])
		item.Icon:SetHeight(native[4])
		nativeBars[item] = nil
	end
	if bars then LayoutBars() end
	if capped then
		Cap.Stop()
	end
end

function Reskin.IsActive(group)
	return active[group] == true
end
