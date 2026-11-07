-- WorldMap.lua: the world map and quest log skins: the map window's chrome, and the quest list and details beside the map.
local _, ns = ...

local K = KstyleUI
local Skin, L = K.Skin, K.L
local Style, Parts, Skins = ns.Style, ns.Parts, ns.Skins

local ADDON = "Blizzard_WorldMap"
local FRAME = "WorldMapFrame"
local BORDER_ART = { "NineSlice", "Bg", "TopTileStreaks", "PortraitContainer", "TitleContainer", "InsetBorderTop" }
local QUEST_POOLS = { "headerFramePool", "campaignHeaderFramePool", "campaignHeaderMinimalFramePool", "covenantCallingsHeaderFramePool" }
local DETAIL_BUTTONS = { "AbandonButton", "ShareButton", "TrackButton" }

local WEAK = { __mode = "k" }
local done = setmetatable({}, WEAK)

local function Log(key, message)
	K.DevTest.Log("Skins", key .. ": " .. message)
end

local function ApplyMap()
	local map = _G[FRAME]
	local border = map.BorderFrame
	Skin.Backdrop(map, { shape = "panel", fill = "surface", shadow = true })
	if type(border) == "table" then
		Skin.Strip(border, { children = BORDER_ART })
		Skin.CloseButton(border.CloseButton)
		local title = type(border.TitleContainer) == "table" and border.TitleContainer.TitleText
		if title then
			Style.Text(title, "heading", "textEmphasis")
		end
		local maxMin = border.MaximizeMinimizeFrame
		if type(maxMin) == "table" then
			Parts.Glyph(maxMin.MaximizeButton, "glyphChevron", { flip = true })
			Parts.Glyph(maxMin.MinimizeButton, "glyphChevron")
		end
	else
		Log("worldMap", "BorderFrame is missing; the map keeps Blizzard's frame")
	end
	local nav = map.NavBar
	if type(nav) == "table" then
		Skin.Strip(nav, { children = { "overlay" } })
		Skin.Backdrop(nav, { shape = "tile", fill = "raised", shadow = false })
	else
		Log("worldMap", "NavBar is missing; skipped")
	end
end

local function QuestRow(row)
	if done[row] then
		return
	end
	done[row] = true
	local text = row.Text or row.ButtonText or row.Name
	if text then
		Style.Text(text, "body")
	end
end

local function QuestRows()
	local scroll = _G.QuestScrollFrame
	if type(scroll) ~= "table" then
		return
	end
	for _, key in ipairs(QUEST_POOLS) do
		local pool = scroll[key]
		if type(pool) == "table" and type(pool.EnumerateActive) == "function" then
			for header in pool:EnumerateActive() do
				QuestRow(header)
			end
		end
	end
	local titles = scroll.titleFramePool
	if type(titles) == "table" and type(titles.EnumerateActive) == "function" then
		for title in titles:EnumerateActive() do
			QuestRow(title)
		end
	end
end

local function ApplyQuestLog()
	local log = _G.QuestMapFrame
	if type(log) ~= "table" then
		Log("questLog", "QuestMapFrame is missing; skipped")
		return
	end
	local quests = log.QuestsFrame
	if type(quests) == "table" then
		local scroll = quests.ScrollFrame
		if type(scroll) == "table" then
			Parts.Hush(scroll.Background)
			Parts.Hush(scroll.Edge)
			Skin.ScrollBar(scroll.ScrollBar)
			Skin.EditBox(scroll.SearchBox)
			if type(scroll.BorderFrame) == "table" then
				Skin.Strip(scroll.BorderFrame)
			end
		end
		local details = quests.DetailsFrame
		if type(details) == "table" then
			if type(details.BorderFrame) == "table" then
				Skin.Strip(details.BorderFrame)
			end
			local back = type(details.BackFrame) == "table" and details.BackFrame
			if back then
				Skin.Strip(back)
				Skin.Button(back.BackButton)
			end
			for _, key in ipairs(DETAIL_BUTTONS) do
				if type(details[key]) == "table" then
					Skin.Button(details[key])
				end
			end
			if type(details.ScrollFrame) == "table" then
				Skin.ScrollBar(details.ScrollFrame.ScrollBar)
			end
		end
	end
	Skin.Backdrop(log, { shape = "tile", fill = "raised", shadow = false })
	if type(QuestLogQuests_Update) == "function" then
		hooksecurefunc("QuestLogQuests_Update", QuestRows)
	else
		Log("questLog", "QuestLogQuests_Update is missing; quest rows keep Blizzard's font")
	end
	QuestRows()
end

Skins.Add({
	key = "worldMap",
	label = L["World map"],
	help = L["Restyles the world map's frame, title bar, buttons and navigation bar."],
	addon = ADDON,
	frame = FRAME,
	Apply = ApplyMap,
})

Skins.Add({
	key = "questLog",
	label = L["Quest log"],
	help = L["Restyles the quest list and quest details beside the world map."],
	frame = "QuestMapFrame",
	Apply = ApplyQuestLog,
})
