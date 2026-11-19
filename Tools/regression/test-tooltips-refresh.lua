-- test-tooltips-refresh.lua: periodic item tooltip refreshes do not restart their fade from alpha zero.
local T = dofile("Tools/regression/tooltips_env.lua")

local function Plays(group)
	local count = 0
	for _, call in ipairs(group._calls) do
		if call.method == "Play" then count = count + 1 end
	end
	return count
end

for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	local env, K, ns = T.New({ width = screen[1], height = screen[2] })
	assert(K.Modules.Enable("Tooltips") and K.Modules.IsRunning("Tooltips"), tostring(env._errors[1]))
	local tip, fade = env.GameTooltip, ns.Style.Fade(env.GameTooltip)
	assert(fade._anims[1]._state.FromAlpha[1] == 0, "each fade Play resets alpha to zero")
	for _, surface in ipairs({ { "Auction", "ANCHOR_RIGHT" }, { "Merchant", "ANCHOR_RIGHT" }, { "Quest reward", "ANCHOR_RIGHT" }, { "Bag", "ANCHOR_NONE" } }) do
		local owner = env.CreateFrame("Button", nil, env.UIParent)
		-- AH SharedTemplates.lua:112-136 installs OnEnter as ItemButton.UpdateTooltip.
		-- GameTooltip.lua:451-458 calls it every 0.2s; SetOwner/content may hide then re-show in that call.
		owner.UpdateTooltip = function(self, hide)
			if hide then T.BlizzardShow(tip, false) end
			tip:SetOwner(self, surface[2])
			tip:AddLine(surface[1] .. " item")
			T.BlizzardShow(tip, true)
		end
		local before = Plays(fade)
		owner:UpdateTooltip()
		assert(Plays(fade) == before + 1, surface[1] .. ": a new hover fades in")
		T.W.FinishGroups(env)
		for i = 1, 10 do
			env._now = env._now + 0.2
			owner:UpdateTooltip(i % 2 == 0)
			env.RunTimers()
			assert(Plays(fade) == before + 1, surface[1] .. ": UpdateTooltip restarted the alpha-zero fade")
			assert(tip:GetAlpha() == 1 and not fade:IsPlaying(), "a refreshed tooltip stays opaque")
			assert(tip:GetOwner() == owner and tip._anchor[1] == surface[2], "refresh keeps native ownership and anchoring")
			assert(tip:GetLeftLine(1):GetText() == surface[1] .. " item", "content still refreshes")
		end
		T.BlizzardShow(tip, false)
		env.RunTimers()
		owner:UpdateTooltip()
		assert(Plays(fade) == before + 2, "leaving and re-entering the same item gets a fresh fade")
		T.BlizzardShow(tip, false)
		env.RunTimers()
	end
	K.Motion.SetReducedMotion(true)
	local before = Plays(fade)
	T.BlizzardShow(tip, true)
	assert(Plays(fade) == before, "Reduced motion still disables tooltip fades")
	assert(ns.Settings.Get("cursorX") == 0 and ns.Settings.Get("cursorY") == 0, "original cursor offsets remain the defaults")
	K.Options.Write("Tooltips", "cursorX", -16)
	assert(ns.Settings.Get("cursorX") == -16, "negative cursor offsets remain available")
	assert(#env._errors == 0, tostring(env._errors[1]))
	print("tooltip refresh stable at " .. screen[1] .. "x" .. screen[2])
end

print("tooltips refresh ok")
