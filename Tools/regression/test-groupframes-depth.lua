-- test-groupframes-depth.lua: the round-2 healer depth: party debuffs inside the card, one dead state, short deficits, distinct short names, heal absorbs, the debuff priority list and glow, the indicator slots, the automatic layout, the click casting panel, the preview fixture and many auras kept inside the tile.
local G = dofile("Tools/regression/group_env.lua")
local W = dofile("Tools/regression/widget_env.lua")
local Scene = dofile("Tools/render/scene.lua")

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

local PARTY = {
	{ name = "Thaldren", class = "WARRIOR", role = "TANK", health = 92 },
	{ name = "Sylaen", class = "DRUID", role = "HEALER", health = 87 },
	{ name = "Kragar", class = "SHAMAN", role = "DAMAGER", health = 0, dead = true },
	{ name = "Lunara", class = "MAGE", role = "DAMAGER", health = 64 },
}

local function party(opts)
	opts = opts or {}
	local env, K, ns = G.New({ saved = opts.saved, setup = opts.setup })
	local members = {}
	for i, m in ipairs(PARTY) do
		members[i] = {}
		for k, v in pairs(m) do
			members[i][k] = v
		end
	end
	G.SetRoster(env, "party", members, opts.player)
	assert(K.Modules.Enable("GroupFrames"))
	env.RunTimers()
	return env, K, ns
end

