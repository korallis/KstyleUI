-- test-skins-tracker.lua: the objective tracker skin keeps the skin font, with the interface's fallback, on every tracker text, draws one caption header with accent discs and accent titles over Blizzard's blocks, and its glass panel follows the tracker's content.
local S = dofile("Tools/regression/skins_env.lua")
local Near = S.W.Near

local HOOKED = {
	GetProgressBar = true, GetTimerBar = true, AddModule = true, SetFontObject = true, UpdateHeaderPosition = true,
	SetCollapsed = true, SetHeader = true, UpdateHighlight = true, EndLayout = true, SetText = true,
}
local BLIZZARD_FACE, FALLBACK_FACE = "Fonts\\FRIZQT__.TTF", "Fonts\\ARIALN.TTF"
local BLIZZARD_GOLD = { r = 1, g = 0.82, b = 0 }
local THIN_SPACE = "\226\128\137"

local function FontPath(text)
	return (text:GetFont())
end

-- Plain(text) -> the font string's text without the thin spaces the caption role tracks letters with.
local function Plain(text)
	return (tostring(text:GetText()):gsub(THIN_SPACE, ""))
end

-- Unloadable(object) makes object refuse every KstyleUI face, as the game does with a font file it cannot load.
local function Unloadable(object)
	local set = object.SetFont
	object.SetFont = function(self, path, ...)
		if type(path) == "string" and path:find("KstyleUI", 1, true) then
			return false
		end
		set(self, path, ...)
		return true
	end
end

-- Holder(B, parent, labelOnBar) -> a stand-in progress bar (label on its Bar) or timer bar (label on the holder).
local function Holder(B, parent, labelOnBar)
	local holder = B.frame("Frame", parent)
	local bar = B.frame("StatusBar", holder)
	holder.Bar = bar
	bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	bar.BorderLeft, bar.BorderRight, bar.BorderMid = B.texture(bar), B.texture(bar), B.texture(bar)
	local owner = labelOnBar and bar or holder
	owner.Label = B.text(owner)
	return holder
end

-- Collapsible(B, header) gives a header Blizzard's minimise button, whose art SetCollapsed swaps.
local function Collapsible(B, header)
	header.MinimizeButton = B.frame("Button", header)
	header.MinimizeButton.Art = B.texture(header.MinimizeButton)
	function header.SetCollapsed() end
end

