-- test-skins-character.lua: the character sheet skin restyles Forever's character window, its tabs, quality-rimmed slots, stats, reputation and currency without touching Blizzard's frames.
local S = dofile("Tools/regression/skins_env.lua")
local W = S.W

local HOOKED = { UpdateRightPaneToggleButton = true }

-- RepBar(B, parent) -> a stand-in ColoredProgressBarTemplate: a frame with a background, a masked Fill and a Text.
local function RepBar(B, parent)
	local bar = B.frame("Frame", parent)
	bar.FillArea = B.frame("Frame", bar)
	local background = B.texture(bar, "BACKGROUND")
	bar.Fill = B.texture(bar, "BORDER")
	bar.Mask = B.add(bar:CreateMaskTexture())
	bar.Fill:AddMaskTexture(bar.Mask)
	bar.Text = B.text(bar)
	return bar, background
end

local function Checkbox(B, parent)
	local check = B.frame("CheckButton", parent)
	B.texture(check)
	check.Label = B.text(check)
	return check
end

local function SidePane(B, parent)
	local pane = B.frame("Frame", parent)
	pane.Title, pane.Subtitle, pane.EmptyText = B.text(pane), B.text(pane), B.text(pane)
	pane.Divider = B.texture(pane, "BORDER")
	pane.DescriptionScrollBar = B.frame("Frame", pane)
	return pane
end

