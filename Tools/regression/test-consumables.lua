-- test-consumables.lua: ranks, combat freezing, settings, attachment and the maximum grid on every owner screen.
local AB = dofile("Tools/regression/actionbars_env.lua")
local slots = {}
local env, K, ns = AB.New({ setup = function(e)
	e.C_Container = {
		GetContainerNumSlots = function(bag) return bag == 0 and #slots or 0 end,
		GetContainerItemInfo = function(_, slot) return slots[slot] end,
	}
	e.C_Item = {
		GetItemCooldown = function() return 0, 0, 1 end,
		GetItemInfoInstant = function(id) return id, nil, nil, nil, nil, id == 90003 and 12 or 0 end,
		GetItemSpell = function(id) return "Use", id == 90002 and 90001 or id end,
		GetItemInfo = function(id) return "Item", nil, nil, id, id, nil, nil, id == 90004 and 1 or 20 end,
	}
end })
AB.Enable(env, K)
local C = ns.Consumables
local cfg = K.Store.Module("ActionBars").consumables
local function Read(path)
	local file = assert(io.open(path, "rb"))
	local text = file:read("*a")
	file:close()
	return text
end
local source = Read("Tools/data/items.json")
for _, kind in ipairs(C.kinds) do
	for _, id in ipairs(kind.ids) do
		assert(source:match('"id": ' .. id .. ',%s*"name": [^\n]+,%s*"classID": 0,'), "curated ids must be consumables proven by items.json")
	end
