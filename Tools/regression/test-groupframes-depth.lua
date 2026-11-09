-- test-groupframes-depth.lua: the round-2 healer depth: party debuffs inside the card, one dead state, short deficits, distinct short names, heal absorbs, the debuff priority list and glow, the indicator slots, the automatic layout, the click casting panel, the preview fixture and many auras kept inside the tile.
local G = dofile("Tools/regression/group_env.lua")
local W = dofile("Tools/regression/widget_env.lua")
local Scene = dofile("Tools/render/scene.lua")

-- Speed: CI runs plain Lua 5.1, where booting an environment and re-applying every header both cost real time. The
-- party checks share one environment and the raid checks another, in an order where each block leaves the
-- settings the next one needs, and Batch writes several settings with one SettingChanged (one re-apply).

local function eq(got, want, what)
	assert(got == want, what .. ": want " .. tostring(want) .. ", got " .. tostring(got))
end

local function content(ns, header, unit)
	local i = 1
	while header._attributes["child" .. i] do
		local button = header._attributes["child" .. i]
		if button._attributes.unit == unit and button._shown then
			return ns.Button.Content(button), button
		end
		i = i + 1
	end
end

local function intersects(a, b)
	return a[1] < b[1] + b[3] - 0.01 and b[1] < a[1] + a[3] - 0.01 and a[2] < b[2] + b[4] - 0.01 and b[2] < a[2] + a[4] - 0.01
end

local function inside(r, box, what)
	assert(r[1] and box[1], what .. ": the rect resolves")
	assert(r[1] >= box[1] - 0.01 and r[2] >= box[2] - 0.01 and r[1] + r[3] <= box[1] + box[3] + 0.01 and r[2] + r[4] <= box[2] + box[4] + 0.01,
		what .. string.format(" [%.1f %.1f %.1f %.1f] inside [%.1f %.1f %.1f %.1f]", r[1], r[2], r[3], r[4], box[1], box[2], box[3], box[4]))
end

