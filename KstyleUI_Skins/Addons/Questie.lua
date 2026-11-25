-- Questie.lua: a shared window card and section cap on Questie's own tracker, leaving its position, sizing and interactions with Questie.
local _, ns = ...

local K = KstyleUI
local Skin = K.Skin
local frame, panel, cap, label, tracker, icon
local painting, queued, enabled, active = false, false, true, false
local art, fonts, nodes = {}, {}, {}
local titleValue, countValue, layout

local function PaintFont(text, path, size, flags)
	if painting then return end
	fonts[text] = { path, size, flags }
	if not active or K.Store.Module("Skins").restyleAddons == false then return end
	local body = ns.Style.Font("body")
	if path == body then return end
	painting = true
	text:SetFont(body, size, flags)
	painting = false
end

local function PaintArt(texture)
	if painting then return end
	local alpha = texture:GetAlpha()
	art[texture] = alpha
	if not active or not K.Widgets.IsSecret(alpha) and alpha == 0 then return end
	painting = true
	texture:SetAlpha(0)
	painting = false
end

local function Discover(node)
	if node == panel or node == cap or (node.IsForbidden and node:IsForbidden()) then return end
	local state = nodes[node]
	local regions, children = node:GetNumRegions(), node:GetNumChildren()
	if K.Widgets.IsSecret(regions) or K.Widgets.IsSecret(children) then return end
	if not state or state.regions ~= regions then
		for _, region in ipairs({ node:GetRegions() }) do
			local kind = region:GetObjectType()
			if kind == "FontString" and region ~= label and not fonts[region] and K.Store.Module("Skins").restyleAddons ~= false then
				local path, size, flags = region:GetFont()
				fonts[region] = { path, size, flags }
				hooksecurefunc(region, "SetFont", PaintFont)
				region:SetFont(ns.Style.Font("body"), size, flags)
			elseif kind == "Texture" and not art[region] and (node == frame or node == icon) then
				art[region] = region:GetAlpha()
				hooksecurefunc(region, "SetVertexColor", PaintArt)
				hooksecurefunc(region, "SetColorTexture", PaintArt)
				region:SetAlpha(0)
			end
		end
	end
	if not state then state = {}; nodes[node] = state end
	state.regions = regions
	if state.count ~= children then
		state.count, state.children = children, { node:GetChildren() }
	end
	for _, child in ipairs(state.children) do Discover(child) end
end

local function PlaceCap()
	if not cap then return end
	local factor = K.Widgets.ScaleFactor(cap)
	local inset = ns.Lumen.Inset(K.Scale.Root()) / factor
	cap:ClearAllPoints()
	K.Widgets.Point(cap, "TOPLEFT", panel, "TOPLEFT", inset, -K.Widgets.Snap(cap, 11 / factor))
	K.Widgets.Point(cap, "TOPRIGHT", panel, "TOPRIGHT", -inset, -K.Widgets.Snap(cap, 11 / factor))
	cap:SetHeight(K.Widgets.Snap(cap, 21 / factor))
end

local function Sync(rows)
	if painting then return end
	if InCombatLockdown() then
		if not queued then
			queued = true
			K.Combat.Queue(function() queued = false; Sync(true) end)
		end
		return
	end
	local base = rawget(_G, "Questie_BaseFrame")
	if type(base) ~= "table" then return end
	painting = true
	if frame ~= base then
		frame, rows = base, true
		if cap then cap:Hide() end
		art, fonts, nodes = {}, {}, {}
		panel = Skin.Backdrop(frame, { shape = "window", fill = "surface", shadow = true, inset = { left = -16, right = -16, bottom = -16 } })
		frame:HookScript("OnShow", function() Sync(true) end)
	end
	local on = enabled and K.Modules.IsEnabled("Skins") and ns.Skins.IsOn("questie")
	on = on and K.Setup.Integrations.QuestTracker() ~= "kstyleui"
	panel:SetShown(on)
	if active ~= on then
		active, rows = on, true
		for texture, alpha in pairs(art) do
			if on then art[texture] = texture:GetAlpha() end
			texture:SetAlpha(on and 0 or alpha)
		end
		for text, font in pairs(fonts) do
			text:SetFont(on and K.Store.Module("Skins").restyleAddons ~= false and ns.Style.Font("body") or font[1], font[2], font[3])
		end
	end
	local header = rawget(_G, "Questie_HeaderFrame")
	icon = type(header) == "table" and header.questieIcon
	local tracked = type(header) == "table" and header.trackedQuests
	local text = type(tracked) == "table" and tracked.label
	if type(text) == "table" and text ~= label then
		label = text
		cap = ns.Lumen.SectionCap(header)
		titleValue, countValue = nil, nil
		layout = { Restyle = function()
			PlaceCap()
			if not active then return end
			painting = true
			for region, font in pairs(fonts) do region:SetFont(K.Store.Module("Skins").restyleAddons ~= false and ns.Style.Font("body") or font[1], font[2], font[3]) end
			painting = false
		end }
		ns.Style.Track(layout)
		hooksecurefunc(label, "SetText", function() Sync(false) end)
	end
	if label then
		label:SetAlpha(on and 0 or 1)
		local value = ns.Lumen.Plain(label:GetText())
		local title, count = value:match("^(.-):%s*(%d+/%d+)$")
		title = title or value
		if titleValue ~= title or countValue ~= count then
			titleValue, countValue = title, count
			cap:SetText(title)
			cap:SetCount(count)
			PlaceCap()
		end
		cap:SetShown(on)
	end
	if on and rows then Discover(frame) end
	painting = false
end

local function Refresh() Sync(true) end

ns.Skins.Add({
	key = "questie",
	label = K.L["Questie"],
	help = K.L["Gives Questie's own quest tracker the KstyleUI card and header."],
	addon = "Questie",
	live = true,
	sweep = false,
	Apply = function()
		local loader = rawget(_G, "QuestieLoader")
		if type(loader) == "table" and type(loader.ImportModule) == "function" then
			local ok, addon = pcall(loader.ImportModule, loader, "QuestieTracker")
			if ok and type(addon) == "table" and type(addon.Update) == "function" and tracker ~= addon then
				tracker = addon
				hooksecurefunc(addon, "Update", Refresh)
			end
		end
		K.Callbacks.Register("SettingChanged", "Skins.Questie", function(_, module)
			if module == "Integrations" then Refresh() end
		end)
		K.Callbacks.Register("ProfileChanged", "Skins.Questie", Refresh)
		Refresh()
	end,
	OnSwitch = function(_, on) enabled = on; Refresh() end,
})
