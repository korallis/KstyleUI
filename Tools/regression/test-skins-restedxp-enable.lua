-- test-skins-restedxp-enable.lua: RestedXP enables under the skin whichever addon starts first, and its waypoint arrow keeps working: RestedXP's OnEnable anchors the active steps and reads where that frame sits (GuideWindow.lua 387), so the rail never leaves the steps frame without a height before RestedXP's first guide loads (the owner's v0.0.7 session raised "arithmetic on a nil value" there and RestedXP stopped enabling), RestedXP's saved window places load as they do without the skin, and its arrow shows at its own place in its own shape.
local S = dofile("Tools/regression/skins_env.lua")
local Fake = dofile("Tools/regression/restedxp_fake.lua")

local HOOKED = { SetAlpha = true, SetChecked = true, SetFont = true, SetFontObject = true, SetText = true, Show = true, Hide = true, SetShown = true, UpdateVisuals = true, SetMinMaxValues = true, SetStep = true, SetScale = true, StopMovingOrSizing = true, SetupArrow = true }

local function Boot(skinFirst, saved)
	local rxp
	local env, K, ns = S.New({
		saved = { version = 9, profiles = { Default = { Appearance = { uiScale = 16 / 19 } } }, characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} },
		setup = function(env)
			rxp = Fake.Install(env, {})
		end,
	})
	local profile = rxp.settings.profile
	if saved then
		profile.framePositions = {
			RXPFrame = { { "TOPLEFT", "UIParent", "BOTTOMLEFT", 35.92848205566406, 595.7601318359375 } },
			arrowFrame = { { "TOP", nil, "TOP", 11.56650161743164, -73.55415344238281 } },
		}
		profile.frameSizes = { RXPFrame = { 343.6986389160156, 35.76005935668945 } }
		profile.windowScale = 1.1
	end
	local ok, err
	local function Enable()
		ok, err = pcall(rxp.fake.enable)
	end
	if skinFirst then
		K.Modules.Enable("Skins")
		env.RunTimers()
		Enable()
	else
		Enable()
		K.Modules.Enable("Skins")
		env.RunTimers()
	end
	return env, K, ns, rxp, ok, err
end

for _, case in ipairs({
	{ skinFirst = true, saved = false, label = "the skin starts before RestedXP enables" },
	{ skinFirst = false, saved = false, label = "RestedXP enables before the skin starts" },
	{ skinFirst = true, saved = true, label = "the skin starts first and RestedXP has saved places" },
	{ skinFirst = false, saved = true, label = "RestedXP enables first and has saved places" },
}) do
	local env, K, ns, rxp, ok, err = Boot(case.skinFirst, case.saved)
	local f = rxp.RXPFrame
	local current = f.CurrentStepFrame
	assert(ok, case.label .. ": RestedXP enables with no error, got " .. tostring(err))
	assert(rxp.enabled == true, case.label .. ": RestedXP finishes enabling, so its update loops start")
	assert(current:GetHeight() > 0, case.label .. ": the steps frame keeps a height before any guide loads, got " .. tostring(current:GetHeight()))

	rxp.SetStep(2)
	env.RunTimers()
	assert(ns.RestedXP.Rail.Placed(), case.label .. ": the rail places the guide once steps load")
	assert(current:GetHeight() > 0 and #current.framePool >= 2, case.label .. ": and the steps keep their height")
	rxp.SetStep(0)
	env.RunTimers()
	rxp.SetStep(2)
	env.RunTimers()
	assert(current:GetHeight() > 0, case.label .. ": steps that come back after a guide change get their height back")

	local arrow = rxp.arrowFrame
	local before = { arrow:GetPoint(1) }
	assert(before[1] == "TOP", case.label .. ": the arrow sits where RestedXP puts it, at the top of the screen")
	if case.saved then
		assert(before[2] == nil or before[2] == env.UIParent, case.label .. ": relative to the screen")
		assert(math.abs(before[4] - 11.56650161743164) < 1e-9 and math.abs(before[5] + 73.55415344238281) < 1e-9, case.label .. ": at the place the player saved, got " .. tostring(before[4]) .. ", " .. tostring(before[5]))
	end
	rxp.fake.arrow("Kill Prideclaw", 120, 1.2)
	env.RunTimers()
	assert(arrow:IsShown() and arrow:GetAlpha() == 1, case.label .. ": the waypoint arrow shows")
	assert(arrow:GetWidth() > 0 and arrow.texture:IsShown() and arrow.texture:GetAlpha() == 1, case.label .. ": with its texture drawn")
	assert(arrow.text:GetText() == "Kill Prideclaw\n(120yd)" and arrow.text:GetAlpha() > 0, case.label .. ": and its words")
	local after = { arrow:GetPoint(1) }
	assert(after[1] == before[1] and after[2] == before[2] and after[3] == before[3] and after[4] == before[4] and after[5] == before[5], case.label .. ": the skin never moves the arrow")
	assert(arrow:GetNumPoints() == 1, case.label .. ": and anchors it as RestedXP did")

	rxp.fake.check(HOOKED)
	assert(#env._errors == 0 and K.ErrorCount() == 0, case.label .. ": nothing raised, got " .. tostring(env._errors[1]))
end

print("skins restedxp enable ok")