-- Muse #3, Fable R2-2: party debuff icons sit outside right by default; the card keeps a lane for them, so the
-- whole three-icon strip stays on the glass instead of hanging past the card's rim.
do
	local env, K, ns = party()
	local k = ns.Settings.current.party
	eq(k.auraPosition, "OUTSIDE_RIGHT", "party debuffs sit outside the tile, right")
	local lane = ns.Geometry.AuraLane(k)
	assert(lane >= k.auraColumns * k.auraSize, "the lane holds the whole strip: " .. lane)
	local tank = content(ns, ns.Headers.party, "party1")
	local tx, _, tw = Scene.Rect(env, tank)
	local card = ns.Headers.cards.party.frame
	local cx, _, cw = Scene.Rect(env, card)
	assert(tx + tw + lane <= cx + cw - ns.Geometry.CARD_PAD + 0.01, "tile plus lane end inside the card's padding")
	eq(select(1, ns.Headers.holders.party:GetSize()), k.width + 2 * ns.Geometry.CARD_PAD, "the card keeps the rail width")
	-- Inside positions need no lane, and a frame too narrow for one keeps its width.
	K.Options.Write("GroupFrames", "party.auraPosition", "BOTTOMRIGHT")
	env.RunTimers()
	eq(ns.Geometry.AuraLane(ns.Settings.current.party), 0, "inside debuffs need no lane")
	eq(ns.Geometry.AuraLane({ width = 60, height = 40, auraPosition = "OUTSIDE_RIGHT", auraColumns = 3, auraCount = 3, auraSize = 20, auraSpacing = 2 }), 0, "a narrow frame keeps its width")
	eq(#env._errors, 0, tostring(env._errors[1]))
end

-- Muse #3: one dead state. Party frames show no health text by default, yet a dead member reads "Dead" on the bar,
-- with the name dimmed, exactly as a raid frame does.
do
	local env, K, ns = party()
	local dead = content(ns, ns.Headers.party, "party3")
	eq(ns.Settings.current.party.healthText, "NONE", "party frames show no health text")
	assert(dead.healthText:IsShown(), "the dead member's label shows anyway")
	eq(dead.healthText:GetText(), "Dead", "and says Dead")
	eq(dead.healthText._points[1][1], "CENTER", "centred on the bar")
	local dr, dg, db = K.Tokens.Color("textDisabled")
	local nr, ng, nb = dead.name:GetTextColor()
	assert(W.Near(nr, dr) and W.Near(ng, dg) and W.Near(nb, db), "the name dims")
	local alive = content(ns, ns.Headers.party, "party1")
	assert(not alive.healthText:IsShown(), "a living member shows no health text")
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
	local env, K, ns = party()
	local Unit = ns.Unit
	eq(Unit.Abbreviate(12400, "party"), "12.4k", "party: one decimal under 100k")
	eq(Unit.Abbreviate(124000, "party"), "124k", "party: whole thousands from 100k")
	eq(Unit.Abbreviate(1240000, "party"), "1.2m", "party: millions")
	eq(Unit.Abbreviate(12400, "raid"), "12k", "raid: whole thousands from 10k")
	eq(Unit.Abbreviate(1240, "raid"), "1.2k", "raid: one decimal under 10k")
	eq(Unit.Abbreviate(840, "raid"), "840", "under a thousand in full")
	assert(env.issecretvalue(Unit.Abbreviate(env.Secret(12400), "party")), "a secret goes through whole")
	K.Options.Write("GroupFrames", "party.healthText", "DEFICIT")
	env._member("party1").health, env._member("party1").maxHealth = 29400, 41800
	env.FireEvent("UNIT_HEALTH", "party1")
	local tank = content(ns, ns.Headers.party, "party1")
	local call = W.LastCall(tank.healthText, "SetFormattedText")
	eq(call[1], "-%s", "the deficit format")
	eq(env.Reveal(call[2]), "12.4k", "missing 12,400 of 41,800 reads 12.4k")
end
do
	local env, _, ns = G.New({
		setup = function(e)
			e.AbbreviateNumbers = function(value, options)
				if options then
					error("unknown option")
				end
				return tostring(value)
			end
		end,
	})
	eq(ns.Unit.Abbreviate(12400, "party"), "12400", "a client that refuses breakpoints keeps its own abbreviation")
	eq(#env._errors, 0, tostring(env._errors[1]))
end

-- Muse #4, Opus #7: a name that does not fit loses letters, never to an ellipsis, and stays distinct from the
-- other members' names; a secret name goes to the engine untouched.
do
	local env, _, ns = party()
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
	local f = content(ns, ns.Headers.party, "party1")
	local secret = env.Secret("Hidden")
	Names.Set(f, secret)
	eq(f.name._state.Text[1], secret, "a secret name is passed straight to the engine")
	eq(f.rawName, nil, "and never kept for comparison")
end

-- Astra #1: heal absorbs draw back from the fill's end in their own colour, from the calculator's GetHealAbsorbs,
-- falling back to UnitGetTotalHealAbsorbs and then to nothing, with each value passed straight to the bar.
do
	local env, K, ns = party()
	local tank = content(ns, ns.Headers.party, "party1")
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
	K.Options.Write("GroupFrames", "prediction.healAbsorbs", false)
	env.RunTimers()
	assert(not tank.healAbsorbs:IsShown(), "the heal absorbs can be turned off")
end
do
	local env, _, ns = party({
		setup = function(e)
			e.CreateUnitHealPredictionCalculator = nil
		end,
	})
	local tank = content(ns, ns.Headers.party, "party1")
	env._member("party1").healAbsorb = 12
	env.FireEvent("UNIT_HEAL_ABSORB_AMOUNT_CHANGED", "party1")
	eq(env.Reveal(W.LastCall(tank.healAbsorbs, "SetValue")[1]), 12, "without the calculator, UnitGetTotalHealAbsorbs feeds the bar")
	env.UnitGetTotalHealAbsorbs = nil
	env.FireEvent("UNIT_HEAL_ABSORB_AMOUNT_CHANGED", "party1")
	eq(W.LastCall(tank.healAbsorbs, "SetValue")[1], 0, "with neither, the bar stays empty")
	eq(#env._errors, 0, tostring(env._errors[1]))
end

-- Muse #4: the debuff priority list. Four groups split the debuffs with the engine's own flags, so no debuff shows
-- twice, and the player's order sets their place in the row. A boss or important debuff also glows.
do
	local env, K, ns = party()
	local tank = content(ns, ns.Headers.party, "party1")
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
	K.Options.Write("GroupFrames", "auras.priority1", "BOSS")
	K.Options.Write("GroupFrames", "auras.priority2", "BOSS")
	env.RunTimers()
	b, d, i, o = order()
	assert(b == 1 and d == 2 and i == 3 and o == 4, "boss first; a repeat's place goes to the category the list left out: " .. table.concat({ b, d, i, o }, ","))
	local slots = tank.highlights._slots
	eq(slots.glowBoss.filter, "HARMFUL", "the boss glow watches debuffs")
	eq(slots.glowBoss.candidateFilters.isBossAura, true, "boss ones")
	eq(slots.glowImportant.candidateFilters.isPriorityAura, true, "and the game's priority ones")
	assert(slots.glowBoss.frame:IsShown() == false, "the engine shows the glow only while such a debuff is up")
	eq(slots.glowBoss.enabled, true, "the glow is on by default")
	K.Options.Write("GroupFrames", "auras.glow", false)
	env.RunTimers()
	eq(slots.glowBoss.enabled, false, "and can be turned off")
	eq(#env._errors, 0, tostring(env._errors[1]))
end

-- Muse #4, Astra #1, Opus #7: six indicator slots on the engine's aura slots. Each takes a category the game's own
-- filters define, or buff spell IDs the engine matches itself; Lua never reads an aura.
do
	local env, K, ns = party()
	local tank = content(ns, ns.Headers.party, "party1")
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
	K.Options.Write("GroupFrames", "indicator4.category", "SPELLS")
	env.RunTimers()
	eq(slots.indicator4.enabled, false, "chosen spells with no IDs stay off")
	K.Options.Write("GroupFrames", "indicator4.spells", "774, 139 x")
	K.Options.Write("GroupFrames", "indicator4.mine", true)
	env.RunTimers()
	eq(slots.indicator4.enabled, true, "with IDs the slot turns on")
	eq(slots.indicator4.filter, "HELPFUL|PLAYER", "your own buffs")
	local ids = slots.indicator4.candidateFilters.includeSpellIDs
	assert(ids[774] and ids[139], "matched by the engine's includeSpellIDs")
	K.Options.Write("GroupFrames", "indicator5.category", "BOSS")
	env.RunTimers()
	eq(slots.indicator5.candidateFilters.isBossAura, true, "boss debuffs by the engine's flag")
	-- Placement: the chosen point on the frame, the lower number above a later slot that shares it.
	K.Options.Write("GroupFrames", "indicator1.position", "TOPRIGHT")
	env.RunTimers()
	local one, two = slots.indicator1.frame, slots.indicator2.frame
	local p = one._points[1]
	assert(p[1] == "TOPRIGHT" and p[2] == tank and p[3] == "TOPRIGHT", "slot 1 at the frame's top right")
	assert(one:GetFrameLevel() > two:GetFrameLevel(), "slot 1 draws above slot 2")
	-- While auras are secret the engine denies its buttons, so placement waits and nothing errors.
	env._aurasSecret = true
	K.Options.Write("GroupFrames", "indicator1.position", "BOTTOMLEFT")
	eq(one._points[1][1], "TOPRIGHT", "placement waits while auras are secret")
	env._aurasSecret = false
	env.RunTimers()
	eq(one._points[1][1], "BOTTOMLEFT", "and lands once they are readable")
	eq(#env._errors, 0, tostring(env._errors[1]))
end
do
	local _, _, ns = party()
	local plan = ns.Slots.Plan({ category = "HOTS", mine = true, spells = "" })
	eq(plan.filter, "HELPFUL|PLAYER|RAID_IN_COMBAT", "your heals over time are already yours")
	eq(ns.Slots.Plan({ category = "OFF" }), nil, "an off slot has no plan")
end

-- Muse #4, Opus #7: the layout switches by raid size and role, out of combat. A raid over 25 gets compact tiles
-- without power bars; a healer gets two dispellable debuffs first and three of their heals.
do
	local _, _, ns = party()
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
do
	local env, K, ns = G.New()
	G.SetRoster(env, "raid", G.Members(20))
	assert(K.Modules.Enable("GroupFrames"))
	env.RunTimers()
	eq(ns.Headers.raid[1]._attributes["kstyle-height"], 40, "twenty members keep the set height")
	env.SetCombat(true)
	G.SetRoster(env, "raid", G.Members(30))
	env.RunTimers()
	eq(#env._blocked, 0, "a roster change in combat touches nothing protected: " .. tostring(env._blocked[1]))
	eq(ns.Headers.raid[1]._attributes["kstyle-height"], 40, "and the size waits for combat to end")
	env.SetCombat(false)
	env.RunTimers()
	eq(ns.Headers.raid[1]._attributes["kstyle-height"], 34, "thirty members get compact frames after combat")
	K.Options.Write("GroupFrames", "auto.size", false)
	env.RunTimers()
	eq(ns.Headers.raid[1]._attributes["kstyle-height"], 40, "the switch can be turned off")
	eq(#env._errors, 0, tostring(env._errors[1]))
end

-- Muse #4, Astra #1, Grok: click casting from the settings page. The panel lists the game's Click Casting bindings,
-- removes one, and binds a dropped spell to the button and keys of the next click, all through C_ClickBindings.
do
	local profile, saved, opened = {}, nil, 0
	local cursor
	local env, K, ns = G.New({
		setup = function(e)
			e.C_ClickBindings = {
				GetProfileInfo = function()
					return profile
				end,
				SetProfileByInfo = function(list)
					saved = list
					profile = list
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
				if cursor then
					return "spell", 1, "spell", cursor
				end
			end
			e.ClearCursor = function()
				cursor = nil
			end
			e.ToggleClickBindingFrame = function()
				opened = opened + 1
			end
			e.LEFT_BUTTON_STRING, e.RIGHT_BUTTON_STRING = "Left", "Right"
		end,
	})
	profile = {
		{ type = 3, actionID = 1, button = "LeftButton", modifiers = 0 },
		{ type = 1, actionID = 774, button = "LeftButton", modifiers = 1 },
	}
	local C = ns.ClickCast
	eq(C.KeyText(profile[2]), "SHIFT + Left", "a binding reads as its keys and button")
	eq((C.Describe(profile[2])), "Rejuvenation", "and its spell")
	local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
	parent:SetSize(280, 600)
	local preview = K.Options.Preview("GroupFrames")(parent)
	local panel = preview.clickCast
	assert(panel, "the preview carries the click casting panel")
	panel:Refresh()
	assert(panel.rows[1]:IsShown() and not panel.rows[2]:IsShown(), "one spell binding listed; the game's target click is not")
	assert(panel.rows[1].key._state.Text[1]:upper():find("SHIFT", 1, true), "the row shows the keys")
	-- Drop Renew, then right-click the slot with Shift held.
	cursor = 139
	panel.drop:GetScript("OnReceiveDrag")(panel.drop)
	eq(cursor, nil, "the dropped spell leaves the cursor")
	panel.drop.onClick(panel.drop, "RightButton")
	local added = saved and saved[#saved]
	assert(added and added.type == 1 and added.actionID == 139 and added.button == "RightButton" and added.modifiers == 1, "Renew bound to Shift + Right")
	eq(#saved, 3, "beside the others")
	-- Binding the same click again replaces it.
	cursor = 774
	panel.drop:GetScript("OnReceiveDrag")(panel.drop)
	panel.drop.onClick(panel.drop, "RightButton")
	eq(#saved, 3, "the same keys and button replace the old binding")
	eq(saved[3].actionID, 774, "with the new spell")
	-- Remove the first spell binding through its row.
	panel:Refresh()
	panel.rows[1].remove.onClick(panel.rows[1].remove)
	eq(#saved, 2, "a row's remove drops that binding")
	-- In combat nothing is saved.
	saved = nil
	env.SetCombat(true)
	local ok = C.Add(1, 139, "MiddleButton", 0)
	eq(ok, false, "no binding changes in combat")
	eq(saved, nil, "nothing reaches the game")
	env.SetCombat(false)
	panel.open.onClick(panel.open)
	eq(opened, 1, "the button opens the game's Click Casting window")
	eq(#env._errors, 0, tostring(env._errors[1]))
end

-- Astra #1: the preview shows a member carrying debuffs, heals over time, a shield, a heal absorb and an indicator
-- at once, so every healer signal can be read before a pull.
do
	local env, K = G.New()
	local parent = env.CreateFrame("Frame", nil, K.Scale.Root())
	parent:SetSize(280, 700)
	local preview = K.Options.Preview("GroupFrames")(parent)
	local tank = preview.partyFrames[1]
	local function shown(list)
		local n = 0
		for _, icon in ipairs(list) do
			if icon:IsShown() then
				n = n + 1
			end
		end
		return n
	end
	assert(shown(tank.sampleAuras) >= 2, "two debuffs")
	assert(shown(tank.sampleBuffs) >= 2, "two of your heals")
	assert(W.LastCall(tank.shield, "SetValue")[1] > 0, "a shield line")
	assert(W.LastCall(tank.healAbsorbs, "SetValue")[1] > 0, "a heal absorb")
	assert(shown(tank.sampleSlots) >= 1, "an indicator")
	local many = preview.raidFrames[6]
	eq(many.sample.name, "Orrin", "the raid sample with nine debuffs")
	eq(shown(many.sampleAuras), many.sampleCells, "shows only the cells that fit")
	assert(many.sampleMark:IsShown() and many.sampleMark:GetText() == "+", "and the + mark for the rest")
	eq(#env._errors, 0, tostring(env._errors[1]))
end

-- Owner, round 2: many auras. A member with eight debuffs and five of your heals shows the highest-priority
-- debuffs (dispellable, then boss and raid, then the rest) up to the cells that fit, a "+" mark for the rest, and
-- nothing outside the tile, or outside the card for the party's outside lane. Indicators stay inside the tile at
-- any size. The fake engine does not lay out, so Flow places the shown buttons as the engine's flow layout would.
local function Flow(env, ns, f, container, keys, shown, step, columns)
	local point = container._flow.anchor
	local gx = container._flow.horizontal == env.AnchorUtil.FlowDirection.Left and -1 or 1
	local gy = container._flow.vertical == env.AnchorUtil.FlowDirection.Down and -1 or 1
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

local function inside(r, box, what)
	assert(r[1] >= box[1] - 0.01 and r[2] >= box[2] - 0.01 and r[1] + r[3] <= box[1] + box[3] + 0.01 and r[2] + r[4] <= box[2] + box[4] + 0.01,
		what .. string.format(" [%.1f %.1f %.1f %.1f] inside [%.1f %.1f %.1f %.1f]", r[1], r[2], r[3], r[4], box[1], box[2], box[3], box[4]))
end

local function drawn(scene, object)
	for _, item in ipairs(scene.items) do
		if item.object == object then
			return item
		end
	end
end

local function manyAuras(env, ns, f, box, what)
	local Auras = ns.Auras
	local k = ns.Settings.current[f.kind]
	local block = Auras.Block(f, k)
	local order = {}
	for key, index in pairs(Auras.Order()) do
		order[index] = key
	end
	local step = block.size + block.spacing
	local placed = Flow(env, ns, f, f.auras, order, { dispels = 3, boss = 2, important = 2, debuffs = 8 }, step, math.max(1, block.columns))
	assert(#placed > block.cells, what .. ": more debuffs than cells reach the engine")
	local scene = Scene.Build(env)
	local clipRect = { Scene.Rect(env, f.auraClip) }
	inside(clipRect, box, what .. ": the debuff block")
	local visible = 0
	for i, button in ipairs(placed) do
		local item = drawn(scene, Auras.Parts(button).icon)
		if item then
			visible = visible + 1
			inside(item.clip or item.rect, box, what .. ": debuff " .. i)
		end
		local mark = drawn(scene, Auras.Parts(button).mark)
		if i == block.cells + 1 then
			assert(mark, what .. ": the first hidden debuff raises the + mark")
			inside(mark.clip or mark.rect, clipRect, what .. ": the + mark")
		elseif i <= block.cells then
			assert(not mark, what .. ": a shown debuff raises no mark (" .. i .. ")")
		end
	end
	eq(visible, block.cells, what .. ": exactly the cells show")
	local first = placed[1]
	eq(first:GetParent(), f.auras, what .. ": the first cell holds the top category")
	eq(first, f.auras._groups[order[1]].frames[1], what .. ": " .. order[1] .. " first")
	-- Your heals: more than fit, clipped to the bar with the same mark.
	local heals = f.buffs
	local side, count, size, spacing = Auras.HealIcons(f, k)
	local healStep = size + spacing
	local healPlaced = Flow(env, ns, f, heals, { "buffs" }, { buffs = 6 }, healStep, math.max(1, count))
	scene = Scene.Build(env)
	local healClip = { Scene.Rect(env, f.buffClip) }
	inside(healClip, { Scene.Rect(env, f) }, what .. ": your heals")
	for i, button in ipairs(healPlaced) do
		local item = drawn(scene, Auras.Parts(button).icon)
		if item then
			inside(item.clip or item.rect, healClip, what .. ": heal " .. i)
		end
	end
	assert(drawn(scene, Auras.Parts(healPlaced[count + 1]).mark), what .. ": the hidden heal raises the + mark (" .. side .. ")")
	-- Indicators: every slot on, the largest size, all inside the tile.
	local K = env.KstyleUI
	for i = 1, 6 do
		K.Options.Write("GroupFrames", "indicator" .. i .. ".category", "EXTERNAL")
		K.Options.Write("GroupFrames", "indicator" .. i .. ".size", 32)
	end
	K.Options.Write("GroupFrames", "indicator6.position", "BOTTOMRIGHT")
	env.RunTimers()
	local tile = { Scene.Rect(env, f) }
	for i = 1, 6 do
		local button = f.indicators._slots["indicator" .. i].frame
		button._aura.icon:SetTexture(135936)
		button:Show()
		inside({ Scene.Rect(env, button) }, tile, what .. ": indicator " .. i)
	end
end

do
	local env, _, ns = party()
	local tank = content(ns, ns.Headers.party, "party1")
	local card = ns.Headers.cards.party.frame
	local cx, cy, cw, ch = Scene.Rect(env, card)
	local pad = ns.Geometry.CARD_PAD
	manyAuras(env, ns, tank, { cx + pad, cy, cw - 2 * pad, ch }, "party")
	eq(#env._errors, 0, tostring(env._errors[1]))
end
do
	local env, K, ns = G.New()
	G.SetRoster(env, "raid", G.Members(10))
	assert(K.Modules.Enable("GroupFrames"))
	env.RunTimers()
	local f = content(ns, ns.Headers.raid[1], "raid1")
	manyAuras(env, ns, f, { Scene.Rect(env, f) }, "raid")
	-- The owner's extreme settings: ten debuffs in four rows of large icons still fit the tile.
	K.Options.Write("GroupFrames", "raid.auraCount", 10)
	K.Options.Write("GroupFrames", "raid.auraColumns", 10)
	K.Options.Write("GroupFrames", "raid.auraRows", 4)
	K.Options.Write("GroupFrames", "raid.auraSize", 40)
	env.RunTimers()
	local block = ns.Auras.Block(f, ns.Settings.current.raid)
	assert(block.cells >= 1, "at least one cell fits")
	inside({ Scene.Rect(env, f.auraClip) }, { Scene.Rect(env, f) }, "raid, large icons: the debuff block")
	eq(#env._errors, 0, tostring(env._errors[1]))
end

-- Codex review, round 2: a count that does not fill the rectangle rounds down to whole rows, so the clip never
-- shows more debuffs than the count; two indicators that share a place sit side by side, both readable; and a
-- name's distinct short form is measured whole, so it never reaches the engine's ellipsis.
do
	local _, _, ns = party()
	local b = ns.Geometry.AuraBlock({ auraCount = 5, auraColumns = 3, auraRows = 2, auraPosition = "BOTTOMLEFT", auraWrap = "UP" }, 77, 40, 8, 1, 2, 0)
	eq(b.columns * b.rows, b.cells, "the clip is exactly the cells")
	assert(b.cells <= 5, "never more than the count: " .. b.cells)
	local Names = ns.Names
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
end
do
	local env, K, ns = party()
	K.Options.Write("GroupFrames", "indicator1.size", 6)
	K.Options.Write("GroupFrames", "indicator2.size", 32)
	env.RunTimers()
	local tank = content(ns, ns.Headers.party, "party1")
	local a, b = tank.indicators._slots.indicator1.frame, tank.indicators._slots.indicator2.frame
	for _, button in ipairs({ a, b }) do
		button._aura.icon:SetTexture(135936)
		button:Show()
	end
	local ra, rb = { Scene.Rect(env, a) }, { Scene.Rect(env, b) }
	local apart = ra[1] + ra[3] <= rb[1] + 0.01 or rb[1] + rb[3] <= ra[1] + 0.01
	assert(apart, "two indicators at the centre sit side by side, not one around the other")
	eq(#env._errors, 0, tostring(env._errors[1]))
end

print("groupframes depth ok")
