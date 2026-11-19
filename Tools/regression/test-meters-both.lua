-- test-meters-both.lua: DPS and manual meter choices share equal-width, separate cards across styles, layouts and screens.
local M = dofile("Tools/regression/meters_env.lua")
local Geometry = dofile("Tools/regression/geometry.lua")

local function Pair(env, K, ns)
	local root = K.Scale.Root()
	local damage = assert(Geometry.Rect(ns.Damage.list.panel, root))
	local threat = assert(Geometry.Rect(ns.Threat.list.panel, root))
	assert(ns.Damage.list.panel:IsVisible() and ns.Threat.list.panel:IsVisible(), "Both must show two separate cards")
	assert(math.abs((damage.right - damage.left) - (threat.right - threat.left)) < 1, "Both cards must share the damage width")
	assert(threat.right < damage.left and math.abs(threat.top - damage.top) < 1, "put threat beside damage with their headings level")
	local screen = assert(Geometry.Rect(root, root))
	assert(Geometry.Outside(damage, screen) < 1 and Geometry.Outside(threat, screen) < 1, "keep both cards inside the screen")
	local layouts, style = K.Setup.Layouts, K.HudStyle.Current()
	local preset = K.Store.Module("Layout").preset
	local places = layouts.Positions(preset, style, K.Scale.Aspect())
	for _, key in ipairs({ "actionbars.bar1", "actionbars.bar2", "actionbars.pet", "actionbars.stance" }) do
		local w, h = layouts.StyleSize(style, K.Scale.Aspect(), key)
		if not w then w, h = layouts.Footprint(preset, key) end
		local left, bottom, right, top = layouts.Rect({ width = w, height = h }, places[key], root:GetWidth(), root:GetHeight())
		for _, card in ipairs({ damage, threat }) do
			assert(card.right <= left + 1 or right <= card.left + 1 or card.top <= bottom + 1 or top <= card.bottom + 1,
				string.format("%s %s: meter %.1f %.1f %.1f %.1f overlaps %s %.1f %.1f %.1f %.1f; move the meter area clear of the action and pet slabs", style, preset, card.left, card.bottom, card.right, card.top, key, left, bottom, right, top))
		end
	end
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

for _, screen in ipairs({ { 1920, 1080 }, { 5120, 1440 } }) do
	for _, style in ipairs({ "frames", "orbs", "medallions" }) do
		for _, layout in ipairs({ "DPS", "Tank", "Healer" }) do
			local env, K, ns = M.New({ width = screen[1], height = screen[2], followRole = true,
				saved = { version = 38, account = { setupSeen = true }, profiles = { Default = {
					HudStyle = { style = style }, Layout = { arrangement = "spread" },
				} } },
				setup = function(e)
					e._fitScale, e._size = true, "auto"
					e.UnitGroupRolesAssigned = function() return "DAMAGER" end
					e._group.size = 5
				end,
			})
			local layouts = K.Setup.Layouts
			local limit = layouts.ScaleLimit
			layouts.ScaleLimit = function(w, h, preset, _, hudStyle)
				return limit(w, h, preset, layouts.Enabled(preset), hudStyle)
			end
			assert(K.Setup.Apply({ layout = layout, modules = { Meters = true } }))
			env.RunTimers()
			assert(ns.Get("roles.DAMAGER") == "damage", "DPS defaults to Damage")
			assert(ns.Damage.holder:IsShown() and not ns.Threat.holder:IsShown(), "Damage shows only damage")
			M.Write(env, K, "roles.DAMAGER", "threat")
			assert(not ns.Damage.holder:IsShown() and ns.Threat.list.panel:IsVisible(), "Threat shows only threat")
			local singleWidth = ns.Threat.holder:GetWidth()
			M.Write(env, K, "roles.DAMAGER", "both")
			Pair(env, K, ns)
			M.Write(env, K, "roles.DAMAGER", "threat")
			assert(ns.Threat.holder:GetWidth() == singleWidth, "return to the independent card width")
			M.Write(env, K, "followRole", false)
			M.Write(env, K, "damage.shown", true)
			M.Write(env, K, "threat.shown", true)
			Pair(env, K, ns)
			M.Write(env, K, "damage.shown", false)
			assert(not ns.Damage.holder:IsShown() and ns.Threat.holder:GetWidth() == singleWidth, "manual Threat releases the pair")
			M.Write(env, K, "damage.shown", true)
			Pair(env, K, ns)
			K.Layout.Update("meters.damage", { width = 300 })
			env.RunTimers()
			assert(ns.Threat.holder:GetWidth() == ns.Damage.holder:GetWidth(), "resizing damage keeps the paired widths equal")
			K.Layout.Update("meters.threat", { x = -900 })
			assert(select(2, ns.Threat.holder:GetPoint(1)) == K.Scale.Root(), "a custom threat position wins")
		end
	end
end
print("DPS and manual meter choices ok: 3 styles, 3 layouts, 2 screens")
