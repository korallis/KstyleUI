-- test-actionbars-ranks.lua: learning a higher rank of a spell on the bars offers to swap it in, and Update bars puts it in every slot that held a lower rank.
local AB = dofile("Tools/regression/actionbars_env.lua")
local W = AB.W

local HS1, HS2, HS3, REND1, REND2, SHOUT2, CHARGE = 78, 284, 285, 772, 6546, 6192, 100
local SPELLS = {
	[HS1] = { "Heroic Strike", "Rank 1" }, [HS2] = { "Heroic Strike", "Rank 2" }, [HS3] = { "Heroic Strike", "Rank 3" },
	[REND1] = { "Rend", "Rank 1" }, [REND2] = { "Rend", "Rank 2" }, [SHOUT2] = { "Battle Shout", "Rank 2" }, [CHARGE] = { "Charge", "" },
}
-- Heroic Strike rank 1 on bar 1 and the battle stance bar (73 to 84), Rend, and a macro and a flyout whose IDs equal rank 1's to leave alone.
local SLOTS = { [3] = { "spell", HS1 }, [75] = { "spell", HS1 }, [5] = { "spell", REND1 }, [7] = { "macro", HS1 }, [8] = { "flyout", HS1 }, [9] = { "spell", CHARGE } }

local function Setup(mode)
	local env, K = AB.New()
	local g = env._game
	for id, s in pairs(SPELLS) do
		g.spells[id] = { name = s[1], subtext = s[2] }
	end
	AB.Enable(env, K)
	K.Options.Write("ActionBars", "ranks", mode or "ask")
	K.Options.Write("ActionBars", "newSpells", "off")
	for slot, s in pairs(SLOTS) do
		g.slots[slot] = { type = s[1], id = s[2], texture = slot }
	end
	return env, K, g
end

local function Learn(env, ...)
	for i = 1, select("#", ...) do
		env.FireEvent("LEARNED_SPELL_IN_SKILL_LINE", (select(i, ...)), 1, false)
	end
	env.FireEvent("SPELLS_CHANGED")
	env.RunTimers()
end

local function Shown(env, K)
	W.Settle(env)
	local host = K.Widgets.DialogHost()
	return host:IsShown() and host.body:GetText() or nil
end

local function Press(env, K, label)
	for _, button in ipairs(K.Widgets.DialogHost().visibleButtons) do
		if button.label:GetText() == label then
			W.Click(button)
			return W.Settle(env)
		end
	end
	error("the dialog has no " .. label .. " button")
end

local function Has(text, part)
	return text ~= nil and text:find(part, 1, true) ~= nil
end

local function Holds(g, slot, id)
	return g.slots[slot] and g.slots[slot].type == "spell" and g.slots[slot].id == id
end

