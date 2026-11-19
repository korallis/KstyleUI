-- test-skins-restedxp-refresh.lua: an unchanged RestedXP refresh keeps the composed guide card's geometry and visibility, before the next timer as well as after it.
local S = dofile("Tools/regression/skins_env.lua")
local Fake = dofile("Tools/regression/restedxp_fake.lua")
local Quests = dofile("Tools/regression/quests_fake.lua")
local Geometry = dofile("Tools/regression/geometry.lua")

for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 }, { 3456, 2234 } }) do
	local rxp
	local env, K, ns = S.New({
		width = screen[1], height = screen[2],
		saved = { version = 12, profiles = { Default = { Appearance = { uiScale = 16 / 19 }, HudStyle = { style = "Medallions" } } }, characters = {}, layouts = {}, account = { setupSeen = true }, devlog = {} },
		setup = function(e)
			Quests.Install(e, Quests.List(3))
			rxp = Fake.Install(e, {})
		end,
		before = function(e) Quests.Tracker(e, S.Blizzard(e)) end,
	})
	K.Modules.Enable("Skins")
	S.LoadAddOn(env, "Blizzard_ObjectiveTracker")
	rxp.SetStep(1, 2)
	env.RunTimers()
	S.W.Settle(env)
	env.RunTimers()
	local f = rxp.RXPFrame
	local card = ns.RestedXP.Chrome.Card(f)
	local glass = K.Skin.Parts(f).backdrop
	local counts, calls = {}, {}
	local tree = Geometry.Tree(f)
	tree[#tree + 1] = glass.chrome
	for _, object in ipairs(tree) do
		for _, method in ipairs({ "Restyle", "SetAlpha", "SetVertexColor", "SetColorTexture", "Show", "Hide", "ClearAllPoints", "SetPoint" }) do
			local original = object[method]
			if type(original) == "function" then
				object[method] = function(self, ...)
					calls[method] = (calls[method] or 0) + 1
					if object == card or object == glass or object == glass.chrome then
						counts[method] = (counts[method] or 0) + 1
					end
					return original(self, ...)
				end
			end
		end
	end
	local function Rect()
		return assert(Geometry.Rect(card, env.UIParent))
	end
	local function Opacity()
		local snapshot = {}
		for _, object in ipairs(Geometry.Tree(f)) do
			local alpha, node = 1, object
			while node do
				alpha = alpha * (node:IsShown() and node:GetAlpha() or 0)
				node = node:GetParent()
			end
			snapshot[object] = alpha
		end
		return snapshot
	end
	local visible = Opacity()
	local function Same(before, name)
		local after = Rect()
		assert(math.abs(before.top - after.top) < 0.01 and math.abs(before.bottom - after.bottom) < 0.01,
			string.format("%s: unchanged refresh blinks the guide card from %.2f to %.2f units; preserve its composed layout before the next timer", name, before.top - before.bottom, after.top - after.bottom))
		assert(f:IsShown() and card:IsShown() and glass:IsShown() and f:GetAlpha() == 1 and card:GetAlpha() == 1 and glass:GetAlpha() == 1, name .. ": guide stays shown at full alpha")
		for object, alpha in pairs(Opacity()) do
			assert(alpha == visible[object], name .. ": refresh changes a region's visible alpha or shown state")
		end
	end
	local refreshes = {
		{ "UpdateText", f.CurrentStepFrame.UpdateText },
		{ "UpdateVisuals", function() f:UpdateVisuals() end },
		{ "SetStep", rxp.SetStep },
		{ "Refit", function() ns.RestedXP.Chrome.Refit(f) end },
		{ "same size", function() f:SetSize(f:GetWidth(), f:GetHeight()) end },
		{ "footer alpha", rxp.HideTimers },
		{ "window alpha", function() f:SetAlpha(1) end },
	}
	for _, refresh in ipairs(refreshes) do
		local before = Rect()
		counts, calls = {}, {}
		for _ = 1, 10 do
			refresh[2]()
			Same(before, refresh[1])
			env.RunTimers()
			Same(before, refresh[1] .. " timers")
		end
		print(string.format("%dx%d %s x10: restyles=%d alpha=%d show=%d hide=%d clear=%d anchors=%d", screen[1], screen[2], refresh[1], counts.Restyle or 0, counts.SetAlpha or 0, counts.Show or 0, counts.Hide or 0, counts.ClearAllPoints or 0, counts.SetPoint or 0))
		print(string.format("  whole tree including RestedXP: alpha=%d vertex=%d color=%d show=%d hide=%d clear=%d anchors=%d", calls.SetAlpha or 0, calls.SetVertexColor or 0, calls.SetColorTexture or 0, calls.Show or 0, calls.Hide or 0, calls.ClearAllPoints or 0, calls.SetPoint or 0))
		assert(next(counts) == nil, refresh[1] .. ": unchanged card must do no repeated restyle, opacity or anchor work")
	end
	env.SetCombat(true)
	local combat = Rect()
	counts = {}
	f.CurrentStepFrame.UpdateText()
	f:UpdateVisuals()
	env.RunTimers()
	Same(combat, "combat refresh")
	assert(next(counts) == nil, "combat refresh retains the composed card while protected placement waits")
	env.SetCombat(false)
	env.RunTimers()
	local before = Rect()
	rxp.fake.guide({ { title = "Step 95", elements = { { text = "Updated quest progress: 1/7" }, { text = "Return to the quest giver" } } } })
	rxp.SetStep(1)
	assert(f.CurrentStepFrame.framePool[1].elements[1].text:GetText() == "Updated quest progress: 1/7", "real content updates in place")
	Same(before, "new content")
	env.RunTimers()
	Same(before, "new content timers")
	for _, n in ipairs({ 20, 1 }) do
		local elements = {}
		for i = 1, n do elements[i] = { text = "Updated quest progress: 1/7" } end
		rxp.fake.guide({ { title = "Step 96", elements = elements } })
		rxp.SetStep(1)
		env.RunTimers()
		assert(f:GetAlpha() == 1 and card:IsShown() and glass:IsShown(), "larger and smaller content updates without hiding or fading the window")
		if n == 1 then
			assert(ns.RestedXP.Rail.Hidden() == 0 and f.CurrentStepFrame.framePool[1].elements[1]:GetAlpha() == 1, "shrinking content clears the overflow cut; composed blank space must not consume the step's room")
		end
	end
	K.Options.Write("Skins", "restedXP.compose", false)
	env.RunTimers()
	assert(ns.RestedXP.Chrome.Path(f).cardHeight == nil, "turning composition off restores bottom anchoring")
	K.Options.Write("Skins", "restedXP.compose", true)
	env.RunTimers()
	assert(ns.RestedXP.Chrome.Path(f).cardHeight ~= nil, "turning composition on restores the shared height")
	K.Options.Write("Skins", "restedXP.rail", false)
	env.RunTimers()
	assert(ns.RestedXP.Chrome.Path(f).cardHeight == nil, "releasing the rail restores RestedXP's natural card")
	assert(K.Skin.Parts(f).fade == nil, "guide refreshes never install an open fade")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

print("skins restedxp refresh ok")