-- Batch(e, K, settings, loud): writes each { key, value } into the stored settings as Options.Write does, then fires
-- one SettingChanged, so the module re-applies once. The re-apply runs with the stubs quiet (no call log, the
-- documented perf mode) unless loud: every check after a Batch reads state, never the call log, and the checks that
-- rely on the stubs' access guards (auras secret) pass loud.
local function Batch(e, K, settings, loud)
	local root = K.Store.Module("GroupFrames")
	for _, kv in ipairs(settings) do
		local node, parts = root, {}
		for part in kv[1]:gmatch("[^%.]+") do
			parts[#parts + 1] = part
		end
		for i = 1, #parts - 1 do
			node[parts[i]] = type(node[parts[i]]) == "table" and node[parts[i]] or {}
			node = node[parts[i]]
		end
		node[parts[#parts]] = kv[2]
	end
	if not loud then
		e.SetQuiet(true)
	end
	K.Callbacks.Fire("SettingChanged", "GroupFrames", settings[#settings][1], settings[#settings][2])
	e.SetQuiet(false)
end

local PARTY = {
	{ name = "Thaldren", class = "WARRIOR", role = "TANK", health = 92 },
	{ name = "Sylaen", class = "DRUID", role = "HEALER", health = 87 },
	{ name = "Kragar", class = "SHAMAN", role = "DAMAGER", health = 0, dead = true },
	{ name = "Lunara", class = "MAGE", role = "DAMAGER", health = 64 },
}

-- The shared party environment. Click Casting stand-ins go in at setup, as the game provides them.
local click = { profile = {}, saved = nil, opened = 0, cursor = nil }
local env, K, ns = G.New({
	setup = function(e)
		e.C_ClickBindings = {
			GetProfileInfo = function()
				return click.profile
			end,
			SetProfileByInfo = function(list)
				click.saved = list
				click.profile = list
			end,
			CanSpellBeClickBound = function(id)
				return id ~= 6603
			end,
		}
		e.Enum.ClickBindingType = { None = 0, Spell = 1, Macro = 2, Interaction = 3, PetAction = 4 }
		e.Enum.ClickBindingInteraction = { Target = 1, OpenContextMenu = 2 }
		e.C_Spell = {
			GetSpellName = function(id)
				return id == 774 and "Rejuvenation" or "Renew"
			end,
			GetSpellTexture = function()
				return 136081
			end,
		}
		e.GetStringFromModifiers = function(mods)
			return mods == 1 and "SHIFT" or ""
		end
		e.MakeModifiers = function()
			return 1
		end
		e.GetCursorInfo = function()
			if click.cursor then
				return "spell", 1, "spell", click.cursor
			end
		end
		e.ClearCursor = function()
			click.cursor = nil
		end
		e.ToggleClickBindingFrame = function()
			click.opened = click.opened + 1
		end
		e.LEFT_BUTTON_STRING, e.RIGHT_BUTTON_STRING = "Left", "Right"
	end,
})
G.SetRoster(env, "party", PARTY)
assert(K.Modules.Enable("GroupFrames"))
env.RunTimers()
local tank = content(ns, ns.Headers.party, "party1")

-- Astra #1: the preview shows a member carrying debuffs, heals over time, a shield, a heal absorb and an indicator
-- at once, so every healer signal can be read before a pull. Built while the settings are the defaults.
local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
parent:SetSize(280, 700)
local preview = K.Options.Preview("GroupFrames")(parent)
do
	local sample = preview.partyFrames[1]
	local function shown(list)
		local n = 0
		for _, icon in ipairs(list) do
			if icon:IsShown() then
				n = n + 1
			end
		end
		return n
	end
	assert(shown(sample.sampleAuras) >= 2, "two debuffs")
	assert(shown(sample.sampleBuffs) >= 2, "two of your heals")
	assert(W.LastCall(sample.shield, "SetValue")[1] > 0, "a shield line")
	assert(W.LastCall(sample.healAbsorbs, "SetValue")[1] > 0, "a heal absorb")
	assert(shown(sample.sampleSlots) >= 1, "an indicator")
	local many = preview.raidFrames[6]
	eq(many.sample.name, "Orrin", "the raid sample with nine debuffs")
	eq(shown(many.sampleAuras), many.sampleCells, "shows only the cells that fit")
	assert(many.sampleMark:IsShown() and many.sampleMark:GetText() == "+", "and the + mark for the rest")
end

-- Muse #4, Astra #1, Grok: click casting from the settings page. The panel lists the game's Click Casting bindings,
-- removes one, and binds a dropped spell to the button and keys of the next click, all through C_ClickBindings.
do
	click.profile = {
		{ type = 3, actionID = 1, button = "LeftButton", modifiers = 0 },
		{ type = 1, actionID = 774, button = "LeftButton", modifiers = 1 },
	}
	local C = ns.ClickCast
	eq(C.KeyText(click.profile[2]), "SHIFT + Left", "a binding reads as its keys and button")
	eq((C.Describe(click.profile[2])), "Rejuvenation", "and its spell")
	local panel = preview.clickCast
	assert(panel, "the preview carries the click casting panel")
	panel:Refresh()
	assert(panel.rows[1]:IsShown() and not panel.rows[2]:IsShown(), "one spell binding listed; the game's target click is not")
	assert(panel.rows[1].key._state.Text[1]:upper():find("SHIFT", 1, true), "the row shows the keys")
	-- Drop Renew, then right-click the slot with Shift held.
	click.cursor = 139
	panel.drop:GetScript("OnReceiveDrag")(panel.drop)
	eq(click.cursor, nil, "the dropped spell leaves the cursor")
	panel.drop.onClick(panel.drop, "RightButton")
	local added = click.saved and click.saved[#click.saved]
	assert(added and added.type == 1 and added.actionID == 139 and added.button == "RightButton" and added.modifiers == 1, "Renew bound to Shift + Right")
	eq(#click.saved, 3, "beside the others")
	-- Binding the same click again replaces it.
	click.cursor = 774
	panel.drop:GetScript("OnReceiveDrag")(panel.drop)
	panel.drop.onClick(panel.drop, "RightButton")
	eq(#click.saved, 3, "the same keys and button replace the old binding")
	eq(click.saved[3].actionID, 774, "with the new spell")
	-- Remove the first spell binding through its row.
	panel:Refresh()
	panel.rows[1].remove.onClick(panel.rows[1].remove)
	eq(#click.saved, 2, "a row's remove drops that binding")
	-- In combat nothing is saved.
	click.saved = nil
	env.SetCombat(true)
	local ok = C.Add(1, 139, "MiddleButton", 0)
	eq(ok, false, "no binding changes in combat")
	eq(click.saved, nil, "nothing reaches the game")
	env.SetCombat(false)
	panel.open.onClick(panel.open)
	eq(click.opened, 1, "the button opens the game's Click Casting window")
end

-- Muse #3, Fable R2-2: party debuff icons sit outside right by default; the card keeps a lane for them, so the
-- whole three-icon strip stays on the glass instead of hanging past the card's rim.
do
	local k = ns.Settings.current.party
	eq(k.auraPosition, "OUTSIDE_RIGHT", "party debuffs sit outside the tile, right")
	local lane = ns.Geometry.AuraLane(k)
	assert(lane >= k.auraColumns * k.auraSize, "the lane holds the whole strip: " .. lane)
	local tx, _, tw = Scene.Rect(env, tank)
	local cx, _, cw = Scene.Rect(env, ns.Headers.cards.party.frame)
	assert(tx + tw + lane <= cx + cw - ns.Geometry.CARD_PAD + 0.01, "tile plus lane end inside the card's padding")
	eq(select(1, ns.Headers.holders.party:GetSize()), k.width + 2 * ns.Geometry.CARD_PAD, "the card keeps the rail width")
	-- Inside positions need no lane, and a frame too narrow for one keeps its width.
	local inner = {}
	for key, value in pairs(k) do
		inner[key] = value
	end
	inner.auraPosition = "BOTTOMRIGHT"
	eq(ns.Geometry.AuraLane(inner), 0, "inside debuffs need no lane")
	eq(ns.Geometry.AuraLane({ width = 60, height = 40, auraPosition = "OUTSIDE_RIGHT", auraColumns = 3, auraCount = 3, auraSize = 20, auraSpacing = 2 }), 0, "a narrow frame keeps its width")
end

-- Muse #3: one dead state. Party frames show no health text by default, yet a dead member reads "Dead" on the bar,
-- with the name dimmed, exactly as a raid frame does.
do
	local dead = content(ns, ns.Headers.party, "party3")
	eq(ns.Settings.current.party.healthText, "NONE", "party frames show no health text")
	assert(dead.healthText:IsShown(), "the dead member's label shows anyway")
	eq(dead.healthText:GetText(), "Dead", "and says Dead")
	eq(dead.healthText._points[1][1], "CENTER", "centred on the bar")
	local dr, dg, db = K.Tokens.Color("textDisabled")
	local nr, ng, nb = dead.name:GetTextColor()
	assert(W.Near(nr, dr) and W.Near(ng, dg) and W.Near(nb, db), "the name dims")
	assert(not tank.healthText:IsShown(), "a living member shows no health text")
	env._member("party3").dead, env._member("party3").health = false, 50
	env.FireEvent("UNIT_HEALTH", "party3")
	assert(not dead.healthText:IsShown(), "risen, the label goes")
	local er, eg, eb = K.Tokens.Color("textEmphasis")
	nr, ng, nb = dead.name:GetTextColor()
	assert(W.Near(nr, er) and W.Near(ng, eg) and W.Near(nb, eb), "and the name brightens")
end

-- Muse #4, Opus #7: missing health reads -12.4k on a party frame and -12k on a narrow raid tile, through the game's
-- own AbbreviateNumbers with breakpoints; a client that refuses them keeps the game's abbreviation.
do
	local Unit = ns.Unit
	eq(Unit.Abbreviate(12400, "party"), "12.4k", "party: one decimal under 100k")
	eq(Unit.Abbreviate(124000, "party"), "124k", "party: whole thousands from 100k")
	eq(Unit.Abbreviate(1240000, "party"), "1.2m", "party: millions")
	eq(Unit.Abbreviate(12400, "raid"), "12k", "raid: whole thousands from 10k")
	eq(Unit.Abbreviate(1240, "raid"), "1.2k", "raid: one decimal under 10k")
	eq(Unit.Abbreviate(840, "raid"), "840", "under a thousand in full")
	assert(env.issecretvalue(Unit.Abbreviate(env.Secret(12400), "party")), "a secret goes through whole")
	Batch(env, K, { { "party.healthText", "DEFICIT" } })
	env._member("party1").health, env._member("party1").maxHealth = 29400, 41800
	env.FireEvent("UNIT_HEALTH", "party1")
	local call = W.LastCall(tank.healthText, "SetFormattedText")
	eq(call[1], "-%s", "the deficit format")
	eq(env.Reveal(call[2]), "12.4k", "missing 12,400 of 41,800 reads 12.4k")
	env._member("party1").health, env._member("party1").maxHealth = 92, 100
	env.FireEvent("UNIT_MAXHEALTH", "party1")
end
do
	-- The breakpoint check runs once per kind and is remembered, so the refusing client needs its own load; it
	-- needs no boot, since Abbreviate reads only the game's function.
	local bare, _, bareNs = G.New({
		boot = false,
		setup = function(e)
			e.AbbreviateNumbers = function(value, options)
				if options then
					error("unknown option")
				end
				return tostring(value)
			end
		end,
	})
	eq(bareNs.Unit.Abbreviate(12400, "party"), "12400", "a client that refuses breakpoints keeps its own abbreviation")
	eq(#bare._errors, 0, tostring(bare._errors[1]))
end

-- Muse #4, Opus #7: a name that does not fit loses letters, never to an ellipsis, and stays distinct from the
-- other members' names; a secret name goes to the engine untouched. Codex review, round 2: the distinct form is
-- measured whole, so it never reaches the engine's ellipsis.
do
	local Names = ns.Names
	local function chars(n)
		return function(text)
			return #text <= n
		end
	end
	eq(Names.Short("Kesh", chars(6), {}), "Kesh", "a name that fits stays whole")
	eq(Names.Short("Thaldren", chars(6), { "Kesh", "Morwen" }), "Thaldr", "a unique name keeps the letters that fit, no ellipsis")
	local a = Names.Short("Shadowstrike", chars(7), { "Shadowstrider" })
	local b = Names.Short("Shadowstrider", chars(7), { "Shadowstrike" })
	assert(a ~= b, "two names with one long prefix stay apart: " .. a .. " and " .. b)
	assert(#a <= 7 and #b <= 7, "and still fit")
	eq(a, "Shado.e", "the first keeps its ending")
	eq(b, "Shado.r", "and so does the second")
	local function width(n)
		return function(text)
			local w = 0
			for c in text:gmatch(".") do
				w = w + (c == "." and 1 or 2)
			end
			return w <= n
		end
	end
	local short = Names.Short("Shadowstrike", width(16), { "Shadowstrix" })
	assert(width(16)(short), "the distinct form fits: " .. short)
	assert(short ~= Names.Short("Shadowstrix", width(16), { "Shadowstrike" }), "and stays distinct")
	local secret = env.Secret("Hidden")
	Names.Set(tank, secret)
	eq(tank.name._state.Text[1], secret, "a secret name is passed straight to the engine")
	eq(tank.rawName, nil, "and never kept for comparison")
	Names.Set(tank, "Thaldren")
end

-- Astra #1: heal absorbs draw back from the fill's end in their own colour, from the calculator's GetHealAbsorbs,
-- falling back to UnitGetTotalHealAbsorbs and then to nothing, with each value passed straight to the bar.
do
	env._member("party1").healAbsorb = 30
	env.FireEvent("UNIT_HEAL_ABSORB_AMOUNT_CHANGED", "party1")
	eq(env.Reveal(W.LastCall(tank.healAbsorbs, "SetValue")[1]), 30, "the calculator's heal absorbs reach the bar")
	eq(env.Reveal(W.LastCall(tank.healAbsorbs, "SetMinMaxValues")[2]), 100, "spanning the health maximum")
	eq(tank.healAbsorbs:GetReverseFill(), true, "filling back from the end")
	local p = tank.healAbsorbs._points[1]
	assert(p[1] == "TOPRIGHT" and p[2] == tank.health:GetStatusBarTexture() and p[3] == "TOPRIGHT", "hung from the fill's end")
	eq(tank.calc.modes.healAbsorb, env.Enum.UnitHealAbsorbClampMode.CurrentHealth, "clamped to the current health")
	local hr, hg, hb = K.Tokens.Color("hostile")
	local c = W.LastCall(tank.healAbsorbs, "SetStatusBarColor")
	assert(W.Near(c[1], hr) and W.Near(c[2], hg) and W.Near(c[3], hb), "in the hostile colour, apart from heals and shields")
	-- Without the calculator (each update asks for it), then without UnitGetTotalHealAbsorbs too.
	local calculator, total = env.CreateUnitHealPredictionCalculator, env.UnitGetTotalHealAbsorbs
	env.CreateUnitHealPredictionCalculator = nil
	env._member("party1").healAbsorb = 12
	env.FireEvent("UNIT_HEAL_ABSORB_AMOUNT_CHANGED", "party1")
	eq(env.Reveal(W.LastCall(tank.healAbsorbs, "SetValue")[1]), 12, "without the calculator, UnitGetTotalHealAbsorbs feeds the bar")
	env.UnitGetTotalHealAbsorbs = nil
	env.FireEvent("UNIT_HEAL_ABSORB_AMOUNT_CHANGED", "party1")
	eq(W.LastCall(tank.healAbsorbs, "SetValue")[1], 0, "with neither, the bar stays empty")
	env.CreateUnitHealPredictionCalculator, env.UnitGetTotalHealAbsorbs = calculator, total
	Batch(env, K, { { "prediction.healAbsorbs", false } })
	assert(not tank.healAbsorbs:IsShown(), "the heal absorbs can be turned off")
end

-- Muse #4: the debuff priority list. Four groups split the debuffs with the engine's own flags, so no debuff shows
-- twice, and the player's order sets their place in the row. A boss or important debuff also glows.
do
	local groups = tank.auras._groups
	local boss, important, dispels, debuffs = groups.boss, groups.important, groups.dispels, groups.debuffs
	assert(boss and important and dispels and debuffs, "four debuff groups")
	eq(boss.candidateFilters.isBossAura, true, "boss debuffs")
	eq(important.candidateFilters.isBossAura, false, "important debuffs exclude boss ones")
	eq(important.candidateFilters.isPriorityAura, true, "and take the game's priority debuffs")
	for _, group in ipairs({ dispels, debuffs }) do
		eq(group.candidateFilters.isBossAura, false, group.key .. " leave boss debuffs to their group")
		eq(group.candidateFilters.isPriorityAura, false, group.key .. " leave priority debuffs to theirs")
	end
	local function order()
		return boss.layout.layoutIndex, dispels.layout.layoutIndex, important.layout.layoutIndex, debuffs.layout.layoutIndex
	end
	local b, d, i, o = order()
	assert(d == 1 and b == 2 and i == 3 and o == 4, "the default order (owner, round 2): dispellable, boss, important, other")
	local slots = tank.highlights._slots
	eq(slots.glowBoss.filter, "HARMFUL", "the boss glow watches debuffs")
	eq(slots.glowBoss.candidateFilters.isBossAura, true, "boss ones")
	eq(slots.glowImportant.candidateFilters.isPriorityAura, true, "and the game's priority ones")
	assert(slots.glowBoss.frame:IsShown() == false, "the engine shows the glow only while such a debuff is up")
	eq(slots.glowBoss.enabled, true, "the glow is on by default")
	Batch(env, K, { { "auras.priority1", "BOSS" }, { "auras.priority2", "BOSS" }, { "auras.glow", false } })
	b, d, i, o = order()
	assert(b == 1 and d == 2 and i == 3 and o == 4, "boss first; a repeat's place goes to the category the list left out: " .. table.concat({ b, d, i, o }, ","))
	eq(slots.glowBoss.enabled, false, "and the glow can be turned off")
	Batch(env, K, { { "auras.priority1", "DISPEL" }, { "auras.priority2", "BOSS" }, { "auras.glow", true } })
end

-- Muse #4, Astra #1, Opus #7: six indicator slots on the engine's aura slots. Each takes a category the game's own
-- filters define, or buff spell IDs the engine matches itself; Lua never reads an aura.
do
	local container = tank.indicators
	assert(container, "the frame has an indicator container")
	local slots = container._slots
	for i = 1, 6 do
		assert(slots["indicator" .. i], "slot " .. i)
	end
	eq(slots.indicator1.filter, "HELPFUL|EXTERNAL_DEFENSIVE", "slot 1: external defensives")
	eq(slots.indicator1.enabled, true, "on")
	eq(slots.indicator2.filter, "HARMFUL|CROWD_CONTROL", "slot 2: crowd control")
	eq(slots.indicator3.filter, "HELPFUL|BIG_DEFENSIVE", "slot 3: big defensives")
	eq(slots.indicator4.enabled, false, "slot 4 is off")
	Batch(env, K, { { "indicator4.category", "SPELLS" } })
	eq(slots.indicator4.enabled, false, "chosen spells with no IDs stay off")
	Batch(env, K, { { "indicator4.spells", "774, 139 x" }, { "indicator4.mine", true }, { "indicator5.category", "BOSS" }, { "indicator1.position", "TOPRIGHT" } })
	eq(slots.indicator4.enabled, true, "with IDs the slot turns on")
	eq(slots.indicator4.filter, "HELPFUL|PLAYER", "your own buffs")
	local ids = slots.indicator4.candidateFilters.includeSpellIDs
	assert(ids[774] and ids[139], "matched by the engine's includeSpellIDs")
	eq(slots.indicator5.candidateFilters.isBossAura, true, "boss debuffs by the engine's flag")
	-- Placement: the chosen point on the frame, the lower number above a later slot.
	local one, two = slots.indicator1.frame, slots.indicator2.frame
	local p = one._points[1]
	assert(p[1] == "TOPRIGHT" and p[2] == tank and p[3] == "TOPRIGHT", "slot 1 at the frame's top right")
	assert(one:GetFrameLevel() > two:GetFrameLevel(), "slot 1 draws above slot 2")
	-- While auras are secret the engine denies its buttons, so placement waits and nothing errors.
	env._aurasSecret = true
	Batch(env, K, { { "indicator1.position", "BOTTOMLEFT" } }, true)
	eq(one._points[1][1], "TOPRIGHT", "placement waits while auras are secret")
	env._aurasSecret = false
	env.RunTimers()
	eq(one._points[1][1], "BOTTOMLEFT", "and lands once they are readable")
	local plan = ns.Slots.Plan({ category = "HOTS", mine = true, spells = "" })
	eq(plan.filter, "HELPFUL|PLAYER|RAID_IN_COMBAT", "your heals over time are already yours")
	eq(ns.Slots.Plan({ category = "OFF" }), nil, "an off slot has no plan")
end

-- Muse #4, Opus #7: the layout switches by raid size and role. A raid over 25 gets compact tiles without power
-- bars; a healer gets two dispellable debuffs first and three of their heals.
do
	local A = ns.AutoLayout
	eq(A.Bracket(20), "MEDIUM", "twenty is a medium raid")
	eq(A.Bracket(30), "LARGE", "thirty is large")
	local cfg = { auto = { size = true, role = true }, party = { height = 40, auraDispelCount = 1, buffCount = 2 }, raid = { height = 40, power = true, auraDispelCount = 1, buffCount = 3 } }
	A.Overlay(cfg, { bracket = "LARGE", healer = true })
	eq(cfg.raid.height, 34, "large raids: 85% height")
	eq(cfg.raid.power, false, "and no power bars")
	eq(cfg.party.auraDispelCount, 2, "a healer sees two dispellable debuffs first")
	eq(cfg.party.buffCount, 3, "and three of their heals")
end

-- Speed fix: an icon's chrome is rebuilt only when its size or pixel border changes, yet a restyle the game's
-- secrecy deferred (Widgets.RestyleAll while auras are secret) still lands once auras are readable.
do
	local button = tank.auras._groups.debuffs.frames[1]
	local parts = ns.Auras.Parts(button)
	local restyle, runs = parts.restyleChrome, 0
	parts.restyleChrome = function(chrome)
		runs = runs + 1
		return restyle(chrome)
	end
	ns.Auras.StyleIcon(button)
	eq(runs, 0, "an unchanged icon keeps its chrome")
	env._aurasSecret = true
	K.Widgets.RestyleAll()
	env._aurasSecret = false
	env.RunTimers()
	eq(runs, 1, "a restyle deferred while auras were secret runs once they are readable")
	parts.restyleChrome = restyle
end

-- Codex review, round 2: a count that does not fill the rectangle rounds down to whole rows, so the clip never
-- shows more debuffs than the count.
do
	local b = ns.Geometry.AuraBlock({ auraCount = 5, auraColumns = 3, auraRows = 2, auraPosition = "BOTTOMLEFT", auraWrap = "UP" }, 77, 40, 8, 1, 2, 0)
	eq(b.columns * b.rows, b.cells, "the clip is exactly the cells")
	assert(b.cells <= 5, "never more than the count: " .. b.cells)
end

-- Owner, round 2: many auras. A member with eight debuffs and five of your heals shows the highest-priority
-- debuffs (dispellable, then boss and raid, then the rest) up to the cells that fit, a "+" mark for the rest, and
-- nothing outside the tile, or outside the card for the party's outside lane. Indicators stay inside the tile at
-- any size. The fake engine does not lay out, so Flow places the shown buttons as the engine's flow layout would;
-- the clip frames bound what draws, so each shown icon must lie wholly inside its clip and each hidden one wholly
-- outside, as the renderer's clip (scene.lua) draws them.
local function Flow(e, container, keys, shown, step, columns)
	local point = container._flow.anchor
	local gx = container._flow.horizontal == e.AnchorUtil.FlowDirection.Left and -1 or 1
	local gy = container._flow.vertical == e.AnchorUtil.FlowDirection.Down and -1 or 1
	local placed, index = {}, 0
	for _, key in ipairs(keys) do
		local group = container._groups[key]
		for i = 1, math.min(shown[key] or 0, group.maxFrameCount) do
			local button = group.frames[i]
			local col, row = index % columns, math.floor(index / columns)
			button:ClearAllPoints()
			button:SetPoint(point, container, point, gx * col * step, gy * row * step)
			button._aura.icon:SetTexture(136207)
			button:Show()
			placed[#placed + 1] = button
			index = index + 1
		end
	end
	-- The engine sizes the container to its content when the layout completes (OnLayoutComplete).
	container:SetSize(math.max(1, math.min(index, columns)) * step, math.max(1, math.ceil(index / columns)) * step)
	return placed
end

local function ManyAuras(e, k8, nsx, f, box, what)
	local Auras = nsx.Auras
	local k = nsx.Settings.current[f.kind]
	local block = Auras.Block(f, k)
	local order = {}
	for key, index in pairs(Auras.Order()) do
		order[index] = key
	end
	local step = block.size + block.spacing
	local placed = Flow(e, f.auras, order, { dispels = 3, boss = 2, important = 2, debuffs = 8 }, step, math.max(1, block.columns))
	assert(#placed > block.cells, what .. ": more debuffs than cells reach the engine")
	local clipRect = { Scene.Rect(e, f.auraClip) }
	inside(clipRect, box, what .. ": the debuff block")
	for i, button in ipairs(placed) do
		local parts = Auras.Parts(button)
		local icon = { Scene.Rect(e, parts.icon) }
		local back = { Scene.Rect(e, parts.markBack) }
		eq(parts.mark:GetText(), "+", what .. ": each icon carries the + mark")
		if i <= block.cells then
			inside(icon, clipRect, what .. ": shown debuff " .. i)
			assert(not intersects(back, clipRect), what .. ": a shown debuff raises no mark (" .. i .. ")")
		else
			assert(not intersects(icon, clipRect), what .. ": debuff " .. i .. " past the cells is clipped")
		end
		if i == block.cells + 1 then
			inside(back, clipRect, what .. ": the first hidden debuff raises the + mark on the last cell")
		end
	end
	eq(placed[1]:GetParent(), f.auras, what .. ": the first cell holds the top category")
	eq(placed[1], f.auras._groups[order[1]].frames[1], what .. ": " .. order[1] .. " first")
	-- Your heals: more than fit, clipped along the bar with the same mark.
	local side, count, size, spacing = Auras.HealIcons(f, k)
	local healPlaced = Flow(e, f.buffs, { "buffs" }, { buffs = 6 }, size + spacing, math.max(1, count))
	local healClip = { Scene.Rect(e, f.buffClip) }
	local tile = { Scene.Rect(e, f) }
	inside(healClip, tile, what .. ": your heals")
	for i, button in ipairs(healPlaced) do
		local icon = { Scene.Rect(e, Auras.Parts(button).icon) }
		if i <= count then
			inside(icon, healClip, what .. ": heal " .. i)
		else
			assert(not intersects(icon, healClip), what .. ": heal " .. i .. " past the bar is clipped")
		end
	end
	inside({ Scene.Rect(e, Auras.Parts(healPlaced[count + 1]).markBack) }, healClip, what .. ": the hidden heal raises the + mark (" .. side .. ")")
	-- Indicators: every slot on, the largest size, all inside the tile.
	local settings = {}
	for i = 1, 6 do
		settings[#settings + 1] = { "indicator" .. i .. ".category", "EXTERNAL" }
		settings[#settings + 1] = { "indicator" .. i .. ".size", 32 }
	end
	settings[#settings + 1] = { "indicator6.position", "BOTTOMRIGHT" }
	Batch(e, k8, settings)
	for i = 1, 6 do
		local button = f.indicators._slots["indicator" .. i].frame
		button:Show()
		inside({ Scene.Rect(e, button) }, tile, what .. ": indicator " .. i)
	end
end

do
	local cx, cy, cw, ch = Scene.Rect(env, ns.Headers.cards.party.frame)
	local pad = ns.Geometry.CARD_PAD
	ManyAuras(env, K, ns, tank, { cx + pad, cy, cw - 2 * pad, ch }, "party")
end

-- Codex review, round 2: two indicators that share a place sit side by side, both readable.
do
	local settings = {
		{ "indicator1.category", "EXTERNAL" }, { "indicator1.position", "CENTER" }, { "indicator1.size", 6 },
		{ "indicator2.category", "EXTERNAL" }, { "indicator2.position", "CENTER" }, { "indicator2.size", 32 },
	}
	for i = 3, 6 do
		settings[#settings + 1] = { "indicator" .. i .. ".category", "OFF" }
	end
	Batch(env, K, settings)
	local a, b = tank.indicators._slots.indicator1.frame, tank.indicators._slots.indicator2.frame
	a:Show()
	b:Show()
	local ra, rb = { Scene.Rect(env, a) }, { Scene.Rect(env, b) }
	assert(not intersects(ra, rb), "two indicators at the centre sit side by side, not one around the other")
end
eq(#env._errors, 0, tostring(env._errors[1]))

-- The raid environment: the size switch out of combat, then many auras on a raid tile and the owner's extreme
-- debuff settings.
do
	local renv, RK, rns = G.New()
	G.SetRoster(renv, "raid", G.Members(20))
	assert(RK.Modules.Enable("GroupFrames"))
	renv.RunTimers()
	eq(rns.Headers.raid[1]._attributes["kstyle-height"], 40, "twenty members keep the set height")
	renv.SetCombat(true)
	G.SetRoster(renv, "raid", G.Members(30))
	renv.RunTimers()
	eq(#renv._blocked, 0, "a roster change in combat touches nothing protected: " .. tostring(renv._blocked[1]))
	eq(rns.Headers.raid[1]._attributes["kstyle-height"], 40, "and the size waits for combat to end")
	renv.SetCombat(false)
	renv.RunTimers()
	eq(rns.Headers.raid[1]._attributes["kstyle-height"], 34, "thirty members get compact frames after combat")
	Batch(renv, RK, { { "auto.size", false } })
	eq(rns.Headers.raid[1]._attributes["kstyle-height"], 40, "the switch can be turned off")
	local f = content(rns, rns.Headers.raid[1], "raid1")
	ManyAuras(renv, RK, rns, f, { Scene.Rect(renv, f) }, "raid")
	-- The owner's extreme settings: ten debuffs in four rows of large icons still fit the tile.
	Batch(renv, RK, { { "raid.auraCount", 10 }, { "raid.auraColumns", 10 }, { "raid.auraRows", 4 }, { "raid.auraSize", 40 } })
	local block = rns.Auras.Block(f, rns.Settings.current.raid)
	assert(block.cells >= 1, "at least one cell fits")
	inside({ Scene.Rect(renv, f.auraClip) }, { Scene.Rect(renv, f) }, "raid, large icons: the debuff block")
	eq(#renv._errors, 0, tostring(renv._errors[1]))
end

print("groupframes depth ok")
