-- travel_fixture.lua: carried travel items, known spells and optional core mount data for behaviour and render fixtures.
local Fixture = {}
Fixture.PORTALS = { 3561, 3562, 3563, 3565, 3566, 3567, 1297659, 10059, 11416, 11417, 11418, 11419, 11420 }
Fixture.NAMES = { "Teleport: Stormwind", "Teleport: Ironforge", "Teleport: Undercity", "Teleport: Darnassus", "Teleport: Thunder Bluff", "Teleport: Orgrimmar", "Teleport: Dalaran", "Portal: Stormwind", "Portal: Ironforge", "Portal: Orgrimmar", "Portal: Undercity", "Portal: Darnassus", "Portal: Thunder Bluff" }

function Fixture.Install(env, mage)
	local data = { items = { { itemID = 6948, itemName = "Hearthstone", iconFileID = 134414 }, { itemID = 5655, itemName = "Chestnut Mare Bridle", iconFileID = 132261 } }, spells = {}, cooldown = { 0, 0 } }
	if mage then
		data.items[3] = { itemID = 18986, itemName = "Ultrasafe Transporter: Gadgetzan", iconFileID = 133716 }
		for i, id in ipairs(Fixture.PORTALS) do data.spells[id] = { name = Fixture.NAMES[i], iconID = i <= 6 and 135763 or 135744 } end
	end
	env.C_Container = {
		GetContainerNumSlots = function(bag) return bag == 0 and #data.items or 0 end,
		GetContainerItemInfo = function(_, slot) return data.items[slot] end,
	}
	env.C_Item = env.C_Item or {}
	env.C_Item.GetItemInfoInstant = function(id) return id, nil, nil, nil, nil, 15, id == 5655 and 5 or 0 end
	env.C_Item.GetItemCooldown = function() return unpack(data.cooldown) end
	env.C_Item.IsUsableItem = function() return true end
	env.C_SpellBook = env.C_SpellBook or {}
	env.C_SpellBook.IsSpellKnown = function(id) return data.spells[id] ~= nil end
	env.C_Spell.GetSpellInfo = function(id) return data.spells[id] end
	env.GetBindLocation = function() return "Stormwind City" end
	return data
end

return Fixture
