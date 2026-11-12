-- KstyleUI_Tooltips.lua: the tooltip paths the card reaches when a tooltip shows, with their time budgets in microseconds per call, for test-perf.lua.
local T = dofile("Tools/regression/tooltips_env.lua")

local SIZES = { { 260, 110 }, { 380, 160 } }

return {
	{
		name = "Tooltips GameTooltip shown for two units of different size: the card resized and its fade played",
		budget = 1000,
		calls = 50,
		setup = function()
			local env, K, ns = T.New()
			if not K.Modules.IsRunning("Tooltips") then
				assert(K.Modules.Enable("Tooltips"))
			end
			env.RunTimers()
			local tip = env.GameTooltip
			local glass = ns.Style.Glass(tip)
			local fade = ns.Style.Fade(tip)
			local root = K.Scale.Root()
			tip:ClearAllPoints()
			tip:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -120, 240)
			local onSize = glass._scripts.OnSizeChanged
			local turn = 0
			local function show()
				turn = turn % 2 + 1
				local size = SIZES[turn]
				T.BlizzardShow(tip, false)
				tip:SetSize(size[1], size[2])
				T.BlizzardShow(tip, true)
				onSize(glass, size[1], size[2])
			end
			show()
			show()
			assert(fade and fade:IsPlaying() and glass.chrome.ornament == nil, "the cost fixture plays the fade and places no crest")
			return env, show
		end,
	},
}
