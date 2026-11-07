-- LootRolls.lua: the group loot roll skin: each roll frame on a glass panel, its item icon rimmed by quality, and a KstyleUI timer bar that mirrors Blizzard's.
local _, ns = ...

local K = KstyleUI
local Skin, L = K.Skin, K.L
local Style, Skins, Kit = ns.Style, ns.Skins, ns.PartC

local KEY = "lootRolls"
local FRAME_COUNT = 4
local TIMER_WIDTH, TIMER_HEIGHT = 190, 8
local SETUP = "GroupLootFrame_SetupItemDisplay"

local rolls = setmetatable({}, { __mode = "k" })

local function RollQuality(frame)
	if type(GetLootRollItemInfo) ~= "function" then
		Kit.LogOnce(KEY, "GetLootRollItemInfo is missing; roll icons have no quality rim")
		return nil
	end
	local rollID = frame.rollID
	if rollID == nil or Kit.IsSecret(rollID) then
		return nil
	end
	local ok, _, _, _, quality = pcall(GetLootRollItemInfo, rollID)
	if not ok then
		return nil
	end
	return quality
end

local function Paint(frame)
	local state = rolls[frame]
	if not state then
		return
	end
	Kit.Quality(KEY, state.rim, RollQuality(frame))
end

local function SkinRoll(frame)
	Skin.Strip(frame, { children = { "NineSlice", "Bg" } })
	Skin.Backdrop(frame, { shape = "panel", fill = "surface", shadow = true })
	local state = { rim = Kit.Item(frame.IconFrame) }
	Kit.MirrorBar(frame.Timer, frame, TIMER_WIDTH, TIMER_HEIGHT)
	if frame.Name then
		Style.Text(frame.Name, "body")
	end
	rolls[frame] = state
	Paint(frame)
end

local function Apply()
	for i = 1, FRAME_COUNT do
		local frame = Kit.Frame(KEY, "GroupLootFrame" .. i)
		if frame then
			SkinRoll(frame)
		end
	end
	if type(_G[SETUP]) == "function" then
		hooksecurefunc(SETUP, Paint)
	else
		Kit.Log(KEY, SETUP .. " is missing; roll rims show the quality at skin time only")
	end
end

local function OnSetting(_, field)
	if field == nil or field == "qualityBorders" or field == "qualityFrom" then
		for frame in pairs(rolls) do
			Paint(frame)
		end
	end
end

Skins.Add({
	key = KEY,
	label = L["Loot rolls"],
	help = L["Restyles the need, greed and pass rolls in a group."],
	frame = "GroupLootFrame1",
	defaults = Kit.QualityDefaults(),
	rows = Kit.QualityRows(L["Colours each roll's item border by its quality."]),
	Apply = Apply,
	OnSetting = OnSetting,
})
