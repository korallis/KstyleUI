-- test-skins-restedxp-boxes.lua: RestedXP's Active Targets and Active Items boxes dock under the guide's card on the story rail (KSTY-77, the owner's live Orbs HUD at 3456x2234, where they overlapped the card's foot at the places he once saved): at the card's width and edges, a small gap apart, inside the guide's slot, re-docked after RestedXP resizes them, kept out of RestedXP's saved places, and let be once the player drags one.
local S = dofile("Tools/regression/skins_env.lua")
local Fake = dofile("Tools/regression/restedxp_fake.lua")
local Quests = dofile("Tools/regression/quests_fake.lua")
local Geometry = dofile("Tools/regression/geometry.lua")
local Measure = dofile("Tools/regression/databars_env.lua")

local HOOKED = { SetAlpha = true, SetVertexColor = true, SetChecked = true, SetFont = true, SetFontObject = true, SetText = true, Show = true, Hide = true, SetShown = true, UpdateVisuals = true, SetMinMaxValues = true, SetStep = true, SetScale = true, StopMovingOrSizing = true, SetTexture = true, SetRotation = true, SetTexCoord = true }
local SCREENS = { { 1920, 1080, 1 }, { 3456, 2234, 768 / 1080 }, { 5120, 1440, 1 }, { 2383, 1540, 768 / 1080 } }
local LEE = {
	activeItemFrame = { "BOTTOMRIGHT", nil, "BOTTOMRIGHT", -47.74521255493164, 242.4930267333984 },
	activeTargetFrame = { "RIGHT", nil, "RIGHT", -191.4820404052734, -276.561767578125 },
}

local function Boot(screen, style)
	local rxp
	local saved = { version = 12, profiles = { Default = { Appearance = { uiScale = 16 / 19 }, Layout = { preset = "DPS" }, HudStyle = { style = style } } }, characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} }
	local env, K, ns = S.New({
		width = screen[1], height = screen[2], uiScale = screen[3], saved = saved,
		setup = function(e)
			e._textWidth = Measure.TextWidth
			Quests.Install(e, Quests.List(3))
			rxp = Fake.Install(e, {})
		end,
		before = function(e)
			Quests.Tracker(e, S.Blizzard(e))
		end,
	})
	local items, targets = rxp.activeItemFrame, rxp.targeting.activeTargetFrame
	for name, box in pairs({ activeItemFrame = items, activeTargetFrame = targets }) do
		local p = LEE[name]
		box:ClearAllPoints()
		box:SetPoint(p[1], env.UIParent, p[3], p[4], p[5])
	end
	rxp.settings.profile.framePositions = { activeItemFrame = { LEE.activeItemFrame }, activeTargetFrame = { LEE.activeTargetFrame } }
	K.Modules.Enable("Skins")
	S.LoadAddOn(env, "Blizzard_ObjectiveTracker")
	rxp.SetStep()
	rxp.targeting:UpdateTargetFrame(1, 0)
	rxp.UpdateItemFrame(nil, 1)
	env.RunTimers()
	S.W.Settle(env)
	env.RunTimers()
	return env, K, ns, rxp
end

local function Glass(K, frame)
	local root = K.Scale.Root()
	return assert(Geometry.ScaledRect(K.Skin.Parts(frame).backdrop, root._env.UIParent, root))
end

local function Near(a, b, tolerance)
	return math.abs(a - b) <= tolerance
end

local function Clear(a, b)
	return a.right <= b.left or b.right <= a.left or a.top <= b.bottom or b.top <= a.bottom
end

