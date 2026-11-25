-- test-actionbars-crest-trinkets.lua: an equipped trinket with a use effect (slots 13 and 14, C_Item.GetItemSpell) is a forged jewel inside the crest's rings at 9 and 3 o'clock (never an icon) that burns its GetInventoryItemCooldown round the central cooldown rim and refills over it (a C_DurationUtil duration object), ignoring the global cooldown and secret values; a trinket without a use effect, or none, shows nothing; only a trinket slot's equipment change or its item data arriving rebuilds, and nothing with the switch off; a class's own bag and equipment updates keep their handlers; nothing is sized in combat; under Frames it is a gem in the row that charges over its cooldown.
local AB = dofile("Tools/regression/actionbars_env.lua")
local Slots = dofile("Tools/regression/aura_slots.lua")
local Guard = dofile("Tools/regression/event_guard.lua")

local USE = { [5002] = 9002, [5003] = 9003 }

local function New(opts)
	opts = opts or {}
	local env, K, ns = AB.New({
		class = opts.class or "WARRIOR",
		setup = function(e)
			e._queries = 0
			e.C_SpellBook = e.C_SpellBook or {}
			e.C_SpellBook.IsSpellKnown = function(id)
				e._queries = e._queries + 1
				return id == 1719 or id == 6673
			end
			e.C_Secrets = { ShouldAurasBeSecret = function() return e._aurasSecret == true end }
			e.C_Spell.GetSpellTexture = function(id) return 100000 + id end
			e._items, e._cd = opts.items or {}, {}
			e.GetInventoryItemID = function(_, slot) return e._items[slot] end
			e.GetInventoryItemCooldown = function(_, slot) return unpack(e._cd[slot] or { 0, 0, 1, false }) end
			e.C_Item = e.C_Item or {}
			e.C_Item.GetItemSpell = function(id) if USE[id] then return "Use", USE[id] end end
			e.C_Item.GetItemIconByID = function(id) return 200000 + id end
			e.C_DurationUtil = { CreateDuration = function() return { SetTimeFromStart = function(d, start, duration) d.start, d.duration = start, duration end } end }
			e._slotGroups = true
			Slots.Install(e)
			e.AuraContainerSortMethod, e.AuraContainerSortDirection = { Default = 0, AuraInstanceIDOnly = 8 }, { Normal = 0, Reverse = 1 }
		end,
	})
	env._collisions = Guard.Install(K)
	AB.Enable(env, K)
	if opts.frames then K.Options.Write("HudStyle", "style", "frames") end
	env.RunTimers()
	return env, K, ns
end

