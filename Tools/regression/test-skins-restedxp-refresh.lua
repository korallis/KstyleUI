-- test-skins-restedxp-refresh.lua: an unchanged RestedXP refresh keeps the composed guide card's geometry and visibility, before the next timer as well as after it.
local S = dofile("Tools/regression/skins_env.lua")
local Fake = dofile("Tools/regression/restedxp_fake.lua")
local Quests = dofile("Tools/regression/quests_fake.lua")
local Geometry = dofile("Tools/regression/geometry.lua")

for _, screen in ipairs({ { 5120, 1440 }, { 1920, 1080 }, { 3456, 2234 } }) do
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
	rxp.SetStep(1)
	env.RunTimers()
	S.W.Settle(env)
	env.RunTimers()
	local f = rxp.RXPFrame
	local card = ns.RestedXP.Chrome.Card(f)
	local glass = K.Skin.Parts(f).backdrop
	local counts = {}
	for _, object in ipairs({ card, glass, glass.chrome }) do
		for _, method in ipairs({ "Restyle", "SetAlpha", "Show", "Hide", "ClearAllPoints", "SetPoint" }) do
			local original = object[method]
			if type(original) == "function" then
				object[method] = function(self, ...)
					counts[method] = (counts[method] or 0) + 1
					return original(self, ...)
				end
			end
		end
	end
	local function Rect()
		return assert(Geometry.Rect(card, env.UIParent))
	end
	local function Same(before, name)
		local after = Rect()
		assert(math.abs(before.top - after.top) < 0.01 and math.abs(before.bottom - after.bottom) < 0.01,
			string.format("%s: unchanged refresh blinks the guide card from %.2f to %.2f units; preserve its composed layout before the next timer", name, before.top - before.bottom, after.top - after.bottom))
		assert(f:IsShown() and card:IsShown() and glass:IsShown() and f:GetAlpha() == 1 and card:GetAlpha() == 1 and glass:GetAlpha() == 1, name .. ": guide stays shown at full alpha")
	end
	local refreshes = {
		{ "UpdateText", f.CurrentStepFrame.UpdateText },
		{ "UpdateVisuals", function() f:UpdateVisuals() end },
		{ "SetStep", rxp.SetStep },
		{ "Refit", function() ns.RestedXP.Chrome.Refit(f) end },
		{ "same size", function() f:SetSize(f:GetWidth(), f:GetHeight()) end },
		{ "footer alpha", rxp.HideTimers },
	}
	for _, refresh in ipairs(refreshes) do
		local before = Rect()
		counts = {}
		for _ = 1, 10 do
			refresh[2]()
			Same(before, refresh[1])
			env.RunTimers()
			Same(before, refresh[1] .. " timers")
		end
		print(string.format("%dx%d %s x10: restyles=%d alpha=%d show=%d hide=%d clear=%d anchors=%d", screen[1], screen[2], refresh[1], counts.Restyle or 0, counts.SetAlpha or 0, counts.Show or 0, counts.Hide or 0, counts.ClearAllPoints or 0, counts.SetPoint or 0))
		assert(next(counts) == nil, refresh[1] .. ": unchanged card must do no repeated restyle, opacity or anchor work")
	end
	assert(K.Skin.Parts(f).fade == nil, "guide refreshes never install an open fade")
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

print("skins restedxp refresh ok")
