-- render_reference_lib.lua: strict reference acceptance shared by three budget-sized preset tests.
local L = dofile("Tools/regression/render_scenes_lib.lua")
local Reference = dofile("Tools/render/scenes/_reference.lua")
local CoreEnv = dofile("Tools/regression/core_env.lua")
local env, K = CoreEnv.New()
CoreEnv.Boot(env)
local Layouts = K.Setup.Layouts
local Guard = dofile("Tools/render/guard.lua")

return function(preset, built)
	built = built or Reference.Build({ layout = preset })
	assert(built.layout == preset, "the scene names its preset")
	local findings = Guard.Check(built)
	assert(#findings == 0, preset .. " has a strict finding without any allowlist: " .. table.concat(Guard.Lines(findings, {}, {}, "strict"), "\n"))
	local rh = 1080 / K.Scale.DEFAULT_USER_SCALE
	local rw = rh * 3456 / 2234
	local positions = Layouts.Get(preset, rh)
	for key, element in pairs(built.elements) do
		local position = positions[key]
		if position then
			local left, bottom = Layouts.Rect(element, position, rw, rh)
			assert(math.abs(left - element.left) * 2234 / rh <= 1, preset .. " did not Apply " .. key .. " horizontally")
			assert(math.abs(bottom - element.bottom) * 2234 / rh <= 1, preset .. " did not Apply " .. key .. " vertically")
		end
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
		assert(built.elements["groupframes.party"], "Healer renders party frames")
		local seen = L.collect(built)
		assert(seen.Leduc and seen.Trolly, "Healer shows its party members")
	elseif preset == "Tank" then
		assert(built.elements["meters.threat"], "Tank registers its threat card")
		assert(L.collect(built).THREAT, "Tank draws the threat card, not an empty hidden reserve")
	end
	L.guard("hud_reference", built)
	L.globs()
	assert(rawget(_G, "RENDER_SCREEN") == nil, "every preset build gives the global screen back")
end
