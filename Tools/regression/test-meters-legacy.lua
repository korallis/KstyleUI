-- test-meters-legacy.lua: the row-style switch restores both previous looks and saved threat controls without taking world clicks.
local M = dofile("Tools/regression/meters_env.lua")
for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	for _, style in ipairs({ "frames", "orbs", "medallions" }) do
		local env, K, ns = M.New({ width = screen[1], height = screen[2], saved = { version = 38,
			profiles = { Default = { HudStyle = { style = style }, Meters = { nameplateRows = false } } },
		}, setup = function(e)
			e._group.size = 5
			e._units.target = { name = "Boss", hostile = true }
			e._threat.player = { false, 1, 75, 75, 750000 }
		end })
		M.Enable(env, K)
		local damage, threat = ns.Damage.list, ns.Threat.list
		for _ = 1, 2 do
			assert(not ns.Get("nameplateRows") and not threat.block and damage.block, "Off restores the two previous row layouts")
			assert(ns.Get("damage.rowHeight") == 18 and ns.Get("damage.outline") == "", "Off restores the damage row defaults")
			assert(ns.Get("threat.texture") == K.Tokens.Texture("barGlass"), "Off restores the threat texture default")
			local row = threat.rows[1]
			assert(math.abs(row.bar:GetHeight() - K.Widgets.Snap(row.bar, 4)) < 0.01, "previous threat rows use a four-unit class pill")
			assert(not row.frame:IsMouseEnabled(), "threat rows must pass clicks to the world")
			assert(ns.Logic.Abbreviate(12400) == "12K" and env.Reveal(ns.Logic.Abbreviate(env.Secret(12400))) == "12K", "Off restores plain and secret number formatting")
			M.Write(env, K, "damage.rowHeight", 27)
			M.Write(env, K, "damage.outline", "OUTLINE")
			assert(ns.Get("damage.rowHeight") == 27 and ns.Get("damage.outline") == "OUTLINE", "previous damage controls can select the shared style defaults")
			M.Write(env, K, "damage.rowHeight", 18)
			M.Write(env, K, "damage.outline", "")
			M.Write(env, K, "threat.rowHeight", 35)
			M.Write(env, K, "threat.fontSize", 15)
			assert(ns.Get("threat.rowHeight") == 35 and ns.Get("threat.fontSize") == 15, "the previous threat controls keep their saved appearance")
			M.Write(env, K, "nameplateRows", true)
			assert(damage.block and threat.block and damage.plate and threat.plate, "On restores the shared nameplate-style builder")
			assert(ns.Get("threat.rowHeight") == ns.Get("damage.rowHeight") and ns.Get("threat.fontSize") == ns.Get("damage.fontSize"), "On shares the damage appearance")
			assert(damage.holder:GetHeight() == threat.holder:GetHeight() and damage.panel:GetHeight() == threat.panel:GetHeight(), "Both cards have equal holder and visible heights")
			assert(damage.capacity == threat.capacity, "Both cards fit the same row count")
			assert(not row.frame:IsMouseEnabled(), "the shared style also keeps world clicks working")
			assert(ns.Logic.Abbreviate(12400) == "12.4K" and env.Reveal(ns.Logic.Abbreviate(env.Secret(12400))) == "12.4K", "On restores shared number formatting")
			M.Write(env, K, "nameplateRows", false)
			assert(ns.Get("threat.rowHeight") == 35 and K.Store.Module("Meters").threat.fontSize == 15, "toggling back retains saved threat appearance")
			M.Write(env, K, "threat.rowHeight", 18)
			M.Write(env, K, "threat.fontSize", 12)
		end
		env._group.size = 0
		env.FireEvent("GROUP_ROSTER_UPDATE")
		env.RunTimers()
		assert(not ns.Threat.paired and not threat.panel:IsShown(), "solo group-only threat releases the pair")
		env._group.size = 5
		env.FireEvent("GROUP_ROSTER_UPDATE")
		env.RunTimers()
		assert(ns.Threat.paired and threat.panel:IsShown(), "joining a group pairs the visible cards again")
		M.Write(env, K, "damage.mode", "skin")
		local enabled = K.Setup.Layouts.Enabled("DPS", K.Store.Profile())
		assert(not enabled["meters.damage"] and enabled["meters.threat"], "Blizzard skin mode reserves only the independent KstyleUI threat card")
		assert(not ns.Threat.paired, "Blizzard's game-managed windows keep their independent placement")
		assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
	end
end
print("meter previous-look switch ok: saved appearance, click-through, equal pair, skin-mode fit; 3 styles and 4 screens")
