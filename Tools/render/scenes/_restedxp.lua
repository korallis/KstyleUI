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
--   right edge; an element is its text's height times 1.1 plus 1 tall, the frame the elements plus 18.
--   RestedXP writes the step text in the theme's font at its guide font size plus 2, the list rows at the guide
--   font size, numbers one smaller, the footer at 9; the owner's screenshot reads a guide font size of 7.
local Common = dofile("Tools/render/scenes/_common.lua")
local Scene = Common.Scene

local RestedXP = {}

RestedXP.WIDTH = 268
RestedXP.LEFT, RestedXP.TOP = 18, 290
local WIDTH = RestedXP.WIDTH
local GUIDE_FONT = 7
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

-- Steps(R, path, width) lays the active steps out above the header as RestedXP does, each as wide as the header,
-- and returns the stack's height.
local function Steps(R, path, width)
	local f = R.rxp.RXPFrame
	local steps = f.CurrentStepFrame
	local requested = GUIDE_FONT + 2
	local total = 0
	for i, spec in ipairs(RestedXP.STEPS) do
		local step = steps.framePool[i]
		local y = 0
		local frameHeight = 0
		for e, value in ipairs(spec.elements) do
			local element = step.elements[e]
			font(element.text, path, requested)
			local _, size = element.text:GetFont()
			local textWidth = width - 6 - 12 - 11 - 5
			local h = math.ceil(height(value, size, path, textWidth) * 1.1) + 1
			at(element, step, 0, 10 + y, width, h)
			at(element.button, element, 6, 1, 12, 12)
			element.text:SetJustifyH("LEFT")
			element.text:SetJustifyV("MIDDLE")
			element.text:SetWordWrap(true)
			element.text:SetWidth(textWidth)
			text(element.text, value, "TOPLEFT", element.button, "TOPRIGHT", 11, -1)
			y = y + h
			frameHeight = frameHeight + h
		end
		frameHeight = math.ceil(frameHeight + 18)
		step:ClearAllPoints()
		local above = steps.framePool[i - 1]
		step:SetPoint("TOPLEFT", above or steps, above and "BOTTOMLEFT" or "TOPLEFT", 0, above and -5 or 0)
		step:SetPoint("TOPRIGHT", above or steps, above and "BOTTOMRIGHT" or "TOPRIGHT", 0, above and -5 or 0)
		step:SetHeight(frameHeight)
		step:Show()
		font(step.number.text, path, GUIDE_FONT)
		text(step.number.text, spec.title, "CENTER", step.number, "CENTER", 2, 1)
		local plateWidth = Scene.TextWidth(spec.title, GUIDE_FONT, path) + 10
		at(step.number, step, 7, -5, plateWidth, 17)
		step.number:SetAlpha(spec.title == "" and 0 or 1)
		total = total + frameHeight + 5
	end
	steps:SetHeight(total - 5)
	return total - 5
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
	footer.cog.Normal:SetAllPoints(footer.cog)
	footer.cog.Normal:SetTexture(GLYPH_TEXTURE)
	footer.icon:ClearAllPoints()
	footer.icon:SetPoint("BOTTOMRIGHT", footer, "BOTTOMRIGHT", -1, 3)
	footer.icon:SetSize(16, 16)
	footer.icon.Normal:SetAllPoints(footer.icon)
	footer.icon.Normal:SetTexture(GLYPH_TEXTURE)
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

-- Others(R, x) lays the v2 guide window, the active item frame and the guide configurator out right of the
-- guide window, as the earlier scene did; RestedXP's own layout of them is not modelled.
local function Others(R, x, itemsTop)
	local rxp, env = R.rxp, R.env
	local ICON = 32
	local items = rxp.activeItemFrame
	at(items, env.UIParent, RestedXP.LEFT, itemsTop + 16, 3 * (ICON + 6) + 10, ICON + 16)
	at(items.title, items, 0, -16, 90, 16)
	text(items.title.text, "Active items", "CENTER", items.title)
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
		end,
	}))
	R.env, R.K, R.S, R.ns = env, K, S, ns
	K.Modules.Enable("Skins")
	local rxp = R.rxp
	local counts = {}
	for i, spec in ipairs(RestedXP.STEPS) do
		counts[i] = #spec.elements
	end
	rxp.fake.rows(#RestedXP.ROWS)
	rxp.SetStep(#RestedXP.STEPS, counts)
	rxp.UpdateItemFrame(nil, 3)
	rxp.ui.v2.configurator:Open()
	env.RunTimers()
	S.W.Settle(env)

	local path = rxp.font or (K.Tokens.Font("body"))
	local f = rxp.RXPFrame
	if not rail then
		f:SetWidth(WIDTH)
	end
	local stack = Steps(R, path, f:GetWidth() - 2 * SIDE)
	local guideBottom = Guide(R, path, RestedXP.TOP + stack + 2)
	rxp.RXPFrame:UpdateVisuals()
	if rail then
		ns.RestedXP.Rail.Place()
	end
	Others(R, RestedXP.LEFT + WIDTH + GAP, guideBottom)
	S.W.Settle(env)

	R.windows = {
		steps = f.CurrentStepFrame.framePool,
		guide = { f, f.GuideName },
		items = { rxp.activeItemFrame, rxp.activeItemFrame.title },
		v2 = { rxp.v2.state and rxp.v2.state.guideWindow.frame or nil },
		configurator = { rxp.ui.v2.configurator.ui.frame },
	}
	R.log = {
		"restedxp: RestedXP's v1 windows are laid out as the game lays them out (sizes and anchors read from the owner's screenshot and RestedXP's frame tree); the v2 window, item frame and configurator are placed by this scene",
		"restedxp: the logo, class icon, cog and resize grabber are stand-in textures",
	}
	return R
end

return RestedXP
