-- test-consumables-cache.lua: cooldown and bag events keep binding and travel queries out of unchanged paths.
local AB = dofile("Tools/regression/actionbars_env.lua")
local queries, bindings, spells, itemID = 0, 0, {}, 118
local env, K, ns = AB.New({ setup = function(e)
	e.C_Container = {
		GetContainerNumSlots = function(bag) return bag == 0 and 1 or 0 end,
		GetContainerItemInfo = function() return { itemID = itemID, stackCount = 3, iconFileID = 134829 } end,
	}
	e.C_Item = { GetItemCooldown = function() return 0, 0 end, GetItemSpell = function(id)
		if id ~= 90001 then queries = queries + 1 end
		return "Travel", spells[id] or id
	end, GetItemInfoInstant = function() return nil, nil, nil, nil, nil, 0 end,
	GetItemInfo = function() return nil, nil, nil, 1, 1, nil, nil, 20 end }
end })
AB.Enable(env, K)
local C = ns.Consumables
local scan, scans = C.Scan, 0
C.Scan = function(...) scans = scans + 1; return scan(...) end
for _, event in ipairs({ "ScaleChanged", "ThemeChanged" }) do K.Callbacks.Fire(event) end
K.Callbacks.Fire("ModuleChanged", "UnitFrames")
assert(scans == 0, "visual changes reuse inventory instead of rescanning bags")
K.Options.Write("ActionBars", "consumables.hotkey", true)
local binding = env.GetBindingKey
env.GetBindingKey = function(...) bindings = bindings + 1; return binding(...) end
local countWrites = 0
local countText = C.buttons[1].count.SetText
C.buttons[1].count.SetText = function(...) countWrites = countWrites + 1; return countText(...) end
local before = queries
env.FireEvent("SPELL_UPDATE_COOLDOWN")
env.FireEvent("BAG_UPDATE_COOLDOWN")
assert(bindings == 0 and countWrites == 0 and queries == before, "cooldowns must reuse bindings, counts and travel spells")
env.FireEvent("BAG_UPDATE_DELAYED")
assert(bindings == 0 and queries == before, "bag changes reuse bindings and resolved travel spells")
env._game.bindings["CLICK KstyleUI_Consumable1:LeftButton"] = { "SHIFT-1" }
env.FireEvent("UPDATE_BINDINGS")
assert(bindings > 0 and C.buttons[1].hotkey:GetText() == "S1", "UPDATE_BINDINGS refreshes cached keys")
itemID = 90001
env.FireEvent("BAG_UPDATE_DELAYED")
assert(#C.selected == 1, "unknown usable consumable warms the travel spell cache")
before = queries
env.FireEvent("BAG_UPDATE_DELAYED")
assert(queries == before, "unknown consumables reuse each resolved travel spell")
spells[C.travel[1]] = 90001
env.FireEvent("SPELLS_CHANGED")
assert(queries > before and #C.selected == 0, "learning spells refreshes travel exclusions")
spells[C.travel[1]] = C.travel[1]
env.FireEvent("GET_ITEM_INFO_RECEIVED", C.travel[1], true)
assert(#C.selected == 1, "loaded item metadata refreshes the affected travel exclusion")
assert(#env._errors == 0, tostring(env._errors[1]))
print("consumables cache ok: cooldowns reuse keys/counts and bags reuse resolved travel spells")
