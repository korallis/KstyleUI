-- Windows.lua: helpers on Blizzard windows: the auction house's Current Expansion Only filter, ticked as the auction house opens only when the game lists that filter and unticked again only if KstyleUI ticked it; the full-screen world map's sidebars, lightened and made click-through, then put back to Blizzard's opaque, mouse-catching black; and a cover over guild chat in the guild and communities window, with the messages faded to nothing beneath it, that a click lifts until the window closes; lifting or turning it off puts back the messages' own opacity.
local _, ns = ...

local K, L = ns.K, ns.L
local Widgets = K.Widgets

local OWNER = "QoL.windows"
local ticked, cleared, hooked, revealed = false, false, false, false
local cover, alpha

local function Expansion()
	local filters, bar = type(Enum) == "table" and Enum.AuctionHouseFilter, type(AuctionHouseFrame) == "table" and AuctionHouseFrame.SearchBar
	local button, id = type(bar) == "table" and bar.FilterButton, type(filters) == "table" and filters.CurrentExpansionOnly
	if not id or type(button) ~= "table" or type(button.GetFilters) ~= "function" or type(button.ToggleFilter) ~= "function" then return end
	return button, id, button:GetFilters()
end

local function Offered(id)
	local groups = type(C_AuctionHouse) == "table" and ns.Ask(C_AuctionHouse.GetFilterGroups)
	for _, group in ipairs(type(groups) == "table" and groups or {}) do
		for _, filter in ipairs(type(group.filters) == "table" and group.filters or {}) do
			if filter == id then return true end
		end
	end
end

local function Auction()
	local button, id, filters = Expansion()
	if not (button and type(filters) == "table") then return end
	local want = ns.running and ns.Get("ahCurrent")
	if want and filters[id] ~= true and Offered(id) then
		button:ToggleFilter(id)
		ticked = true
	elseif not want and ticked then
		if filters[id] == true then button:ToggleFilter(id) end
		ticked = false
	end
end

local function Sidebars()
	local frame = type(WorldMapFrame) == "table" and WorldMapFrame.BlackoutFrame
	if type(frame) ~= "table" or type(frame.Blackout) ~= "table" then return end
	local on = ns.running and ns.Get("mapSidebars")
	if on or cleared then
		frame.Blackout:SetAlpha(on and ns.Get("mapSidebarsOpacity") / 100 or 1)
		frame:EnableMouse(not (on and ns.Get("mapClickThrough")))
		cleared = on
	end
end

local function Guild(frame)
	local id = type(frame.GetSelectedClubId) == "function" and frame:GetSelectedClubId()
	if not id then return false end
	local info = type(C_Club) == "table" and ns.Ask(C_Club.GetClubInfo, id)
	local guild = type(Enum) == "table" and type(Enum.ClubType) == "table" and Enum.ClubType.Guild
	return type(info) ~= "table" or ns.IsSecret(info.clubType) or info.clubType == guild
end

local function Cover()
	local frame = CommunitiesFrame
	local chat = type(frame) == "table" and frame.Chat
	local messages = type(chat) == "table" and chat.MessageFrame
	if type(messages) ~= "table" then return end
	local on = ns.running and ns.Get("guildCover")
	if on and not cover then
		cover = CreateFrame("Button", nil, chat)
		cover:SetAllPoints(messages)
		cover:SetFrameLevel(messages:GetFrameLevel() + 10)
		cover.chrome = Widgets.Chrome(cover, { shape = "tile", fill = "surface", shadow = false })
		cover.text = Widgets.Text(cover, "body", "text")
		Widgets.Point(cover.text, "CENTER", cover, "CENTER")
		Widgets.SetText(cover.text, L["Guild chat is hidden. Click to show it."])
		cover:SetScript("OnClick", function() revealed = true; Cover() end)
	end
	if on and not hooked then
		hooked = true
		frame:HookScript("OnHide", function() revealed = false; Cover() end)
		if type(frame.OnClubSelected) == "function" then hooksecurefunc(frame, "OnClubSelected", Cover) end
	end
	local hide = on and not revealed and Guild(frame)
	if hide and not alpha then
		alpha = messages:GetAlpha()
		messages:SetAlpha(0)
	elseif not hide and alpha then
		messages:SetAlpha(alpha)
		alpha = nil
	end
	if cover then cover:SetShown(hide) end
end

local function Loaded(_, name)
	if name == "Blizzard_WorldMap" then Sidebars() elseif name == "Blizzard_Communities" then Cover() end
end

local function Sync()
	local loads = ns.running and (ns.Get("mapSidebars") or ns.Get("guildCover"))
	if loads then K.Events.Register(OWNER, "ADDON_LOADED", Loaded) else K.Events.Unregister(OWNER, "ADDON_LOADED") end
	if ns.running and ns.Get("ahCurrent") then
		K.Events.Register(OWNER, "AUCTION_HOUSE_SHOW", function() C_Timer.After(0, Auction) end)
	else
		K.Events.Unregister(OWNER, "AUCTION_HOUSE_SHOW")
	end
	Auction()
	Sidebars()
	Cover()
end

local KEYS = { ahCurrent = true, mapSidebars = true, mapSidebarsOpacity = true, mapClickThrough = true, guildCover = true }

ns.AddPart({
	name = "windows",
	Start = Sync,
	Stop = Sync,
	Setting = function(key)
		if key == nil or KEYS[key] then Sync() end
	end,
})
