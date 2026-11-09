-- _tracker.lua: the objective tracker stand-in built the way Forever's Blizzard_ObjectiveTracker builds it,
-- shared by the tracker scene and the HUD scene: the container header, the quest module's header, two quest
-- blocks with their POI buttons and objective lines, and the nine-slice bottom the panel follows.
--
--   local Tracker = dofile("Tools/render/scenes/_tracker.lua")
--   local tracker, module = Tracker.StandIn(env, B, Tracker.QUESTS)   -- ObjectiveTrackerFrame in a Skins env
--
-- Every size and anchor below comes from the forever branch of wow-ui-source, so the render is honest about
-- what the skin can and cannot move:
--   Blizzard_ObjectiveTrackerContainer.xml: the container header is 260 by 32 with its text at LEFT x 7 and an
--     18 by 19 collapse-all button at RIGHT x -1; NineSlice hangs from TOPLEFT x -30 and TOPRIGHT x 5.
--   Blizzard_ObjectiveTrackerContainer.lua: the first module sits BASE_TOP_PADDING = 38 below the container's
--     top, NineSlice's bottom 10 below the last module (bottomModulePadding); UpdateHeaderPosition pins the
--     header at the top.
--   Blizzard_ObjectiveTrackerModule.xml and .lua: a module is 260 wide; its header is 260 by 26 with the text at
--     LEFT x 7 and a 16 by 16 collapse button at RIGHT x 1; ContentsFrame hangs below the header; the first
--     block sits fromHeaderOffsetY = -10 below it, each next block fromBlockOffsetY = -10 below the last,
--     blocks start blockOffsetX = 20 in; a module is headerHeight = 25 plus its blocks tall.
--   Blizzard_ObjectiveTrackerBlock.xml and .lua, Blizzard_ObjectiveTrackerShared.xml: HeaderText spans the
--     block's top in ObjectiveTrackerLineFont (12); each line hangs lineSpacing = 4 below the last with its Dash
--     at TOPLEFT and its Text to the dash's right; titles take OBJECTIVE_TRACKER_COLOR.Header, lines Normal.
--   Blizzard_ObjectiveTrackerQuestPOIBlock.lua and Blizzard_POIButton/POIButton.xml: the 20 by 20 POI button
--     hangs its TOPRIGHT at the title's TOPLEFT (-7, 5), its NormalTexture and Display icon are 32 by 32 about
--     its centre, its Glow 50 by 50; Forever shows the "Quest-In-Progress-Icon-yellow" atlas with no numeral.
-- The game's atlases draw as grey boxes and its texture files have no local copy; the skin hushes all of them.
-- The tracker's position is Edit Mode's, and the stand-in takes Forever's preset for it: TOPRIGHT of UIParent at
-- -110, -275 (Blizzard_EditMode/Mainline/EditModePresetLayouts.lua, the ObjectiveTracker anchorInfo, which the
-- camelot game type loads through the toc's [Family] line). The mockup draws the tracker 89 units under the
-- minimap with its right edge on the minimap's, but KstyleUI never moves Blizzard's tracker: the player does, in
-- Edit Mode. OBJECTIVE_TRACKER_BLOCK_HEADER_COLOR is not in the UI source dump; the game's tracker draws gold
-- titles (spec/g_quest.png), so the stand-in uses NORMAL_FONT_COLOR.
local Common = dofile("Tools/render/scenes/_common.lua")

local Tracker = {}

local WIDTH, EDIT_MODE_HEIGHT = 260, 600
local BASE_TOP_PADDING, BOTTOM_MODULE_PADDING = 38, 10
local CONTAINER_HEADER_HEIGHT, MODULE_HEADER_HEIGHT, HEADER_HEIGHT = 32, 26, 25
local FROM_HEADER_OFFSET_Y, FROM_BLOCK_OFFSET_Y, BLOCK_OFFSET_X, LINE_SPACING = -10, -10, 20, 4
local LINE_FONT_SIZE, HEADER_FONT_SIZE = 12, 14
local LINE_HEIGHT = LINE_FONT_SIZE + 3
local POI_SIZE, POI_ART, POI_GLOW = 20, 32, 50
local EDIT_MODE_X, EDIT_MODE_Y = -110, -275
local GOLD = { 1, 0.82, 0 }
local NORMAL = { 0.8, 0.8, 0.8 }

Tracker.QUESTS = {
	{ title = "Riverglade Crocolisks", objectives = { "Crocolisk Hide 3/8" }, questID = 101 },
	{ title = "The Lost Patrol", objectives = { "Speak to Ranger Kalanna 0/1" }, questID = 102, superTracked = true },
}

local function saved()
	return {
		version = 2,
		profiles = { Default = { Skins = { enabled = true } } },
		characters = {},
		layouts = {},
		account = { setupSeen = true },
		devlog = {},
	}
end

local function shared(env)
	Common.ForceScreen(env)
	env.RAID_CLASS_COLORS = env.RAID_CLASS_COLORS or {}
	env.RAID_CLASS_COLORS.WARRIOR = { r = Common.WARRIOR[1], g = Common.WARRIOR[2], b = Common.WARRIOR[3] }
	env.UnitClass = function(unit)
		if unit == "player" or unit == nil then
			return "Warrior", "WARRIOR", 1
		end
	end
end

local function fonts(env, B)
	env.GameFontHighlight = B.text(env.UIParent)
	env.GameFontHighlight:SetFont("Fonts\\ARIALN.TTF", 12, "")
	env.ObjectiveTrackerLineFont, env.ObjectiveTrackerHeaderFont = B.text(env.UIParent), B.text(env.UIParent)
	env.ObjectiveTrackerLineFont:SetFont("Fonts\\FRIZQT__.TTF", LINE_FONT_SIZE, "")
	env.ObjectiveTrackerHeaderFont:SetFont("Fonts\\FRIZQT__.TTF", HEADER_FONT_SIZE, "")
end

-- POIButton(B, block, questID, superTracked) -> ObjectiveTrackerPOIButtonTemplate as POIButton.xml lays it out.
local function POIButton(B, block, questID, superTracked)
	local button = B.frame("Button", block)
	button:SetSize(POI_SIZE, POI_SIZE)
	button:SetPoint("TOPRIGHT", block.HeaderText, "TOPLEFT", -7, 5)
	button.Glow = B.texture(button, "BACKGROUND")
	button.Glow:SetSize(POI_GLOW, POI_GLOW)
	button.Glow:SetPoint("CENTER")
	button.Glow:SetTexture("Interface\\WorldMap\\UI-QuestPoi-IconGlow")
	button.Glow:SetShown(superTracked)
	button.HighlightTexture = B.texture(button, "OVERLAY")
	button.HighlightTexture:SetSize(POI_ART, POI_ART)
	button.HighlightTexture:SetPoint("CENTER")
	button.HighlightTexture:Hide()
	for _, key in ipairs({ "NormalTexture", "PushedTexture" }) do
		button[key] = B.texture(button, "ARTWORK")
		button[key]:SetSize(POI_ART, POI_ART)
		button[key]:SetPoint("CENTER")
		button[key]:SetTexture("Interface\\WorldMap\\UI-QuestPoi-NumberIcons")
	end
	button.NormalTexture:SetTexCoord(0.875, 1, 0.875, 1)
	button.PushedTexture:SetTexCoord(0.75, 0.875, 0.875, 1)
	button.PushedTexture:Hide()
	button.Display = B.frame("Frame", button)
	button.Display:SetSize(1, 1)
	button.Display:SetPoint("CENTER")
	button.Display.Icon = B.texture(button.Display, "ARTWORK")
	button.Display.Icon:SetSize(POI_ART, POI_ART)
	button.Display.Icon:SetPoint("CENTER")
	button.Display.Icon:SetAtlas(superTracked and "Quest-In-Progress-Icon-Brown" or "Quest-In-Progress-Icon-yellow")
	button.questID = questID
	button.selected = superTracked == true
	function button.IsSelected(self)
		return self.selected
	end
	return button
end

-- Block(B, module, quest) -> ObjectiveTrackerQuestPOIBlockTemplate with its title and objective lines laid out.
local function Block(B, module, quest)
	local block = B.frame("Frame", module.ContentsFrame)
	block.HeaderText = B.text(block)
	block.HeaderText:SetFontObject("ObjectiveTrackerLineFont")
	block.HeaderText:SetJustifyH("LEFT")
	block.HeaderText:SetPoint("TOPLEFT", block, "TOPLEFT")
	block.HeaderText:SetPoint("RIGHT", block, "RIGHT")
	block.HeaderText:SetHeight(LINE_HEIGHT)
	block.title = quest.title
	block.isHighlighted = false
	block.poiQuestID = quest.questID
	block.poiIsComplete = false
	block.lines = {}
	block.usedLines = block.lines
	local anchor, height = block.HeaderText, LINE_HEIGHT
	for _, objective in ipairs(quest.objectives) do
		local line = B.frame("Frame", block)
		line:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -LINE_SPACING)
		line:SetPoint("RIGHT", block, "RIGHT")
		line:SetHeight(LINE_HEIGHT)
		line.Dash = B.text(line)
		line.Dash:SetFontObject("ObjectiveTrackerLineFont")
		line.Dash:SetPoint("TOPLEFT", line, "TOPLEFT", 0, 1)
		line.Dash:SetText("- ")
		line.Dash:SetTextColor(NORMAL[1], NORMAL[2], NORMAL[3])
		line.Text = B.text(line)
		line.Text:SetFontObject("ObjectiveTrackerLineFont")
		line.Text:SetJustifyH("LEFT")
		line.Text:SetPoint("TOP", line, "TOP")
		line.Text:SetPoint("LEFT", line.Dash, "RIGHT")
		line.Text:SetPoint("RIGHT", line, "RIGHT")
		line.Text:SetText(objective)
		line.Text:SetTextColor(NORMAL[1], NORMAL[2], NORMAL[3])
		block.lines[#block.lines + 1] = line
		anchor = line
		height = height + LINE_SPACING + LINE_HEIGHT
	end
	block.height = height
	block:SetHeight(height)
	function block.SetHeader(self, text)
		self.HeaderText:SetText(text)
		self.HeaderText:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
		self.HeaderText.colorStyle = { r = GOLD[1], g = GOLD[2], b = GOLD[3] }
	end
	function block.UpdateHighlight() end
	block.poiButton = POIButton(B, block, quest.questID, quest.superTracked)
	block.nextBlock = nil
	return block
end

-- Header(B, parent, width, height, text, buttonW, buttonH, buttonX) -> a container or module header template.
local function Header(B, parent, width, height, text, buttonW, buttonH, buttonX)
	local header = B.frame("Frame", parent)
	header:SetSize(width, height)
	header.Background = B.texture(header, "BACKGROUND")
	header.Background:SetAllPoints(header)
	header.Text = B.text(header)
	header.Text:SetFontObject("ObjectiveTrackerHeaderFont")
	header.Text:SetJustifyH("LEFT")
	header.Text:SetPoint("LEFT", header, "LEFT", 7, 0)
	header.Text:SetText(text)
	header.Text:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
	header.MinimizeButton = B.frame("Button", header)
	header.MinimizeButton:SetSize(buttonW, buttonH)
	header.MinimizeButton:SetPoint("RIGHT", header, "RIGHT", buttonX, 0)
	header.MinimizeButton.Art = B.texture(header.MinimizeButton)
	header.MinimizeButton.Art:SetAllPoints(header.MinimizeButton)
	function header.SetCollapsed() end
	return header
end

-- StandIn(env, B, quests) -> ObjectiveTrackerFrame with the quest module laid out as Blizzard's Update does.
function Tracker.StandIn(env, B, quests)
	local tracker = B.frame("Frame", nil, "ObjectiveTrackerFrame")
	tracker.isCollapsed = false
	tracker:SetSize(WIDTH, EDIT_MODE_HEIGHT)
	tracker:SetPoint("TOPRIGHT", env.UIParent, "TOPRIGHT", EDIT_MODE_X, EDIT_MODE_Y)
	tracker.NineSlice = B.frame("Frame", tracker)
	tracker.NineSlice:SetPoint("TOPLEFT", tracker, "TOPLEFT", -30, 0)
	tracker.NineSlice:SetPoint("TOPRIGHT", tracker, "TOPRIGHT", 5, 0)
	tracker.Header = Header(B, tracker, WIDTH, CONTAINER_HEADER_HEIGHT, "All Objectives", 18, 19, -1)
	tracker.Header:SetPoint("TOPLEFT", tracker, "TOPLEFT", 0, 0)

	local module = B.frame("Frame", tracker)
	module:SetWidth(WIDTH)
	module:SetPoint("TOP", tracker, "TOP", 0, -BASE_TOP_PADDING)
	module:SetPoint("LEFT", tracker, "LEFT", 0, 0)
	module.Header = Header(B, module, WIDTH, MODULE_HEADER_HEIGHT, "Quests", 16, 16, 1)
	module.Header:SetPoint("TOPLEFT", module, "TOPLEFT")
	module.Header.Shine, module.Header.Glow = B.texture(module.Header, "ARTWORK"), B.texture(module.Header, "OVERLAY")
	module.Header.Shine:SetAlpha(0)
	module.Header.Glow:SetAlpha(0)
	module.ContentsFrame = B.frame("Frame", module)
	module.ContentsFrame:SetPoint("TOP", module.Header, "BOTTOM")
	module.ContentsFrame:SetPoint("LEFT", module, "LEFT")
	module.ContentsFrame:SetPoint("RIGHT", module, "RIGHT")
	module.ContentsFrame:SetPoint("BOTTOM", module, "BOTTOM")
	module.usedProgressBars, module.usedTimerBars = {}, {}
	module.blocks = {}
	for _, quest in ipairs(quests) do
		module.blocks[#module.blocks + 1] = Block(B, module, quest)
	end
	module.firstBlock = nil
	module.contentsHeight = 0
	function module.GetContentsHeight(self)
		return self.contentsHeight
	end
	function module.GetProgressBar() end
	function module.GetTimerBar() end
	function module.SetHeader(self, text)
		self.Header.Text:SetText(text)
	end
	function module.EndLayout() end
	function module.Update(self)
		local last
		self.firstBlock = nil
		self.contentsHeight = HEADER_HEIGHT
		for _, block in ipairs(self.blocks) do
			block.nextBlock = nil
			block:ClearAllPoints()
			local offsetY
			if last then
				offsetY = FROM_BLOCK_OFFSET_Y
				block:SetPoint("TOP", last, "BOTTOM", 0, offsetY)
				last.nextBlock = block
			else
				offsetY = FROM_HEADER_OFFSET_Y
				block:SetPoint("TOP", self.ContentsFrame, "TOP", 0, offsetY)
				self.firstBlock = block
			end
			block:SetPoint("LEFT", self.ContentsFrame, "LEFT", BLOCK_OFFSET_X, 0)
			block:SetPoint("RIGHT", self.ContentsFrame, "RIGHT", 0, 0)
			block:SetHeader(block.title)
			self.contentsHeight = self.contentsHeight + block.height - offsetY
			last = block
		end
		self:SetHeight(self.contentsHeight)
		self:EndLayout()
	end

	function tracker.ForEachModule(_, fn)
		fn(module)
	end
	function tracker.IsCollapsed(self)
		return self.isCollapsed
	end
	function tracker.UpdateHeaderPosition(self)
		self.Header:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
	end
	function tracker.Update(self)
		module:Update()
		self.NineSlice:SetPoint("BOTTOM", module, "BOTTOM", 0, -BOTTOM_MODULE_PADDING)
		self:UpdateHeaderPosition()
	end
	function tracker.SetCollapsed(self, collapsed)
		self.isCollapsed = collapsed
		self:Update()
	end
	tracker:Update()
	fonts(env, B)
	return tracker, module
end

Tracker.Saved, Tracker.Shared = saved, shared

return Tracker
