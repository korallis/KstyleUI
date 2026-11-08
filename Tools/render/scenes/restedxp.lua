-- restedxp.lua: the RestedXP windows the skin tests' fake builds (Tools/regression/restedxp_fake.lua), skinned by
-- KstyleUI_Skins, laid out as the owner's crop ~/.local/share/kstyleui-handoff/spec/g_rxp.png shows them: the
-- active step window over the guide window (header, step list, footer), 270 units wide, with the v2 guide window,
-- the active item frame and the leveling report beside them. The fake makes frames with no size or anchor, so
-- this scene places them; RestedXP's own layout is not modelled.
local Common = dofile("Tools/render/scenes/_common.lua")

local LEFT, TOP = 60, 260
local WIDTH = 270
local STEP_HEIGHT, HEADER_HEIGHT, LIST_HEIGHT, FOOTER_HEIGHT = 110, 60, 250, 22
local GAP = 12
local ICON = 32

local function place(frame, x, y, w, h, env)
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", env.UIParent, "TOPLEFT", x, -y)
	frame:SetSize(w, h)
	frame:Show()
end

local function inside(frame, parent, left, top, w, h)
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", parent, "TOPLEFT", left, -top)
	frame:SetSize(w, h)
	frame:Show()
end

local function text(fs, value, point, rel, relPoint, x, y)
	fs:ClearAllPoints()
	fs:SetPoint(point, rel, relPoint or point, x or 0, y or 0)
	fs:SetText(value)
	fs:Show()
end

return Common.Run(function()
	local S = dofile("Tools/regression/skins_env.lua")
	local Fake = dofile("Tools/regression/restedxp_fake.lua")
	local rxp
	local env, K = S.New(Common.ScreenOpts({
		saved = {
			version = 2,
			profiles = { Default = { Skins = { enabled = true } } },
			characters = {},
			layouts = {},
			account = { setupSeen = true },
			devlog = {},
		},
		setup = function(env)
			Common.ForceScreen(env)
			rxp = Fake.Install(env, { v2 = true, activeTheme = "DarkMode" })
		end,
	}))
	K.Modules.Enable("Skins")
	rxp.SetStep(1)
	rxp.UpdateItemFrame(nil, 3)
	rxp.ui.v2.configurator:Open()
	env.RunTimers()
	S.W.Settle(env)

	-- The guide window: header, step list with its scroll bar, footer.
	local f = rxp.RXPFrame
	local y = TOP + STEP_HEIGHT + GAP
	place(f, LEFT, y, WIDTH, HEADER_HEIGHT + LIST_HEIGHT + FOOTER_HEIGHT, env)
	inside(f.GuideName, f, 0, 0, WIDTH, HEADER_HEIGHT)
	inside(f.BottomFrame, f, 0, HEADER_HEIGHT, WIDTH, LIST_HEIGHT)
	inside(f.Footer, f, 0, HEADER_HEIGHT + LIST_HEIGHT, WIDTH, FOOTER_HEIGHT)
	text(f.GuideName.text, "1-6 Durotar\nSpeedrun Guide 1-22", "CENTER", f.GuideName)
	f.GuideName.text:SetJustifyH("CENTER")
	text(f.Footer.text, "RestedXP Guides v4.11.34", "CENTER", f.Footer)
	inside(f.ScrollFrame, f.BottomFrame, 6, 6, WIDTH - 24, LIST_HEIGHT - 12)
	inside(f.ScrollFrame.ScrollBar, f.BottomFrame, WIDTH - 16, 6, 10, LIST_HEIGHT - 12)
	inside(f.ScrollChild, f.BottomFrame, 6, 6, WIDTH - 24, LIST_HEIGHT - 12)
	local row = f.ScrollChild.framePool[1]
	inside(row, f.ScrollChild, 0, 0, WIDTH - 24, 36)

	-- The active step window above it.
	local steps = f.CurrentStepFrame
	place(steps, LEFT, TOP, WIDTH, STEP_HEIGHT, env)
	local step = steps.framePool[1]
	inside(step, steps, 0, 0, WIDTH, STEP_HEIGHT)
	inside(step.number, step, 8, -8, 56, 18)
	text(step.number.text, "Step 25", "CENTER", step.number)
	local element = step.elements[1]
	inside(element, step, 16, 30, WIDTH - 32, 60)
	inside(element.button, element, 0, 38, 14, 14)
	text(element.text, "Kill Scorpid Workers. Loot them for Scorpid Worker Tails\n7/10 Scorpid Worker Tail", "TOPLEFT", element, "TOPLEFT", 0, 0)
	element.text:SetWidth(WIDTH - 32)
	element.text:SetJustifyH("LEFT")

	-- The v2 guide window beside them.
	local v2 = rxp.v2.state.guideWindow
	local x2 = LEFT + WIDTH + 40
	place(v2.frame, x2, TOP, WIDTH, STEP_HEIGHT + GAP + HEADER_HEIGHT + LIST_HEIGHT + FOOTER_HEIGHT, env)
	inside(v2.upperFrame, v2.frame, 0, 0, WIDTH, 70)
	inside(v2.guideStepsFrame, v2.frame, 0, 76, WIDTH, STEP_HEIGHT + GAP + HEADER_HEIGHT + LIST_HEIGHT + FOOTER_HEIGHT - 76)
	text(v2.title, "Durotar 1-6", "LEFT", v2.upperFrame, "LEFT", 16, 0)
	inside(v2.closebutton, v2.upperFrame, WIDTH - 28, 8, 20, 20)
	inside(v2.guideSteps.scroll.scrollbar, v2.guideStepsFrame, WIDTH - 16, 6, 10, 200)

	-- The active item frame under the guide window.
	local items = rxp.activeItemFrame
	local itemsTop = y + HEADER_HEIGHT + LIST_HEIGHT + FOOTER_HEIGHT + GAP + 16
	place(items, LEFT, itemsTop, 3 * (ICON + 6) + 10, ICON + 16, env)
	inside(items.title, items, 0, -16, 90, 16)
	text(items.title.text, "Active items", "CENTER", items.title)
	for i, button in ipairs(items.buttonList) do
		inside(button, items, 8 + (i - 1) * (ICON + 6), 8, ICON, ICON)
		button.icon:SetAllPoints(button)
		button.icon:SetTexture(134400 + i)
	end

	-- The guide configurator (an RXP v2 window with buttons and a scroll bar).
	local configurator = rxp.ui.v2.configurator.ui
	local x3 = x2 + WIDTH + 40
	place(configurator.frame, x3, TOP, 320, 240, env)
	text(configurator.titletext, "Guide configurator", "TOP", configurator.frame, "TOP", 0, -14)
	for i, key in ipairs({ "backbutton", "resetbutton", "submitbutton" }) do
		local button = configurator[key]
		inside(button, configurator.frame, 16 + (i - 1) * 100, 240 - 44, 88, 26)
		text(button.text, ({ "Back", "Reset", "Submit" })[i], "CENTER", button)
	end
	inside(configurator.scrollContainer.scrollbar, configurator.frame, 320 - 20, 50, 10, 140)

	local scene = Common.Scene.Build(env)
	local err = Common.Errors(env, K)
	if err then
		scene.log[#scene.log + 1] = "restedxp error: " .. err
	end
	scene.log[#scene.log + 1] = "restedxp: the fake's frames are laid out by this scene; RestedXP's own layout is not modelled"
	return scene
end)
