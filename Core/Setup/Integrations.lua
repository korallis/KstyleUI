-- Integrations.lua: overlapping-addon notices and optional, movable lanes and WeakAuras anchors.
local _, K = ...
local L, Widgets, Layout, Store = K.L, K.Widgets, K.Layout, K.Store
local Integration = { frames = {} }
K.Setup.Integrations = Integration

local OVERLAPS = {
	UnitFrames = { "ElvUI", "Tukui", "ShadowedUnitFrames", "PitBull4" },
	ActionBars = { "Bartender4", "Dominos", "ElvUI", "Tukui" },
	DataBars = { "Bartender4", "Dominos" },
	Meters = { "Details" },
	Nameplates = { "Plater", "Kui_Nameplates", "TidyPlates", "ElvUI" },
	GroupFrames = { "Grid2", "VuhDo", "HealBot", "ElvUI", "ShadowedUnitFrames" },
	Bags = { "Bagnon", "AdiBags", "BetterBags", "Baganator", "ElvUI" },
	Chat = { "Prat-3.0", "Chatter", "Chattynator", "ElvUI" },
	Skins = { "Questie" },
}
function Integration.Detected(module)
	local out, api = {}, C_AddOns
	if api and type(api.IsAddOnLoaded) == "function" then
		for _, name in ipairs(OVERLAPS[module] or {}) do
			local ok, loaded = pcall(api.IsAddOnLoaded, name)
			if ok and not Widgets.IsSecret(loaded) and loaded == true then out[#out + 1] = name end
		end
	end
	return out
end

function Integration.Note(module, standard)
	if Store.IsLoaded() and not Store.Module("Integrations").notices then return standard end
	local detected = Integration.Detected(module)
	if module == "Skins" and #detected > 0 then return L["Questie detected. Choose your quest tracker in Existing addons."] end
	return #detected > 0 and string.format(L["Also detected: %s. Choose above."], table.concat(detected, ", ")) or standard
end

local LANES = {
	{ key = "timerLane", label = L["Boss timers"], width = 360, height = 120, x = -500, y = 330 },
	{ key = "announcementLane", label = L["Boss announcements"], width = 520, height = 48, y = 420 },
	{ key = "weakAuras", label = L["WeakAuras anchor 1"], name = "KstyleUI_WeakAuras1", width = 180, height = 48, x = -300, y = 180 },
	{ key = "weakAuras", label = L["WeakAuras anchor 2"], name = "KstyleUI_WeakAuras2", width = 180, height = 48, x = 300, y = 180 },
}
Store.RegisterDefaults("Integrations", { notices = true, timerLane = true, announcementLane = true, weakAuras = true, questTracker = "kstyleui" })
K.Options.Register("Integrations", {
	{ type = "header", label = L["Existing addons"] },
	{ type = "toggle", key = "notices", label = L["Other-addon notices"], help = L["Names overlapping addons in setup and explains boss-addon support. Off hides these notices."] },
	{ type = "dropdown", key = "questTracker", label = L["Quest tracker"], help = L["Keep Questie's map pins and choose one tracker. Enabling Questie's tracker may reload the UI."], showWhen = function() return #Integration.Detected("Skins") > 0 end, options = {
		{ value = "kstyleui", label = L["Use KstyleUI's quest card"] },
		{ value = "questie", label = L["Use Questie's quest tracker"] },
	} },
	{ type = "toggle", key = "timerLane", label = L["Boss timer lane"], help = L["Reserve a movable 360 by 120 lane for your boss addon's timers."] },
	{ type = "toggle", key = "announcementLane", label = L["Announcement lane"], help = L["Reserve a movable 520 by 48 lane for boss announcements."] },
	{ type = "toggle", key = "weakAuras", label = L["WeakAuras anchors"], help = L["Two movable anchors; attach your own auras to KstyleUI_WeakAuras1 and KstyleUI_WeakAuras2."] },
})

local function Apply()
	if not Store.IsLoaded() then return end
	K.Combat.Queue(function()
		local config = Store.Module("Integrations")
		for i, spec in ipairs(LANES) do
			local frame = Integration.frames[i]
			if config[spec.key] and not frame then
				frame = CreateFrame("Frame", spec.name, K.Scale.Root())
				Widgets.Size(frame, spec.width, spec.height)
				Integration.frames[i] = frame
				Layout.Register(frame, "integrations." .. (spec.name or spec.key), { anchor = "CENTER", x = spec.x or 0, y = spec.y }, { label = spec.label, module = "Integrations" })
			end
			if frame then
				Layout.SetLive("integrations." .. (spec.name or spec.key), config[spec.key])
				frame:SetShown(config[spec.key])
			end
		end
	end)
end
K.Callbacks.Register("SettingChanged", "Integrations", function(_, module) if module == "Integrations" then Apply() end end)
K.Callbacks.Register("ProfileChanged", "Integrations", Apply)
K.Events.Register("Integrations", "PLAYER_LOGIN", Apply)

function Integration.Preview(parent)
	local frame = CreateFrame("Frame", nil, parent)
	Widgets.Size(frame, 520, 190)
	local lanes = {}
	for i = 1, 2 do
		local spec = LANES[i]
		local lane = CreateFrame("Frame", nil, frame)
		lane.chrome = Widgets.Chrome(lane, { shape = "tile", fill = "deep", shadow = false })
		lane.text = CreateFrame("Frame", nil, lane)
		lane.label = Widgets.Text(lane.text, "caption", "textEmphasis")
		lane.label:SetText(spec.label)
		lanes[i] = lane
	end
	function frame:Restyle()
		Widgets.Size(self, 520, 190)
		for i, lane in ipairs(lanes) do
			Widgets.Size(lane, LANES[i].width, LANES[i].height)
			Widgets.Point(lane, "TOP", self, "TOP", 0, i == 1 and 0 or -132)
			lane:SetShown(Store.Module("Integrations")[LANES[i].key])
			lane.text:SetScale(1 / self:GetScale())
			Widgets.Size(lane.text, 6, 6)
			Widgets.Point(lane.text, "CENTER", lane, "CENTER")
			Widgets.StyleText(lane.label)
			Widgets.Point(lane.label, "CENTER", lane.text, "CENTER")
		end
	end
	frame.Refresh = frame.Restyle
	Widgets.Track(frame)
	frame:Refresh()
	return frame
end
