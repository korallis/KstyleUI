-- The shortcut audit requires a healing key that never spends mana, eligible ranks, displaced bindings and non-colour range feedback.
local AB = dofile("Tools/regression/actionbars_env.lua")
local ids, level = { 13446, 118, 2455 }, 10
local env, K, ns = AB.New({ setup = function(e)
	e.UnitLevel = function() return level end
	e.C_Container = { GetContainerNumSlots = function(bag) return bag == 0 and #ids or 0 end,
		GetContainerItemInfo = function(_, slot) return { itemID = ids[slot], stackCount = 3, iconFileID = 134829 } end }
	e.C_Item = { GetItemInfo = function(id) return "Potion", nil, nil, nil, ({ [13446] = 45, [118] = 1, [2455] = 5 })[id] end }
	e._game.bindings.JUMP = { "F9" }
	e.BINDING_NAME_JUMP = "Jump"
end })
AB.Enable(env, K)
local c, mode = ns.Consumables, ns.Keybind
assert(c.selected[1].id == 118, "at level 10 select the usable minor heal")
assert(mode.Enter())
local overlay = assert(mode.overlays[c.buttons[1]])
overlay:GetScript("OnEnter")(overlay)
mode.Input("F9")
assert(mode.panel.current:GetText():find("Jump", 1, true) and env.GetBindingAction("F9") == "JUMP", "preview names the displaced action before saving")
mode.Save()
assert(AB.PressKey(env, "F9") and AB.Used(env) == "item:118")
level = 45
env.FireEvent("PLAYER_LEVEL_UP", level)
assert(AB.PressKey(env, "F9") and AB.Used(env) == "item:13446", "same shortcut upgrades after levelling")
ids = { 2455 }
env.FireEvent("BAG_UPDATE_DELAYED")
local used = #env._game.used
AB.PressKey(env, "F9")
assert(#env._game.used == used and c.buttons[1]:GetAttribute("item") == "item:2455", "mana packs first but F9 does nothing")
AB.Slot(env, 1, { type = "spell", id = 100, texture = 132337 })
env.FireEvent("ACTIONBAR_SLOT_CHANGED", 1); env.RunTimers()
local b = ns.bars.bar1.buttons[1]
env.FireEvent("ACTION_RANGE_CHECK_UPDATE", 1, false, true)
assert(b.rangeMark and b.rangeMark:IsShown(), "out of range has a mark without a key")
for _, state in ipairs({ { true, true }, { false, false }, { env.Secret(false), true } }) do
	env.FireEvent("ACTION_RANGE_CHECK_UPDATE", 1, unpack(state))
	assert(not b.rangeMark:IsShown(), "only known out-of-range actions get a mark")
end
assert(#env._errors == 0, AB.Errors(env))
print("shortcut safety ok: eligible heal, category upgrade, no mana use, displaced action and range states")
