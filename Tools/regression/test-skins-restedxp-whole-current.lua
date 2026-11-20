-- test-skins-restedxp-whole-current.lua: when the rail's band cannot hold even one whole step, the guide's card still shows every line of the current step with its tick box taking the mouse, so the player can skip it (RestedXP completes a step only once every line is ticked); only later steps rest under the "more" line.
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

print("skins restedxp whole current ok")