-- Character(env, B) -> the stand-in Forever character window, built as Blizzard_UIPanels_Game and Blizzard_TokenUI build it, and its parts.
local function Character(env, B)
	local p = {}
	local f = B.frame("Frame", nil, "CharacterFrame")
	f:Hide()
	f.NineSlice = B.frame("Frame", f)
	B.texture(f.NineSlice)
	f.Bg = B.texture(f, "BACKGROUND")
	f.TitleContainer = B.frame("Frame", f)
	f.TitleContainer.TitleText = B.text(f.TitleContainer)
	f.PortraitContainer = B.frame("Frame", f)
	f.PortraitContainer.portrait = B.texture(f.PortraitContainer)
	f.CloseButton = B.frame("Button", f)
	B.texture(f.CloseButton)
	f.LeftPaneHost = B.frame("Frame", f)
	p.leftArt = B.texture(f.LeftPaneHost, "BACKGROUND")
	f.RightPaneHost = B.frame("Frame", f)
	f.RightPaneHost.StoneBg = B.texture(f.RightPaneHost)
	p.divider = B.texture(B.frame("Frame", f.RightPaneHost), "OVERLAY")
	f.ModeTabs = B.frame("Frame", f)
	f.ModeTabs.Tabs = {}
	for i = 1, 3 do
		local tab = B.frame("Frame", f.ModeTabs)
		tab.Background = B.texture(tab, "BACKGROUND")
		tab.Icon = B.texture(tab)
		tab.SelectedTexture = B.texture(tab, "OVERLAY")
		tab.HighlightTexture = B.texture(tab, "HIGHLIGHT")
		function tab.SetChecked(self, checked)
			self.SelectedTexture:SetShown(checked)
		end
		f.ModeTabs.Tabs[i] = tab
		tab:SetChecked(i == 1)
	end
	local toggle = B.frame("Button", f)
	f.RightPaneToggleButton = toggle
	p.toggleArt = B.texture(toggle)
	p.collapsed = false
	function f.IsRightPaneCollapsed()
		return p.collapsed
	end
	function f.UpdateRightPaneToggleButton() end
	function f.UpdateTabLayout() end

	p.qualities = {}
	env.GetInventoryItemQuality = function(unit, id)
		assert(unit == "player")
		return p.qualities[id]
	end
	env.PaperDollItemSlotButton_Update = function() end
	p.slots = {}
	for name, id in pairs({ CharacterHeadSlot = 1, CharacterMainHandSlot = 16, CharacterAmmoSlot = 0 }) do
		local slot = B.frame("Button", f, name)
		slot:SetID(id)
		slot.icon = B.texture(slot, "BORDER")
		slot.IconBorder = B.texture(slot, "OVERLAY")
		slot.NormalTexture = B.texture(slot)
		slot.BorderFrame = B.frame("Frame", slot)
		B.texture(slot.BorderFrame, "BACKGROUND")
		p.slots[name] = slot
	end

	local doll = B.frame("Frame", f, "PaperDollFrame")
	doll.TopBackgroundStripHost = B.frame("Frame", doll)
	p.strip = B.texture(doll.TopBackgroundStripHost)
	p.modelArt = B.texture(B.frame("Frame", doll, "CharacterModelScene"), "BACKGROUND")
	env.CharacterLevelText = B.text(doll)
	for i = 1, 2 do
		local tab = B.frame("CheckButton", f, "PaperDollSidebarTab" .. i)
		tab.Icon = B.texture(tab, "BACKGROUND")
		B.texture(tab, "BORDER")
	end

	local stats = B.frame("Frame", f, "CharacterStatsPaneScrollBox")
	stats.Border = B.texture(stats, "BORDER")
	stats.ScrollBox = S.ScrollBox(B, stats)
	stats.ScrollBar = B.frame("Frame", stats)
	local header = B.frame("Frame", stats.ScrollBox.ScrollTarget)
	header.Background = B.texture(header, "BACKGROUND")
	header.Title = B.text(header)
	stats.ScrollBox.AddRow(header, { isHeader = true })
	local stat = B.frame("Frame", stats.ScrollBox.ScrollTarget)
	stat.Background = B.texture(stat, "BACKGROUND")
	stat.Icon = B.texture(stat)
	stat.Label, stat.Value = B.text(stat), B.text(stat)
	stats.ScrollBox.AddRow(stat, {})
	p.header, p.stat = header, stat
	local late = B.frame("Frame", stats.ScrollBox.ScrollTarget)
	late.Background = B.texture(late, "BACKGROUND")
	late.Label, late.Value = B.text(late), B.text(late)
	p.lateStat = late

	local rep = B.frame("Frame", f, "ReputationFrame")
	local drop = B.frame("Button", rep)
	rep.filterDropdown = drop
	drop.Background, drop.Arrow, drop.Text = B.texture(drop, "BACKGROUND"), B.texture(drop), B.text(drop)
	rep.ScrollBox = S.ScrollBox(B, rep)
	rep.ScrollBar = B.frame("Frame", rep)
	p.scrollLine = B.texture(B.frame("Frame", rep.ScrollBox), "OVERLAY")
	local repHeader = B.frame("Button", rep.ScrollBox.ScrollTarget)
	p.repHeaderArt = B.texture(repHeader, "BACKGROUND")
	repHeader.StateIcon = B.texture(repHeader, "BORDER")
	repHeader.Name = B.text(repHeader)
	rep.ScrollBox.AddRow(repHeader, { isHeader = true })
	local entry = B.frame("Button", rep.ScrollBox.ScrollTarget)
	entry.Content = B.frame("Frame", entry)
	entry.Content.ReputationBar, p.entryBarArt = RepBar(B, entry.Content)
	entry.Content.Name = B.text(entry.Content)
	entry.Content.BackgroundHighlight = B.frame("Frame", entry.Content)
	p.washArt = B.texture(entry.Content.BackgroundHighlight, "BACKGROUND")
	rep.ScrollBox.AddRow(entry, {})
	p.entry, p.repHeader = entry, repHeader
	local detail = SidePane(B, rep)
	rep.ReputationDetailFrame = detail
	detail.StandingBar = RepBar(B, detail)
	detail.AtWarCheckbox = Checkbox(B, detail)
	detail.ViewRenownButton = B.frame("Button", detail)
	B.texture(detail.ViewRenownButton)

	local token = B.frame("Frame", f, "TokenFrame")
	token.ScrollBox = S.ScrollBox(B, token)
	token.ScrollBar = B.frame("Frame", token)
	local currency = B.frame("Button", token.ScrollBox.ScrollTarget)
	currency.Content = B.frame("Frame", currency)
	currency.Content.CurrencyIcon = B.texture(currency.Content)
	currency.Content.Name, currency.Content.Count = B.text(currency.Content), B.text(currency.Content)
	currency.Content.BackgroundHighlight = B.frame("Frame", currency.Content)
	B.texture(currency.Content.BackgroundHighlight, "BACKGROUND")
	token.ScrollBox.AddRow(currency, {})
	token.DetailFrame = SidePane(B, token)
	token.DetailFrame.InactiveCheckbox = Checkbox(B, token.DetailFrame)
	p.currency = currency
	p.frame, p.rep, p.token, p.stats = f, rep, token, stats
	return p
