-- test-meters-placement.lua: damage and a solo threat meter stay at their presets across screens and styles, while saved positions win.
local M = dofile("Tools/regression/meters_env.lua")
local Geometry = dofile("Tools/regression/geometry.lua")

for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	for _, style in ipairs({ "frames", "orbs", "medallions" }) do
		for _, size in ipairs({ "auto", 16 / 19 }) do
			local env, K, ns = M.New({ width = screen[1], height = screen[2], followRole = true,
				setup = function(e) e._fitScale, e._size = true, size end,
			})
			assert(K.Setup.Apply({ layout = "DPS", modules = { Meters = true } }))
			env.RunTimers()
			local root, layouts = K.Scale.Root(), K.Setup.Layouts
			local rect = assert(Geometry.Rect(ns.Damage.holder, root))
			local place = layouts.Default("meters.damage")
			local left, bottom, right, top = layouts.Rect({ width = rect.right - rect.left, height = rect.top - rect.bottom }, place, root:GetWidth(), root:GetHeight())
			local label = string.format("%s %dx%d size %s", style, screen[1], screen[2], size)
			assert(math.abs(rect.left - left) < 1 and math.abs(rect.bottom - bottom) < 1 and math.abs(rect.right - right) < 1 and math.abs(rect.top - top) < 1,
				label .. ": restore the damage meter to the layout's lower right rail preset")
			assert(rect.top < root:GetHeight() * 0.4, label .. ": keep damage below the nameplate band")
			assert(K.Layout.Set("meters.damage", "x", -90))
			assert(K.Layout.Set("meters.damage", "y", 60))
			env.RunTimers()
			local saved = assert(Geometry.Rect(ns.Damage.holder, root))
			assert(math.abs(saved.right - (root:GetWidth() - 90)) < 1 and math.abs(saved.bottom - 60) < 1, label .. ": preserve the player's saved meter position")
		end
	end
end
for _, key in ipairs({ "meters.damage", "medallions:meters.damage" }) do
	local env, K, ns = M.New({ saved = { version = 38, account = { setupSeen = true },
		profiles = { Default = { } },
		layouts = { Default = { [key] = { anchor = "BOTTOMRIGHT", x = -90, y = 60 } } },
	} })
	M.Enable(env, K)
	local rect, root = Geometry.Rect(ns.Damage.holder, K.Scale.Root()), K.Scale.Root()
	assert(math.abs(rect.right - (root:GetWidth() - 90)) < 1 and math.abs(rect.bottom - 60) < 1,
		key .. ": keep positions saved both before and after the Medallions meter override")
end
for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }) do
	local env, K, ns = M.New({ width = screen[1], height = screen[2], followRole = true })
	assert(K.Setup.Apply({ layout = "Tank", modules = { Meters = true } }))
	env.RunTimers()
	local root = K.Scale.Root()
	local rect = assert(Geometry.Rect(ns.Threat.holder, root))
	local left, bottom = K.Setup.Layouts.Rect({ width = rect.right - rect.left, height = rect.top - rect.bottom }, K.Setup.Layouts.Default("meters.threat"), root:GetWidth(), root:GetHeight())
	assert(math.abs(rect.left - left) < 1 and math.abs(rect.bottom - bottom) < 1, string.format("medallions %dx%d: put a solo threat meter at the layout preset, not mid-screen", screen[1], screen[2]))
end
print("damage meter placement ok: 4 screens, 3 styles, automatic and reference sizes; saved positions win")
