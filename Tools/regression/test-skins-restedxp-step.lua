-- test-skins-restedxp-step.lua: with RestedXP's Active Targets and Active Items boxes docked under the guide, the guide's current step still shows its first line at 1920x1080 and 5120x1440 at UI scale 1 (KSTY-77, the Captain's ruling: the quest card gives up a row before the guide gives up its step), the boxes share one row, and the "N more" line keeps off the card's title.
rawset(_G, "RENDER_HUD_STYLE", "Orbs")
rawset(_G, "RENDER_RXP_BOXES", "1")
local Reference = dofile("Tools/render/scenes/_reference.lua")

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

for _, screen in ipairs({ { 1920, 1080 }, { 5120, 1440 } }) do
	local what = screen[1] .. "x" .. screen[2]
	rawset(_G, "RENDER_SCREEN", { width = screen[1], height = screen[2], uiScale = 1, size = "auto" })
	local scene = Reference.Build({ live = true, modules = { "tracker" } })
	rawset(_G, "RENDER_SCREEN", nil)
	local step = Find(scene, function(text)
		return Plain(text):find("Kill Bandit Highwayman", 1, true) ~= nil
	end)
	assert(step, what .. ": the current step's first line shows with both boxes up")
	local targets = Find(scene, function(text)
		return text == "TARGETS"
	end)
	local items = Find(scene, function(text)
		return text == "ITEMS"
	end)
	assert(targets and items, what .. ": both boxes show, in one row with compact headers")
	assert(math.abs(targets.top - items.top) < 1 and targets.right < items.left, what .. ": the boxes sit side by side")
	assert(step.bottom <= targets.top, what .. ": the step stands above the boxes")
	local cap = Find(scene, function(text)
		return text:find("SKYBORNE", 1, true) ~= nil
	end)
	local more = Find(scene, function(text)
		return text:find("%d+ more$") ~= nil and not text:find("scroll", 1, true)
	end)
	assert(cap, what .. ": the guide's title shows")
	assert(not more or more.top >= cap.bottom, string.format("%s: the more line keeps off the card's title, more %.1f..%.1f title %.1f..%.1f", what, more and more.top or 0, more and more.bottom or 0, cap.top, cap.bottom))
end
rawset(_G, "RENDER_HUD_STYLE", nil)
rawset(_G, "RENDER_RXP_BOXES", nil)

print("skins restedxp step ok")
