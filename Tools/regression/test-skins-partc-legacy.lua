-- test-skins-partc-legacy.lua: the Legacy skin waits for Blizzard_LegacySystem, then restyles LegacySystemFrame, its side tabs, bars and page controls.
local S = dofile("Tools/regression/skins_env.lua")
local W = S.W

local HOOKED = { SetChecked = true }

local function Alpha(region)
	return region:GetAlpha()
end

local function FontPath(text)
	return (text:GetFont())
end

local function Bar(B, parent)
	local bar = B.frame("StatusBar", parent)
	bar:SetStatusBarTexture("Legacy-Progressbar-Fill")
	B.add(bar:GetStatusBarTexture())
	bar.ProgressBarFrame = B.texture(bar, "OVERLAY")
	bar.Text = B.text(bar)
	return bar
end

-- Legacy(env, B) -> the stand-in LegacySystemFrame from Blizzard_LegacySystem.
local function Legacy(env, B)
	local p = {}
	local f = B.frame("Frame", nil, "LegacySystemFrame")
	f:Hide()
	f.NineSlice = B.frame("Frame", f)
	B.texture(f.NineSlice)
	f.Bg = B.texture(f, "BACKGROUND")
	f.TitleContainer = B.frame("Frame", f)
	f.TitleContainer.TitleText = B.text(f.TitleContainer)
	f.PortraitContainer = B.frame("Frame", f)
	p.portrait = B.texture(f.PortraitContainer)
	f.CloseButton = B.frame("Button", f)
	B.texture(f.CloseButton)
	f.Tabs = {}
	for i = 1, 3 do
		local tab = B.frame("Frame", f)
		tab.Background = B.texture(tab, "BACKGROUND")
		tab.Icon = B.texture(tab)
		tab.SelectedTexture = B.texture(tab, "OVERLAY")
		function tab.SetChecked(self, checked)
			self.SelectedTexture:SetShown(checked)
		end
		tab:SetChecked(i == 1)
		f.Tabs[i] = tab
	end
	local track = B.frame("Frame", f)
	track:SetFrameLevel(100)
	f.RewardTrackPage = track
	track.Background = B.texture(track, "BACKGROUND")
	track.Points, track.PointsLabel = B.text(track), B.text(track)
	track.ProgressBarBackground = B.texture(track)
	track.LegacyRewardProgressBar = Bar(B, track)
	track.LegacyRewardProgressBar:SetFrameLevel(100)
	local challenges = B.frame("Frame", f)
	f.ChallengesPage = challenges
	challenges.Background = B.texture(challenges, "BACKGROUND")
	local list = B.frame("Frame", challenges)
	challenges.CategoryList = list
	list.FilterDropdown = B.frame("Button", list)
	list.FilterDropdown.Background = B.texture(list.FilterDropdown, "BACKGROUND")
	list.SearchBox = B.frame("EditBox", list)
	p.searchArt = B.texture(list.SearchBox)
	list.ScrollBar = B.frame("Frame", list)
	challenges.DetailPane = B.frame("Frame", challenges)
	challenges.DetailPane.ScrollBar = B.frame("Frame", challenges.DetailPane)
	local summary = B.frame("Frame", challenges)
	challenges.LegacyChallengePointSummary = summary
	summary.ProgressBarBackground = B.texture(summary)
	summary.PointsBar = Bar(B, summary)
	challenges.VerticalDivider = B.frame("Frame", challenges)
	p.challengeDivider = B.texture(challenges.VerticalDivider)
	local tree = B.frame("Frame", f)
	f.TreePage = tree
	tree.Background = B.texture(tree, "BACKGROUND")
	tree.LegacyTreeTraitPanel = B.frame("Frame", tree)
	tree.LegacyTreeTraitPanel.ApplyButton = B.frame("Button", tree.LegacyTreeTraitPanel)
	B.texture(tree.LegacyTreeTraitPanel.ApplyButton)
	tree.LegacyTreePointSummary = B.frame("Frame", tree)
	tree.LegacyTreePointSummary.Border = B.texture(tree.LegacyTreePointSummary)
	tree.LegacyTreePointSummary.AvailablePointsLabel = B.text(tree.LegacyTreePointSummary)
	p.frame = f
	return p
end

