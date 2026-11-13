-- Legacy.lua: the Legacy window skin: the window and its side tabs on glass, progress bars in the shared bar look with their reading above the bar, the reward cards as slot-edged icons under a level diamond, and the challenge and tree pages' controls.
local _, ns = ...

local K = KstyleUI
local Skin, Tokens, L = K.Skin, K.Tokens, K.L
local Style, Parts, Skins, Kit = ns.Style, ns.Parts, ns.Skins, ns.PartC

local KEY = "legacy"
local PAGE_ART_KEYS = { "RewardTrackPage.Background", "RewardTrackPage.Icon", "ChallengesPage.Background", "TreePage.Background" }
local BAR_BACKGROUNDS = { "RewardTrackPage.ProgressBarBackground", "ChallengesPage.LegacyChallengePointSummary.ProgressBarBackground" }
local BARS = { "RewardTrackPage.LegacyRewardProgressBar", "ChallengesPage.LegacyChallengePointSummary.PointsBar" }
local DIVIDERS = { "ChallengesPage.VerticalDivider", "TreePage.VerticalDivider" }
local SCROLL_BARS = { "ChallengesPage.CategoryList.ScrollBar", "ChallengesPage.DetailPane.ScrollBar" }
local SEARCH_BOXES = { "ChallengesPage.CategoryList.SearchBox", "TreePage.LegacyTreeTraitPanel.SearchBox" }

local CARD_ART = { "RewardCardBG", "Highlight", "IconBorder", "LevelSquare" }
local ICON_CROP = 0.07
local GEM_UNITS = 22

local pageArt = {}
local cards = setmetatable({}, { __mode = "k" })

local function ShowPageArt()
	local alpha = Skins.Setting(KEY, "pageArt") and 1 or 0
	for _, texture in ipairs(pageArt) do
		texture:SetAlpha(alpha)
	end
end

local function PaintCard(card)
	local state = cards[card]
	local earned = Parts.IsTexture(card.EarnedCheckmark) and card.EarnedCheckmark:IsShown() == true
	if state.rim then
		state.rim:SetRimColor(Tokens.Color(earned and "gilt" or "slotRim"))
	end
	K.Widgets.Tint(state.gem, earned and "gilt" or "giltDim")
	K.Widgets.Size(state.gem, GEM_UNITS, GEM_UNITS)
end

local function RewardCard(card)
	if type(card) ~= "table" or type(card.GetRegions) ~= "function" then
		return
	end
	if not cards[card] then
		for _, key in ipairs(CARD_ART) do
			Parts.Hush(card[key])
		end
		local state = {}
		local icon = card.Icon
		if Parts.IsTexture(icon) then
			icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
			state.rim = Parts.Rim(card, { target = icon, outset = Tokens.Size("gapTiny") })
		end
		state.gem = card:CreateTexture(nil, "ARTWORK")
		state.gem:SetTexture((Tokens.Texture("diamond")))
		state.gem:SetPoint("CENTER", Parts.IsTexture(card.LevelSquare) and card.LevelSquare or card, "CENTER")
		cards[card] = state
		if type(card.Refresh) == "function" then
			hooksecurefunc(card, "Refresh", PaintCard)
		end
	end
	if card.Level then
		Style.Text(card.Level, "number", "textEmphasis")
	end
	if card.RewardName then
		Style.Text(card.RewardName, "body")
	end
	PaintCard(card)
end

local function RewardCards(progress)
	if type(progress.GetElements) ~= "function" then
		return
	end
	for _, card in ipairs(progress:GetElements() or {}) do
		RewardCard(card)
	end
end

local function RewardTrack(page)
	if page.Points then
		Style.Text(page.Points, "number", "textEmphasis", function()
			return (select(2, Style.Font("display")))
		end)
	end
	if page.PointsLabel then
		Style.Text(page.PointsLabel, "caption", "text")
	end
	local bar = page.LegacyRewardProgressBar
	if type(bar) == "table" and type(bar.GetStatusBarTexture) == "function" then
		Style.StatusBar(bar, { accent = true })
		if type(bar.Text) == "table" and type(bar.Text.SetPoint) == "function" then
			bar.Text:ClearAllPoints()
			bar.Text:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", 0, K.Widgets.Snap(bar, Tokens.Size("gapSmall")))
			bar.Text:SetJustifyH("RIGHT")
			Style.Text(bar.Text, "number", "text")
		end
	end
	local progress = page.LegacyRewardProgressFrame
	if type(progress) == "table" then
		RewardCards(progress)
		if type(progress.Init) == "function" then
			hooksecurefunc(progress, "Init", RewardCards)
		end
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