-- Ask (the default): a higher rank of a spell on the bars shows one popup, with its icon, and changes nothing yet.
do
	local env, K, g = Setup()
	Learn(env, HS2)
	local text, host = Shown(env, K), K.Widgets.DialogHost()
	assert(Has(text, "You learned a new rank: |T1000284:0|t HEROIC STRIKE (RANK 2). Update your action bars?"), tostring(text))
	local buttons = host.visibleButtons
	assert(host.titleText:GetText() == "NEW SPELL RANK" and #buttons == 2 and buttons[1].label:GetText() == "Not now" and buttons[2].label:GetText() == "Update bars" and buttons[2].primary)
	assert(Holds(g, 3, HS1) and Holds(g, 75, HS1) and #g.placed == 0, "nothing changes before the player answers")
	Press(env, K, "Not now")
	assert(Shown(env, K) == nil and Holds(g, 3, HS1) and #g.placed == 0, "Not now closes it and changes nothing")
	assert(#env._errors == 0, AB.Errors(env))
end

-- No popup for a spell with no rank, a rank whose spell is not on the bars, or a rank below the one on the bars.
do
	local env, K, g = Setup()
	g.slots[3], g.slots[75] = { type = "spell", id = HS3 }, { type = "spell", id = HS3 }
	Learn(env, CHARGE, SHOUT2, HS2)
	assert(Shown(env, K) == nil and #g.placed == 0, "an unranked spell, a rank not on the bars and a lower rank show nothing")
	Learn(env, REND2)
	local text = Shown(env, K)
	assert(Has(text, "REND (RANK 2)") and not Has(text, "HEROIC") and not Has(text, "SHOUT") and not Has(text, "CHARGE"), "a real rank lists only itself: " .. tostring(text))
	assert(#env._errors == 0, AB.Errors(env))
end

-- Update bars replaces exactly the slots with a lower rank, the stance bar's too, and leaves the cursor empty.
do
	local env, K, g = Setup()
	Learn(env, HS2)
	Press(env, K, "Update bars")
	assert(Holds(g, 3, HS2) and Holds(g, 75, HS2), "bar 1 and the battle stance bar get rank 2")
	assert(Holds(g, 5, REND1) and g.slots[7].type == "macro" and g.slots[8].type == "flyout" and Holds(g, 9, CHARGE), "other slots, macros and flyouts are untouched")
	table.sort(g.placed)
	assert(#g.placed == 2 and g.placed[1] == 3 and g.placed[2] == 75 and g.cursor == nil, "only those two slots change, and the old rank is not left on the cursor")
	assert(#env._blocked == 0 and #env._errors == 0, AB.Errors(env))
end

-- Several ranks at once, or a second while the popup is open, give one popup listing them all, and one update.
do
	local env, K, g = Setup()
	Learn(env, HS2, HS3, REND2)
	local text = Shown(env, K)
	assert(Has(text, "HEROIC STRIKE (RANK 3)") and Has(text, "REND (RANK 2)") and not Has(text, "HEROIC STRIKE (RANK 2)"), tostring(text))
	Press(env, K, "Update bars")
	assert(Holds(g, 3, HS3) and Holds(g, 75, HS3) and Holds(g, 5, REND2), "the highest learned rank wins")
	assert(Shown(env, K) == nil and g.cursor == nil, "one popup, closed, and an empty cursor")
	env, K, g = Setup()
	Learn(env, HS3)
	Learn(env, HS2, REND2)
	text = Shown(env, K)
	assert(Has(text, "HEROIC STRIKE (RANK 3)") and Has(text, "REND (RANK 2)") and not Has(text, "HEROIC STRIKE (RANK 2)"), "the open popup grows: " .. tostring(text))
	Press(env, K, "Update bars")
	assert(Holds(g, 3, HS3) and Holds(g, 5, REND2) and Shown(env, K) == nil, "one click updates both, and a lower rank learned later never wins")
end

-- A slot that does not take the new rank is logged once, a slot changed since the popup is left alone, and the cursor ends empty.
do
	local env, K, g = Setup()
	g.refuse, g.slots[4] = { [75] = true }, { type = "spell", id = HS1 }
	Learn(env, HS2)
	g.slots[4] = { type = "spell", id = REND1 }
	Press(env, K, "Update bars")
	assert(Holds(g, 3, HS2) and Holds(g, 4, REND1) and g.cursor == nil, "slot 3 updates, the changed slot 4 stays, and the cursor is empty")
	local found = 0
	for _, entry in ipairs(env.KstyleUIDB.devlog) do
		found = found + (tostring(entry.message):find("slot 75 did not take", 1, true) and 1 or 0)
	end
	assert(found == 1, "the failed slot is logged once")
end

-- A busy cursor is never touched: the update waits for the item to go down and for combat to end, and swaps only what was approved.
do
	local env, K, g = Setup()
	Learn(env, HS2)
	local item = { type = "item", id = 6948 }
	g.cursor = item
	Press(env, K, "Update bars")
	assert(g.cursor == item and #g.placed == 0, "the held item stays on the cursor")
	g.cursor = nil
	env.SetCombat(true)
	Learn(env, REND2)
	assert(#g.placed == 0 and #env._blocked == 0, "a wait that ends in combat waits for combat to end too")
	env.SetCombat(false)
	assert(Holds(g, 3, HS2) and Holds(g, 75, HS2) and g.cursor == nil, "then the update runs")
	assert(Holds(g, 5, REND1) and Has(Shown(env, K), "REND (RANK 2)"), "a rank learned meanwhile still waits for its own answer")
end

-- In combat Update bars waits for combat to end, says so, and makes no protected call.
do
	local env, K, g = Setup()
	Learn(env, HS2)
	env.SetCombat(true)
	Press(env, K, "Update bars")
	assert(#g.placed == 0 and #env._blocked == 0, "nothing is placed in combat")
	assert(Has(Shown(env, K), "when combat ends"), "the player is told it waits")
	env.SetCombat(false)
	assert(Holds(g, 3, HS2) and Holds(g, 75, HS2) and g.cursor == nil and #env._blocked == 0, "it runs when combat ends")
end

-- Update automatically swaps with no popup; Off does nothing, and cancels a swap still waiting for combat to end.
do
	local env, K, g = Setup("auto")
	Learn(env, HS2)
	assert(Shown(env, K) == nil and Holds(g, 3, HS2) and Holds(g, 75, HS2) and g.cursor == nil, "placed with no popup")
	env, K, g = Setup("auto")
	env.SetCombat(true)
	Learn(env, HS2)
	K.Options.Write("ActionBars", "ranks", "off")
	Learn(env, HS2)
	K.Options.Write("ActionBars", "ranks", "ask")
	env.SetCombat(false)
	assert(Shown(env, K) == nil and Holds(g, 3, HS1) and #g.placed == 0, "Off cancels the waiting swap for good, and shows and changes nothing")
	env.FireEvent("LEARNED_SPELL_IN_SKILL_LINE", HS2, 1, false)
	K.Options.Write("ActionBars", "ranks", "off")
	K.Options.Write("ActionBars", "ranks", "ask")
	env.RunTimers()
	assert(Shown(env, K) == nil and #g.placed == 0, "Off also cancels a rank still in the learn batch")
end

-- The settings row: Ask by default, Update automatically and Off, with short help.
do
	local env, K = AB.New()
	local row
	for _, r in ipairs(K.Options.Get("ActionBars")) do
		row = r.key == "ranks" and r or row
	end
	local o = row.options
	assert(row.type == "dropdown" and row.label == "New spell ranks" and #row.help < 100 and K.Store.Module("ActionBars").ranks == "ask", "Ask is the default")
	assert(#o == 3 and o[1].value == "ask" and o[2].value == "auto" and o[2].label == "Update automatically" and o[3].value == "off" and #env._errors == 0)
end

-- Secret names, ranks and slots are skipped without errors; plain ones still work.
do
	local env, K, g = Setup()
	g.slots[100] = { type = env.Secret("spell"), id = env.Secret(HS1) }
	g.spells[REND1].subtext, g.spells[SHOUT2].name = env.Secret("Rank 1"), env.Secret("Battle Shout")
	Learn(env, HS2, REND2, SHOUT2)
	local text = Shown(env, K)
	assert(Has(text, "HEROIC STRIKE (RANK 2)") and not Has(text, "REND") and #env._errors == 0, tostring(text) .. AB.Errors(env))
	Press(env, K, "Update bars")
	assert(Holds(g, 3, HS2) and Holds(g, 5, REND1) and env.issecretvalue(g.slots[100].id) and #env._errors == 0, "only the plain slots change" .. AB.Errors(env))
end

local function Logged(env, part)
	local found = 0
	for _, entry in ipairs(env.KstyleUIDB.devlog) do
		found = found + (tostring(entry.message):find(part, 1, true) and 1 or 0)
	end
	return found
end

-- A rank whose text has not loaded is asked for with RequestLoadSpellData and offered once SPELL_DATA_LOAD_RESULT says it loaded.
do
	local env, K, g = Setup()
	local data = g.spells[HS2]
	g.spells[HS2] = nil
	Learn(env, HS2, REND2)
	assert(Has(Shown(env, K), "REND (RANK 2)") and not Has(Shown(env, K), "HEROIC"), "the loaded rank is offered at once")
	assert(#g.loadRequests == 1 and g.loadRequests[1] == HS2, "only the unloaded rank is requested: " .. #g.loadRequests)
	Press(env, K, "Not now")
	env.FireEvent("SPELL_DATA_LOAD_RESULT", env.Secret(HS2), true)
	env.FireEvent("SPELL_DATA_LOAD_RESULT", REND2, true)
	env.RunTimers()
	assert(Shown(env, K) == nil and #env._errors == 0, "a secret or unrequested result does nothing" .. AB.Errors(env))
	g.spells[HS2] = data
	env.FireEvent("SPELL_DATA_LOAD_RESULT", HS2, true)
	env.RunTimers()
	assert(Has(Shown(env, K), "You learned a new rank: |T1000284:0|t HEROIC STRIKE (RANK 2)."), "the loaded rank is offered: " .. tostring(Shown(env, K)))
	Press(env, K, "Update bars")
	assert(Holds(g, 3, HS2) and Holds(g, 75, HS2) and g.cursor == nil and #g.loadRequests == 1, "and placed, with no second request")
	assert(#env._errors == 0, AB.Errors(env))
end

-- A load that fails is dropped: no popup, no second request, no error. An unranked spell that has loaded is never requested.
do
	local env, K, g = Setup()
	local data = g.spells[HS2]
	g.spells[HS2] = nil
	Learn(env, HS2, CHARGE)
	assert(#g.loadRequests == 1 and g.loadRequests[1] == HS2, "Charge has loaded and has no rank, so only Heroic Strike is requested")
	g.spells[HS2] = data
	env.FireEvent("SPELL_DATA_LOAD_RESULT", HS2, false)
	env.RunTimers()
	assert(Shown(env, K) == nil and #g.loadRequests == 1 and Holds(g, 3, HS1), "a failed load is dropped")
	Learn(env, HS2)
	assert(Has(Shown(env, K), "HEROIC STRIKE (RANK 2)"), "learning it again, loaded, offers it")
	assert(#env._errors == 0, AB.Errors(env))
end

-- Without IsSpellDataCached a spell with no rank text is requested once and dropped when the loaded data still has no rank.
do
	local env, K, g = Setup()
	env.C_Spell.IsSpellDataCached = nil
	local data = g.spells[HS2]
	g.spells[HS2] = nil
	Learn(env, HS2, CHARGE)
	table.sort(g.loadRequests)
	assert(#g.loadRequests == 2 and g.loadRequests[1] == CHARGE and g.loadRequests[2] == HS2, "both are requested once: " .. table.concat(g.loadRequests, ","))
	g.spells[HS2] = data
	env.FireEvent("SPELL_DATA_LOAD_RESULT", CHARGE, true)
	env.FireEvent("SPELL_DATA_LOAD_RESULT", HS2, true)
	env.RunTimers()
	local text = Shown(env, K)
	assert(Has(text, "HEROIC STRIKE (RANK 2)") and not Has(text, "CHARGE") and #g.loadRequests == 2, "the rank is offered and Charge is not requested again: " .. tostring(text))
	assert(#env._errors == 0, AB.Errors(env))
end

-- Without RequestLoadSpellData an unloaded rank is skipped and logged once. Off requests nothing.
do
	local env, K, g = Setup()
	env.C_Spell.RequestLoadSpellData = nil
	g.spells[HS2] = nil
	Learn(env, HS2)
	Learn(env, HS2)
	assert(Shown(env, K) == nil and Logged(env, "RequestLoadSpellData") == 1 and #env._errors == 0, "skipped and logged once" .. AB.Errors(env))
	env, K, g = Setup("off")
	g.spells[HS2] = nil
	Learn(env, HS2)
	assert(#g.loadRequests == 0 and Shown(env, K) == nil, "Off asks the client for nothing")
end

-- A result the client delivers from inside RequestLoadSpellData itself is kept, and the rank is offered.
do
	local env, K, g = Setup()
	local data = g.spells[HS2]
	g.spells[HS2] = nil
	env.C_Spell.RequestLoadSpellData = function(id)
		g.loadRequests[#g.loadRequests + 1] = id
		g.spells[id] = data
		env.FireEvent("SPELL_DATA_LOAD_RESULT", id, true)
	end
	Learn(env, HS2)
	assert(#g.loadRequests == 1 and Has(Shown(env, K), "HEROIC STRIKE (RANK 2)"), "a synchronous load still offers the rank: " .. tostring(Shown(env, K)))
	Press(env, K, "Update bars")
	assert(Holds(g, 3, HS2) and Holds(g, 75, HS2) and #env._errors == 0, "and places it" .. AB.Errors(env))
end

-- The loading set is bounded, and a result frees its slot.
do
	local env, _, g = Setup()
	local ids = {}
	for i = 1, 25 do
		ids[i] = 900000 + i
	end
	Learn(env, unpack(ids))
	assert(#g.loadRequests == 20 and Logged(env, "loading") == 1, "at most 20 spells load at once, logged once: " .. #g.loadRequests)
	for i = 1, 25 do
		env.FireEvent("SPELL_DATA_LOAD_RESULT", ids[i], false)
	end
	env.RunTimers()
	Learn(env, ids[25])
	assert(#g.loadRequests == 21 and g.loadRequests[21] == ids[25] and #env._errors == 0, "a result frees its slot" .. AB.Errors(env))
end

local function NewSpells(mode)
	local env, K, g = Setup()
	K.Options.Write("ActionBars", "newSpells", mode or "ask")
	g.spells[200] = { name = "New Ability", subtext = "" }
	g.spells[201] = { name = "Other Ability", subtext = "Rank 1" }
	g.bookSpells[20] = { spellID = 200, itemType = env.Enum.SpellBookItemType.Spell, isPassive = false, isOffSpec = false }
	g.bookSpells[21] = { spellID = 201, itemType = env.Enum.SpellBookItemType.Spell, isPassive = false, isOffSpec = false }
	return env, K, g
end

-- Ask is on by default; a new active spell gets its own action, and one empty slot gets it.
do
	local env, K = AB.New()
	local row
	for _, r in ipairs(K.Options.Get("ActionBars")) do
		if r.key == "newSpells" then row = r end
	end
	assert(K.Store.Module("ActionBars").newSpells == "ask" and row.label == "New spells")
	assert(row.options[2].value == "auto" and row.options[2].label == "Always add" and row.options[3].label == "Never")
	assert(#env._errors == 0, AB.Errors(env))
	local g
	env, K, g = NewSpells()
	Learn(env, 200)
	assert(Has(Shown(env, K), "NEW ABILITY") and #K.Widgets.DialogHost().visibleButtons == 2 and #g.placed == 0)
	Press(env, K, "Add new to bars")
	assert(Holds(g, 1, 200) and #g.placed == 1 and g.cursor == nil and Shown(env, K) == nil)
	Learn(env, 200)
	assert(Shown(env, K) == nil and #g.placed == 1, "a spell already on any action page is never added again")
end

-- A combined offer preserves the other choice, regardless of which action the player takes first.
for _, first in ipairs({ "Update bars", "Add new to bars" }) do
	local env, K, g = NewSpells()
	Learn(env, HS2, 200)
	local text = Shown(env, K)
	assert(Has(text, "HEROIC STRIKE") and Has(text, "NEW ABILITY") and #K.Widgets.DialogHost().visibleButtons == 3)
	Press(env, K, first)
	if first == "Update bars" then
		assert(Holds(g, 3, HS2) and not Holds(g, 1, 200) and Has(Shown(env, K), "NEW ABILITY"))
		Press(env, K, "Add new to bars")
	else
		assert(Holds(g, 1, 200) and Holds(g, 3, HS1) and Has(Shown(env, K), "HEROIC STRIKE"))
		Press(env, K, "Update bars")
	end
	assert(Holds(g, 1, 200) and Holds(g, 3, HS2) and Holds(g, 75, HS2) and #g.placed == 3 and #env._errors == 0, AB.Errors(env))
end

-- Combat batches both kinds without opening a dialog or making protected calls.
do
	local env, K, g = NewSpells()
	env.SetCombat(true)
	Learn(env, HS2, 200, 201)
	assert(Shown(env, K) == nil and #g.placed == 0 and #env._blocked == 0)
	env.SetCombat(false)
	assert(Has(Shown(env, K), "NEW ABILITY") and Has(Shown(env, K), "OTHER ABILITY"))
	env.SetCombat(true)
	Press(env, K, "Add new to bars")
	assert(#g.placed == 0 and #env._blocked == 0)
	env.SetCombat(false)
	assert(Holds(g, 1, 200) and Holds(g, 2, 201) and #g.placed == 2 and #env._blocked == 0 and #env._errors == 0, AB.Errors(env))
end

-- Bar 1 fills before bar 2's real page (61 onward); occupied slots and hidden buttons stay intact.
do
	local env, K, g = NewSpells("auto")
	for slot = 1, 12 do g.slots[slot] = { type = "item", id = 6948 } end
	K.Options.Write("ActionBars", "bar2.buttons", 2)
	g.slots[61] = { type = "macro", id = 1 }
	Learn(env, 200)
	assert(Holds(g, 62, 200) and #g.placed == 1 and g.slots[1].type == "item" and g.slots[61].type == "macro")
	Learn(env, 201)
	assert(Has(Shown(env, K), "No free slots") and #g.placed == 1 and not g.slots[63], "hidden buttons cannot receive spells")
	env, K, g = NewSpells("auto")
	K.Options.Write("ActionBars", "bar1.enabled", false)
	Learn(env, 200)
	assert(Holds(g, 61, 200) and not g.slots[1] and #g.placed == 1, "disabled bar 1 is skipped")
	K.Options.Write("ActionBars", "bar2.enabled", false)
	Learn(env, 201)
	assert(Has(Shown(env, K), "No free slots") and #g.placed == 1)
end

-- Physical left-to-right order follows reversed growth and vertical layouts too.
do
	local env, K, g = NewSpells("auto")
	K.Options.Write("ActionBars", "bar1.growth", "LEFTDOWN")
	Learn(env, 200)
	assert(Holds(g, 12, 200) and #g.placed == 1)
	env, K, g = NewSpells("auto")
	K.Options.Write("HudStyle", "style", "frames")
	K.Options.Write("ActionBars", "bar1.growth", "RIGHTDOWN")
	K.Options.Write("ActionBars", "bar1.rows", 2)
	K.Options.Write("ActionBars", "bar1.orientation", "VERTICAL")
	g.slots[3] = nil
	g.slots[1] = { type = "item", id = 6948 }
	Learn(env, 200)
	assert(Holds(g, 3, 200) and #g.placed == 1, "fill left to right before the next physical row: " .. table.concat(g.placed, ","))
end

-- Passives, professions, flyouts, future/off-spec spells and unsafe metadata do not qualify.
for _, excluded in ipairs({ "passive", "profession", "flyout", "future", "offspec", "secret", "missing" }) do
	local env, K, g = NewSpells()
	local info = g.bookSpells[20]
	if excluded == "passive" then info.isPassive = true
	elseif excluded == "profession" then g.professions = { indices = { 1 }, [1] = { count = 2, offset = 19 } }
	elseif excluded == "flyout" then info.itemType = env.Enum.SpellBookItemType.Flyout
	elseif excluded == "future" then info.itemType = env.Enum.SpellBookItemType.FutureSpell
	elseif excluded == "offspec" then info.isOffSpec = true
	elseif excluded == "secret" then info.isPassive = env.Secret(false)
	else env.C_SpellBook.FindSpellBookSlotForSpell = nil end
	Learn(env, 200)
	assert(Shown(env, K) == nil and #g.placed == 0 and #env._errors == 0, excluded .. AB.Errors(env))
end

-- A native auto-push before the batch, before acceptance, or during a cursor wait is not duplicated.
for _, when in ipairs({ "batch", "accept", "cursor" }) do
	local env, K, g = NewSpells()
	if when == "batch" then g.slots[120] = { type = "spell", id = 200 } end
	Learn(env, 200)
	if when == "batch" then
		assert(Shown(env, K) == nil)
	else
		if when == "cursor" then g.cursor = { type = "item", id = 6948 } end
		if when == "accept" then g.slots[120] = { type = "spell", id = 200 } end
		Press(env, K, "Add new to bars")
		g.slots[120], g.cursor = { type = "spell", id = 200 }, nil
		env.RunTimers()
	end
	assert(#g.placed == 0 and not g.slots[1] and #env._errors == 0, when .. AB.Errors(env))
end

-- Never cancels a waiting addition, while disabling rank updates leaves new-spell offers enabled.
do
	local env, K, g = NewSpells()
	Learn(env, 200)
	g.cursor = { type = "item", id = 6948 }
	Press(env, K, "Add new to bars")
	K.Options.Write("ActionBars", "newSpells", "off")
	K.Options.Write("ActionBars", "newSpells", "ask")
	g.cursor = nil
	env.RunTimers()
	assert(#g.placed == 0 and Shown(env, K) == nil)
	Learn(env, 200)
	K.Options.Write("ActionBars", "ranks", "off")
	assert(Has(Shown(env, K), "NEW ABILITY"))
	Press(env, K, "Add new to bars")
	assert(Holds(g, 1, 200) and #env._errors == 0, AB.Errors(env))
end

-- Successive approvals merge during a cursor wait; learning multiple ranks of a new spell adds only the highest.
do
	local env, K, g = NewSpells()
	local after, retries = env.C_Timer.After, {}
	env.C_Timer.After = function(delay, fn)
		if delay >= 1 then retries[#retries + 1] = fn else after(delay, fn) end
	end
	g.cursor = { type = "item", id = 6948 }
	Learn(env, 200)
	Press(env, K, "Add new to bars")
	Learn(env, 201)
	Press(env, K, "Add new to bars")
	g.cursor = nil
	env.C_Timer.After = after
	for _, retry in ipairs(retries) do retry() end
	assert(Holds(g, 1, 200) and Holds(g, 2, 201) and #g.placed == 2)
	env, K, g = NewSpells()
	g.spells[202] = { name = "Other Ability", subtext = "Rank 2" }
	g.bookSpells[22] = { spellID = 202, itemType = env.Enum.SpellBookItemType.Spell, isPassive = false, isOffSpec = false }
	Learn(env, 201, 202)
	Press(env, K, "Add new to bars")
	assert(Holds(g, 1, 202) and #g.placed == 1 and #env._errors == 0, "only the highest rank of a new spell goes onto the bars" .. AB.Errors(env))
end

print("test-actionbars-ranks: ok")
