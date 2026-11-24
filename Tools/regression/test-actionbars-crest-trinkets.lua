-- test-actionbars-crest-trinkets.lua: an equipped trinket with a use effect (slots 13 and 14, C_Item.GetItemSpell) stands as a small icon beside the crest's major cooldowns, the first slot left of the icon row and the second right, burns its GetInventoryItemCooldown with a ring and greys while cooling, ignores the global cooldown and secret values, and lights again when ready; a trinket without a use effect, or none, shows nothing; equipping and unequipping rebuild it out of combat only, and while auras are secret nothing raises; its switch hides it; under Frames it is a medal in the row.
local AB = dofile("Tools/regression/actionbars_env.lua")
local Slots = dofile("Tools/regression/aura_slots.lua")

local USE = { [5002] = 9002, [5003] = 9003 }

local function New(opts)
	opts = opts or {}
	local env, K, ns = AB.New({
		class = "WARRIOR",
		setup = function(e)
			e.C_SpellBook = e.C_SpellBook or {}
			e.C_SpellBook.IsSpellKnown = function(id) return id == 1719 end
			e.C_Secrets = { ShouldAurasBeSecret = function() return e._aurasSecret == true end }
			e.C_Spell.GetSpellTexture = function(id) return 100000 + id end
			e._items, e._cd = opts.items or {}, {}
			e.GetInventoryItemID = function(_, slot) return e._items[slot] end
			e.GetInventoryItemCooldown = function(_, slot) return unpack(e._cd[slot] or { 0, 0, 1, false }) end
			e.C_Item = e.C_Item or {}
			e.C_Item.GetItemSpell = function(id) if USE[id] then return "Use", USE[id] end end
			e.C_Item.GetItemIconByID = function(id) return 200000 + id end
			e._slotGroups = true
			Slots.Install(e)
			e.AuraContainerSortMethod, e.AuraContainerSortDirection = { Default = 0, AuraInstanceIDOnly = 8 }, { Normal = 0, Reverse = 1 }
		end,
	})
	AB.Enable(env, K)
	if opts.frames then K.Options.Write("HudStyle", "style", "frames") end
	env.RunTimers()
	return env, K, ns
end

local function Clean(env, K, what)
	assert(#env._errors == 0 and K.ErrorCount() == 0, what .. ": " .. AB.Errors(env))
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

local function Grey(piece)
	local call = AB.W.LastCall(piece.lit.icon, "SetDesaturated")
	return call ~= nil and call[1] == true
end

-- No trinket, or one without a use effect: nothing.
do
	local env, K, ns = New()
	assert(ns.SlabTrackers.Has("crestTrinkets") and not Trinket(ns, 13) and not Trinket(ns, 14), "no trinket equipped: no trinket icon")
	Equip(env, 13, 5001)
	assert(not Trinket(ns, 13), "a trinket without a use effect shows nothing")
	Clean(env, K, "no trinket")
end

-- An on-use trinket in each slot: beside the cooldowns, cooling, ready, unequipped, switched off.
do
	local env, K, ns = New()
	local rim = Find(ns, "crest", function(spec) return spec.seat == "cooldowns" end)
	Equip(env, 13, 5002)
	local left = Trinket(ns, 13)
	assert(left and left.lit:IsShown() and left.lit.icon._state.Texture[1] == 205002, "equipping an on-use trinket shows its own icon")
	local point, to, other = left:GetPoint(1)
	assert(point == "TOPRIGHT" and to == rim.lits[1].container and other == "TOPLEFT", "the first trinket sits left of the cooldown icons")
	assert(not Grey(left), "a ready trinket is lit")
	Equip(env, 14, 5003)
	local right = Trinket(ns, 14)
	point, to, other = right:GetPoint(1)
	assert(point == "TOPLEFT" and to == rim.lits[#rim.lits].container and other == "TOPRIGHT", "the second sits right of them")
	env._cd[13] = { 100, 120, 1, false }
	env.FireEvent("BAG_UPDATE_COOLDOWN")
	local set = AB.W.LastCall(left.timer, "SetCooldown")
	assert(set and set[1] == 100 and set[2] == 120 and Grey(left), "using it burns its two-minute cooldown round it and greys it")
	assert(not Grey(right), "the other trinket stays ready")
	env._cd[13] = { 300, 1.5, 1, true }
	env.FireEvent("BAG_UPDATE_COOLDOWN")
	assert(not Grey(left), "the global cooldown is not a trinket cooldown")
	env._cd[13] = { env.Secret(100), env.Secret(120), 1, false }
	local calls = #AB.W.Calls(left.timer, "SetCooldown")
	env.FireEvent("BAG_UPDATE_COOLDOWN")
	assert(#AB.W.Calls(left.timer, "SetCooldown") == calls and not Grey(left), "a secret cooldown is never compared or passed on")
	env._cd[13] = { 100, 120, 1, false }
	env.FireEvent("BAG_UPDATE_COOLDOWN")
	left.timer:GetScript("OnCooldownDone")(left.timer)
	assert(not Grey(left), "ready again: lit")
	K.Options.Write("ActionBars", "crestCooldowns", false)
	env.RunTimers()
	point, to, other = Trinket(ns, 13):GetPoint(1)
	assert(point == "TOPRIGHT" and to == ns.Slab.hub and other == "CENTER", "cooldowns off: the trinkets keep the icon row's place")
	K.Options.Write("ActionBars", "crestCooldowns", true)
	K.Options.Write("ActionBars", "crestTrinkets", false)
	env.RunTimers()
	assert(not Trinket(ns, 13) and not Trinket(ns, 14), "its switch hides both")
	K.Options.Write("ActionBars", "crestTrinkets", true)
	env.RunTimers()
	Equip(env, 13, nil)
	assert(not Trinket(ns, 13) and Trinket(ns, 14), "unequipping hides that trinket only")
	Clean(env, K, "trinkets")
end

-- While auras are secret and in combat: the cooldown still burns, nothing new is built, nothing raises.
do
	local env, K, ns = New({ items = { [14] = 5003 } })
	env._aurasSecret = true
	env.SetCombat(true)
	env._cd[14] = { 100, 120, 1, false }
	env.FireEvent("BAG_UPDATE_COOLDOWN")
	assert(Grey(Trinket(ns, 14)), "a built trinket cools in combat")
	Equip(env, 13, 5002)
	assert(not Trinket(ns, 13), "a new trinket waits for combat to end")
	env.FireEvent("UPDATE_SHAPESHIFT_FORM")
	Clean(env, K, "locked")
	env._aurasSecret = false
	env.SetCombat(false)
	assert(Trinket(ns, 13), "combat over: it is built")
	Clean(env, K, "unlocked")
end

-- Frames: a medal in the row above the stance bar.
do
	local env, K, ns = New({ frames = true, items = { [13] = 5002 } })
	local medal = Trinket(ns, 13, "row")
	assert(medal and medal.steel and medal.lit:IsShown() and medal.lit.icon._state.Texture[1] == 205002, "under Frames the trinket is a medal with its icon")
	env._cd[13] = { 100, 120, 1, false }
	env.FireEvent("BAG_UPDATE_COOLDOWN")
	assert(Grey(medal) and AB.W.LastCall(medal.timer, "SetCooldown"), "and burns its cooldown there")
	Clean(env, K, "frames")
end

print("actionbars crest trinkets ok")
