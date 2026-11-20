-- Questie.lua: a shared window card and section cap on Questie's own tracker, leaving its position, sizing and interactions with Questie.
local _, ns = ...

local K = KstyleUI
local Skin = K.Skin
local frame, panel, cap, label, tracker
local painting, queued, enabled = false, false, true

local function Refresh()
	if painting then return end
	if InCombatLockdown() then
		if not queued then
			queued = true
			K.Combat.Queue(function() queued = false; Refresh() end)
		end
		return
	end
	local base = rawget(_G, "Questie_BaseFrame")
	if type(base) ~= "table" then return end
	painting = true
	if frame ~= base then
		frame = base
		Skin.Strip(frame)
		panel = Skin.Backdrop(frame, { shape = "window", fill = "surface", shadow = true, inset = { left = -16, right = -16, bottom = -16 } })
		frame:HookScript("OnShow", Refresh)
		frame:HookScript("OnSizeChanged", Refresh)
	end
	local on = enabled and K.Modules.IsEnabled("Skins") and ns.Skins.IsOn("questie")
	on = on and K.Setup.Integrations.QuestTracker() == "questie"
	panel:SetShown(on)
	local header = rawget(_G, "Questie_HeaderFrame")
	if on and type(header) == "table" and type(header.questieIcon) == "table" then Skin.Strip(header.questieIcon) end
	local tracked = type(header) == "table" and header.trackedQuests
	local text = type(tracked) == "table" and tracked.label
	if type(text) == "table" and text ~= label then
		label = text
		cap = ns.Lumen.SectionCap(header)
		cap:SetPoint("LEFT", frame, "LEFT", 0, 0)
		cap:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
		cap:SetPoint("TOP", header, "TOP", 0, 0)
		hooksecurefunc(label, "SetText", Refresh)
	end
	if label then
		label:SetAlpha(on and 0 or 1)
		local value = ns.Lumen.Plain(label:GetText())
		local title, count = value:match("^(.-):%s*(%d+/%d+)$")
		cap:SetText(title or value)
		cap:SetCount(count)
		cap:SetShown(on)
	end
	if on then ns.Style.Sweep(frame, { skip = { [panel] = true, [cap or panel] = true } }) end
	painting = false
end

ns.Skins.Add({
	key = "questie",
	label = K.L["Questie"],
	help = K.L["Gives Questie's own quest tracker the KstyleUI card and header."],
	addon = "Questie",
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