-- Children(env, parent) -> the KstyleUI frames made on parent, oldest first.
local function Children(env, parent)
	local out = {}
	for _, frame in ipairs(env._frames) do
		if frame:GetParent() == parent then
			out[#out + 1] = frame
		end
	end
	return out
end

-- Region(env, K, parent, kind, textureName) -> the first region of kind on a KstyleUI child frame of parent; a
-- texture must show textureName.
local function Region(env, K, parent, kind, textureName)
	for _, frame in ipairs(Children(env, parent)) do
		for _, region in ipairs({ frame:GetRegions() }) do
			if region:GetObjectType() == kind and (not textureName or region:GetTexture() == (K.Tokens.Texture(textureName))) then
				return region, frame
			end
		end
	end
end

-- Caption(env, header, text) -> the KstyleUI font string reading text on a child frame of header, and its frame.
local function Caption(env, header, text)
	for _, frame in ipairs(Children(env, header)) do
		for _, region in ipairs({ frame:GetRegions() }) do
			if region:GetObjectType() == "FontString" and Plain(region) == text then
				return region, frame
			end
		end
	end
end

-- Chevron(env, K, button) -> the KstyleUI chevron drawn on a child frame of button.
local function Chevron(env, K, button)
	return (Region(env, K, button, "Texture", "glyphChevron"))
end

-- POIButton(B, block) -> a stand-in ObjectiveTrackerPOIButtonTemplate hung off the block's title as
-- Blizzard_ObjectiveTrackerQuestPOIBlock.lua does: the 20-unit button's right edge 7 left of the title, its
-- 32-unit art centred on it (Blizzard_POIButton/POIButton.xml), and the Display frame's icon over it.
local function POIButton(B, block)
	local button = B.frame("Button", block)
	button:SetSize(20, 20)
	button:SetPoint("TOPRIGHT", block.HeaderText, "TOPLEFT", -7, 5)
	for _, key in ipairs({ "NormalTexture", "PushedTexture", "HighlightTexture", "Glow" }) do
		button[key] = B.texture(button)
		button[key]:SetPoint("CENTER")
	end
	button.Display = B.frame("Frame", button)
	button.Display.Icon = B.texture(button.Display)
	button.selected = false
	function button.IsSelected(self)
		return self.selected
	end
	return button
end

-- Block(B, module, title, quest) -> a stand-in ObjectiveTrackerQuestPOIBlockTemplate: the title font string Blizzard
-- colours in SetHeader and UpdateHighlight (Blizzard_ObjectiveTrackerBlock.lua), and a POI button when quest is set.
local function Block(B, module, title, quest)
	local block = B.frame("Frame", module)
	block.HeaderText = B.text(block)
	block.HeaderText:SetPoint("TOPLEFT")
	block.title = title
	block.isHighlighted = false
	block.poiQuestID = quest
	block.poiIsComplete = false
	function block.SetHeader(self, text)
		self.HeaderText:SetText(text)
		self.HeaderText:SetTextColor(BLIZZARD_GOLD.r, BLIZZARD_GOLD.g, BLIZZARD_GOLD.b)
		self.HeaderText.colorStyle = BLIZZARD_GOLD
	end
	function block.UpdateHighlight(self)
		local c = self.isHighlighted and { r = 1, g = 1, b = 1 } or BLIZZARD_GOLD
		self.HeaderText:SetTextColor(c.r, c.g, c.b)
		self.HeaderText.colorStyle = c
	end
	if quest then
		block.poiButton = POIButton(B, block)
	end
	block.nextBlock = false
	return block
end

-- Tracker(env, B, unloadable) -> a stand-in ObjectiveTrackerFrame that lays out as Blizzard's container does:
-- each layout re-anchors NineSlice's bottom to the last module with content, hides the frame when nothing is
-- tracked, and ends with self:UpdateHeaderPosition(). Each module lays its blocks out in the order of its
-- blocks list, chaining firstBlock and nextBlock, calls SetHeader on each block and ends with EndLayout, as
-- Blizzard_ObjectiveTrackerModule.lua does. p.layout is the Update captured before any hook, which a dirty
-- update runs, as DirtiableMixin does. Edit Mode, not the content, sizes the frame.
local function Tracker(env, B, unloadable)
	local p = { modules = {} }
	local tracker = B.frame("Frame", nil, "ObjectiveTrackerFrame")
	tracker.isCollapsed = false
	tracker.NineSlice = B.frame("Frame", tracker)
	tracker.Header = B.frame("Frame", tracker)
	tracker.Header.Background, tracker.Header.Text = B.texture(tracker.Header, "BACKGROUND"), B.text(tracker.Header)
	tracker.Header.Text:SetText("All Objectives")
	Collapsible(B, tracker.Header)
	for i, def in ipairs({
		{ height = 120, name = "Quests", quests = { { "Riverglade Crocolisks", 101 }, { "The Lost Patrol", 102 } } },
		{ height = 60, name = "Achievements", quests = { { "Explore Riverglades" } } },
	}) do
		local module = B.frame("Frame", tracker)
		module.contentsHeight = def.height
		module.Header = B.frame("Frame", module)
		module.Header.Background, module.Header.Text = B.texture(module.Header, "BACKGROUND"), B.text(module.Header)
		module.Header.Text:SetText(def.name)
		Collapsible(B, module.Header)
		module.usedProgressBars, module.usedTimerBars = {}, {}
		module.blocks = {}
		for _, quest in ipairs(def.quests) do
			module.blocks[#module.blocks + 1] = Block(B, module, quest[1], quest[2])
		end
		module.firstBlock = nil
		local progress, timer = Holder(B, module, true), Holder(B, module, false)
		function module.GetContentsHeight(self)
			return self.contentsHeight
		end
		function module.GetProgressBar(self, key)
			self.usedProgressBars[key] = progress
			return progress
		end
		function module.GetTimerBar(self, key)
			self.usedTimerBars[key] = timer
			return timer
		end
		function module.SetHeader(self, text)
			self.Header.Text:SetText(text)
		end
		function module.EndLayout() end
		function module.Update(self)
			local last
			self.firstBlock = nil
			for _, block in ipairs(self.blocks) do
				block.nextBlock = false
				block:SetHeader(block.title)
				if last then
					last.nextBlock = block
				else
					self.firstBlock = block
				end
				last = block
			end
			self:EndLayout()
		end
		p.modules[i] = module
	end
	function tracker.ForEachModule(self, fn)
		for _, module in ipairs(p.modules) do
			fn(module)
		end
	end
	function tracker.IsCollapsed(self)
		return self.isCollapsed
	end
	function tracker.UpdateHeaderPosition() end
	function tracker.Update(self)
		local last
		for _, module in ipairs(p.modules) do
			module:Update()
			last = module:GetContentsHeight() > 0 and module or last
		end
		if last then
			self.NineSlice:SetPoint("BOTTOM", last, "BOTTOM", 0, -10)
		end
		self._shown = last ~= nil
		self:UpdateHeaderPosition()
	end
	function tracker.SetCollapsed(self, collapsed)
		self.isCollapsed = collapsed
		self:Update()
	end
	p.layout = tracker.Update
	p.layout(tracker)

	env.GameFontHighlight = B.text(env.UIParent)
	env.GameFontHighlight:SetFont(FALLBACK_FACE, 12, "")
	env.ObjectiveTrackerLineFont, env.ObjectiveTrackerHeaderFont = B.text(env.UIParent), B.text(env.UIParent)
	env.ObjectiveTrackerLineFont:SetFont(BLIZZARD_FACE, 12, "")
	env.ObjectiveTrackerHeaderFont:SetFont(BLIZZARD_FACE, 14, "")
	if unloadable then
		for _, object in ipairs({ env.ObjectiveTrackerLineFont, env.ObjectiveTrackerHeaderFont, tracker.Header.Text, p.modules[1].Header.Text }) do
			Unloadable(object)
		end
	end
	p.tracker = tracker
	return p
end

-- Edge(frame, side, blizzard) -> the Blizzard object and point that frame's TOP, BOTTOM, LEFT or RIGHT edge
-- hangs from, following anchors through KstyleUI's own frames, and the x and y offsets summed along the way.
-- blizzard is keyed by Blizzard objects, as B.snapshot() is.
local function Edge(frame, side, blizzard)
	for i = 1, frame:GetNumPoints() do
		local point, relative, relativePoint, x, y = frame:GetPoint(i)
		if point:find(side, 1, true) then
			x, y = x or 0, y or 0
			if blizzard[relative] then
				return relative, relativePoint, x, y
			end
			local object, objectPoint, dx, dy = Edge(relative, side, blizzard)
			return object, objectPoint, x + (dx or 0), y + (dy or 0)
		end
	end
end

-- The mockup at 1.348 px per unit: quest titles start 39 units from the panel's left edge, the discs 8 inside
-- it, and Blizzard puts titles blockOffsetX = 20 in from the tracker with the POI button's centre 17 left of them
-- (Blizzard_ObjectiveTrackerModule.lua, Blizzard_ObjectiveTrackerQuestPOIBlock.lua), so the panel starts 16 units
-- left of the tracker. Its top rises 4 units above the first shown module's header, whose text row the caption
-- takes, so the caption's centre sits 17 below the panel's top and the rule 30; its bottom hangs 8 below
-- Blizzard's NineSlice, which already hangs 10 below the content. The find-group button
-- (questFindGroupButtonSettings.offsetX = 5) reaches 5 right of the tracker.
local PANEL_LEFT, PANEL_TOP, PANEL_BOTTOM = 16, 4, 8
local FIND_GROUP_REACH = 5
local DISC_UNITS, CAPTION_SIZE = 18, 12.5

-- The glass panel hugs the tracker's content through every Blizzard layout -------------------------------

do
	local B, snap, p
	local env, K, ns = S.New({
		before = function(env)
			B = S.Blizzard(env)
			p = Tracker(env, B)
			snap = B.snapshot()
		end,
	})
	local Style = ns.Style
	K.Modules.Enable("Skins")
	S.LoadAddOn(env, "Blizzard_ObjectiveTracker")
	assert(ns.Skins.IsApplied("tracker"), "the shown tracker is skinned once its addon has loaded")
	local tracker = p.tracker
	local quests = p.modules[1]
	local panel = K.Skin.Parts(tracker).backdrop
	assert(panel and panel:IsShown(), "a glass panel sits behind the tracker")
	assert(panel.chrome.shapeName == "window", "window-grade glass: the mockup cuts the tracker's corners 12 units")
	local function Top()
		return Edge(panel, "TOP", snap)
	end
	local function Bottom()
		return Edge(panel, "BOTTOM", snap)
	end
	local function Snap(units)
		return K.Widgets.Snap(panel, units)
	end
	local top, topPoint, _, topY = Top()
	assert(top == quests.Header and topPoint:find("TOP", 1, true), "the panel starts at the first shown module's header, the row the caption takes, not at the tracker's own header")
	assert(Near(topY, Snap(PANEL_TOP)), "the panel's top rises " .. PANEL_TOP .. " above that header's top, got " .. tostring(topY))
	local bottom, bottomPoint, _, bottomY = Bottom()
	assert(bottom == tracker.NineSlice and bottomPoint == "BOTTOM", "with quests tracked, the panel ends where Blizzard's content ends, not at the tracker's Edit Mode height: " .. tostring(bottomPoint))
	assert(Near(bottomY, -Snap(PANEL_BOTTOM)), "the panel ends " .. PANEL_BOTTOM .. " below Blizzard's content, got " .. tostring(bottomY))
	local pad, pixel = Snap(K.Tokens.Size("panelPadding")), K.Scale.Pixel()
	local function Sides()
		local left, leftPoint, leftX = Edge(panel, "LEFT", snap)
		local right, rightPoint, rightX = Edge(panel, "RIGHT", snap)
		assert(left == tracker and leftPoint:find("LEFT", 1, true), "the panel's left edge hangs from the tracker's left")
		assert(right == tracker and rightPoint:find("RIGHT", 1, true), "the panel's right edge hangs from the tracker's right")
		return leftX, rightX
	end
	local leftX, rightX = Sides()
	assert(Near(leftX, -Snap(PANEL_LEFT), pixel), "the panel starts " .. PANEL_LEFT .. " left of the tracker, so titles sit 36 from its edge and the POI discs 10 inside it, got " .. tostring(leftX))
	assert(Near(rightX, pad, pixel), "the panel gives the quest text the design's padding on the right, got " .. tostring(rightX))
	assert(rightX >= FIND_GROUP_REACH, "the find-group button sits inside the panel")

	for _, header in ipairs({ tracker.Header, quests.Header }) do
		local chevron = Chevron(env, K, header.MinimizeButton)
		assert(header.MinimizeButton.Art:GetAlpha() == 0 and chevron, "Blizzard's red and yellow collapse buttons become KstyleUI chevrons")
		header:SetCollapsed(true)
		assert(S.W.LastCall(chevron, "SetTexCoord")[3] == 0, "collapsed, the chevron points down to open")
		header:SetCollapsed(false)
		assert(S.W.LastCall(chevron, "SetTexCoord")[3] == 1, "open, it points up to collapse")
	end
	tracker:SetCollapsed(true)
	assert(Top() == tracker, "collapsed, the panel starts at the tracker's top")
	assert(Bottom() == tracker.Header, "collapsed, the panel wraps the header only")
	tracker:SetCollapsed(false)
	assert(Top() == quests.Header and Bottom() == tracker.NineSlice, "expanded again, the panel follows the content")
	local leftAgain, rightAgain = Sides()
	assert(Near(leftAgain, leftX) and Near(rightAgain, rightX), "a relayout keeps the panel's width")
	for _, module in ipairs(p.modules) do
		module.contentsHeight = 0
	end
	p.layout(tracker)
	assert(Top() == tracker and Bottom() == tracker.Header, "with nothing tracked, a dirty layout shrinks the panel to the header")
	p.modules[2].contentsHeight = 40
	p.layout(tracker)
	assert(Top() == p.modules[2].Header, "with only achievements tracked, the panel starts at the achievement module's header")
	assert(Bottom() == tracker.NineSlice, "a quest tracked again grows the panel back with the next layout")
	quests.contentsHeight = 120
	p.layout(tracker)
	assert(Top() == quests.Header, "with quests back, the quest module leads again")

	local module = p.modules[1]
	local timer = module:GetTimerBar("t1")
	assert(FontPath(timer.Label) == Style.Font("caption"), "timer bar labels take the skin font")
	assert(timer.Bar.BorderLeft:GetAlpha() == 0, "timer bars lose their border art")
	assert(timer.Bar:GetStatusBarTexture():GetAlpha() == 1, "timer bars keep their fill")
	local timerChrome = K.Skin.Parts(timer.Bar).backdrop.chrome
	assert(timerChrome.fillName == "surface" and S.W.SameColor(timerChrome.inner[7], K.Tokens.Color("edgeBar")), "timer and progress bars wear the bar grade: the glass surface under the edgeBar line")
	assert(FontPath(module:GetProgressBar("q1").Bar.Label) == Style.Font("caption"), "progress bar labels take the skin font")
	K.Options.Write("Skins", "tracker.panel", false)
	assert(not panel:IsShown(), "the panel switch still hides the panel")
	B.check(snap, HOOKED)
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- One caption header, accent discs and accent titles over Blizzard's blocks ------------------------------

do
	local B, snap, p
	local env, K, ns = S.New({
		loaded = { Blizzard_ObjectiveTracker = true },
		before = function(env)
			B = S.Blizzard(env)
			p = Tracker(env, B)
			snap = B.snapshot()
		end,
	})
	local Style = ns.Style
	K.Modules.Enable("Skins")
	assert(ns.Skins.IsApplied("tracker"))
	local tracker, quests = p.tracker, p.modules[1]
	local ar, ag, ab = Style.Accent()

	-- Blizzard's two headers become one: its "All Objectives" and "Quests" texts are hushed, and a KstyleUI
	-- caption with an accent chevron and a 1-unit rule takes the quest module's header row.
	assert(tracker.Header.Text:GetAlpha() == 0, "Blizzard's All Objectives text is hushed")
	assert(quests.Header.Text:GetAlpha() == 0, "Blizzard's Quests text is hushed; the caption is KstyleUI's")
	tracker.Header.Text:SetAlpha(1)
	assert(tracker.Header.Text:GetAlpha() == 0, "a Blizzard alpha change keeps the text hushed")
	local caption, row = Caption(env, quests.Header, "QUESTS")
	assert(caption, "a KstyleUI caption reads QUESTS, upper case, on the quest module's header")
	assert(caption:GetText():find(THIN_SPACE, 1, true), "the caption's letters are tracked")
	assert(FontPath(caption) == Style.Font("caption") and Near((select(2, caption:GetFont())), CAPTION_SIZE), "in the caption face at the mockup's size, got " .. tostring((select(2, caption:GetFont()))))
	assert(row:IsShown(), "the quest caption shows while the tracker is expanded")
	local chevron = Region(env, K, quests.Header, "Texture", "glyphChevron")
	assert(chevron and chevron:GetParent() == row, "an accent chevron sits on the caption row")
	assert(S.W.SameRGB(chevron, ar, ag, ab), "in the accent")
	assert(Near(S.W.LastCall(chevron, "SetRotation")[1], -math.pi / 2), "pointing left, as the mockup draws it")
	local chevronPoint = { chevron:GetPoint(1) }
	local captionPoint = { caption:GetPoint(1) }
	assert(chevronPoint[1] == "LEFT" and captionPoint[1] == "LEFT" and captionPoint[4] > chevronPoint[4], "the chevron leads the caption from the left")
	local rule = Region(env, K, quests.Header, "Texture", "divider")
	assert(rule and Near(rule:GetHeight(), K.Widgets.Snap(rule, 1)), "a 1-unit rule closes the header row")
	local allCaption, allRow = Caption(env, tracker.Header, "OBJECTIVES")
	assert(allCaption and not allRow:IsShown(), "the tracker's own header keeps an OBJECTIVES caption for the collapsed tracker, hidden while expanded")
	local allChevron = Chevron(env, K, tracker.Header.MinimizeButton)
	assert(allChevron and not allChevron:IsShown(), "the collapse-all chevron hides with it")
	local allRule = Region(env, K, tracker.Header, "Texture", "divider")
	assert(allRule and not allRule:IsShown(), "and so does its rule, which would otherwise float above the panel")
	tracker:SetCollapsed(true)
	assert(allRow:IsShown() and allChevron:IsShown() and allRule:IsShown(), "collapsed, the OBJECTIVES caption, its chevron and its rule show in the panel")
	tracker:SetCollapsed(false)
	assert(not allRow:IsShown() and not allChevron:IsShown() and not allRule:IsShown(), "expanded again, they hide")
	local right
	for i = 1, caption:GetNumPoints() do
		right = right or (caption:GetPoint(i) == "RIGHT" and { caption:GetPoint(i) })
	end
	assert(right and right[2] == row and right[4] < 0, "the caption ends before the collapse button, so a long scenario name cannot run under it")
	assert(S.W.LastCall(caption, "SetWordWrap")[1] == false, "on one line")
	quests:SetHeader("Tracked quests")
	assert(Plain(caption) == "TRACKED QUESTS", "a header Blizzard renames follows, upper case")
	quests.Header.Text:SetText("The Deadmines")
	assert(Plain(caption) == "THE DEADMINES", "a header Blizzard writes directly, as the scenario module does, follows too")
	assert(quests.Header.Text:GetAlpha() == 0, "and stays hushed")

	-- Each quest's POI button loses Blizzard's 32-unit art and gets a 13-unit accent disc with a dark numeral in
	-- the block's order; the super-tracked quest and the hovered button show a ring.
	local function Disc(button)
		local disc, holder = Region(env, K, button, "Texture", "dot")
		local ring = Region(env, K, button, "Texture", "ringBevel")
		local numeral = Region(env, K, button, "FontString")
		return disc, ring, numeral, holder
	end
	for index, block in ipairs(quests.blocks) do
		local button = block.poiButton
		for _, key in ipairs({ "NormalTexture", "PushedTexture", "HighlightTexture", "Glow" }) do
			assert(button[key]:GetAlpha() == 0, "Blizzard's POI " .. key .. " is hushed")
		end
		assert(button.Display.Icon:GetAlpha() == 0, "Blizzard's POI icon is hushed")
		button.NormalTexture:SetAlpha(1)
		assert(button.NormalTexture:GetAlpha() == 0, "Blizzard's UpdateButtonAlpha cannot bring the art back")
		local disc, ring, numeral, holder = Disc(button)
		assert(disc and ring and numeral and holder:GetParent() == button, "a KstyleUI disc, ring and numeral sit on the POI button")
		assert(Near(disc:GetWidth(), K.Widgets.Snap(disc, DISC_UNITS)) and Near(disc:GetHeight(), disc:GetWidth()), "the disc is " .. DISC_UNITS .. " units, got " .. tostring(disc:GetWidth()))
		assert(S.W.SameRGB(disc, ar, ag, ab), "in the accent")
		assert(Plain(numeral) == tostring(index), "numbered in the block's order, got " .. Plain(numeral))
		assert(FontPath(numeral) == Style.Font("number"), "the numeral uses the number font")
		local nr, ng, nb = numeral:GetTextColor()
		assert(nr + ng + nb < 0.3, "in a dark colour")
		assert(not ring:IsShown(), "no ring while the quest is neither super-tracked nor hovered")
	end
	local first, second = quests.blocks[1], quests.blocks[2]
	quests.blocks[1], quests.blocks[2] = second, first
	p.layout(tracker)
	assert(Plain(select(3, Disc(second.poiButton))) == "1" and Plain(select(3, Disc(first.poiButton))) == "2", "a relayout renumbers the discs in the new order")
	second.poiButton.selected = true
	p.layout(tracker)
	local _, ring = Disc(second.poiButton)
	assert(ring:IsShown(), "the super-tracked quest's disc gets a ring")
	assert(S.W.SameRGB(ring, ar, ag, ab), "in the accent")
	second.poiButton.selected = false
	p.layout(tracker)
	assert(not ring:IsShown(), "cleared when super-tracking moves on")
	first.poiButton:GetScript("OnEnter")(first.poiButton)
	local _, hoverRing = Disc(first.poiButton)
	assert(hoverRing:IsShown(), "hovering a POI button shows its ring")
	first.poiButton:GetScript("OnLeave")(first.poiButton)
	assert(not hoverRing:IsShown(), "and leaving hides it")

	-- Titles take the accent, brighter under the mouse; the setting restores Blizzard's colours.
	local function TitleColor(block)
		return block.HeaderText:GetTextColor()
	end
	local r, g, b = TitleColor(first)
	assert(Near(r, ar) and Near(g, ag) and Near(b, ab), "quest titles take the accent after Blizzard colours them")
	first.isHighlighted = true
	first:UpdateHighlight()
	local hr, hg, hb = TitleColor(first)
	assert(hr >= ar and hg >= ag and hb >= ab and (hr + hg + hb) > (ar + ag + ab), "under the mouse the title brightens from the accent")
	first.isHighlighted = false
	first:UpdateHighlight()
	r, g, b = TitleColor(first)
	assert(Near(r, ar) and Near(g, ag) and Near(b, ab), "and returns to the accent")
	local achievement = p.modules[2].blocks[1]
	r, g, b = TitleColor(achievement)
	assert(Near(r, ar) and Near(g, ag) and Near(b, ab), "every module's titles take the accent")
	K.Options.Write("Skins", "tracker.titles", false)
	r, g, b = TitleColor(first)
	assert(Near(r, BLIZZARD_GOLD.r) and Near(g, BLIZZARD_GOLD.g) and Near(b, BLIZZARD_GOLD.b), "the titles switch restores Blizzard's colour at once")
	p.layout(tracker)
	r, g, b = TitleColor(first)
	assert(Near(r, BLIZZARD_GOLD.r) and Near(g, BLIZZARD_GOLD.g) and Near(b, BLIZZARD_GOLD.b), "and leaves Blizzard's colour alone on the next layout")
	K.Options.Write("Skins", "tracker.titles", true)
	r, g, b = TitleColor(first)
	assert(Near(r, ar) and Near(g, ag) and Near(b, ab), "switched back on, the accent returns")
	B.check(snap, HOOKED)
	assert(#env._errors == 0, tostring(env._errors[1]))
end

-- A face the game cannot load: tracker text falls back like the rest of the interface ------------------

do
	local B, snap, p
	local env, K, ns = S.New({
		loaded = { Blizzard_ObjectiveTracker = true },
		before = function(env)
			B = S.Blizzard(env)
			p = Tracker(env, B, true)
			snap = B.snapshot()
		end,
	})
	local Style = ns.Style
	assert(Style.Font("body"):find("KstyleUI", 1, true), "the test needs the default face to be KstyleUI's")
	K.Modules.Enable("Skins")
	assert(ns.Skins.IsApplied("tracker"))
	local lineFont, headerFont = env.ObjectiveTrackerLineFont, env.ObjectiveTrackerHeaderFont
	local path, size = lineFont:GetFont()
	assert(path == FALLBACK_FACE, "quest lines and titles use GameFontHighlight's face, as the rest of the interface does, got " .. tostring(path))
	assert(Near(size, 12), "at Blizzard's tracker size, got " .. tostring(size))
	assert(FontPath(headerFont) == FALLBACK_FACE and Near(select(2, headerFont:GetFont()), 14))
	assert(Caption(env, p.modules[1].Header, "QUESTS"), "the caption still draws")
	assert(S.Logged(env, "GameFontHighlight"), "the fallback is logged")

	lineFont:SetFontObject("ObjectiveTrackerFont16")
	path, size = lineFont:GetFont()
	assert(path == FALLBACK_FACE and Near(size, 16), "Edit Mode's text size keeps the fallback face at the new size, got " .. tostring(path) .. " " .. tostring(size))
	K.Options.Write("Skins", "text.size", 1.25)
	assert(FontPath(lineFont) == FALLBACK_FACE and Near(select(2, lineFont:GetFont()), 20), "the text size setting still scales it")
	B.check(snap, HOOKED)
	assert(#env._errors == 0, tostring(env._errors[1]))
end

print("skins tracker ok")
