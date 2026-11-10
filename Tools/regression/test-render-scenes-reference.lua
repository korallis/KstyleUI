-- test-render-scenes-reference.lua: the reference scene (scenes/hud_reference.lua) builds staging's HUD in the state of the owner's picture of 2026-11-09, on his 3456 by 2234 screen, and gives every later scene the Mac screen back.
local L = dofile("Tools/regression/render_scenes_lib.lua")
local Reference = dofile("Tools/render/scenes/_reference.lua")

assert(type(dofile("Tools/render/scenes/hud_reference.lua")) == "function", "hud_reference.lua returns its builder")

local scene = Reference.Build()
assert(type(scene) == "table" and #scene.items > 0, "the reference scene draws")
for _, line in ipairs(scene.log) do
	assert(not line:find("error:", 1, true), "reference: " .. line)
end
local physical = scene.screen.physical
assert(physical.width == 3456 and physical.height == 2234, "the scene draws the owner's full screen, got " .. physical.width .. " by " .. physical.height)
assert(scene.screen.height == 1080 and math.abs(scene.screen.width - 1080 * 3456 / 2234) < 0.01, "the screen is 1080 units tall at the panel's aspect")
assert(rawget(_G, "RENDER_SCREEN") == nil, "the build gives the global screen back")
assert(L.Common.SCREEN.width == 2383 and L.Common.SCREEN.height == 1540, "later scenes draw the Mac window again")

local texts = L.collect(scene)
local buffX = {}
for _, item in ipairs(scene.items) do
	if item.kind == "text" and (item.text == "8s" or item.text == "14s") then
		buffX[item.text] = item.rect[1]
	end
end
assert(buffX["8s"] and buffX["14s"] and buffX["8s"] < buffX["14s"], "the configured tracked buffs read 8s then 14s from left to right beside the portrait")
for _, text in ipairs({ "Windfield Orchard", "[11] Unnerving Silence", "[9] Crab Season", "Lightning Bolt", "Searing Totem", "203", "Korallis", "Shadowgale Poacher" }) do
	local found = texts[text]
	if not found then
		for seen in pairs(texts) do
			if seen:upper() == text:upper() then
				found = true
			end
		end
	end
	assert(found, "the picture's state draws " .. text)
end
local function chatLine(prefix)
	for seen in pairs(texts) do
		if seen:find(prefix, 1, true) then
			return true
		end
	end
end
assert(chatLine("Congratulations, you have reached"), "the session's chat lines draw")

-- The picture's bars are on: bar 2 over bar 1 and bars 4 and 5 as the right-hand columns; the Layout rects are kept for
-- handoffs/reference-diff/DIFF.md's measurements.
local elements = assert(scene.elements, "the scene keeps the Layout elements' rects")
for _, key in ipairs({ "actionbars.bar1", "actionbars.bar2", "actionbars.bar4", "actionbars.bar5", "unitframes.player", "unitframes.target", "minimap.main", "meters.damage", "chat.main", "databars.xp" }) do
	assert(elements[key], "the scene measures " .. key)
end
assert(elements["actionbars.bar2"].bottom > elements["actionbars.bar1"].bottom, "bar 2 stands over bar 1")

dofile("Tools/regression/render_reference_lib.lua")("DPS", scene)
rawset(_G, "RENDER_SCREEN", { width = 1280, height = 720, size = 0.6 })
local nested = dofile("Tools/render/scenes/_common.lua")
local opts = nested.ScreenOpts()
assert(opts.width == 1280 and opts.height == 720 and opts.size == 0.6 and opts.uiScale == 768 / 1080, "screen overrides retain the UI scale default")
rawset(_G, "RENDER_SCREEN", { width = 1920, height = 1080, uiScale = 0.65, size = 1.5 })
assert(nested.SCREEN.width == 1920 and L.Common.SCREEN.width == 1920 and nested.SCREEN.size == 1.5, "already-loaded scenes follow the next screen and requested size")
rawset(_G, "RENDER_SCREEN", nil)
assert(nested.SCREEN.width == 2383 and nested.SCREEN.height == 1540 and nested.SCREEN.size == nil, "a scene loaded during an override does not retain it")
print("ok test-render-scenes-reference")
