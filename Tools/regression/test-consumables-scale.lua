-- test-consumables-scale.lua: consumables never change staging's automatic HUD scale, including custom grids.
local CoreEnv = dofile("Tools/regression/core_env.lua")
local env, K = CoreEnv.New({ fit = true })
CoreEnv.Boot(env)
K.Store.Module("DataBars").strip = { placement = "rail" }
local L = K.Setup.Layouts
local frames = { 15 / 16, 63 / 64, 63 / 64, 31 / 32 }
for _, style in ipairs({ "frames", "medallions" }) do
	K.Options.Write("HudStyle", "style", style)
	for index, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
		for _, name in ipairs(L.Names()) do
			local enabled = L.Enabled(name)
			enabled["consumables.bar"] = false
			local cap, fits = L.ScaleLimit(screen[1], screen[2], name, enabled)
			local baseline = K.Scale.Auto(screen[2], cap, fits)
			local expected = style == "medallions" and 15 / 16 or frames[index]
			assert(baseline == expected, "every preset keeps the " .. style .. " DPS auto scale for " .. name .. " " .. screen[1])
			for _, rows in ipairs({ 2, 1, 3 }) do
				K.Store.Module("ActionBars").consumables = { rows = rows }
				enabled["consumables.bar"] = true
				local limit, predicate = L.ScaleLimit(screen[1], screen[2], name, enabled)
				local auto = K.Scale.Auto(screen[2], limit, predicate)
				local label = string.format("%dx%d %s %s %d rows", screen[1], screen[2], style, name, rows)
				assert(auto == baseline, label .. ": exclude consumables from HUD auto scale; got " .. auto .. " expected " .. baseline)
			end
		end
	end
end
local enabled = L.Enabled("DPS")
K.Store.Module("ActionBars").consumables = { rows = 2 }
local span = L.PrepareFits("DPS", 5120, 1440, enabled, nil, true).span
K.Store.Module("ActionBars").consumables = { rows = 1, size = 64, spacing = 12 }
assert(L.PrepareFits("DPS", 5120, 1440, enabled, nil, true).span == span, "excluded consumables must not change the scale search step")
print("consumables scale ok: staging auto scale unchanged at four sizes x both styles x three presets x three grids")
