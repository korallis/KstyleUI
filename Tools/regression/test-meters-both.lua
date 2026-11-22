-- test-meters-both.lua: DPS and manual meter choices pair separate cards, threat at the slot width beside damage, across layouts and screens.
local M = dofile("Tools/regression/meters_env.lua")
local Geometry = dofile("Tools/regression/geometry.lua")

local function Pair(env, K, ns)
	local root = K.Scale.Root()
	local damage = assert(Geometry.Rect(ns.Damage.list.panel, root))
	local threat = assert(Geometry.Rect(ns.Threat.list.panel, root))
	assert(ns.Damage.list.panel:IsVisible() and ns.Threat.list.panel:IsVisible(), "Both must show two separate cards")
	assert(math.abs(ns.SLOT_WIDTH - (threat.right - threat.left)) < 1, "Both docks threat at the slot width that clears the HUD")
	assert(math.abs(damage.left - threat.right - K.Setup.Layouts.GAP) <= K.Scale.Pixel(1), "the meters keep the shared gap")
	assert(threat.right < damage.left and math.abs(threat.top - damage.top) < 1, "put threat beside damage with their headings level")
	assert(math.abs((damage.top - damage.bottom) - (threat.top - threat.bottom)) < 1, "Both cards share their live height")
	assert(ns.Damage.list.capacity == ns.Threat.list.capacity, "Both cards have the same row capacity")
	local screen = assert(Geometry.Rect(root, root))
	assert(Geometry.Outside(damage, screen) < 1 and Geometry.Outside(threat, screen) < 1, "keep both cards inside the screen")
	local layouts = K.Setup.Layouts
	local preset = K.Store.Module("Layout").preset
	local places = layouts.Positions(preset, "medallions", K.Scale.Aspect())
	local enabled = layouts.Enabled(preset)
	assert(enabled["cooldowns.bars"] ~= false and layouts.Element("cooldowns.bars").height >= 27, "Both collision checks must include the CDM tracked-bar footprint")
	enabled["meters.damage"], enabled["meters.threat"] = true, true
	local width, height = env.GetPhysicalScreenSize()
	assert(layouts.Fits(preset, width, height, K.Scale.AppliedUserScale(), enabled, nil), "the pair must also clear the story cards")
	for _, element in ipairs(layouts.ELEMENTS) do
		local key = element.key
		if key ~= "meters.damage" and key ~= "meters.threat" and layouts.Enabled(preset)[key] ~= false then
			local w, h = layouts.StyleSize(K.Scale.Aspect(), key)
			if not w then w, h = layouts.Footprint(preset, key, K.Scale.Aspect()) end
			local styled = layouts.Aspect(K.Scale.Aspect(),"medallions",preset,key) or layouts.Style(preset,key)
			if styled and styled.width then w, h = styled.width, styled.height end
			local left, bottom, right, top = layouts.Rect({ width = w, height = h }, places[key], root:GetWidth(), root:GetHeight())
			for _, card in ipairs({ damage, threat }) do
				assert(card.right <= left + 1 or right <= card.left + 1 or card.top <= bottom + 1 or top <= card.bottom + 1,
					string.format("%s: meter %.1f %.1f %.1f %.1f overlaps %s %.1f %.1f %.1f %.1f; move the meter area clear of the other HUD elements", preset, card.left, card.bottom, card.right, card.top, key, left, bottom, right, top))
			end
		end
	end
	assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
end

do
	local env, K, ns = M.New({ saved = { version = 38, profiles = { Default = { Meters = { followRole = false } } }, layouts = { Default = { ["meters.damage"] = { width = 269, height = 158 } } } }, setup = function(e) e._group.size = 5 end })
	M.Enable(env, K)
	assert(ns.Damage.holder:GetWidth() == 250 and ns.Threat.holder:GetWidth() == 250, "an existing profile's old default width must migrate to the compact pair")
	assert(K.Store.Layout()["meters.damage"].width == 250, "persist the updated default width")
end

for _, screen in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 }, { 2383, 1540 }, { 4236, 1495 }, { 1280, 1024 } }) do
	for _, layout in ipairs({ "DPS", "Tank", "Healer" }) do
		local env, K, ns = M.New({ width = screen[1], height = screen[2], followRole = true,
			saved = { version = 38, account = { setupSeen = true }, profiles = { Default = { Layout = { arrangement = "spread" },
			} } },
			setup = function(e)
				e._fitScale, e._size = true, "auto"
				e.UnitGroupRolesAssigned = function() return "DAMAGER" end
				e._group.size = 5
			end,
		})
		local layouts = K.Setup.Layouts
		local limit = layouts.ScaleLimit
		layouts.ScaleLimit = function(w, h, preset)
			local enabled = layouts.Enabled(preset)
			local meters = layouts.Enabled(preset, K.Store.Profile())
			enabled["meters.damage"], enabled["meters.threat"] = meters["meters.damage"], meters["meters.threat"]
			return limit(w, h, preset, enabled)
		end
		assert(K.Setup.Apply({ layout = layout, modules = { Meters = true } }))
		env.RunTimers()
		assert(ns.Get("roles.DAMAGER") == "damage", "DPS defaults to Damage")
		assert(ns.Damage.holder:IsShown() and not ns.Threat.holder:IsShown(), "Damage shows only damage")
		K.Layout.Update("meters.threat", { width = 200 })
		M.Write(env, K, "roles.DAMAGER", "threat")
		env.RunTimers()
		assert(not ns.Damage.holder:IsShown() and ns.Threat.list.panel:IsVisible(), "Threat shows only threat")
		local singleWidth = ns.Threat.holder:GetWidth()
		assert(math.abs(singleWidth - 200) < 1, "Threat alone keeps the existing profile's width")
		M.Write(env, K, "roles.DAMAGER", "both")
		env.RunTimers()
		Pair(env, K, ns)
		assert(K.Store.Layout()["meters.threat"].width == 200, "pairing must preserve an existing profile's saved solo width")
		M.Write(env, K, "roles.DAMAGER", "threat")
		assert(math.abs(ns.Threat.holder:GetWidth() - singleWidth) < 1, "return to the independent card width")
		M.Write(env, K, "followRole", false)
		M.Write(env, K, "damage.shown", true)
		M.Write(env, K, "threat.shown", true)
		env.RunTimers()
		Pair(env, K, ns)
		M.Write(env, K, "damage.shown", false)
		assert(not ns.Damage.holder:IsShown() and math.abs(ns.Threat.holder:GetWidth() - singleWidth) < 1, "manual Threat releases the pair: " .. tostring(ns.Threat.holder:GetWidth()) .. " vs " .. tostring(singleWidth))
		M.Write(env, K, "damage.shown", true)
		Pair(env, K, ns)
		K.Layout.Update("meters.damage", { width = 300 })
		env.RunTimers()
		assert(ns.Threat.holder:GetWidth() == ns.SLOT_WIDTH, "resizing damage keeps the docked threat at the slot width")
		K.Layout.Update("meters.threat", { x = -900 })
		assert(select(2, ns.Threat.holder:GetPoint(1)) == K.Scale.Root(), "a custom threat position wins")
	end
end
print("DPS and manual meter choices ok: 3 layouts, 7 screens")
