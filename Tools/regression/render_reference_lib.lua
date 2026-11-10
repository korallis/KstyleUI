-- render_reference_lib.lua: strict reference acceptance shared by three budget-sized preset tests.
local L = dofile("Tools/regression/render_scenes_lib.lua")
local Reference = dofile("Tools/render/scenes/_reference.lua")
local CoreEnv = dofile("Tools/regression/core_env.lua")
local env, K = CoreEnv.New()
CoreEnv.Boot(env)
local Layouts = K.Setup.Layouts
local Guard = dofile("Tools/render/guard.lua")

return function(preset, built)
	local ok, why = pcall(Reference.Build, { layout = "unknown" })
	assert(not ok and tostring(why):find("reference layout must be", 1, true), "unknown reference presets fail before building")
	if not built then
		local loader = assert(loadfile("Tools/render/scenes/hud_reference.lua"))
		local picked = setmetatable({ getenv = function(key)
			if key == "RENDER_LAYOUT" then
				return preset
			end
			return os.getenv(key)
		end }, { __index = os })
		setfenv(loader, setmetatable({ os = picked }, { __index = _G }))
		built = loader()()
	end
	assert(built.layout == preset, "the scene names its preset")
	local findings = Guard.Check(built)
	assert(#findings == 0, preset .. " has a strict finding without any allowlist: " .. table.concat(Guard.Lines(findings, {}, {}, "strict"), "\n"))
	local rh = 1080 / K.Scale.DEFAULT_USER_SCALE
	local rw = rh * 3456 / 2234
	local positions = Layouts.Get(preset, rh)
	for _, key in ipairs({ "actionbars.bar1", "actionbars.bar2", "actionbars.bar4", "actionbars.bar5", "unitframes.player", "unitframes.target", "minimap.main", "meters.damage", "chat.main", "databars.xp" }) do
		assert(positions[key] and built.elements[key], preset .. " compares the declared and applied position of " .. key)
	end
	for key, element in pairs(built.elements) do
		local position = positions[key]
		if position then
			local left, bottom = Layouts.Rect(element, position, rw, rh)
			assert(math.abs(left - element.left) * 2234 / rh <= 1, preset .. " did not Apply " .. key .. " horizontally")
			assert(math.abs(bottom - element.bottom) * 2234 / rh <= 1, preset .. " did not Apply " .. key .. " vertically")
		end
	end
	local seen = L.collect(built)
	for _, text in ipairs({ "45s", "7s", "9s", "8s", "14s", "Lightning Bolt", "Searing Totem", "203", "Korallis", "Shadowgale Poacher", "[11] Unnerving Silence", "[9] Crab Season", "You receive loot:" }) do
		local found = false
		for drawn in pairs(seen) do
			found = found or drawn:lower():find(text:lower(), 1, true) ~= nil
		end
		assert(found, preset .. " retains fixture content after Apply: " .. text)
	end
	local wrapped, clipped = false, false
	for _, item in ipairs(built.items) do
		if item.kind == "text" and item.text:find("appearance collection", 1, true) then
			assert(item.wordWrap ~= false, "chat messages wrap rather than ellipsize")
			assert(item.clip and item.scroll, "chat messages use the native scrolling viewport")
			wrapped = item.rect[4] > item.font.size * 1.3
		elseif item.kind == "text" and item.clip and item.scroll then
			clipped = true
		end
	end
	assert(clipped, preset .. " models the scrolling chat viewport")
	if preset == "Healer" then
		assert(wrapped, "the linked Healer message wraps at its own width with no smaller font")
	elseif preset == "Tank" then
		assert(built.elements["meters.threat"], "Tank registers its threat card")
		assert(seen.THREAT, "Tank draws the threat card, not an empty hidden reserve")
	end
	if preset ~= "DPS" then
		assert(built.elements["groupframes.party"], preset .. " renders party frames")
		assert(seen.Leduc and seen.Trolly, preset .. " shows its party members")
	end
	L.guard("hud_reference", built)
	L.globs()
	assert(rawget(_G, "RENDER_SCREEN") == nil, "every preset build gives the global screen back")
end
