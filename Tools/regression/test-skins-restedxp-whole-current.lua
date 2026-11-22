-- test-skins-restedxp-whole-current.lua: when the guide's band cannot hold every step, the guide's card still shows every line of the current step with its tick box taking the mouse, so the player can skip it (RestedXP completes a step only once every line is ticked); only later steps rest under the "more" line. After the hidden steps RestedXP keeps in its stack at height 1 (GuideWindow.lua sets a hidden step's height to 1 and anchors the next 5 under it), the current step still ends inside the steps' frame.
local S = dofile("Tools/regression/skins_env.lua")
local Fake = dofile("Tools/regression/restedxp_fake.lua")
local Quests = dofile("Tools/regression/quests_fake.lua")
local Scene = dofile("Tools/render/scene.lua")

for _, count in ipairs({ 1, 3 }) do
	local rxp
	local env, K = S.New({
		width = 3840, height = 2160,
		saved = { version = 42, profiles = { Default = {} }, characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} },
		setup = function(e)
			e._size, e._fitScale = "auto", true
			e._textWidth = function(text, path, size) return Scene.TextWidth(text, size, path) end
			Quests.Install(e, Quests.List(3))
			rxp = Fake.Install(e, {})
		end,
		before = function(e) Quests.Tracker(e, S.Blizzard(e)) end,
	})
	K.Modules.Enable("Skins")
	rxp.SetStep(count, 2)
	local pool = rxp.RXPFrame.CurrentStepFrame.framePool
	for _, step in ipairs(pool) do
		for _, row in ipairs(step.elements) do
			row:EnableMouse(true)
			row.button:EnableMouse(true)
		end
	end
	env.RunTimers()
	S.W.Settle(env)
	env.RunTimers()
	local first = pool[1]
	assert(first:GetAlpha() > 0, count .. " steps: the current step shows")
	for e, row in ipairs(first.elements) do
		assert(row:GetAlpha() > 0, count .. " steps: line " .. e .. " of the current step shows")
		assert(row.button:IsMouseEnabled(), count .. " steps: line " .. e .. "'s tick box takes the mouse")
	end
end

do
	local rxp
	local env, K, ns = S.New({
		width = 1920, height = 1080,
		setup = function(e)
			e._size, e._fitScale = "auto", true
			rxp = Fake.Install(e, {})
		end,
	})
	K.Modules.Enable("Skins")
	local current = rxp.RXPFrame.CurrentStepFrame
	for _, hidden in ipairs({ 0, 1, 3, 5 }) do
		rxp.SetStep(hidden + 2, 14)
		env.RunTimers()
		for i = 1, hidden do
			local step = current.framePool[i]
			step:SetAlpha(0)
			step:SetHeight(1)
			step:EnableMouse(false)
		end
		ns.RestedXP.Rail.Fit()
		local last = current.framePool[hidden + 1].elements[2].button
		assert(ns.RestedXP.Rail.Hidden() == 1, hidden .. " hidden steps: the later step rests under the more line")
		assert(last:GetBottom() >= current:GetBottom(), hidden .. " hidden steps: the current step's last tick box ends inside the steps' frame, got " .. last:GetBottom() .. " under " .. current:GetBottom())
	end
end

print("skins restedxp whole current ok")
