-- test-bags-newmark.lua: a new item's marker stays inside its slot, only fades, and stops when pointed at, in the bags and the options preview.
local B = dofile("Tools/regression/bags_env.lua")
local Geometry = dofile("Tools/regression/geometry.lua")
local W = B.W
local Item = B.Item

local function Snapshot(button)
	local set = {}
	for _, object in ipairs(Geometry.Tree(button)) do
		set[object] = true
		for _, group in ipairs(object._groups or {}) do
			set[group] = true
		end
	end
	return set
end

-- Every object and animation group the new-item marker added under the slot's button.
local function Added(button, before)
	local objects, groups = {}, {}
	for _, object in ipairs(Geometry.Tree(button)) do
		if not before[object] then
			objects[#objects + 1] = object
		end
		for _, group in ipairs(object._groups or {}) do
			if not before[group] then
				groups[#groups + 1] = group
			end
		end
	end
	return objects, groups
end

local function CheckMarker(label, button, before)
	local objects, groups = Added(button, before)
	assert(#objects > 0, label .. ": marking an item new draws something")
	local bounds = Geometry.Rect(button, button)
	for _, object in ipairs(objects) do
		if object._type == "Texture" or object._type == "MaskTexture" or object._type == "Line" then
			local rect, why = Geometry.Rect(object, button)
			assert(rect, label .. ": a marker texture has no known extent (" .. tostring(why) .. "); the game would draw it at its file's size")
			local over = Geometry.Outside(rect, bounds)
			assert(over < 0.01, string.format("%s: a marker texture reaches %.1f units past the slot", label, over))
		end
	end
	for _, group in ipairs(groups) do
		for _, animation in ipairs(group._anims or {}) do
			assert(animation._type == "Alpha", label .. ": the marker uses a " .. tostring(animation._type) .. " animation; it may only fade")
		end
	end
end

-- The bag window ----------------------------------------------------------------------------------

do
	local env, _, ns = B.New({ bags = { [0] = { size = 8, items = { [1] = Item("potion"), [2] = Item("sword") } } } })
	env.ToggleAllBags()
	env.RunTimers()
	W.Settle(env)
	local slot = ns.Inventory.Slot(0, 2)
	assert(slot and slot.size and slot.size > 0, "the sword's slot is laid out")
	local before = Snapshot(slot.button)
	env._new["0:2"] = true
	env.FireEvent("BAG_NEW_ITEMS_UPDATED")
	W.Settle(env)
	assert(slot.glow and slot.glow:IsPlaying(), "a new item is marked")
	CheckMarker("bags", slot.button, before)
	W.Enter(slot.button)
	assert(not slot.glow:IsPlaying(), "pointing at the item clears its mark")
end

-- The options preview -----------------------------------------------------------------------------

do
	local _, K, ns = B.New({ bags = { [0] = { size = 4, items = {} } } })
	local Preview = ns.Preview
	assert(Preview and Preview.Build, "the bags module has an options preview")
	assert(K.Options.Write("Bags", "showNewGlow", false) ~= false, "turning the new-item mark off")
	local frame = Preview.Build(K.Scale.Root())
	local marked
	for _, slot in ipairs(frame.slots) do
		if slot.state.isNew then
			marked = slot
		end
	end
	assert(marked and not (marked.glow and marked.glow:IsPlaying()), "with the setting off the preview marks nothing")
	local before = Snapshot(marked.button)
	assert(K.Options.Write("Bags", "showNewGlow", true) ~= false, "turning the new-item mark on")
	frame:Refresh()
	assert(marked.glow and marked.glow:IsPlaying(), "the preview shows a new item")
	CheckMarker("preview", marked.button, before)
end

print("test-bags-newmark: ok")
