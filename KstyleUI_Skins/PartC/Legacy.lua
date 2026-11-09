-- Legacy.lua: the Legacy window skin: the window and its side tabs on glass, progress bars in the shared bar look, and the challenge and tree pages' controls.
local _, ns = ...

local K = KstyleUI
local Skin, L = K.Skin, K.L
local Style, Parts, Skins, Kit = ns.Style, ns.Parts, ns.Skins, ns.PartC

local KEY = "legacy"
local PAGE_ART_KEYS = { "RewardTrackPage.Background", "ChallengesPage.Background", "TreePage.Background" }
local BAR_BACKGROUNDS = { "RewardTrackPage.ProgressBarBackground", "ChallengesPage.LegacyChallengePointSummary.ProgressBarBackground" }
local BARS = { "RewardTrackPage.LegacyRewardProgressBar", "ChallengesPage.LegacyChallengePointSummary.PointsBar" }
local DIVIDERS = { "ChallengesPage.VerticalDivider", "TreePage.VerticalDivider" }
local SCROLL_BARS = { "ChallengesPage.CategoryList.ScrollBar", "ChallengesPage.DetailPane.ScrollBar" }
local SEARCH_BOXES = { "ChallengesPage.CategoryList.SearchBox", "TreePage.LegacyTreeTraitPanel.SearchBox" }

local pageArt = {}

local function ShowPageArt()
	local alpha = Skins.Setting(KEY, "pageArt") and 1 or 0
	for _, texture in ipairs(pageArt) do
		texture:SetAlpha(alpha)
	end
end

local function RewardTrack(page)
	if page.Points then
		Style.Text(page.Points, "display", "textEmphasis")
	end
	if page.PointsLabel then
		Style.Text(page.PointsLabel, "caption", "text")
	end
end

local function Tree(page)
	local panel = page.LegacyTreeTraitPanel
	if type(panel) == "table" and type(panel.ApplyButton) == "table" then
		Kit.Button(panel.ApplyButton)
	end
	local summary = page.LegacyTreePointSummary
	if type(summary) == "table" then
		Parts.Hush(summary.Border)
		if summary.AvailablePointsLabel then
			Style.Text(summary.AvailablePointsLabel, "caption", "text")
		end
	end
end

local function Apply()
	local frame = Kit.Frame(KEY, "LegacySystemFrame")
	if not frame then
		return
	end
	Kit.Window(frame, { tabs = false })
	if type(frame.Tabs) == "table" then
		for _, tab in ipairs(frame.Tabs) do
			Parts.SideTab(tab)
		end
		Kit.Dock(frame, frame.Tabs)
	else
		Kit.Log(KEY, "the side tabs are missing; they keep Blizzard's look")
	end
	Kit.Each(KEY, frame, PAGE_ART_KEYS, function(texture)
		pageArt[#pageArt + 1] = texture
	end)
	ShowPageArt()
	Kit.Each(KEY, frame, BAR_BACKGROUNDS, Parts.Hush)
	Kit.Each(KEY, frame, BARS, Kit.Bar)
	Kit.Each(KEY, frame, DIVIDERS, Skin.Strip)
	Kit.Each(KEY, frame, SCROLL_BARS, Kit.ScrollBar)
	Kit.Each(KEY, frame, SEARCH_BOXES, function(box)
		Kit.EditBox(box, { "searchIcon" })
	end)
	local filter = Kit.Child(KEY, frame, "ChallengesPage.CategoryList.FilterDropdown")
	if filter then
		Parts.Dropdown(filter)
	end
	if type(frame.RewardTrackPage) == "table" then
		RewardTrack(frame.RewardTrackPage)
	end
	if type(frame.TreePage) == "table" then
		Tree(frame.TreePage)
	end
end

local function OnSetting(_, field)
	if field == nil or field == "pageArt" then
		ShowPageArt()
	end
end

Skins.Add({
	key = KEY,
	label = L["Legacy"],
	help = L["Restyles the Legacy window: its tabs, bars, lists and buttons."],
	addon = "Blizzard_LegacySystem",
	frame = "LegacySystemFrame",
	defaults = { pageArt = false },
	rows = {
		{
			type = "toggle", key = "pageArt", label = L["Page art"],
			help = L["Shows Blizzard's art behind the Legacy pages instead of plain glass."],
		},
	},
	Apply = Apply,
	OnSetting = OnSetting,
})
