-- KstyleUI_Tooltips.lua: the tooltip paths an ornament reaches, with their time budgets in microseconds per call, for test-perf.lua.
local T = dofile("Tools/regression/tooltips_env.lua")

local SIZES = { { 260, 110 }, { 380, 160 } }

return {
	{
		name = "Tooltips GameTooltip shown at Full for two units of different size, crest re-placed",
		budget = 1000,
		calls = 50,
		setup = function()
			local env, K, ns = T.New()
			if not K.Modules.IsRunning("Tooltips") then
				assert(K.Modules.Enable("Tooltips"))
			end
			K.Options.Write("Widgets", "ornaments", "Full")
			env.RunTimers()
			local tip = env.GameTooltip
			local glass = ns.Style.Glass(tip)
			local crest = glass.chrome.ornament
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
			assert(crest.used > 0 and crest.textures[1]:IsShown(), "the cost fixture places a crest at Full")
			return env, show
		end,
	},
}
