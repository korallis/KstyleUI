-- test-skins-restedxp-step.lua: with RestedXP's Active Targets and Active Items boxes docked under the guide, the guide's current step still shows its first line at 1920x1080 and 5120x1440 at UI scale 1 and at Blizzard's default 768/1080 (KSTY-77, the Captain's ruling: the quest card gives up a row before the guide gives up its step), the docked boxes show no headers (their chip placement is test-skins-restedxp-boxes.lua's), the "N more" line keeps off the card's title, and the header keeps its step counter.
rawset(_G, "RENDER_RXP_BOXES", "1")
local Reference = dofile("Tools/render/scenes/_reference.lua")
local owner = Reference.SCREEN

local function Find(scene, test)
	for _, item in ipairs(scene.items) do
		if item.kind == "text" and type(item.text) == "string" and test(item.text) and (item.alpha or 1) > 0 then
			local x, y, w, h = unpack(item.rect)
			return { left = x, top = y, right = x + w, bottom = y + h }
		end
	end
	return nil
end

local function Plain(text)
	return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h", ""):gsub("|h", ""))
end

for _, screen in ipairs({ { 1920, 1080, 1 }, { 5120, 1440, 1 }, { 1920, 1080, 768 / 1080 }, { 5120, 1440, 768 / 1080 } }) do
	local what = string.format("%dx%d at UI scale %.3f", screen[1], screen[2], screen[3])
	Reference.SCREEN = { width = screen[1], height = screen[2], uiScale = screen[3], size = "auto" }
	local scene = Reference.Build({ live = true, modules = { "tracker" } })
	assert(scene.screen.physical.width == screen[1] and scene.screen.physical.height == screen[2], what .. ": the scene draws that screen, got " .. scene.screen.physical.width .. "x" .. scene.screen.physical.height)
	local step = Find(scene, function(text)
		return Plain(text):find("Kill Bandit Highwayman", 1, true) ~= nil
	end)
	assert(step, what .. ": the current step's first line shows with both boxes up")
	assert(not Find(scene, function(text) return text == "TARGETS" or text == "ITEMS" or text:find("^ACTIVE ") end), what .. ": the docked boxes show no headers")
	local cap = Find(scene, function(text)
		return text:find("SKYBORNE", 1, true) ~= nil
	end)
	local more = Find(scene, function(text)
		return text:find("%d+ more$") ~= nil and not text:find("scroll", 1, true)
	end)
	assert(cap, what .. ": the guide's title shows")
	local counter = Find(scene, function(text)
		return text == "Step 57"
	end)
	assert(counter and counter.left > cap.right, what .. ": the guide's header keeps its step counter, right of the title")
	assert(not more or more.top >= cap.bottom, string.format("%s: the more line keeps off the card's title, more %.1f..%.1f title %.1f..%.1f", what, more and more.top or 0, more and more.bottom or 0, cap.top, cap.bottom))
end
Reference.SCREEN = owner
rawset(_G, "RENDER_RXP_BOXES", nil)

print("skins restedxp step ok")
