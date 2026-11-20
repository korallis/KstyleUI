-- test-hud-attached.lua: cooldowns use attached defaults, retain custom positions and offer the previous placement.
local C = dofile("Tools/regression/cooldowns_env.lua")
local G = dofile("Tools/regression/geometry.lua")
local env, K, ns = C.New({ cooldowns = C.Sample() })
C.Enable(env, K)
assert(K.Store.Module("Cooldowns").attached == true, "Cooldowns needs an attached placement setting, on by default")
for _, style in ipairs({ "frames", "orbs", "medallions" }) do
	K.Options.Write("HudStyle", "style", style)
	env.RunTimers()
	local L = K.Setup.Layouts
	for _, count in ipairs({1,3,6,12}) do
		local p = L.Place("DPS", style, K.Scale.Aspect(), "cooldowns.essential")
		local cast = L.Place("DPS", style, K.Scale.Aspect(), "unitframes.castbar.player")
		assert(style == "medallions" and p.x == 0 and p.y > cast.y + 49 or style ~= "medallions" and math.abs(p.y - cast.y) < 100, style .. ": centre Medallions above the casts; keep other styles by the cast area")
		local cfg = ns.Settings.current.essential
		assert(ns.Grid.Capacity(cfg) >= count, "default essential grid must accommodate twelve icons")
		local x1 = ns.Grid.Offset(1, count, cfg)
		local xn = ns.Grid.Offset(math.min(count, cfg.columns), count, cfg)
		local width = ns.Grid.Size(cfg)
		assert(math.abs((x1 + xn + cfg.size) / 2 - width / 2) < 0.01, "short rows grow from a fixed centre")
		local row = ns.Mirror.Row("essential")
		row:SetCount(count)
		assert(row.count == count, "show every essential icon")
		for i = 1, count do
			local r = assert(G.ScaledRect(row.icons[i], env.UIParent, K.Scale.Root()))
			local castSize = style == "medallions" and {width=300,height=20} or L.Element("unitframes.castbar.player")
			local l,b,rr,t = L.Rect(castSize, cast, K.Scale.Root():GetWidth(), K.Scale.Root():GetHeight())
			assert(r.right <= l or r.left >= rr or r.top <= b or r.bottom >= t, "cooldowns leave casts clear")
			if style == "medallions" then assert(r.bottom >= cast.y + 49, "essential cooldowns stay above both casts") end
		end
		local utility = ns.Mirror.Row("utility")
		utility:SetCount(count)
		assert(utility.count == count, "show every utility icon")
		for i = 1, count do
			local r = assert(G.ScaledRect(utility.icons[i], env.UIParent, K.Scale.Root()))
			for j = 1, count do
				local e = assert(G.ScaledRect(row.icons[j], env.UIParent, K.Scale.Root()))
				assert(r.right <= e.left or r.left >= e.right or r.top <= e.bottom or r.bottom >= e.top, "essential and utility icons stay separate")
			end
		end
	end
	for _, screen in ipairs({ {1920,1080}, {2560,1440}, {3440,1440}, {3456,2234}, {3840,2160}, {5120,1440} }) do
		assert(L.Fits("DPS", screen[1], screen[2], 0.6, nil, nil, style), style .. ": attached defaults fit at " .. screen[1] .. "x" .. screen[2])
	end
end
K.Options.Write("Cooldowns", "essential.columns", 6)
K.Options.Write("Cooldowns", "essential.rows", 1)
assert(ns.Settings.current.essential.columns == 6 and ns.Settings.current.essential.rows == 1, "explicit grid settings override automatic placement defaults")
K.Options.Write("HudStyle", "style", "medallions")
K.Layout.Update("cooldowns.essential", {anchor="BOTTOM", x=-470, y=260}, true)
K.Options.Write("Cooldowns", "attached", false)
env.RunTimers()
assert(K.Layout.Get("cooldowns.essential").x == -470, "the placement toggle preserves a custom position")
K.Layout.Reset("cooldowns.essential")
assert(math.abs(K.Layout.Get("cooldowns.essential").y - K.Setup.Layouts.Default("cooldowns.essential").y) < 1, "off restores today's placement")
assert(#env._errors == 0, tostring(env._errors[1]))
print("attached cooldown defaults, 1/3/6/12 icons, legacy option and custom positions ok")

do
	local saved = { version=35, profiles={ Default={HudStyle={style="medallions"}} }, layouts={Default={
		["cooldowns.essential"]={anchor="BOTTOM",x=0,y=K.Setup.Layouts.Default("cooldowns.essential").y},
		["cooldowns.utility"]={anchor="BOTTOM",x=510,y=305,scale=1.2},
	}}, account={setupSeen=true}, characters={}, devlog={} }
	local _, upgraded = C.New({saved=saved})
	local layout = upgraded.Store.Layout()
	assert(layout["cooldowns.essential"] == nil, "migrate only the old default")
	assert(layout["medallions:cooldowns.utility"].x == 510 and layout["medallions:cooldowns.utility"].scale == 1.2, "preserve custom positions and size in Medallions")
end
