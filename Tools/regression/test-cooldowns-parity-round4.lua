-- test-cooldowns-parity-round4.lua: EllesmereUI parity round 4 for Cooldowns: every new option keeps today's defaults on a v0.2.8 profile, applies when switched on (keybinds and their offsets, mirrored key presses, crafted-quality pips, talent conditions, cooldown bars with charge lines, shade and smoothing), follows the events that change it, restores when switched off, and reaches the preview; Action Bars relays its presses.
local C = dofile("Tools/regression/cooldowns_env.lua")
local W = C.W

local game

local function Setup(e)
	C.Game(e)
	game = { slots = {}, keys = {}, actions = {}, page = 1, known = {}, names = {}, quality = {}, item = 8001 }
	e._cdm.cooldowns[204] = { category = C.CATEGORY.Utility, spellCategoryID = 30 }
	e._cdm.charges[1002] = { current = 1, max = 2 }
	e.C_ActionBar = {
		FindSpellActionButtons = function(spell) return game.slots[spell] or {} end,
		GetActionBarPage = function() return game.page end,
		HasBonusActionBar = function() return game.bonus ~= nil end,
		GetBonusBarIndex = function() return game.bonus end,
		HasVehicleActionBar = function() return game.vehicle == true end,
		GetVehicleBarIndex = function() return 12 end,
		HasOverrideActionBar = function() return false end,
		HasTempShapeshiftActionBar = function() return false end,
	}
	e.GetBindingKey = function(command) return game.keys[command] end
	e.GetBindingText = function(key) return key end
	e.GetActionInfo = function(slot) if game.actions[slot] then return "spell", game.actions[slot] end end
	e.C_SpellBook = { IsSpellKnown = function(id) return game.known[id] == true end }
	e.C_Spell.GetSpellIDForSpellIdentifier = function(name) return game.names[name] end
	e.C_Spell.GetSpellCastCount = function() return 3 end
	e.C_Spell.GetLastCategoryCooldownSource = function() return 7001, game.item end
	e.C_Spell.GetItemCooldown = function() return { startTime = 0, duration = 0, modRate = 1, isEnabled = true, isActive = false, isOnGCD = false } end
	e.C_TradeSkillUI = { GetItemCraftedQualityByItemInfo = function(item) return game.quality[item] end }
end

local function New(path)
	local saved = { version = 42, profiles = { Default = { Cooldowns = { enabled = true, path = path } } }, characters = {} }
	local env, K, ns = C.New({ saved = saved, setup = Setup })
	env.RunTimers()
	return env, K, ns, function(key, value) K.Options.Write("Cooldowns", key, value); env.RunTimers() end
end

local function IconOf(ns, group, test)
	local row = ns.Mirror.Row(group)
	for i = 1, row.count do
		local entry = row.icons[i].entry
		if entry and (entry.spellID == test or entry.categoryID == test) then return row.icons[i] end
	end
end

local function BarOf(ns, spell)
	local row = ns.Mirror.Row("bars")
	for i = 1, row.count do
		if row.bars[i].entry and row.bars[i].entry.spellID == spell then return row.bars[i] end
	end
end