do
	local B, p, snap
	local env, K, ns = S.New({ before = function() end })
	local Style = ns.Style
	assert(K.Options.Row("Skins", "legacy.enabled") and K.Options.Row("Skins", "legacy.pageArt"), "the Legacy window has a switch and a page art setting")
	K.Modules.Enable("Skins")
	assert(S.Logged(env, "legacy: waits for Blizzard_LegacySystem to load"), "nothing loads the on-demand addon for KstyleUI")
	B = S.Blizzard(env)
	p = Legacy(env, B)
	snap = B.snapshot()
	S.LoadAddOn(env, "Blizzard_LegacySystem")
	assert(not ns.Skins.IsApplied("legacy"))
	S.Show(p.frame)
	assert(ns.Skins.IsApplied("legacy"), "the first show skins the window")
	local f = p.frame
	assert(K.Skin.IsSkinned(f, "Window") and Alpha(f.Bg) == 0 and Alpha(p.portrait) == 0, "a glass panel replaces the window art")
	assert(FontPath(f.TitleContainer.TitleText) == Style.Font("heading"))
	assert(not K.Skin.IsSkinned(f.Tabs[1], "Tab"), "side tabs are not given bottom-tab underlines")
	assert(ns.Parts.RimOf(f.Tabs[1]).rim[1]:IsShown(), "the selected page's tab wears an accent rim")
	assert(Alpha(f.Tabs[2].Background) == 0 and Alpha(f.Tabs[2].Icon) == 1, "a side tab keeps its icon")
	f.Tabs[1]:SetChecked(false)
	f.Tabs[2]:SetChecked(true)
	assert(ns.Parts.RimOf(f.Tabs[2]).rim[1]:IsShown() and not ns.Parts.RimOf(f.Tabs[1]).rim[1]:IsShown(), "the rim follows the page")
	assert(Alpha(f.RewardTrackPage.Background) == 0 and Alpha(f.ChallengesPage.Background) == 0 and Alpha(f.TreePage.Background) == 0, "page art is hidden by default")
	K.Options.Write("Skins", "legacy.pageArt", true)
	assert(Alpha(f.TreePage.Background) == 1, "the page art setting brings it back at once")
	K.Options.Write("Skins", "legacy.pageArt", false)
	assert(Alpha(f.TreePage.Background) == 0)

	local bar = f.RewardTrackPage.LegacyRewardProgressBar
	assert(Alpha(bar.ProgressBarFrame) == 0 and Alpha(bar:GetStatusBarTexture()) == 1, "a progress bar keeps only its fill")
	assert(Alpha(f.RewardTrackPage.ProgressBarBackground) == 0, "and loses its background art")
	assert(W.LastCall(bar, "SetStatusBarTexture")[1] == Style.BarTexture(), "it takes the bar texture")
	local track = ns.PartC.Bar(bar)
	assert(track and track.owner == bar, "its dark track is drawn on the bar itself, so page art at the bar's frame level cannot cover it")
	local piece = track.fill[5]
	assert(piece:GetDrawLayer() == "BACKGROUND" and Alpha(piece) == 1, "under the fill")
	S.Show(bar)
	assert(Alpha(piece) == 1 and Alpha(bar.ProgressBarFrame) == 0, "showing the bar again keeps the track and keeps Blizzard's frame hidden")
	assert(FontPath(bar.Text) == Style.Font("number"))
	assert(ns.PartC.Bar(f.ChallengesPage.LegacyChallengePointSummary.PointsBar).owner, "the challenge points bar too")
	assert(FontPath(f.RewardTrackPage.Points) == Style.Font("display") and FontPath(f.RewardTrackPage.PointsLabel) == Style.Font("caption"))

	local list = f.ChallengesPage.CategoryList
	assert(K.Skin.IsSkinned(list.FilterDropdown, "Backdrop") and K.Skin.IsSkinned(list.SearchBox, "EditBox") and Alpha(p.searchArt) == 0, "the filter and search are restyled")
	assert(K.Skin.IsSkinned(list.ScrollBar, "ScrollBar") and K.Skin.IsSkinned(f.ChallengesPage.DetailPane.ScrollBar, "ScrollBar"))
	assert(Alpha(p.challengeDivider) == 0, "the page divider goes")
	local tree = f.TreePage
	assert(K.Skin.IsSkinned(tree.LegacyTreeTraitPanel.ApplyButton, "Button") and Alpha(tree.LegacyTreePointSummary.Border) == 0, "the tree's apply button and points bar are restyled")
	assert(S.Logged(env, "TreePage.LegacyTreeTraitPanel.SearchBox is missing"), "a missing part is logged")
	B.check(snap, HOOKED)
	assert(#env._errors == 0, tostring(env._errors[1]))
end

print("skins part C legacy ok")
