-- _restedxp.lua: the RestedXP Guides windows the skin tests' fake builds (Tools/regression/restedxp_fake.lua),
-- skinned by KstyleUI_Skins and laid out the way RestedXP lays its v1 windows out in the game, read from the
-- owner's screenshot (~/.local/share/kstyleui-handoff/ingame/ingame-17.png) and RestedXP's public frame tree, so
-- a render shows how close the text sits to the glass the skin draws. Shared by scenes/restedxp.lua and
-- scenes/gallery_restedxp.lua.
--
--   local RestedXP = dofile("Tools/render/scenes/_restedxp.lua")
--   local R = RestedXP.Build()        -- R.env, R.K, R.ns, R.rxp, R.windows (name -> frame list) and R.log lines
--
-- With RestedXP.PRESET set to a layout name, the skin's story rail places the guide window for that layout, as it
-- does in the game, and folds its step list; without it the window sits at RestedXP.LEFT and RestedXP.TOP, the
-- gallery's spot, with its list at RestedXP.LIST_HEIGHT and the rail switched off.
--
-- RestedXP's v1 geometry, in units (its frames are parented to UIParent at the root's scale):
--   The guide window RXPFrame is 235 by 125 by default; the owner's reads 268 wide. BottomFrame (the step list)
--   is inset 3 on its top and sides and 14 at the bottom; GuideName (the header) is 35 tall and hangs its bottom
--   9 below BottomFrame's top; Footer is 20 tall on RXPFrame's bottom edge, inset 3 at the sides.
--   The header's title runs from x 29 to the right edge, centred; its 42-unit logo is centred 16 in from the left
--   edge, with a 24-unit class icon at the logo's bottom right.
--   The step list's ScrollFrame is inset 5 on the top and left, 7 at the bottom and 20 on the right; its 16-unit
--   scroll bar hangs from the ScrollFrame's top right, 18 down; the list child is 35 narrower than RXPFrame; each
--   row starts 2 in and 3 down, its text 5 below its top and its two-digit number at its bottom right.
--   The footer's text runs from x 40 to 16 before the right edge; the 18-unit cog sits 1 in from the left and the
--   16-unit resize grabber 1 in from the right, 3 up.
--   The active steps stack above the header, their bottom 2 above its top, 5 apart, anchored to CurrentStepFrame as
--   RestedXP anchors them (restedxp_fake.lua), so they follow the window: each step frame is as wide as the header, its "Step N" plate 17 tall at (7, 5) over its top edge, its first element 10 below its top, each
--   element's 12-unit check button at (6, -1) and its text from the button's right plus 11 to 5 before the frame's
--   right edge; an element is its text's height times 1.1 plus 1 tall, the frame the elements plus 18. The fake
--   does that layout itself (its UpdateText), and the skin then moves each line under the cap's title and each
--   check into the gem's column, as it does in the game.
--   RestedXP writes the step text in the theme's font at its guide font size plus 2, the list rows at the guide
--   font size, numbers one smaller, the footer at 9; the guide font size is RestedXP's default, 9, which the
--   owner's saved settings keep.
local Common = dofile("Tools/render/scenes/_common.lua")
local Scene = Common.Scene

local RestedXP = {}

RestedXP.WIDTH = 268
RestedXP.LEFT, RestedXP.TOP = 18, 290
local WIDTH = RestedXP.WIDTH
RestedXP.LIST_HEIGHT = 130
local HEADER_HEIGHT, FOOTER_HEIGHT = 35, 20
local HEADER_OVERLAP, FOOTER_RISE = 9, 14
local SIDE = 3
local LINE = 1.2
local LOGO = 42
local CLASS_ICON = 24
local SCROLLBAR = 16
local GAP = 40

RestedXP.STEPS = {
	{
		title = "Step 34",
		elements = {
			"Kill Kul Tiras Sailors and Kul Tiras Marines. Loot them for their Canvas Scraps",
			"2/10 Kul Tiras Sailor slain",
			"2/8 Kul Tiras Marine slain",
			"8/8 Canvas Scraps",
		},
	},
	{
		title = "",
		elements = { "Loot the Raider's Bow on the ground\nIt has two different spawn locations", "0/1 Raider's Bow" },
	},
	{
		title = "Step 35",
		elements = { "Loot the Raider's Battleaxe on the ground", "0/1 Raider's Battleaxe" },
	},
}
RestedXP.ROWS = {
	{ 37, "Move toward the second floor of the keep" },
	{ 38, "Kill Lieutenant Benedict. Loot him for his Key\n0/1 Lieutenant Benedict slain\nBenedict's Key: 0/1" },
	{ 39, "Go upstairs in the keep\nOpen Benedict's Chest. Loot it for the [Aged Envelope]\nUse the [Aged Envelope] to start the quest\nAged Envelope: 0/1\nAccept The Admiral's Orders" },
	{ 40, "Loot the Raider's Bow on the ground\nIt has two different spawn locations\n0/1 Raider's Bow" },
}
RestedXP.TITLE = "6-10 Durotar\nSpeedrun Guide 1-22"
RestedXP.FOOTER = "RestedXP Guides v4.11.35"
local LOGO_TEXTURE = "Interface\\AddOns\\KstyleUI\\Media\\Logo\\Logo64.png"
local CLASS_ICON_FILE = 132333
local GLYPH_TEXTURE = "Interface\\AddOns\\KstyleUI\\Media\\Textures\\GlyphChevron.png"