end
assert(cfg.enabled and cfg.attached and cfg.rows == 2 and cfg.hideEmpty, "on, attached, two rows and hidden when empty by default")
assert(not C.header and not C.holder, "empty inventory creates no holder or secure header")
assert(#C.buttons == 0, "an empty inventory defers all secure slot art until the first carried consumable")

local function Bag(ids)
	slots = {}
	for i, id in ipairs(ids) do slots[i] = { itemID = id, stackCount = i + 1, iconFileID = 134829 } end
	env.FireEvent("BAG_UPDATE_DELAYED")
end
local function near(a, b) return math.abs(a - b) < 0.02 end
local function Clean()
	assert(#env._errors == 0, tostring(env._errors[1]))
	assert(#env._blocked == 0, tostring(env._blocked[1]))
end

env._combat = true
Bag({ 118 })
assert(#C.buttons == 0 and #C.selected == 0, "the first consumable acquired in combat creates no secure slots")
Clean()
env._combat = false
env.FireEvent("PLAYER_REGEN_ENABLED")
assert(#C.buttons == 12 and C.selected[1].id == 118, "the first out-of-combat repack creates the secure pool")
local button = C.buttons[1]
K.Options.Write("ActionBars", "consumables.size", 38)
local reference = K.Widgets.FontString(button.overlay, "OVERLAY")
for _, scale in ipairs({ 0.5, 1, 1.5 }) do
	C.holder:SetScale(scale)
	ns.StyleTextsFor(button, "consumables")
	for _, key in ipairs({ "hotkey", "count", "cooldown" }) do
		local fs = key == "cooldown" and button.countdown or button[key]
		local path = fs:GetFont()
		K.Widgets.ApplyFont(reference, path, ns.Config("text")[key].size * K.Theme.FontScale(), "")
		assert(not K.Widgets.IsFitted(fs), "size 38 must keep the old text floor at holder scale " .. scale)
		assert(select(2, fs:GetFont()) == select(2, reference:GetFont()), "size 38 must keep the previous " .. key .. " text at holder scale " .. scale)
	end
end
C.holder:SetScale(1)
K.Options.Write("ActionBars", "consumables.size", 26)
assert(cfg.size == 26 and cfg.spacing == 0 and cfg.backing == true and cfg.hotkey == false, "Options starts at size 26 with no gap, backing on and keybind text off")
local backing = C.header:GetChildren()
assert(backing.chrome and backing:IsShown(), "the shared Chrome tile is shown by default")
K.Options.Write("ActionBars", "consumables.backing", false)
assert(not backing:IsShown(), "the backing toggle hides the tile")
K.Options.Write("ActionBars", "consumables.backing", true)
assert(backing:IsShown(), "the backing toggle restores the tile")
for _, style in ipairs({ "frames", "medallions" }) do
	K.Options.Write("HudStyle", "style", style)
	for _, class in ipairs(K.Setup.Layouts.ASPECTS) do
		local _, size, gap = K.Setup.Layouts.ConsumableGrid(class)
		local slot = K.Setup.Layouts.MEDALLIONS_SLOT
		local actionSize = style == "medallions" and (slot[class] or slot.size) or ns.defaults.bar3.size
		assert(near(size, actionSize * 26 / 38) and gap == 0, style .. " " .. class .. ": size 26 scales with the action slot and the default gap is 0")
	end
	button:Restyle()
	assert(button.countdown:GetPoint() == "CENTER", style .. ": restyling keeps the compact countdown centered")
	for _, key in ipairs({ "hotkey", "count", "cooldown" }) do
		local fs = key == "cooldown" and button.cooldown:GetCountdownFontString() or button[key]
		local _, size = fs:GetFont()
		assert(size <= button.opts.size and size < ns.Config("text")[key].size, style .. ": consumable " .. key .. " text scales with its button")
		assert(size * K.Widgets.ScaleFactor(fs) / K.Scale.Pixel(1) >= 9 - 0.01 and select(3, fs:GetFont()) == "OUTLINE", style .. ": compact text keeps a nine-pixel outlined floor")
	end
end
K.Options.Write("ActionBars", "consumables.hotkey", true)
assert(not button.hotkey:IsShown(), "compact counts win over optional keys")
K.Options.Write("ActionBars", "consumables.count", false)
assert(button.hotkey:IsShown() and not button.count:IsShown(), "optional compact keys show when Count text is off")
env.C_Item.GetItemCooldown = function() return 1, 120, 1 end
env.FireEvent("SPELL_UPDATE_COOLDOWN")
C.buttons[1].cooldown:GetScript("OnShow")(C.buttons[1].cooldown)
assert(C.buttons[1].hotkey:GetAlpha() == 0, "a compact countdown replaces the key label instead of crossing it")
assert(C.buttons[1].countdown:GetPoint() == "CENTER" and C.buttons[1].count:GetAlpha() == 0, "the centered compact timer replaces the count")
K.Options.Write("ActionBars", "consumables.count", true)
assert(button.count:IsShown() and button.count:GetAlpha() == 0 and not button.hotkey:IsShown(), "enabling counts during cooldown keeps the timer alone")
K.Options.Write("ActionBars", "consumables.cooldown", false)
assert(C.buttons[1].hotkey:GetAlpha() > 0 and C.buttons[1].count:GetAlpha() == 1, "hiding countdown text restores both corners")
K.Options.Write("ActionBars", "consumables.cooldown", true)
env.C_Item.GetItemCooldown = function() return 0, 0, 1 end
env.FireEvent("SPELL_UPDATE_COOLDOWN")
C.buttons[1].cooldown:GetScript("OnCooldownDone")(C.buttons[1].cooldown)
assert(not button.hotkey:IsShown() and button.count:GetAlpha() == 1, "the count returns when the cooldown ends without exposing the key")
K.Options.Write("ActionBars", "consumables.hotkey", false)

AB.CoreEnv.Logout(env)
local _, refilled = AB.New({ saved = AB.CoreEnv.DeepCopy(env.KstyleUIDB) })
assert(refilled.Store.Module("ActionBars").consumables.size == 26 and refilled.Store.Module("ActionBars").consumables.spacing == 0 and refilled.Store.Module("ActionBars").consumables.backing and refilled.Store.Module("ActionBars").consumables.hotkey == false, "stripped defaults refill without migration")
local explicit = AB.CoreEnv.DeepCopy(env.KstyleUIDB)
explicit.profiles.Default.ActionBars.consumables = { size = 46, spacing = 4, backing = false, hotkey = true }
local savedEnv, savedK = AB.New({ saved = explicit })
assert(savedK.Store.Module("ActionBars").consumables.size == 46 and savedK.Store.Module("ActionBars").consumables.spacing == 4 and savedK.Store.Module("ActionBars").consumables.backing == false and savedK.Store.Module("ActionBars").consumables.hotkey == true, "explicit saved size and backing survive refill")
AB.CoreEnv.Logout(savedEnv)
assert(savedEnv.KstyleUIDB.profiles.Default.ActionBars.consumables.size == 46 and savedEnv.KstyleUIDB.profiles.Default.ActionBars.consumables.spacing == 4 and savedEnv.KstyleUIDB.profiles.Default.ActionBars.consumables.backing == false and savedEnv.KstyleUIDB.profiles.Default.ActionBars.consumables.hotkey == true, "explicit choices survive stripping")

Bag({ 6948 })
assert(#C.selected == 0, "a Hearthstone in the bags never creates a slot")
for _, id in ipairs(C.travel) do
	Bag({ id, 5510 })
	assert(#C.selected == 1 and C.selected[1].id == 5510, "travel items stay out of every kind while Healthstones stay")
end
local use = env.C_Item.GetItemSpell
env.C_Item.GetItemSpell = function() return "Travel", 3561 end
Bag({ 90001 }); assert(#C.selected == 0, "an unknown teleport item is excluded by its use spell")
env.C_Item.GetItemSpell = use

for _, kind in ipairs(C.kinds) do
	for i = 1, #kind.ids - 1 do
		Bag({ kind.ids[i + 1], kind.ids[i] })
		assert(#C.selected == 1 and C.selected[1].id == kind.ids[i], kind.key .. " curated rank wins")
	end
	Bag({ kind.ids[1] })
	K.Options.Write("ActionBars", "consumables." .. kind.key, false)
	assert(#C.selected == 0, kind.key .. " off excludes known ranks rather than passing them through Other")
	K.Options.Write("ActionBars", "consumables." .. kind.key, true)
end

Bag({ 118, 13446, 5512, 5510, 5349, 22895, 5350, 8079 })
assert(#C.selected == 4 and C.selected[1].id == 13446 and C.selected[2].id == 5510 and C.selected[3].id == 22895 and C.selected[4].id == 8079, "potion, Healthstone, conjured food and conjured water rank independently")
local b = C.buttons[1]
assert(b:GetAttribute("type") == "item" and b:GetAttribute("item") == "item:13446", "secure use binds the item id rather than the bag slot")
local before = C.header:GetWidth()
local firstPoint = { b:GetPoint() }
env._combat = true
env.FireEvent("PLAYER_REGEN_DISABLED")
AB.Click(env, b, "LeftButton", true)
AB.Click(env, b, "LeftButton", false)
assert(AB.Used(env) == "item:13446", "secure item click retains its id in combat")
Bag({ 118, 5512, 5349, 5350, 14530 })
assert(C.buttons[1]:GetAttribute("item") == "item:13446" and #C.selected == 4, "no rank substitution or new kind during combat")
assert(C.buttons[1].count:GetText() == "0" and AB.W.LastCall(C.buttons[1].icon, "SetDesaturated")[1], "emptied slot dims with count zero")
assert(C.header:GetWidth() == before and b:GetPoint() == firstPoint[1], "combat keeps the live footprint and anchor")
local pending = K.Combat.Pending()
env.FireEvent("BAG_UPDATE_DELAYED")
assert(K.Combat.Pending() == pending, "one queued repack despite repeated bag events")
Clean()
env._combat = false
env.FireEvent("PLAYER_REGEN_ENABLED")
assert(C.selected[1].id == 118 and #C.selected == 5 and C.selected[3].id == 14530, "combat end upgrades bindings and packs in priority order")
Bag({ 118 })
assert(C.header:GetWidth() < before, "shrinks out of combat")
local narrow = C.header:GetWidth()
Bag({ 118, 2455, 5512, 1251, 5349, 5350, 2456, 20452, 13510, 13452, 20007, 954 })
assert(#C.selected == 12 and C.header:GetWidth() > narrow, "grows to the cap out of combat")
K.Options.Write("ActionBars", "consumables.buttons", 3)
assert(#C.selected == 3 and C.selected[1].id == 118 and C.selected[3].id == 5512, "button limit keeps the highest-priority item kinds")
assert(C.buttons[3]:IsShown() and not C.buttons[4]:IsShown(), "button limit hides unused secure slots")
K.Options.Write("ActionBars", "consumables.buttons", 12)
assert(#C.selected == 12, "raising the limit restores the remaining carried kinds")
for _, rows in ipairs({ 1, 2, 3 }) do
	K.Options.Write("ActionBars", "consumables.rows", rows)
	local w, h = K.Setup.Layouts.ConsumableFootprint()
	assert(near(C.holder:GetWidth(), K.Widgets.Snap(C.holder, w)) and near(C.holder:GetHeight(), K.Widgets.Snap(C.holder, h)), "mover reserves all 12 at " .. rows .. " rows, snapped to physical pixels")
	local x, y, _, dx, dy = C.buttons[math.min(12, math.ceil(12 / rows) + 1)]:GetPoint()
	assert(x == "BOTTOMRIGHT" and y == C.header and near(dx, 0) and dy > 0 or rows == 1, "row-major fill starts a new row from the attached edge")
end
K.Options.Write("ActionBars", "consumables.rows", 2)
K.Options.Write("ActionBars", "editBar", "consumables")
local pane = env.CreateFrame("Frame", nil, K.Scale.Root())
pane:SetSize(600, 300)
local preview = ns.Preview(pane)
assert(preview:GetHeight() > C.buttons[1]:GetHeight(), "Options previews the consumables grid rather than bar 1")
preview.buttons[3].cooldown:GetScript("OnShow")(preview.buttons[3].cooldown)
assert(preview.buttons[3].countdown:GetPoint() == "CENTER" and preview.buttons[3].count:GetAlpha() == 0, "Options uses the live bar's compact countdown placement")
K.Options.Write("ActionBars", "consumables.orientation", "VERTICAL")
local _, _, _, x, y = C.buttons[2]:GetPoint()
assert(x == 0 and y > 0, "column-first fill")
K.Options.Write("ActionBars", "consumables.growth", "RIGHTDOWN")
assert(C.buttons[1]:GetPoint() == "TOPLEFT", "custom growth")
K.Options.Write("ActionBars", "consumables.size", 48)
K.Options.Write("ActionBars", "consumables.spacing", 8)
-- Medallions scales the 48 size by the 33.5/38 slot of this screen; the 8 gap stays.
assert(C.holder:GetWidth() == 294 and C.holder:GetHeight() == 93, "custom size and gap reach both mover and live buttons")

for _, style in ipairs({ "frames", "medallions" }) do
	K.Options.Write("HudStyle", "style", style)
	local player = env.CreateFrame("Frame", nil, K.Scale.Root())
	player:SetSize(491, 77.5)
	K.Layout.Register(player, "unitframes.player", K.Setup.Layouts.Default("unitframes.player"))
	K.Callbacks.Fire("LayoutChanged", "unitframes.player")
	C.Apply()
	local _, relative = C.holder:GetPoint()
	assert(relative == player, style .. ": the bar physically follows the player frame")
	K.Options.Write("ActionBars", "consumables.attached", false)
	local _, free = C.holder:GetPoint()
	assert(free == K.Scale.Root() and K.Layout.Element("consumables.bar").opts.plate ~= false, "detached bar has a free mover")
	K.Layout.Set("consumables.bar", "x", 500)
	K.Options.Write("ActionBars", "consumables.attached", true)
	local _, docked = C.holder:GetPoint()
	assert(docked == player, style .. ": reattaching overrides a free saved position")
end

K.Options.Write("ActionBars", "consumables.hotkey", true)
env._game.bindings["CLICK KstyleUI_Consumable1:LeftButton"] = { "SHIFT-1" }
env.FireEvent("UPDATE_BINDINGS")
assert(C.buttons[1].hotkey:GetText() == "S1", "bindings use the action bars' compact key text")
local tooltipKey
local tooltip = env.GameTooltip
tooltip.SetItemByID = function() end
tooltip.AddLine = function(_, text) tooltipKey = text end
K.Options.Write("ActionBars", "consumables.hotkey", false)
AB.W.Enter(C.buttons[1])
assert(tooltipKey == env.GetBindingText("SHIFT-1"), "the tooltip exposes the full binding even when button keys are off")
AB.W.Leave(C.buttons[1])
K.Options.Write("ActionBars", "consumables.hotkey", true)
assert(ns.Keybind.Enter())
local overlay = ns.Keybind.overlays[C.buttons[1]]
assert(overlay, "consumables take part in /kb")
overlay:GetScript("OnEnter")(overlay)
ns.Keybind.Input("F8")
ns.Keybind.Save()
assert(env.GetBindingAction("F8") == "CLICK KstyleUI_Consumable1:LeftButton", "/kb saves real secure click bindings")
for _, key in ipairs({ "count", "hotkey", "cooldown" }) do
	K.Options.Write("ActionBars", "consumables." .. key, false)
	assert(key ~= "count" or C.buttons[1].count:GetText() == "", "count text off")
	assert(key ~= "hotkey" or C.buttons[1].hotkey:GetText() == "", "binding text off")
	assert(key ~= "cooldown" or AB.W.LastCall(C.buttons[1].cooldown, "SetHideCountdownNumbers")[1], "cooldown text off")
	K.Options.Write("ActionBars", "consumables." .. key, true)
end
K.Options.Write("ActionBars", "consumables.fade", true)
K.Options.Write("ActionBars", "consumables.fadeAlpha", 0.25)
AB.W.Settle(env)
assert(C.header:GetAlpha() == 0.25, "fade opacity")
AB.W.Enter(C.buttons[1]); AB.W.Settle(env); assert(C.header:GetAlpha() == 1, "hover restores opacity")
AB.W.Leave(C.buttons[1]); env.RunTimers(); AB.W.Settle(env); assert(C.header:GetAlpha() == 0.25, "leaving fades again")
K.Options.Write("ActionBars", "consumables.fade", false)
AB.W.Settle(env)
assert(C.header:GetAlpha() == 1, "fade off")
for _, key in ipairs({ "combat", "idle", "enabled" }) do
	K.Options.Write("ActionBars", "consumables." .. key, false)
	assert(env.Driver(C.header, "visibility"):find("hide", 1, true), key .. " off registers secure visibility")
	if key ~= "enabled" then
		env._combat = true; env.RunStateDrivers()
		assert(C.header:IsShown() == (key == "idle"), "secure combat visibility obeys " .. key)
		env._combat = false; env.RunStateDrivers()
		assert(C.header:IsShown() == (key == "combat"), "secure idle visibility obeys " .. key)
	end
	K.Options.Write("ActionBars", "consumables." .. key, true)
end
Bag({ 90001, 90002, 90003, 90004 })
assert(#C.selected == 1 and C.selected[1].id == 90002, "Other groups use-spell ids, ranks by required level, and excludes quest/permanent items")
K.Options.Write("ActionBars", "consumables.other", false)
assert(#C.selected == 0, "Other off")
K.Options.Write("ActionBars", "consumables.hideEmpty", false)
assert(C.header:IsShown() and C.buttons[1]:IsShown(), "hide empty off keeps the empty bar")
-- The holder snaps the Medallions grid to physical pixels; the header keeps the exact grid inside that pixel.
assert(math.abs(C.header:GetWidth() - C.holder:GetWidth()) < K.Scale.Pixel(1) and math.abs(C.header:GetHeight() - C.holder:GetHeight()) < K.Scale.Pixel(1), "an empty visible bar and its backing use the complete chosen grid")
K.Options.Write("ActionBars", "consumables.hideEmpty", true)
assert(not C.header:IsShown(), "hide empty on")

for _, field in ipairs({ "itemID", "stackCount", "iconFileID" }) do
	Bag({ 118 })
	slots[1][field] = env.Secret(42)
	env.FireEvent("BAG_UPDATE_DELAYED")
	assert(field == "iconFileID" or #C.selected == 0, "secret bag fields are dropped before indexing, arithmetic or comparison")
end
slots = { env.Secret({}) }
env.FireEvent("BAG_UPDATE_DELAYED")
assert(#C.selected == 0, "secret bag records are skipped")
env.C_Container.GetContainerNumSlots = function() return env.Secret(5) end
env.FireEvent("BAG_UPDATE_DELAYED")
assert(#C.selected == 0, "secret bag sizes are skipped")
env.C_Container.GetContainerNumSlots = function(bag) return bag == 0 and #slots or 0 end
K.Options.Write("ActionBars", "consumables.other", true)
local instant, spell, info = env.C_Item.GetItemInfoInstant, env.C_Item.GetItemSpell, env.C_Item.GetItemInfo
env.C_Item.GetItemInfoInstant = function() return nil, nil, nil, nil, nil, env.Secret(0) end
Bag({ 90001 }); assert(#C.selected == 0, "secret item class is never compared")
env.C_Item.GetItemInfoInstant = instant
env.C_Item.GetItemSpell = function() return "Use", env.Secret(100) end
Bag({ 90001 }); assert(#C.selected == 0, "secret use-spell id is never indexed")
env.C_Item.GetItemSpell = spell
env.C_Item.GetItemInfo = function() return nil, nil, nil, env.Secret(100), env.Secret(50), nil, nil, env.Secret(20) end
Bag({ 90001 }); assert(#C.selected == 0, "secret metadata is never ranked")
env.C_Item.GetItemInfo = info
Bag({ 118 })
env.C_Item.GetItemCooldown = function() return env.Secret(1), env.Secret(120), 1 end
env._combat = true
env.FireEvent("SPELL_UPDATE_COOLDOWN")
env._combat = false
env.FireEvent("PLAYER_REGEN_ENABLED")
Clean()
K.Modules.Disable("ActionBars")
assert(not C.header:IsShown(), "module disable hides the bar")
K.Modules.Enable("ActionBars")
Bag({ 118, 2455 })
local first, second = C.buttons[1]:GetAttribute("item"), C.buttons[2]:GetAttribute("item")
K.Options.Write("ActionBars", "consumables.reverse", true)
K.Options.Write("ActionBars", "consumables.clickThrough", true)
assert(C.buttons[1]:GetAttribute("item") == first and C.buttons[2]:GetAttribute("item") == second, "reversal keeps consumable button identities")
assert(not C.buttons[1]:IsMouseEnabled() and not C.buttons[2]:IsMouseEnabled(), "consumables pass the mouse through")
env._game.bindings["CLICK KstyleUI_Consumable1:LeftButton"] = { "F8" }
assert(AB.PressKey(env, "F8") and AB.Used(env) == first, "click-through preserves consumable keybind actions")
env._game.bindings["CLICK KstyleUI_Toggle_consumables:LeftButton"] = { "F9" }
env._combat = true
assert(AB.PressKey(env, "F9") and not C.gate:IsShown(), "consumables toggle securely in combat")
assert(AB.PressKey(env, "F9") and C.gate:IsShown(), "consumables return securely in combat")
env._combat = false
Clean()
print("consumables ok: curated ranks, secure combat repack, attachment, grids, settings and secrets")