local function Clean(env, K, what)
	assert(#env._errors == 0 and K.ErrorCount() == 0 and #(env._blocked or {}) == 0, what .. ": " .. AB.Errors(env))
	Guard.Check(env._collisions, what)
end

local function Find(ns, form, test)
	local f = ns.SlabTrackers.state.forms[form or "crest"]
	for _, p in pairs(f and f.pieces or {}) do
		if p:IsShown() and test(p.spec) then return p end
	end
end

local function Trinket(ns, slot, form)
	return Find(ns, form, function(spec) return spec.key == "crestTrinkets" and spec.slot == slot end)
end

local function Equip(env, slot, id)
	env._items[slot] = id
	env.FireEvent("PLAYER_EQUIPMENT_CHANGED", slot, id == nil)
end

local function Seat(ns, p)
	local hub = ns.Slab.hub
	local x, y = p:GetCenter()
	local hx, hy = hub:GetCenter()
	local s = p:GetEffectiveScale() / hub:GetEffectiveScale()
	return x * s - hx, y * s - hy
end

-- No trinket, or one without a use effect: nothing.
do
	local env, K, ns = New()
	assert(ns.SlabTrackers.Has("crestTrinkets") and not Trinket(ns, 13) and not Trinket(ns, 14), "no trinket equipped: no trinket jewel")
	Equip(env, 13, 5001)
	assert(not Trinket(ns, 13), "a trinket without a use effect shows nothing")
	Clean(env, K, "no trinket")
end

-- An on-use trinket in each slot: a jewel inside the rings that burns its cooldown round the central rim.
do
	local env, K, ns = New()
	local rim = Find(ns, "crest", function(spec) return spec.seat == "cooldowns" end)
	Equip(env, 13, 5002)
	local left = Trinket(ns, 13)
	assert(left and left.bar and left.lit:IsShown() and not left.lit.icon and not left.steel, "equipping an on-use trinket sets a jewel on the crest, no icon")
	local x, y = Seat(ns, left)
	assert(math.abs(x + 33) < 1 and math.abs(y + 24) < 1, "a warrior's first trinket jewel sits inside the rings below the horn, clear of the cooldown sigils")
	assert(math.sqrt(x * x + y * y) + 6 < 112 / 2 * 0.9375, "and clear of the inner ring's band")
	assert(AB.W.LastCall(left.bar, "SetValue")[1] == 1, "a ready trinket's jewel is full")
	local ring, point = left.timer, { left.timer:GetPoint(1) }
	assert(point[1] == "CENTER" and point[2] == ns.SlabTrackers.state.forms.crest.frame and ring.units == rim.timer.units, "its ring is the central cooldown rim's ring")
	assert(AB.W.LastCall(ring, "SetSwipeColor")[1] == AB.W.LastCall(rim.timer, "SetSwipeColor")[1], "in the rim's colour")
	Equip(env, 14, 5003)
	local right = Trinket(ns, 14)
	x, y = Seat(ns, right)
	assert(math.abs(x - 33) < 1 and math.abs(y + 24) < 1, "the second below the opening")
	env._cd[13] = { 100, 120, 1, false }
	env.FireEvent("BAG_UPDATE_COOLDOWN")
	local burn, fill = AB.W.LastCall(ring, "SetCooldown"), AB.W.LastCall(left.bar, "SetTimerDuration")
	assert(burn and burn[1] == 100 and burn[2] == 120, "using it burns its two-minute cooldown round the central rim, with no buff up")
	assert(fill and fill[1].start == 100 and fill[1].duration == 120, "and empties the jewel, refilling it over the cooldown")
	assert(not AB.W.LastCall(right.timer, "SetCooldown") and not AB.W.LastCall(right.bar, "SetTimerDuration"), "the other trinket stays ready")
	local burns, timed = #AB.W.Calls(ring, "SetCooldown"), #AB.W.Calls(left.bar, "SetTimerDuration")
	env._cd[13] = { 300, 1.5, 1, true }
	env.FireEvent("BAG_UPDATE_COOLDOWN")
	assert(#AB.W.Calls(ring, "SetCooldown") == burns and #AB.W.Calls(left.bar, "SetTimerDuration") == timed and AB.W.LastCall(left.bar, "SetValue")[1] == 1, "the global cooldown is not a trinket cooldown")
	env._cd[13] = { env.Secret(100), env.Secret(120), 1, false }
	env.FireEvent("BAG_UPDATE_COOLDOWN")
	assert(#AB.W.Calls(ring, "SetCooldown") == burns and #AB.W.Calls(left.bar, "SetTimerDuration") == timed, "a secret cooldown is never compared or passed on")
	ring:GetScript("OnCooldownDone")(ring)
	K.Options.Write("ActionBars", "crestTrinkets", false)
	env.RunTimers()
	assert(not Trinket(ns, 13) and not Trinket(ns, 14), "its switch hides both, ring and all")
	env._queries = 0
	Equip(env, 13, 5003)
	assert(env._queries == 0, "with the switch off a trinket change rebuilds nothing")
	K.Options.Write("ActionBars", "crestTrinkets", true)
	env.RunTimers()
	env._queries = 0
	Equip(env, 16, 2092)
	assert(env._queries == 0, "a weapon change rebuilds nothing for a class without equipment pieces")
	Equip(env, 13, nil)
	assert(not Trinket(ns, 13) and Trinket(ns, 14), "unequipping hides that trinket only")
	Clean(env, K, "trinkets")
end

-- An item whose use spell is not loaded yet appears when its item data arrives.
do
	local env, K, ns = New()
	Equip(env, 13, 5004)
	assert(not Trinket(ns, 13), "no use spell yet: nothing")
	USE[5004] = 9004
	env.FireEvent("GET_ITEM_INFO_RECEIVED", 5004, true)
	assert(Trinket(ns, 13), "its item data arriving shows the jewel")
	USE[5004] = nil
	Clean(env, K, "item data")
end

-- A priest's and a druid's bag updates still rebuild their crest with a trinket on (the oil socket on pickup).
for _, class in ipairs({ "PRIEST", "DRUID" }) do
	local env, K, ns = New({ class = class, items = { [13] = 5002 } })
	assert(Trinket(ns, 13), class .. ": the trinket shows")
	env.C_Item.GetItemCount = function(id) return id == 20744 and 1 or 0 end
	env.FireEvent("BAG_UPDATE_DELAYED")
	assert(Find(ns, "crest", function(spec) return spec.key == "crestOil" end), class .. ": picking up an oil shows its socket at once")
	Clean(env, K, class .. " bags")
end

-- In combat nothing is sized, even with auras readable; the cooldown still burns. While auras are secret nothing new is built.
do
	local env, K, ns = New({ items = { [14] = 5003 } })
	local shout = Find(ns, "crest", function(spec) return spec.key == "crestShout" end)
	env.SetCombat(true)
	local writes, size = 0, shout.lit.bar.SetSize
	shout.lit.bar.SetSize = function(...) writes = writes + 1 return size(...) end
	ns.SlabTrackers.state.form.frame:SetScale(1.5)
	ns.SlabTrackers.Update()
	assert(writes == 0, "a new pixel size in combat waits: nothing under an engine aura button is resized")
	env._cd[14] = { 100, 120, 1, false }
	env.FireEvent("BAG_UPDATE_COOLDOWN")
	assert(AB.W.LastCall(Trinket(ns, 14).timer, "SetCooldown"), "a built trinket burns in combat")
	env._aurasSecret = true
	Equip(env, 13, 5002)
	assert(not Trinket(ns, 13), "a new trinket waits for combat to end")
	env.FireEvent("UPDATE_SHAPESHIFT_FORM")
	Clean(env, K, "locked")
	env._aurasSecret = false
	env.SetCombat(false)
	assert(Trinket(ns, 13) and writes > 0, "combat over: it is built and the crest is sized")
	Clean(env, K, "unlocked")
end

-- Frames: the crest's jewel at medal size in the row above the stance bar, no icon, as a figures class's.
do
	local env, K, ns = New({ frames = true, items = { [13] = 5002 } })
	local medal = Trinket(ns, 13, "row")
	assert(medal and medal.glint and medal.lit:IsShown() and not medal.lit.icon, "under Frames the trinket is the crest's jewel, no icon")
	env._cd[13] = { 100, 120, 1, false }
	env.FireEvent("BAG_UPDATE_COOLDOWN")
	assert(AB.W.LastCall(medal.bar, "SetTimerDuration") and AB.W.LastCall(medal.timer, "SetCooldown"), "and charges and burns its cooldown there")
	Clean(env, K, "frames")
end

print("actionbars crest trinkets ok")