local function Key(icon) return icon.hotkey:GetText() end
local function Last(object, method) local call = W.LastCall(object, method) return call and call[1] end
local function Clean(env, K, what) assert(#env._errors == 0 and K.ErrorCount() == 0, what .. " raised no errors") end
local function Registered(env, event)
	for _, frame in ipairs(env._frames) do if frame._events[event] then return true end end
	return false
end
local function Fire(env, ...) env.FireEvent(...); env.RunTimers() end
local function Shown(dots) local n = 0 for _, dot in ipairs(dots or {}) do if dot:IsShown() then n = n + 1 end end return n end

-- Defaults: a v0.2.8 profile keeps every new option off, every icon and bar as it was, and listens to nothing new.
do
	local env, K, ns = New("mirror")
	local current = ns.Settings.current
	for _, group in ipairs({ "essential", "utility" }) do
		local cfg = current[group]
		assert(not cfg.keybind and cfg.keybindX == 0 and cfg.keybindY == 0 and not cfg.pressMirror and not cfg.itemQuality, group .. " keeps keybinds, presses and quality off")
	end
	local bars = current.bars
	assert(not bars.cdSmooth and not bars.hashLines and bars.lineWidth == 1 and bars.lineColorR == 0 and not bars.chargeShade and bars.shadeAlpha == 0.5, "bars keep charge lines and shade off")
	assert(current.rules.talent == "" and current.rules.cdBars == "", "the new spell lists are empty")
	game.slots[1001], game.keys.ACTIONBUTTON1, game.actions[1] = { 1 }, "1", 1001
	local a, potion = IconOf(ns, "essential", 1001), IconOf(ns, "utility", 30)
	assert(not Key(a) or Key(a) == "", "no keybind shows")
	assert(not potion.rankDots, "no quality pips are made")
	K.Widgets.ActionPressed(1, true)
	assert(a.pressHeld == nil, "a press is not mirrored")
	assert(not Registered(env, "UPDATE_BINDINGS") and not Registered(env, "ACTIONBAR_SLOT_CHANGED"), "no key event is heard")
	assert(ns.Mirror.Row("bars").count == 0, "no cooldown bar joins the tracked bars")
	Clean(env, K, "defaults")
end

-- Show keybind: the first bound slot's key, the main bar's only on its shown page, refreshed by its events, moved by its offsets, then off.
do
	local env, K, ns, Write = New("mirror")
	local a, b, util = IconOf(ns, "essential", 1001), IconOf(ns, "essential", 1002), IconOf(ns, "utility", 2001)
	game.slots[1001], game.keys.ACTIONBUTTON3 = { 3 }, "SHIFT-3"
	game.slots[1002], game.keys.MULTIACTIONBAR1BUTTON2 = { 62 }, "CTRL-Q"
	game.slots[2001] = { 15 }
	game.keys.ACTIONBUTTON3 = "SHIFT-3"
	Write("essential.keybind", true)
	assert(Key(a) == "S3" and Key(b) == "CQ", "each icon shows its spell's short key: main bar and bottom left bar")
	assert(Registered(env, "UPDATE_BINDINGS") and Registered(env, "ACTIONBAR_PAGE_CHANGED") and Registered(env, "UPDATE_BONUS_ACTIONBAR"), "key events are heard while a keybind shows")
	assert(not Key(util) or Key(util) == "", "Utility keeps its own switch")
	local size = select(2, a.hotkey:GetFont())
	assert(size == select(2, a.count:GetFont()), "the keybind takes the count's font and size")
	game.keys.ACTIONBUTTON3 = "F"
	Fire(env, "UPDATE_BINDINGS")
	assert(Key(a) == "F", "a new binding shows after UPDATE_BINDINGS")
	game.page = 2; Fire(env, "ACTIONBAR_PAGE_CHANGED")
	assert(not Key(a) or Key(a) == "", "the main bar's key goes when another page shows")
	game.slots[1001] = { 3, 15 }; game.keys.ACTIONBUTTON3 = "F"; Fire(env, "ACTIONBAR_SLOT_CHANGED", 15)
	assert(Key(a) == "F", "a slot on the shown page gives the key")
	game.page, game.bonus = 1, 7; Fire(env, "UPDATE_BONUS_ACTIONBAR")
	assert(not Key(a) or Key(a) == "", "a stance page replaces page one")
	game.slots[1001] = { 75 }; Fire(env, "ACTIONBAR_SLOT_CHANGED", 75)
	assert(Key(a) == "F", "the stance page's own slot gives the key")
	game.vehicle = true; Fire(env, "UPDATE_VEHICLE_ACTIONBAR")
	assert(not Key(a) or Key(a) == "", "a vehicle bar takes the main bar's keys")
	game.vehicle, game.bonus = nil, nil; game.slots[1001] = { 3 }; Fire(env, "UPDATE_BONUS_ACTIONBAR")
	a:Restyle()
	local base = { a.hotkey:GetPoint(1) }
	Write("essential.keybindX", 6); Write("essential.keybindY", -4)
	local moved = { a.hotkey:GetPoint(1) }
	assert(moved[1] == base[1] and moved[2] == base[2] and moved[4] > base[4] and moved[5] < base[5], "the offsets move the keybind from its own anchor")
	a:Restyle()
	moved = { a.hotkey:GetPoint(1) }
	assert(moved[4] > base[4] and moved[5] < base[5], "a restyle keeps the offsets")
	Write("essential.keybindX", 0); Write("essential.keybindY", 0)
	local back = { a.hotkey:GetPoint(1) }
	assert(back[4] == base[4] and back[5] == base[5], "zero offsets restore the exact anchor")
	assert(back[1] == "TOPLEFT" and select(1, a.count:GetPoint(1)) == "BOTTOMRIGHT" and select(1, a.countdown:GetPoint(1)) == "CENTER", "the keybind keeps its corner clear of the count and the countdown")
	env.SetCombat(true); Write("essential.keybindX", 2); env.SetCombat(false)
	Clean(env, K, "keybind in combat")
	env.C_ActionBar.FindSpellActionButtons = function() error("unavailable") end
	Fire(env, "UPDATE_BINDINGS")
	assert(not Key(a) or Key(a) == "", "an unreadable slot list shows no key")
	env.C_ActionBar.FindSpellActionButtons = function(spell) return game.slots[spell] or {} end
	Write("essential.keybind", false)
	assert((not Key(a) or Key(a) == "") and (not Key(b) or Key(b) == ""), "off clears every keybind")
	assert(not Registered(env, "UPDATE_BINDINGS") and not Registered(env, "ACTIONBAR_SLOT_CHANGED"), "off stops the key events")
	Clean(env, K, "keybind")
end

-- Mirror key presses: a press of the slot holding the spell presses its icon, even on cooldown; other icons and other groups stay still; off stops it.
do
	local env, K, ns, Write = New("mirror")
	local a, b, util = IconOf(ns, "essential", 1001), IconOf(ns, "essential", 1002), IconOf(ns, "utility", 2001)
	game.actions[1], game.actions[2], game.actions[3] = 1001, 2001, 1033
	Write("essential.pressMirror", true)
	env._cdm.cooldown[1001] = { active = true }; Fire(env, "SPELL_UPDATE_COOLDOWN")
	K.Widgets.ActionPressed(1, true)
	assert(a.pressHeld == true and not b.pressHeld, "the pressed spell's icon goes down, on cooldown too")
	K.Widgets.ActionPressed(1, false)
	assert(a.pressHeld == false, "and comes back up on release")
	K.Widgets.ActionPressed(2, true)
	assert(not util.pressHeld, "Utility keeps its own switch")
	local c = IconOf(ns, "essential", 1003)
	K.Widgets.ActionPressed(3, true)
	assert(c.pressHeld == true, "an overridden spell's press reaches its icon")
	game.actions[4] = env.Secret(1001)
	K.Widgets.ActionPressed(4, true)
	K.Widgets.ActionPressed(env.Secret(1), true)
	Clean(env, K, "secret presses")
	Write("essential.pressMirror", false)
	a.pressHeld = nil
	K.Widgets.ActionPressed(1, true)
	assert(a.pressHeld == nil, "off stops mirroring presses")
	Write("essential.pressMirror", true)
	K.Modules.Disable("Cooldowns"); env.RunTimers()
	a.pressHeld = nil
	K.Widgets.ActionPressed(1, true)
	assert(a.pressHeld == nil, "stopping the module stops listening")
	Clean(env, K, "presses")
end

-- Item quality: the last potion's crafted rank as pips, kept through a secret source, refreshed on item events, then off.
do
	local env, K, ns, Write = New("mirror")
	local potion = IconOf(ns, "utility", 30)
	game.quality[8001] = 2
	Write("utility.itemQuality", true)
	assert(Shown(potion.rankDots) == 2, "a rank-2 potion shows two pips")
	assert(select(1, potion.rankDots[1]:GetPoint(1)) == "TOPRIGHT", "the pips sit in the free top-right corner")
	game.item, game.quality[8002] = 8002, 3; Fire(env, "BAG_UPDATE_COOLDOWN")
	assert(Shown(potion.rankDots) == 3, "a new potion's rank follows the item event")
	game.item = env.Secret(8001); Fire(env, "BAG_UPDATE_COOLDOWN")
	assert(Shown(potion.rankDots) == 3, "a secret source keeps the last rank")
	game.item, game.quality[8003] = 8003, nil; Fire(env, "BAG_UPDATE_COOLDOWN")
	assert(Shown(potion.rankDots) == 0, "an item with no crafted quality shows none")
	game.item = 8002; env.C_TradeSkillUI = nil; Fire(env, "BAG_UPDATE_COOLDOWN")
	assert(Shown(potion.rankDots) == 0, "without the API no pip shows")
	env.C_TradeSkillUI = { GetItemCraftedQualityByItemInfo = function(item) return game.quality[item] end }
	Fire(env, "BAG_UPDATE_COOLDOWN")
	assert(Shown(potion.rankDots) == 3, "the API back shows the rank")
	assert(not IconOf(ns, "essential", 1001).rankDots, "spells never get pips")
	Write("utility.itemQuality", false)
	assert(Shown(potion.rankDots) == 0, "off hides the pips")
	Clean(env, K, "item quality")
end

-- Only with talent: a talent by name or ID hides a spell until known, follows SPELLS_CHANGED, closes gaps, and is safe without its APIs.
do
	local env, K, ns, Write = New("mirror")
	local a, b = IconOf(ns, "essential", 1001), IconOf(ns, "essential", 1002)
	Write("essential.growth", "right")
	local slotA = W.LastCall(a, "SetPoint")[4]
	game.names["Feral Instinct"] = 9001
	Write("rules.talent", "1001=Feral Instinct, 1002=9002")
	assert(a:GetAlpha() == 0 and b:GetAlpha() == 0 and not a:IsMouseEnabled(), "a spell hides while its talent is not known")
	game.known[9001] = true; Fire(env, "SPELLS_CHANGED")
	assert(a:GetAlpha() == 1 and a:IsMouseEnabled() and b:GetAlpha() == 0, "learning the talent shows it")
	game.known[9002] = true; Fire(env, "SPELLS_CHANGED")
	assert(b:GetAlpha() == 1, "a talent by ID works too")
	game.known[9001] = nil; Fire(env, "SPELLS_CHANGED")
	Write("rules.shift", "1001")
	assert(a:GetAlpha() == 0 and W.LastCall(b, "SetPoint")[4] == slotA, "Close gaps for these closes its gap")
	Write("rules.talent", "1001=Unknown Talent")
	assert(a:GetAlpha() == 0, "a talent the game does not know hides the spell")
	env.C_SpellBook.IsSpellKnown = function() return env.Secret(false) end
	Write("rules.talent", "1001=9001")
	assert(a:GetAlpha() == 1, "a secret answer hides nothing")
	env.C_SpellBook = nil; Fire(env, "SPELLS_CHANGED")
	assert(a:GetAlpha() == 1, "without the API nothing is hidden")
	env.SetCombat(true); Write("rules.talent", "1001=Feral Instinct"); env.SetCombat(false)
	Write("rules.talent", ""); Write("rules.shift", "")
	assert(a:GetAlpha() == 1 and W.LastCall(a, "SetPoint")[4] == slotA, "clearing the list restores the icon and its slot")
	Clean(env, K, "talents")
end

-- Cooldown bars: listed cooldowns join the tracked bars, fill as they recover, follow cooldown and charge events, split by charges with lines, shade and smoothing, then off.
do
	local env, K, ns, Write = New("mirror")
	Write("bars.count", 4)
	env._cdm.cooldown[1001] = { active = true }
	Write("rules.cdBars", "1001, 1002")
	local bar, charged = BarOf(ns, 1001), BarOf(ns, 1002)
	assert(bar and charged and ns.Mirror.Row("bars").count == 2, "each listed cooldown is a bar")
	assert(bar.name:GetText() == "Spell 1001" and bar:GetAlpha() == 1, "a cooldown bar shows its name in full")
	local timed = W.LastCall(bar.status, "SetTimerDuration")
	assert(timed and timed[1].spell == 1001 and timed[2] == 0 and timed[3] == 0, "a cooling spell's bar fills as it recovers, without easing")
	assert(Last(bar.timer, "SetCooldownFromDurationObject").spell == 1001, "its timer counts the cooldown down")
	env._cdm.cooldown[1001] = { active = false }; Fire(env, "SPELL_UPDATE_COOLDOWN")
	assert(Last(bar.status, "SetValue") == 1, "a ready spell's bar is full")
	local writes = #W.Calls(bar.status, "SetTimerDuration")
	env.FireEvent("UNIT_AURA", "player", { isFullUpdate = true }); env.RunTimers()
	assert(#W.Calls(bar.status, "SetTimerDuration") == writes, "an aura refresh leaves cooldown bars alone")
	env._cdm.cooldown[1001] = { active = true }; Fire(env, "SPELL_UPDATE_COOLDOWN")
	assert(#W.Calls(bar.status, "SetTimerDuration") == writes + 1, "a cooldown event refreshes it")
	Write("bars.cdSmooth", true)
	assert(W.LastCall(bar.status, "SetTimerDuration")[2] == 1, "Smooth cooldown bars eases them")
	assert(not charged.hashes and not charged.recharge, "no charge lines until asked")
	Write("bars.hashLines", true)
	assert(charged.hashes and charged.hashes[1]:IsShown() and not (charged.hashes[2] and charged.hashes[2]:IsShown()), "two charges give one line")
	assert(Last(charged.status, "SetValue") ~= nil and charged.recharge:IsShown(), "the charges fill and the recharging section shows")
	assert(W.LastCall(charged.recharge, "SetTimerDuration")[1].kind == "charge", "the recharging section fills with the next charge")
	assert(Last(charged.timer, "SetCooldownFromDurationObject").kind == "charge", "the timer shows the next charge")
	assert(W.LastCall(charged.recharge, "SetPoint")[2] == charged.status:GetStatusBarTexture(), "it starts where the charges end")
	assert(W.LastCall(charged.hashes[1], "SetColorTexture")[1] == 0, "lines take the line colour")
	local drawn, styled = #W.Calls(charged.hashes[1], "SetColorTexture"), #W.Calls(charged.recharge, "SetOrientation")
	Fire(env, "SPELL_UPDATE_CHARGES"); Fire(env, "SPELL_UPDATE_COOLDOWN")
	assert(#W.Calls(charged.hashes[1], "SetColorTexture") == drawn and #W.Calls(charged.recharge, "SetOrientation") == styled, "charge and cooldown events redraw no line and restyle no section")
	local plain = { unpack(charged.recharge.colorRGBA, 1, 4) }
	assert(plain[4] == ns.Settings.current.bars.fillOpacity, "the recharging section takes the bar colour")
	Write("bars.chargeShade", true); Write("bars.shadeAlpha", 0.6)
	local shaded = charged.recharge.colorRGBA
	assert(math.abs(shaded[1] - plain[1] * 0.4) < 1e-6 and math.abs(shaded[3] - plain[3] * 0.4) < 1e-6 and shaded[4] == plain[4], "Partial charge shade darkens the recharging section by Shade darkness")
	Write("bars.lineWidth", 3); Write("bars.lineColor", { r = 1, g = 1, b = 1 })
	assert(W.LastCall(charged.hashes[1], "SetColorTexture")[1] == 1, "the line colour applies")
	env._cdm.charges[1002] = { current = 2, max = 2 }; Fire(env, "SPELL_UPDATE_CHARGES")
	assert(not charged.recharge:IsShown(), "full charges hide the recharging section")
	env.C_Spell.GetSpellCharges = function() return env.Secret({}) end; Fire(env, "SPELL_UPDATE_CHARGES")
	assert(charged.hashes[1]:IsShown(), "secret charges keep the last known sections")
	Write("bars.orientation", "VERTICAL")
	assert(W.LastCall(charged.hashes[1], "SetPoint")[1] == "BOTTOMRIGHT", "a vertical bar's lines run across it")
	Write("bars.hashLines", false)
	assert(not charged.hashes[1]:IsShown() and not charged.recharge:IsShown(), "off hides the lines and the section")
	env.SetCombat(true); Write("bars.hashLines", true); env.SetCombat(false)
	Write("rules.cdBars", "")
	assert(ns.Mirror.Row("bars").count == 0, "clearing the list removes the cooldown bars")
	Clean(env, K, "cooldown bars")
end

-- Preview: sample keybinds, a press, quality pips on the sample potion, hidden talent samples and a sample cooldown bar with its sections.
do
	local env, K, ns, Write = New("mirror")
	local pane = env.CreateFrame("Frame", nil, env.UIParent)
	pane:SetSize(280, 300)
	local frame = ns.Preview.Build(pane)
	local first = frame.rows.essential.icons[1]
	assert(not Key(first) or Key(first) == "", "the preview shows no keybind by default")
	Write("essential.keybind", true); frame:Refresh()
	assert(Key(first) == "1" and Key(frame.rows.essential.icons[2]) == "2", "the preview shows sample keybinds")
	Write("essential.pressMirror", true); frame:Refresh()
	assert(first.pressHeld == false and W.LastCall(first.press, "Play"), "the preview presses the first sample")
	Write("utility.itemQuality", true); frame:Refresh()
	local row, potion = frame.rows.utility, nil
	for i = 1, row.count do if row.icons[i].rankDots then potion = row.icons[i] end end
	assert(potion and Shown(potion.rankDots) == 3, "the preview's sample potion shows its pips")
	Write("rules.talent", "x=Unknown Talent"); frame:Refresh()
	assert(first:GetAlpha() == 0, "the preview hides samples whose talent is not known")
	Write("rules.talent", ""); Write("rules.cdBars", "x"); Write("bars.hashLines", true); frame:Refresh()
	local bar = frame.rows.bars.bars[2]
	assert(bar.name:GetText() == K.L["Multi-Shot"] and bar.hashes[1]:IsShown() and bar.recharge:IsShown(), "the preview shows a cooldown bar with its sections")
	Write("rules.cdBars", ""); frame:Refresh()
	assert(not bar.recharge:IsShown(), "and goes back to the buff bars")
	Clean(env, K, "preview")
end

-- Action Bars relays a key press on its button, down and up, with the slot, only while someone listens.
do
	local AB = dofile("Tools/regression/actionbars_env.lua")
	local env, K = AB.New({ class = "WARRIOR", setup = function(e) e._game.bindings.ACTIONBUTTON1 = { "1" } end })
	AB.Enable(env, K)
	AB.Slot(env, 1, { texture = 135489, type = "spell", id = 100 })
	local got = {}
	K.Widgets.OnActionPress(function(slot, down) got[#got + 1] = { slot, down } end)
	AB.PressKey(env, "1")
	assert(#got == 2 and got[1][1] == 1 and got[1][2] == true and got[2][2] == false, "a key press reaches the listener with its slot, down then up")
	K.Widgets.OnActionPress(nil)
	AB.PressKey(env, "1")
	assert(#got == 2, "with no listener nothing is relayed")
	assert(#AB.Errors(env) == 0, "relaying raised no errors")
end

print("cooldowns parity round 4 ok")