local function at(frame, parent, x, y, w, h)
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
	frame:SetSize(w, h)
	frame:Show()
end

local function text(fs, value, point, rel, relPoint, x, y)
	fs:ClearAllPoints()
	fs:SetPoint(point, rel, relPoint or point, x or 0, y or 0)
	fs:SetText(value)
	fs:Show()
end

-- height(value, size, path, width) -> the units a wrapped text takes at a font size, the page's wrap rule.
local function height(value, size, path, width)
	return Scene.WrappedLines(value, size, path, width) * size * LINE
end

local function font(fs, path, size)
	fs:SetFont(path, size, "")
end

-- Steps(R) hands RestedXP.STEPS to the fake as the guide's active steps. The fake lays them out as RestedXP's
-- UpdateText does (restedxp_fake.lua), and the skin's hook then places each line under the cap's title, so the render
-- shows the steps where the game draws them. Returns the stack's height.
local function Steps(R)
	local specs = {}
	for i, spec in ipairs(RestedXP.STEPS) do
		local elements = {}
		for e, value in ipairs(spec.elements) do
			elements[e] = { text = value }
		end
		specs[i] = { index = i, title = spec.title, elements = elements }
	end
	if not RestedXP.PRESET then
		specs[#specs + 1] = { index = 12, title = "Tip", tip = true, elements = {
			{ text = "Keep your Hearthstone in Razor Hill.\nTrain your new abilities at level 10.", textOnly = true },
		} }
	end
	R.rxp.fake.guide(specs)
	R.rxp.SetStep(#specs)
	return R.rxp.RXPFrame.CurrentStepFrame:GetHeight()
end

-- AceGUIContainer-Frame.lua:195-250,294-296: title at the top, content inset 17/27/17/40,
-- and a 100x20 Close button 27/17 from the bottom right. Only the gallery chooses the window's screen position.
local function AceWindow(R, widget, x, y, w, h)
	at(widget.frame, R.env.UIParent, x, y, w, h)
	local title = widget.titletext:GetParent()
	at(title, widget.frame, 0, -12, w, 40)
	widget.titletext:SetSize(w - 40, 20)
	text(widget.titletext, widget.titletext:GetText(), "TOP", title, "TOP", 0, -14)
	at(widget.content, widget.frame, 17, 27, w - 34, h - 67)
	widget.statustext:GetParent():Hide()
	for _, child in ipairs({ widget.frame:GetChildren() }) do
		if child.obj == widget and child._template == "UIPanelButtonTemplate" then
			at(child, widget.frame, w - 127, h - 37, 100, 20)
			text(child:GetFontString(), "Close", "CENTER", child)
		end
	end
end

-- AceGUIContainer-ScrollFrame.lua:171-196: a 20-unit right gutter, 16-unit buttons and bar.
local function AceScroll(widget, parent, x, y, w, h)
	at(widget.frame, parent, x, y, w, h)
	at(widget.scrollframe, widget.frame, 0, 0, w - 20, h)
	widget.scrollframe:EnableMouseWheel(true)
	at(widget.content, widget.scrollframe, 0, 0, w - 20, h)
	widget.content:SetClipsChildren(true)
	at(widget.scrollbar, widget.scrollframe, w - 16, 16, 16, h - 32)
	local bar = widget.scrollbar
	at(bar.ScrollUpButton, bar, 0, -16, 16, 16)
	at(bar.ScrollDownButton, bar, 0, h - 32, 16, 16)
	bar.ThumbTexture:SetSize(16, 30)
	bar.ThumbTexture:SetPoint("TOP", bar, "TOP", 0, -4)
end

local function Bar(bar)
	local w, h = bar:GetWidth(), bar:GetHeight()
	at(bar.ScrollUpButton, bar, 0, -16, w, 16)
	at(bar.ScrollDownButton, bar, 0, h, w, 16)
	bar.ScrollUpButton.Normal:SetAllPoints(bar.ScrollUpButton)
	bar.ScrollDownButton.Normal:SetAllPoints(bar.ScrollDownButton)
	bar.ThumbTexture:ClearAllPoints()
	bar.ThumbTexture:SetPoint("TOP", bar, "TOP", 0, -4)
	bar.ThumbTexture:SetSize(w, 30)
end

local function Label(widget, parent, x, y, w, h, value)
	at(widget.frame, parent, x, y, w, h)
	at(widget.label, widget.frame, 0, 0, w, h)
	widget.label:SetJustifyH("LEFT")
	widget.label:SetJustifyV("TOP")
	widget.label:SetWordWrap(true)
	widget.label:SetText(value)
end

-- LevelingTracker.lua:420-643: report size is attachment width*.7 and height-40-tabsHeight*2;
-- Flow top row (45% level button, 55% player), List groups, four-unit spacers. The attachment is 398x484
-- (Forever Camelot/CharacterFrameConstants.lua:4-7); a supplied legacy tab is 32 high
-- (Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:932-933). Only the report is drawn here.
local function Report(R)
	local rxp, env = R.rxp, R.env
	local attachment = env.CreateFrame("Frame", "RenderRestedXPCharacter", env.UIParent)
	at(attachment, env.UIParent, 0, 0, 398, 484)
	rxp.tracker:CreateGui(attachment, "Valerin")
	local ui = rxp.tracker.ui.RenderRestedXPCharacter
	local w, h = attachment:GetWidth() * 0.7, attachment:GetHeight() - 40 - 32 * 2
	AceWindow(R, ui, 320, 30, w, h)
	AceScroll(ui.scrollContainer, ui.content, 0, 0, w - 34, h - 67)
	local content = ui.scrollContainer.content
	local inner = content:GetWidth()
	local top = ui.scrollContainer.children[1]
	at(top.frame, content, 0, 0, inner, 24)
	at(top.content, top.frame, 0, 0, inner, 24)
	at(ui.levelButton.frame, top.content, 0, 0, inner * 0.45, 24)
	text(ui.levelButton.frame:GetFontString(), "9 to 10", "CENTER", ui.levelButton.frame)
	Label(ui.target, top.content, inner * 0.45, 5, inner * 0.55, 18, "Valerin")
	ui.target.label:SetJustifyH("CENTER")
	local groups = {
		{ "reached", "Reached Level 9", "In-progress" },
		{ "speed", "Time spent", "00:32:18" },
		{ "zones", "Zones & Dungeons", "Durotar: 00:26:40\nOrgrimmar: 00:05:38" },
		{ "sources", "Experience Sources", { quests = "Quests: 6,240 (68%)", mobs = "Mobs: 2,936 (32%)" } },
		{ "teamwork", "Teamwork", { solo = "Solo: 00:28:12", group = "Group: 00:04:06" } },
		{ "extras", "Extras", "Deaths: 0\nDistance travelled: 4,210 yd" },
	}
	local y = 30
	for _, spec in ipairs(groups) do
		local group = ui[spec[1] .. "Container"]
		local parent = content
		local rows = type(spec[3]) == "table" and 2 or (spec[3]:find("\n") and 2 or 1)
		local gh = 18 + 4 + rows * 15
		if group.frame then
			at(group.frame, content, 0, y, inner, gh)
			at(group.content, group.frame, 0, 0, inner, gh)
			parent = group.content
		end
		Label(group.label, parent, 0, group.frame and 0 or y, inner, 18, spec[2])
		local dy = (group.frame and 0 or y) + 22
		if type(spec[3]) == "table" then
			for _, key in ipairs(spec[1] == "sources" and { "quests", "mobs" } or { "solo", "group" }) do
				Label(group.data[key], parent, 0, dy, inner, 15, spec[3][key])
				dy = dy + 15
			end
		else
			Label(group.data, parent, 0, dy, inner, rows * 15, spec[3])
		end
		y = y + gh + 3
	end
	R.windows.report = { ui.frame }
end

-- LevelingTracker.lua:1002-1106,1244-1342: the fake supplies the anchors; label measurements determine
-- the window's width+16 and combined text heights+26. These are the recent splits of a level 9 character.
local function Splits(R)
	R.rxp.tracker:CreateLevelSplits()
	local f = R.rxp.tracker.levelSplits
	local values = { history = "Level 7: 00:18:42\nLevel 8: 00:23:16\nLevel 9: 00:27:09", current = "Level Time: 00:32:18", total = "Total Time: 02:14:35" }
	local width, total = 0, 0
	for _, key in ipairs({ "history", "current", "total" }) do
		local fs = f[key].label
		local path, size = fs:GetFont()
		local h = height(values[key], size, path, 260)
		width = math.max(width, Scene.TextWidth(values[key], size, path))
		f[key].frame:SetSize(260, h)
		at(fs, f[key].frame, 0, 0, 260, h)
		fs:SetJustifyH("LEFT")
		fs:SetJustifyV("TOP")
		fs:SetText(values[key])
		total = total + h
	end
	at(f, R.env.UIParent, 620, 920, width + 16, total + 26)
	f.title:SetWidth(width)
	text(f.title.text, "Level splits", "CENTER", f.title, "CENTER", 0, 1)
	for _, key in ipairs({ "history", "current", "total" }) do
		f[key].frame:SetWidth(width)
		f[key].label:SetWidth(width)
	end
	R.windows.splits = { f, f.title }
end

-- UI/V2/Core.lua:97-126,179-235: 320x126, message at (14,35), 142x24 buttons 12 from the bottom,
-- and the 20-unit close button at TOPRIGHT (6,6). GuideImporter.lua:871-886,1038-1055 supplies the copy.
local function Popup(R, popup, key, y, title, message)
	popup:Show()
	at(popup.frame, R.env.UIParent, 620, y, 320, 126)
	text(popup.title, title, "TOP", popup.frame, "TOP", 0, -9)
	at(popup.message, popup.frame, 14, 35, 292, 56)
	popup.message:SetJustifyH("LEFT")
	popup.message:SetJustifyV("TOP")
	popup.message:SetWordWrap(true)
	popup.message:SetText(message)
	for i, button in ipairs(popup.buttons) do
		at(button, popup.frame, i == 1 and 12 or 166, 90, 142, 24)
		text(button.text, i == 1 and "Yes" or "No", "CENTER", button)
	end
	for _, child in ipairs({ popup.frame:GetChildren() }) do
		if child:GetNormalTexture() then
			at(child, popup.frame, 306, -6, 20, 20)
		end
	end
	R.windows[key] = { popup.frame }
end

-- UI/V2/GuideImporter.lua:248-287,800-841,890-1098: 500x298 plus history, content (10,48),
-- paste field (8,18) 50 high, beta's two import buttons, 24-high dropdown, three 150x24 actions,
-- progress 47 below the dropdown and history 13 under the bar. Beta is on to expose the splice control.
local function Importer(R)
	R.rxp.guideImporter:Open()
	local w = R.rxp.guideImporter.widgets
	local ui = w.import
	at(ui.frame, R.env.UIParent, 1000, 30, 500, 334)
	at(ui.content, ui.frame, 10, 48, 480, 276)
	text(ui.title, "RestedXP Guide Import - v4.11.35", "TOP", ui.frame, "TOP", 0, -4)
	text(ui.description, "Import Guides", "TOPLEFT", ui.frame, "TOPLEFT", 18, -31)
	at(ui.closebutton, ui.frame, 486, -6, 20, 20)
	text(w.importLabel, 'Paste your guide string into the text field and click "Import".', "TOPLEFT", ui.content, "TOPLEFT", 8, -1)
	at(w.importBox.frame, ui.content, 8, 18, 464, 50)
	at(w.importBox.background, w.importBox.frame, 0, 4, 464, 42)
	at(w.importBox.editBox, w.importBox.background, 5, 6, 455, 32)
	w.importBox.editBox:SetText("RXPGuides: 6-10 Durotar\n!RXPGuides;1;9;Durotar;4.11.35")
	for i, key in ipairs({ "importButton", "importSplicedString" }) do
		at(w[key].frame, ui.content, 8 + (i - 1) * 236, 76, 228, 24)
		text(w[key].text, i == 1 and "Import" or "Import Spliced String", "CENTER", w[key].frame)
	end
	text(w.guidesLabel, "Show imported guides", "TOPLEFT", ui.content, "TOPLEFT", 8, -112)
	at(w.currentGuides.frame, ui.content, 8, 124, 464, 24)
	at(w.currentGuides.dropdown, w.currentGuides.frame, -15, 0, 496, 24)
	at(w.currentGuides.button, w.currentGuides.frame, 440, 0, 24, 24)
	w.currentGuides.text:SetWidth(414)
	w.currentGuides.text:SetJustifyH("RIGHT")
	text(w.currentGuides.text, "6-10 Durotar", "LEFT", w.currentGuides.frame, "LEFT", 10, 0)
	for i, key in ipairs({ "purgeButton", "reloadButton", "deleteButton" }) do
		at(w[key].frame, ui.content, 8 + (i - 1) * 160, 156, 150, 24)
		text(w[key].text, ({ "Purge", "Reload", "Delete" })[i], "CENTER", w[key].frame)
	end
	text(w.progressLabel, "Progress", "TOPLEFT", ui.content, "TOPLEFT", 8, -195)
	at(w.progress, ui.content, 8, 209, 464, 18)
	w.progress:SetValue(0.72)
	w.progressBackground:SetAllPoints(w.progress)
	w.progressBackground:SetColorTexture(0.05, 0.05, 0.05, 0.3)
	text(w.progressText, "Importing guides: 18 / 25", "LEFT", w.progress, "LEFT", 6, 0)
	at(w.history, ui.content, 8, 240, 464, 36)
	w.history:SetJustifyH("LEFT")
	w.history:SetJustifyV("TOP")
	w.history:SetText("6-10 Durotar imported successfully\n10-12 Barrens imported successfully")
	Popup(R, w.purgeConfirmation, "purge", 30, "Purge", "This action will remove ALL guides from the database\nAre you sure?")
	Popup(R, w.deleteConfirmation, "delete", 186, "Remove", "Remove 6-10 Durotar?")
	R.windows.importer = { ui.frame }
end

-- Communications.lua:595-675 and AceGUIContainer-Frame.lua:149-150: feedback uses AceGUI's 700x500
-- default; branded export gets its caller's width/height. AceGUIWidget-MultiLineEditBox.lua:38-51,290-327
-- places the label at y4, scroll background below it, edit inset (5,6), Accept at bottom left if writable.
local function Dialog(R, widget, x, y, w, h, feedback)
	AceWindow(R, widget, x, y, w, h)
	local parent, edit = widget.content, widget.children[1]
	if feedback then
		AceScroll(edit, parent, 0, 0, w - 34, h - 67)
		parent, edit = edit.content, edit.children[1]
	end
	local ew, eh = parent:GetWidth(), parent:GetHeight()
	at(edit.frame, parent, 0, 0, ew, eh)
	local path, size = R.ns.Style.Font("body")
	local labelHeight = height(edit.label:GetText(), size, path, ew)
	at(edit.label, edit.frame, 0, 4, ew, labelHeight)
	edit.label:SetJustifyH("LEFT")
	edit.label:SetJustifyV("TOP")
	edit.label:SetWordWrap(true)
	local bottom = feedback and 4 or 26
	at(edit.scrollBG, edit.frame, 0, labelHeight + 4, ew - 16, eh - labelHeight - 4 - bottom)
	at(edit.scrollFrame, edit.scrollBG, 5, 6, ew - 25, edit.scrollBG:GetHeight() - 10)
	at(edit.editBox, edit.scrollFrame, 0, 0, ew - 25, edit.scrollFrame:GetHeight())
	at(edit.scrollBar, edit.frame, ew - 16, labelHeight + 23, 16, eh - labelHeight - 23 - bottom - 19)
	if not feedback then
		at(edit.button, edit.frame, 0, eh - 26, 72, 22)
		text(edit.button:GetFontString(), "Accept", "CENTER", edit.button)
	end
end

local function ExtraWindows(R)
	local rxp, env = R.rxp, R.env
	Report(R)
	Splits(R)
	Importer(R)
	rxp.comms.OpenBugReport({ arg1 = 12 })
	local feedback = env.RESTEDXP_BUG_REPORT_WINDOW.obj
	Dialog(R, feedback, 960, 550, 700, 500, true)
	feedback.children[1].children[1].editBox:SetText("RestedXP Feedback Form\n\nCharacter: Orc / Warrior / level 9 (72.00%)\nZone: Durotar / Tiragarde Keep / 59.24,58.13\nGuide: 6-10 Durotar v4.11.35\nStep: 12\n\nDescribe the issue:\nThe Canvas Scraps objective did not update after looting.\n\nWhat did you expect to happen?\nThe counter should increase when the quest item is looted.")
	rxp.comms.OpenBrandedExport("Guide export", "Copy or edit your guide string", "#classic\n#name 6-10 Durotar\n#next 10-12 Barrens\n\nstep\n.goto Durotar,59.24,58.13\n>>Collect Canvas Scraps", 320, 240, function() end)
	Dialog(R, env.RESTEDXP_BRANDED_EXPORT.obj, 620, 650, 320, 240, false)
	R.windows.feedback = { feedback.frame }
	R.windows.export = { env.RESTEDXP_BRANDED_EXPORT }
	-- Targeting.lua:1129-1325 and map.lua:40-98,140-166 are already laid out by the fake.
	rxp.targeting:UpdateTargetFrame(3, 1)
	local targets = rxp.targeting.activeTargetFrame
	at(targets, env.UIParent, 18, 40, targets:GetWidth(), targets:GetHeight())
	for i, button in ipairs(targets.enemyTargetButtons) do button.icon:SetTexture(132333 + i) end
	for _, button in ipairs(targets.friendlyTargetButtons) do button.icon:SetTexture(135942) end
	rxp.SetupArrow()
	rxp.fake.arrow("Tiragarde Keep", 126, 0.35)
	at(rxp.arrowFrame, env.UIParent, 210, 40, 32, 32)
	rxp.arrowFrame.text:SetWidth(130)
	rxp.arrowFrame.text:SetHeight(30)
	R.windows.targets = { targets, targets.title }
	R.windows.arrow = { rxp.arrowFrame, rxp.arrowFrame.text }
	-- GuideWindow.lua:1001-1012: UpdateText's tip branch is modelled by the fake (230 wide, outside the stack).
	local tip = rxp.RXPFrame.CurrentStepFrame.framePool[#RestedXP.STEPS + 1]
	at(tip, env.UIParent, 18, 170, 230, tip:GetHeight())
	R.windows.tip = { tip, tip.number }
	-- QuestLog.lua:762-791: 200x22 cleanup below Abandon, or parent BOTTOMLEFT (20,45).
	local button = rxp.fake.createCleanupButton()
	env.FireEvent("PLAYER_ENTERING_WORLD", true, false)
	env.RunTimers()
	at(env.QuestMapFrame, env.UIParent, 0, 900, 240, 120)
	at(env.QuestMapFrame.DetailsFrame, env.QuestMapFrame, 0, 0, 240, 120)
	at(button, env.QuestMapFrame.DetailsFrame, 20, 53, 200, 22)
	text(button:GetFontString(), "Cleanup Orphaned Quests", "CENTER", button)
	R.windows.cleanup = { button }
	-- LibUIDropDownMenu.lua:58-59,1213-1248,1386 and GuideWindow.lua:1561-1586: the complete step menu.
	-- The fake lays out its shared rows; ShowMenu leases the list's kit chrome and typography.
	local menu = rxp.fake.menuRows({ "Go to step 12", "Select another guide", "Reload Guide", "Options...", "Give Feedback for step", "Close" })
	rxp:ShowMenu(rxp.RXPFrame.bottomMenu, rxp.RXPFrame.MenuFrame, "cursor", 0, 0, "MENU")
	at(menu, env.UIParent, 18, 870, menu:GetWidth(), menu:GetHeight())
	env.L_DropDownList1Backdrop:SetAllPoints(menu)
	env.L_DropDownList1MenuBackdrop:SetAllPoints(menu)
	R.windows.menu = { menu }
	-- Finish the template geometry the fake deliberately omits (the constructors above own these sizes).
	Bar(rxp.v2.state.guideWindow.guideSteps.scroll.scrollbar)
	at(rxp.v2.state.guideWindow.guideSteps.scroll.scrollbar, rxp.v2.state.guideWindow.guideStepsFrame, WIDTH - 16, 19, 10, 200)
	-- UI/V2/Core.lua:1081-1083: the banner header sits one unit inside the upper frame.
	at(rxp.v2.state.guideWindow.header, rxp.v2.state.guideWindow.upperFrame, 1, 1, WIDTH - 2, rxp.v2.state.guideWindow.upperFrame:GetHeight() - 2)
	Bar(rxp.ui.v2.configurator.ui.scrollContainer.scrollbar)
	Bar(rxp.tracker.ui.RenderRestedXPCharacter.scrollContainer.scrollbar)
	Bar(feedback.scrollContainer.scrollbar)
	Bar(feedback.children[1].children[1].scrollBar)
	Bar(env.RESTEDXP_BRANDED_EXPORT.obj.children[1].scrollBar)
	local configurator = rxp.ui.v2.configurator.ui
	-- GuideConfigurator.lua:478-479,1075-1106: close, settings, import and help controls.
	for _, child in ipairs({ configurator.frame:GetChildren() }) do
		local normal = child:GetNormalTexture()
		local path = type(normal) == "table" and tostring(normal:GetTexture()) or ""
		if path:find("rxp%-btn%-close") then at(child, configurator.frame, 301, -5, 24, 24)
		elseif path:find("rxp%-icon%-cog") then at(child, configurator.frame, 284, 24, 24, 24)
		elseif path:find("icon%-btn%-import") then at(child, configurator.frame, 252, 21, 30, 30)
		elseif path:find("icon%-btn%-help") then at(child, configurator.frame, 220, 21, 30, 30) end
	end
	local items = rxp.activeItemFrame
	at(items, env.UIParent, 18, 790, items:GetWidth(), items:GetHeight())
	at(button, env.QuestMapFrame.DetailsFrame, 330, 53, 200, 22)
	-- UI/V2/Core.lua:396-420,466-468: backdrop wrappers fill their window, shadow extends two units.
	for _, frame in ipairs(env._frames) do
		if frame.rxpBackground then frame.rxpBackground:SetAllPoints(frame) end
		if frame.rxpBorder then frame.rxpBorder:SetAllPoints(frame) end
		if frame.rxpShadow then
			frame.rxpShadow:SetPoint("TOPLEFT", frame, "TOPLEFT", -2, 2)
			frame.rxpShadow:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 2, -2)
		end
	end
	env.CharacterFrame:Hide()
end

-- Guide(R, path, top) lays the guide window out: in the gallery with its header's top at `top`, header, step list
-- and footer; on the rail the skin has placed and sized the window, so only its contents are laid out.
local function Guide(R, path, top)
	local f, env = R.rxp.RXPFrame, R.env
	local rail = RestedXP.PRESET ~= nil
	local LIST_HEIGHT = RestedXP.LIST_HEIGHT
	local frameWidth = rail and f:GetWidth() or WIDTH
	local frameHeight = rail and f:GetHeight() or (LIST_HEIGHT + SIDE + FOOTER_RISE)
	local inner = frameWidth - 2 * SIDE
	if not rail then
		local frameTop = top + HEADER_HEIGHT - HEADER_OVERLAP - SIDE
		at(f, env.UIParent, RestedXP.LEFT, frameTop, WIDTH, frameHeight)
		at(f.GuideName, f, SIDE, SIDE + HEADER_OVERLAP - HEADER_HEIGHT, inner, HEADER_HEIGHT)
		at(f.BottomFrame, f, SIDE, SIDE, inner, LIST_HEIGHT)
		at(f.Footer, f, SIDE, frameHeight - FOOTER_HEIGHT, inner, FOOTER_HEIGHT)
	end
	local name = f.GuideName
	name.text:SetJustifyH("CENTER")
	name.text:SetJustifyV("MIDDLE")
	name.text:SetWordWrap(true)
	name.text:SetWidth(inner - 29)
	text(name.text, RestedXP.TITLE, "LEFT", name, "LEFT", 29, 0)
	name.icon:ClearAllPoints()
	name.icon:SetPoint("CENTER", name, "LEFT", 16, 0)
	name.icon:SetSize(LOGO, LOGO)
	name.icon:SetTexture(LOGO_TEXTURE)
	name.classIcon:ClearAllPoints()
	name.classIcon:SetPoint("CENTER", name.icon, "BOTTOMRIGHT", -4, 10)
	name.classIcon:SetSize(CLASS_ICON, CLASS_ICON)
	name.classIcon:SetTexture(CLASS_ICON_FILE)
	local footer = f.Footer
	font(footer.text, path, 9)
	footer.text:SetJustifyH("LEFT")
	footer.text:SetWidth(inner - 40 - 16)
	text(footer.text, RestedXP.FOOTER, "LEFT", footer, "LEFT", 40, 1)
	footer.cog:ClearAllPoints()
	footer.cog:SetPoint("LEFT", footer, "LEFT", 1, 1)
	footer.cog:SetSize(18, 18)
	local cog = footer.cog:GetNormalTexture()
	if type(cog) ~= "table" then
		cog = footer.cog:CreateTexture(nil, "ARTWORK")
		footer.cog:SetNormalTexture(cog)
	end
	cog:SetAllPoints(footer.cog)
	cog:SetTexture(GLYPH_TEXTURE)
	footer.icon:ClearAllPoints()
	footer.icon:SetPoint("BOTTOMRIGHT", footer, "BOTTOMRIGHT", -1, 3)
	footer.icon:SetSize(16, 16)
	footer.icon:GetNormalTexture():SetAllPoints(footer.icon)
	footer.icon:GetNormalTexture():SetTexture(GLYPH_TEXTURE)
	if rail then
		return top + frameHeight
	end
	local bottom = f.BottomFrame
	local scrollWidth, scrollHeight = inner - 5 - 20, RestedXP.LIST_HEIGHT - 5 - 7
	at(f.ScrollFrame, bottom, 5, 5, scrollWidth, scrollHeight)
	f.ScrollFrame:SetClipsChildren(true)
	local bar = f.ScrollFrame.ScrollBar
	at(bar, f.ScrollFrame, scrollWidth, 18, SCROLLBAR, scrollHeight - 36)
	at(bar.ScrollUpButton, bar, 0, -SCROLLBAR, SCROLLBAR, SCROLLBAR)
	at(bar.ScrollDownButton, bar, 0, scrollHeight - 36, SCROLLBAR, SCROLLBAR)
	bar.ThumbTexture:ClearAllPoints()
	bar.ThumbTexture:SetPoint("TOP", bar, "TOP", 0, -4)
	bar.ThumbTexture:SetSize(SCROLLBAR, 24)
	bar.ScrollUpButton.Normal:SetAllPoints(bar.ScrollUpButton)
	bar.ScrollDownButton.Normal:SetAllPoints(bar.ScrollDownButton)
	local childWidth = frameWidth - 35
	at(f.ScrollChild, f.ScrollFrame, 0, 0, childWidth, scrollHeight)
	R.rxp.fake.rows(#RestedXP.ROWS)
	local GUIDE_FONT = select(2, f.ScrollChild.framePool[1].text:GetFont())
	local y = 3
	for i, spec in ipairs(RestedXP.ROWS) do
		local row = f.ScrollChild.framePool[i]
		local number = tostring(spec[1])
		local numberWidth = Scene.TextWidth(number, GUIDE_FONT - 1, path) + 2
		local textWidth = childWidth - numberWidth
		font(row.text, path, GUIDE_FONT)
		local _, rowSize = row.text:GetFont()
		local h = height(spec[2], rowSize, path, textWidth) + 8
		at(row, f.ScrollChild, 2, y, childWidth, h)
		row:SetAlpha(0.66)
		row.text:SetJustifyH("LEFT")
		row.text:SetJustifyV("TOP")
		row.text:SetWordWrap(true)
		row.text:SetWidth(textWidth)
		text(row.text, spec[2], "TOPLEFT", row, "TOPLEFT", 0, -5)
		row.number:ClearAllPoints()
		row.number:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
		row.number:SetSize(numberWidth, 10)
		font(row.number.text, path, GUIDE_FONT - 1)
		text(row.number.text, number, "CENTER", row.number, "CENTER", 0, 0)
		y = y + h + 3
	end
	return top + HEADER_HEIGHT - HEADER_OVERLAP - SIDE + frameHeight
end

-- ConfiguratorRows(env, rxp, configurator) lays the configurator's pane out as RestedXP's GuideConfigurator.lua
-- fills it: the guide's title and description labels, then the option rows the fake renders on Open (its
-- RXPV2GuideConfiguratorOption widgets, each anchored as RestedXP anchors it: a 40-unit image at the left, the
-- label beside it, the recommendation line above the label and the 17-unit check at the right), stacked in the
-- pane, so the skin's treatment of RestedXP's rows can be judged.
local OPTION_ROW, OPTION_GAP = 40, 4
local OPTION_FLOOR = 240 - 44 - 10

local function ConfiguratorRows(env, rxp, configurator)
	local Fake = dofile("Tools/regression/restedxp_fake.lua")
	local frame = configurator.frame
	local left, top, width = 16, 40, 320 - 16 - 28
	local intro = configurator.scrollContainer.children[1]
	at(intro.frame, frame, left, top, width, 34)
	at(intro.content, intro.frame, 0, 0, width, 34)
	Label(intro.titleLabel, intro.content, 0, 0, width, 16, "Shadowfang Keep, 18 to 26")
	Label(intro.descriptionLabel, intro.content, 0, 18, width, 14, "Choose what this guide should include.")
	local pane = configurator.scrollContainer.frame
	at(pane, frame, left, top + 38, width, OPTION_FLOOR - top - 38)
	configurator.scrollContainer.scrollframe:SetAllPoints(pane)
	configurator.scrollContainer.content:SetAllPoints(pane)
	local y = 0
	for _, option in ipairs(Fake.ConfiguratorOptions(configurator)) do
		if y + OPTION_ROW > OPTION_FLOOR - top - 38 then
			option.frame:Hide()
		else
			local holder = option.frame:GetParent()
			if holder ~= pane then
				at(holder, pane, 0, y, width, OPTION_ROW)
			end
			at(option.frame, holder, 0, holder == pane and y or 0, width, OPTION_ROW)
			option.text:SetHeight(16)
			option.recommendation:SetHeight(12)
			y = y + OPTION_ROW + OPTION_GAP
		end
	end
end

-- Others(R, x) lays the v2 guide window, the active item frame and the guide configurator out right of the
-- guide window, as the earlier scene did; RestedXP's own layout of them is not modelled.
local function Others(R, x, itemsTop)
	local rxp, env = R.rxp, R.env
	local ICON = 32
	local items = rxp.activeItemFrame
	at(items, env.UIParent, RestedXP.LEFT, itemsTop + 16, 3 * (ICON + 6) + 10, ICON + 16)
	-- RestedXP hangs the title plate from the frame's top edge: TOPLEFT at (5, 10), 19 tall, as its
	-- ActiveItemFrame.lua anchors it. The skin raises the card's glass over the plate.
	at(items.title, items, 5, -10, 90, 19)
	text(items.title.text, "Active items", "CENTER", items.title)
	items:UpdateVisuals()
	for i, button in ipairs(items.buttonList) do
		at(button, items, 8 + (i - 1) * (ICON + 6), 8, ICON, ICON)
		button.icon:SetAllPoints(button)
		button.icon:SetTexture(134400 + i)
	end
	local v2 = rxp.v2.state and rxp.v2.state.guideWindow
	if v2 then
		local v2Height = 400
		at(v2.frame, env.UIParent, x, RestedXP.TOP, WIDTH, v2Height)
		at(v2.upperFrame, v2.frame, 0, 0, WIDTH, 70)
		at(v2.guideStepsFrame, v2.frame, 0, 76, WIDTH, v2Height - 76)
		text(v2.title, "6-10 Durotar", "LEFT", v2.upperFrame, "LEFT", 16, 0)
		at(v2.closebutton, v2.upperFrame, WIDTH - 28, 8, 20, 20)
		at(v2.guideSteps.scroll.scrollbar, v2.guideStepsFrame, WIDTH - 16, 6, 10, 200)
	end
	local configurator = rxp.ui.v2.configurator.ui
	local x3 = x + WIDTH + GAP
	at(configurator.frame, env.UIParent, x3, RestedXP.TOP, 320, 240)
	text(configurator.titletext, "Guide configurator", "TOP", configurator.frame, "TOP", 0, -14)
	for i, key in ipairs({ "backbutton", "resetbutton", "submitbutton" }) do
		local button = configurator[key]
		at(button, configurator.frame, 16 + (i - 1) * 100, 240 - 44, 88, 26)
		text(button.text, ({ "Back", "Reset", "Submit" })[i], "CENTER", button)
	end
	at(configurator.scrollContainer.scrollbar, configurator.frame, 320 - 20, 50, 10, 140)
	ConfiguratorRows(env, rxp, configurator)
end

function RestedXP.Build()
	local S = dofile("Tools/regression/skins_env.lua")
	local Fake = dofile("Tools/regression/restedxp_fake.lua")
	local R = {}
	local rail = RestedXP.PRESET ~= nil
	local env, K, ns = S.New(Common.ScreenOpts({
		saved = {
			version = 2,
			profiles = { Default = { Skins = { enabled = true, restedXP = { rail = rail } }, Layout = rail and { preset = RestedXP.PRESET } or nil } },
			characters = {},
			layouts = {},
			account = { setupSeen = true },
			devlog = {},
		},
		setup = function(env)
			Common.ForceScreen(env)
			R.rxp = Fake.Install(env, { v2 = not rail, activeTheme = "DarkMode" })
			-- RestedXP's loaded guide: its title is the name with the group appended (GuideWindow.lua).
			R.rxp.currentGuide = { name = "6-10 Durotar", subgroup = "Speedrun Guide 1-22" }
		end,
	}))
	R.env, R.K, R.S, R.ns = env, K, S, ns
	K.Modules.Enable("Skins")
	local rxp = R.rxp
	-- The gallery shows the v1 guide beside the v2 window, which the game never does: with v2 on, RestedXP hides
	-- the v1 steps and leaves the v1 window undrawn (GuideWindow.lua's UpdateText and UpdateVisuals). So the v2
	-- window is built and skinned with v2 on, and from here v1 is laid out as if v2 were off.
	rxp.v2.IsGuideWindowEnabled = function()
		return false
	end
	rxp.fake.rows(#RestedXP.ROWS)
	Steps(R)
	rxp.UpdateItemFrame(nil, 3)
	rxp.ui.v2.configurator:Open()
	env.RunTimers()
	S.W.Settle(env)

	local path = rxp.font or (K.Tokens.Font("body"))
	local f = rxp.RXPFrame
	if not rail then
		f:SetWidth(WIDTH)
	end
	f.CurrentStepFrame.UpdateText()
	local guideBottom = Guide(R, path, RestedXP.TOP + f.CurrentStepFrame:GetHeight() + 2)
	f.CurrentStepFrame.UpdateText()
	rxp.RXPFrame:UpdateVisuals()
	if rail then
		ns.RestedXP.Rail.Place()
	end
	Others(R, RestedXP.LEFT + WIDTH + GAP, guideBottom)
	S.W.Settle(env)

	R.windows = {
		steps = f.CurrentStepFrame.framePool,
		guide = { ns.RestedXP.Chrome.Card(f) or f },
		items = { rxp.activeItemFrame, rxp.activeItemFrame.title, K.Skin.Parts(rxp.activeItemFrame).backdrop },
		v2 = { rxp.v2.state and rxp.v2.state.guideWindow.frame or nil },
		configurator = { rxp.ui.v2.configurator.ui.frame },
	}
	if not rail then
		local v2 = rxp.v2.state.guideWindow
		at(v2.frame, env.UIParent, 330, 480, WIDTH, 400)
		at(rxp.ui.v2.configurator.ui.frame, env.UIParent, 620, 340, 320, 240)
		ExtraWindows(R)
		S.W.Settle(env)
	end
	R.log = {
		"restedxp: RestedXP's v1 windows are laid out as the game lays them out (sizes and anchors read from the owner's screenshot and RestedXP's frame tree); the v2 window, item frame and configurator are placed by this scene",
		"restedxp: the logo, class icon, cog and resize grabber are stand-in textures",
	}
	return R
end

return RestedXP