end

local function Alpha(region)
	return region:GetAlpha()
end

local function FontPath(text)
	return (text:GetFont())
end

local function RimColor(ns, frame)
	local rim = ns.Parts.RimOf(frame)
	assert(rim, "the frame has a KstyleUI rim")
	if not rim.rim[1]:IsShown() then
		return nil
	end
	return rim.rim[1]:GetVertexColor()
end

-- The whole window, as Forever builds it ------------------------------------------------------------

do
	local p, B, snap
	local env, K, ns = S.New({
		setup = S.UseScrollUtil,
		before = function(env)
			B = S.Blizzard(env)
			p = Character(env, B)
			snap = B.snapshot()
		end,
	})
	local Style = ns.Style
	assert(K.Options.Row("Skins", "character.enabled"), "the character sheet has a switch")
	assert(K.Options.Row("Skins", "character.qualityBorders") and K.Options.Row("Skins", "character.qualityFrom"), "and its quality border settings")
	K.Modules.Enable("Skins")
	assert(not ns.Skins.IsApplied("character"), "nothing happens before the window opens")
	S.Show(p.frame)
	assert(ns.Skins.IsApplied("character"), "the first show skins the window")
	assert(S.Logged(env, "character: applied"))
	local f = p.frame

	assert(K.Skin.IsSkinned(f, "Window"), "a KstyleUI glass panel behind the window")
	assert(Alpha(f.Bg) == 0 and Alpha(p.leftArt) == 0 and Alpha(f.RightPaneHost.StoneBg) == 0 and Alpha(p.divider) == 0, "Blizzard's pane art is stripped")
	assert(FontPath(f.TitleContainer.TitleText) == Style.Font("heading"), "the title wears the skin font")
	assert(Alpha(p.toggleArt) == 0, "the pane toggle's art is stripped")

	assert(RimColor(ns, f.ModeTabs.Tabs[1]) ~= nil, "the tab Blizzard had selected before the skin keeps its selection")
	local tab = f.ModeTabs.Tabs[2]
	assert(Alpha(tab.Background) == 0 and Alpha(tab.SelectedTexture) == 0 and Alpha(tab.HighlightTexture) == 0, "side tab art is stripped")
	assert(Alpha(tab.Icon) > 0 and Alpha(tab.Icon) < 1, "an unchosen side tab keeps its icon, quiet")
	tab:SetChecked(true)
	local ar, ag, ab = Style.Accent()
	local r, g, b = RimColor(ns, tab)
	assert(W.Near(r, ar) and W.Near(g, ag) and W.Near(b, ab), "the selected side tab wears an accent rim")
	assert(Alpha(tab.Icon) == 1, "and its icon at full")
	tab:SetChecked(false)
	assert(RimColor(ns, tab) == nil, "an unselected side tab has no rim")
	-- The mode tabs stand on one glass rail docked to the window's right edge: a clip frame starts at that edge
	-- and spans the shown tabs, and the rail inside it runs on under the window, so the clip cuts its left
	-- corners away and the rail reads as the window's own tab column, not a second panel beside it.
	local rail = ns.CharacterRail(f)
	assert(rail and K.Skin.IsSkinned(rail, "Backdrop"), "the mode tabs get a glass rail")
	local clip = rail.clip
	assert(clip and rail:GetParent() == clip and clip:GetParent() == f.ModeTabs, "inside a clip under the tabs' own frame")
	assert(clip:GetFrameLevel() < f.ModeTabs.Tabs[1]:GetFrameLevel(), "behind the tabs")
	assert(W.LastCall(clip, "SetClipsChildren")[1] == true, "the clip clips")
	assert(K.Skin.Parts(rail).backdrop.chrome.shadowOn ~= true, "the rail casts no shadow onto the window")
	local function Anchors(frame)
		local out = {}
		for _, point in ipairs(frame._points) do
			out[point[1]] = point[2]
		end
		return out
	end
	local anchors = Anchors(clip)
	assert(anchors.LEFT == f, "the clip starts at the window")
	assert(anchors.TOP == f.ModeTabs.Tabs[1] and anchors.BOTTOM == f.ModeTabs.Tabs[3] and anchors.RIGHT == f.ModeTabs.Tabs[3], "and spans the first shown tab to the last")
	local railPoints = Anchors(rail)
	assert(railPoints.TOPLEFT == clip and rail._points[1][4] < 0, "the rail hangs off the clip's left, under the window")
	f.ModeTabs.Tabs[3]:SetShown(false)
	f:UpdateTabLayout()
	anchors = Anchors(clip)
	assert(anchors.BOTTOM == f.ModeTabs.Tabs[2], "a hidden tab shortens the rail")
	f.ModeTabs.Tabs[3]:SetShown(true)
	f:UpdateTabLayout()
	assert(Anchors(clip).BOTTOM == f.ModeTabs.Tabs[3], "and a shown one lengthens it again")
	local sidebar = env.PaperDollSidebarTab1
	sidebar:SetChecked(true)
	assert(RimColor(ns, sidebar) ~= nil and Alpha(sidebar.Icon) == 1, "the paper doll's sidebar tabs follow their check state")

	local head, hand = p.slots.CharacterHeadSlot, p.slots.CharacterMainHandSlot
	assert(Alpha(head.icon) == 1, "the slot keeps its icon")
	assert(Alpha(head.IconBorder) == 0 and Alpha(head.NormalTexture) == 0, "Blizzard's slot frame and quality border are stripped")
	p.qualities[1], p.qualities[16] = 4, 1
	env.PaperDollItemSlotButton_Update(head)
	env.PaperDollItemSlotButton_Update(hand)
	local qr, qg, qb = K.Theme.QualityColor(4)
	r, g, b = RimColor(ns, head)
	assert(W.Near(r, qr) and W.Near(g, qg) and W.Near(b, qb), "an epic item gets the epic rim")
	assert(RimColor(ns, hand) == nil, "a common item stays plain by default")
	K.Options.Write("Skins", "character.qualityFrom", 1)
	assert(RimColor(ns, hand) ~= nil, "lowering the threshold rims common items at once")
	K.Options.Write("Skins", "character.qualityBorders", false)
	assert(RimColor(ns, head) == nil, "switching quality borders off clears every rim")
	K.Options.Write("Skins", "character.qualityBorders", true)
	assert(RimColor(ns, head) ~= nil)
	assert(S.Logged(env, "CharacterNeckSlot is missing"), "a slot this client lacks is logged and skipped")

	assert(Alpha(p.strip) == 0 and Alpha(p.modelArt) == 0, "the paper doll's backdrop art is stripped")
	assert(FontPath(env.CharacterLevelText) == Style.Font("caption"))

	assert(Alpha(p.stats.Border) == 0 and K.Skin.IsSkinned(p.stats.ScrollBar, "ScrollBar"), "the stats pane's frame art goes and its scroll bar is restyled")
	assert(Alpha(p.header.Background) == 0 and FontPath(p.header.Title) == Style.Font("caption"), "a stat category reads as a caption")
	assert(Alpha(p.stat.Background) == 0 and Alpha(p.stat.Icon) == 1, "a stat row keeps its icon")
	assert(FontPath(p.stat.Value) == Style.Font("number"), "stat values use the number font")
	local late = p.lateStat
	p.stats.ScrollBox.Init(late, {})
	assert(Alpha(late.Background) == 0 and FontPath(late.Label) == Style.Font("body"), "a row the list shows later is skinned too")

	local rep = p.rep
	assert(K.Skin.IsSkinned(rep.filterDropdown, "Backdrop") and Alpha(rep.filterDropdown.Background) == 0, "the filter dropdown wears a raised tile")
	assert(Alpha(rep.filterDropdown.Arrow) == 1, "and keeps its arrow")
	assert(Alpha(p.scrollLine) == 0, "the list's scroll lines are stripped")
	assert(Alpha(p.repHeaderArt) == 0 and Alpha(p.repHeader.StateIcon) == 1, "a header keeps its expand icon")
	local bar = p.entry.Content.ReputationBar
	assert(Alpha(p.entryBarArt) == 0 and Alpha(bar.Fill) == 1, "a reputation bar keeps only its fill")
	assert(bar.Fill:GetNumMaskTextures() == 0, "the fill loses Blizzard's rounded mask")
	assert(W.LastCall(bar.Fill, "SetTexture")[1] == Style.BarTexture(), "the fill uses the bar texture")
	bar.Fill:SetVertexColor(0, 0, 0.1)
	local er, eg, eb = K.Theme.Brighten(0, 0, 0.1)
	r, g, b = bar.Fill:GetVertexColor()
	assert(W.Near(r, er) and W.Near(g, eg) and W.Near(b, eb), "Blizzard's standing colour is lifted for the glass")
	K.Options.Write("Skins", "bars.fill", "right")
	assert(bar.Fill._points[1][1] == "RIGHT", "the fill direction setting re-anchors the fill")
	assert(Alpha(p.washArt) == 0, "the row highlight's Blizzard art is stripped")
	local detail = rep.ReputationDetailFrame
	assert(Alpha(detail.Divider) == 0 and K.Skin.IsSkinned(detail.AtWarCheckbox, "CheckBox"), "the detail pane's divider and checkboxes are restyled")
	assert(K.Skin.IsSkinned(detail.ViewRenownButton, "Button"))

	local token = p.token
	assert(K.Skin.IsSkinned(token.ScrollBar, "ScrollBar"), "the currency list's scroll bar is restyled")
	assert(Alpha(p.currency.Content.CurrencyIcon) == 1 and FontPath(p.currency.Content.Name) == Style.Font("body"), "a currency row keeps its icon")
	assert(K.Skin.IsSkinned(token.DetailFrame.InactiveCheckbox, "CheckBox"))

	B.check(snap, HOOKED)
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- A client missing parts of the window still gets the rest, and says what it skipped ------------------

do
	local env, K, ns = S.New({
		before = function(env)
			local B = S.Blizzard(env)
			local f = B.frame("Frame", nil, "CharacterFrame")
			f.Bg = B.texture(f, "BACKGROUND")
		end,
	})
	K.Modules.Enable("Skins")
	assert(ns.Skins.IsApplied("character"), "an open window is skinned at once")
	assert(K.Skin.IsSkinned(env.CharacterFrame, "Window"))
	assert(S.Logged(env, "ReputationFrame is missing") and S.Logged(env, "TokenFrame is missing"), "missing tabs are logged")
	assert(#env._errors == 0, tostring(env._errors[1]))
end

print("skins character ok")
