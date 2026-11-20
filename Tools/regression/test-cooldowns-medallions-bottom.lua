-- test-cooldowns-medallions-bottom.lua: centred cooldowns grow above the casts from the essential row with empty and full utility grids.
local C = dofile("Tools/regression/cooldowns_env.lua")
local Load = dofile("Tools/regression/load_files.lua")
local G = dofile("Tools/regression/geometry.lua")
for _, screen in ipairs({ {1920,1080}, {2560,1440}, {5120,1440}, {3840,2160} }) do
	local env, K = C.W.New({ boot = false, width = screen[1], height = screen[2], size = "auto", fit = true, setup = function(e)
		C.Install(e)
	end })
	Load(C.Files(), env)
	C.CoreEnv.Boot(env)
	K.Options.Write("HudStyle", "style", "medallions")
	C.Enable(env, K)
	env.RunTimers()
	local ns = env._addons.KstyleUI_Cooldowns
	local essential, utility = ns.Mirror.Row("essential"), ns.Mirror.Row("utility")
	local L = K.Setup.Layouts
	local cast = L.Place("DPS", "medallions", K.Scale.Aspect(), "unitframes.castbar.target")
	local castTop = cast.y + L.MEDALLIONS_UNITS.cast[2]
	local previous
	for _, count in ipairs({0, 12}) do
		utility:SetCount(count)
		essential:SetCount(6)
		local bottom = math.huge
		for _, row in ipairs({essential, utility}) do
			for i = 1, row.count do
				local r = assert(G.ScaledRect(row.icons[i], env.UIParent, K.Scale.Root()))
				bottom = math.min(bottom, r.bottom)
			end
		end
		local gap = bottom - castTop
		print(string.format("%dx%d utility=%d gap=%.2f", screen[1], screen[2], count, gap))
		assert(math.abs(gap - 8) < 1.1, "anchor the cooldown block bottom eight units above the top cast; essential must sit nearest the casts")
		assert(not previous or math.abs(gap - previous) < 0.01, "empty utility must leave the same small gap as full utility")
		previous = gap
	end
	assert(#env._errors == 0, tostring(env._errors[1]))
end
print("Medallions cooldown block bottom stays by the casts at all four owner screens")
