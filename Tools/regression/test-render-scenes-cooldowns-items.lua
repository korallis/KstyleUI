-- test-render-scenes-cooldowns-items.lua: each rendered item has its own timer, count and native texture.
local L = dofile("Tools/regression/render_scenes_lib.lua")
local build = dofile("Tools/render/scenes/cooldowns_items.lua")
local scene = L.guard("cooldowns_items", L.check("cooldowns_items", build()))
local texts, files = L.collect(scene)
assert(texts["4"], "the equipped item's four-second timer renders")
assert(texts["12"], "the category item's twelve-second timer renders")
assert(texts["3"], "item uses and spell charges render in their count corners")
assert(not texts["20"], "the unrelated category spell timer is not rendered")
assert(files[L.SET_B .. "133283.png"], "the equipped item's texture renders")
assert(files[L.SET_B .. "134834.png"], "the native health-potion category icon renders")

local function textsInIcon(file)
	local rect
	for _, item in ipairs(scene.items) do
		if item.kind == "texture" and item.file == L.SET_B .. file .. ".png" then
			rect = item.rect
			break
		end
	end
	assert(rect, "the fixture has the requested item icon")
	local found = {}
	for _, item in ipairs(scene.items) do
		if item.kind == "text" then
			local x, y = item.rect[1] + item.rect[3] / 2, item.rect[2] + item.rect[4] / 2
			if x >= rect[1] and x <= rect[1] + rect[3] and y >= rect[2] and y <= rect[2] + rect[4] then
				found[item.text] = true
			end
		end
	end
	return found
end

assert(textsInIcon("133283")["4"], "four seconds belong to the equipped trinket")
local potion = textsInIcon("134834")
assert(potion["12"] and potion["3"], "the potion itself shows twelve seconds and three uses")
print("cooldowns item render ok")