for _, screen in ipairs(SCREENS) do
	for _, style in ipairs({ "orbs", "frames" }) do
		local what = string.format("%dx%d %s", screen[1], screen[2], style)
		local env, K, ns, rxp = Boot(screen, style)
		local px = K.Scale.Pixel(1) + 0.01
		local edge = px + K.Scale.Pixel(1) / 2
		local gap = K.Tokens.Size("gapSmall")
		local items, targets = rxp.activeItemFrame, rxp.targeting.activeTargetFrame
		assert(items:IsShown() and targets:IsShown(), what .. ": both boxes show for the step")
		local guide, t, i = Glass(K, rxp.RXPFrame), Glass(K, targets), Glass(K, items)
		local slot = K.Setup.Story("DPS", true).guide
		for name, box in pairs({ targets = t, items = i }) do
			assert(Clear(box, guide), string.format("%s: the %s box keeps off the guide's card, box %.1f..%.1f card %.1f..%.1f", what, name, box.bottom, box.top, guide.bottom, guide.top))
			assert(Near(guide.bottom - box.top, gap, 2 * px), string.format("%s: the %s box docks a small gap under the card's foot, got %.2f", what, name, guide.bottom - box.top))
			assert(box.bottom >= slot.bottom - px, string.format("%s: the %s box stays in the guide's slot, got %.1f for %.1f", what, name, box.bottom, slot.bottom))
		end
		local half = (guide.right - guide.left - gap) / 2
		assert(Near(t.left, guide.left, edge) and Near(i.right, guide.right, edge) and Near(i.left - t.right, gap, 2 * px), string.format("%s: the two boxes share one row at the card's width within the guide's half-pixel snap, its gutter between them, got %.1f..%.1f and %.1f..%.1f for %.1f..%.1f", what, t.left, t.right, i.left, i.right, guide.left, guide.right))
		assert(Near(t.right - t.left, half, 2 * px) and Near(i.right - i.left, half, 2 * px), what .. ": each takes half the width")
		for name, box in pairs({ targets = targets, items = items }) do
			local caption = ns.RestedXP.Chrome.Caption(box.title.text)
			local glass = Glass(K, box)
			assert(caption:GetText() == (name == "items" and "ITEMS" or "TARGETS"), what .. ": the " .. name .. " box wears a compact caps header, got " .. tostring(caption:GetText()))
			local c = Geometry.ScaledRect(caption, env.UIParent, K.Scale.Root())
			assert(not c or c.right <= glass.right + px, what .. ": the " .. name .. " header fits its half")
		end
		if screen[1] == 3456 or style == "orbs" then
			assert(ns.RestedXP.Rail.Hidden() == 0, what .. ": the guide keeps its step on show above the boxes")
		end
		assert(items.savePosition == false and targets.savePosition == false, what .. ": RestedXP leaves the docked boxes out of its saved places")
		rxp.fake.logout()
		local saved = rxp.settings.profile.framePositions
		assert(saved.activeItemFrame[1][4] == LEE.activeItemFrame[4] and saved.activeTargetFrame[1][5] == LEE.activeTargetFrame[5], what .. ": the places the player saved stay in RestedXP's settings")

		rxp.UpdateItemFrame(nil, 16)
		env.RunTimers()
		S.W.Settle(env)
		env.RunTimers()
		guide, t, i = Glass(K, rxp.RXPFrame), Glass(K, targets), Glass(K, items)
		assert(Near(t.left, guide.left, edge) and Near(t.right, guide.right, edge) and Near(i.right, guide.right, edge) and i.left <= guide.left + edge and Near(t.bottom - i.top, gap, 2 * px), string.format("%s: overflowing items stack at full width; guide %.1f..%.1f, targets %.1f..%.1f, items %.1f..%.1f, gap %.1f", what, guide.left, guide.right, t.left, t.right, i.left, i.right, t.bottom - i.top))
		assert(ns.RestedXP.Chrome.Caption(items.title.text):GetText() == "ACTIVE ITEMS", what .. ": a full-width box keeps RestedXP's own caption")
		for n = 1, #items.buttonList do
			local button = items.buttonList[n]
			if button:IsShown() then
				local b = Geometry.ScaledRect(button, env.UIParent, K.Scale.Root())
				assert(b.right <= i.right + px, what .. ": every item sits on its box")
			end
		end

		rxp.UpdateItemFrame(nil, 0)
		env.RunTimers()
		S.W.Settle(env)
		env.RunTimers()
		assert(not items:IsShown(), what .. ": no items, no box")
		local alone = Glass(K, targets)
		local card = Glass(K, rxp.RXPFrame)
		assert(Near(card.bottom - alone.top, gap, 2 * px) and alone.bottom >= slot.bottom - px, what .. ": Active Targets stays docked alone")
		assert(Near(alone.left, card.left, edge) and Near(alone.right, card.right, edge), what .. ": and takes the card's full width within its half-pixel snap")

		rxp.fake.check(HOOKED)
		assert(#env._errors == 0 and K.ErrorCount() == 0, what .. ": " .. tostring(env._errors[1]))
	end
end

-- The player drags a box away: the rail lets both be, RestedXP saves the drag, and the other box goes back to the place
-- RestedXP had for it.
do
	local env, K, ns, rxp = Boot({ 1920, 1080, 1 }, "orbs")
	local items, targets = rxp.activeItemFrame, rxp.targeting.activeTargetFrame
	targets:ClearAllPoints()
	targets:SetPoint("CENTER", env.UIParent, "CENTER", -300, 40)
	targets:GetScript("OnMouseUp")(targets, "LeftButton")
	env.RunTimers()
	S.W.Settle(env)
	env.RunTimers()
	assert(ns.Skins.Setting("restedXP", "boxes") == false, "a drag turns docking off")
	assert(targets.savePosition ~= false and items.savePosition ~= false, "and gives RestedXP its boxes' places back")
	local point = { targets:GetPoint(1) }
	assert(point[1] == "CENTER" and point[4] == -300 and point[5] == 40, "the dragged box stays where the player put it")
	local saved = rxp.settings.profile.framePositions.activeTargetFrame
	assert(saved and saved[1][1] == "CENTER" and saved[1][4] == -300, "and RestedXP saves the drag")
	local ip = { items:GetPoint(1) }
	assert(ip[1] == LEE.activeItemFrame[1] and ip[4] == LEE.activeItemFrame[4] and ip[5] == LEE.activeItemFrame[5], "the other box goes back to its saved place")
	K.Options.Write("Skins", "restedXP.boxes", true)
	env.RunTimers()
	S.W.Settle(env)
	env.RunTimers()
	local guide, t = Glass(K, rxp.RXPFrame), Glass(K, targets)
	assert(math.abs(guide.bottom - t.top - K.Tokens.Size("gapSmall")) <= 2 * K.Scale.Pixel(1) + 0.02, "turning docking back on docks them again")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

-- A drag in combat: RestedXP's own save skips both docked boxes, and the rail waits for combat to end, then puts the
-- other box back and saves, so a logout never keeps the other box's docked place.
do
	local env, K, ns, rxp = Boot({ 1920, 1080, 1 }, "orbs")
	local items, targets = rxp.activeItemFrame, rxp.targeting.activeTargetFrame
	env.SetCombat(true)
	targets:ClearAllPoints()
	targets:SetPoint("CENTER", env.UIParent, "CENTER", -300, 40)
	targets:GetScript("OnMouseUp")(targets, "LeftButton")
	assert(items.savePosition == false, "in combat the undragged box stays out of RestedXP's saved places")
	rxp.fake.logout()
	local saved = rxp.settings.profile.framePositions.activeItemFrame
	assert(saved[1][1] == LEE.activeItemFrame[1] and saved[1][4] == LEE.activeItemFrame[4], "a logout in combat keeps the undragged box's own saved place")
	env.SetCombat(false)
	env.RunTimers()
	S.W.Settle(env)
	saved = rxp.settings.profile.framePositions
	assert(saved.activeTargetFrame[1][1] == "CENTER" and saved.activeTargetFrame[1][4] == -300, "after combat RestedXP saves the drag")
	assert(saved.activeItemFrame[1][1] == LEE.activeItemFrame[1] and saved.activeItemFrame[1][4] == LEE.activeItemFrame[4], "and the undragged box's own place")
	assert(ns.Skins.Setting("restedXP", "boxes") == false, "docking is off")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

print("skins restedxp boxes ok")
