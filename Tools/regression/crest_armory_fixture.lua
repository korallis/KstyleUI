-- crest_armory_fixture.lua: the warrior's, paladin's and rogue's crest effect tests' shared stub game (known spells, usable strikes, cooldowns, an on-use trinket, two weapons and the aura slots) and helpers.
local F = { AB = dofile("Tools/regression/actionbars_env.lua"), Slots = dofile("Tools/regression/aura_slots.lua") }
local AB, Slots = F.AB, F.Slots

function F.New(class, known, frames)
	local env, K, ns = AB.New({
		class = class,
		setup = function(e)
			e._known, e._usable, e._cooling = {}, {}, {}
			for _, id in ipairs(known) do e._known[id] = true end
			e.C_SpellBook = e.C_SpellBook or {}
			e.C_SpellBook.IsSpellKnown = function(id) return e._known[id] == true end
			e.C_Secrets = { ShouldAurasBeSecret = function() return e._aurasSecret == true end }
			e.C_Spell.IsSpellUsable = function(id) return e._usable[id] == true, false end
			e.C_Spell.GetSpellCooldown = function(id) return { isActive = e._cooling[id] == true, isOnGCD = false } end
			e.C_Spell.GetSpellCooldownDuration = function(id) return { start = 0, finish = e._cooling[id] and 10 or 0 } end
			e.C_Spell.GetSpellTexture = function(id) return 100000 + id end
			e.GetInventoryItemID = function(_, slot) return (slot == 16 or slot == 17) and 2092 or slot == 13 and 4001 or nil end
			e.GetInventoryItemCooldown = function() return 10, 120, 1 end
			e.GetShapeshiftFormID = function() return e._form end
			e.C_Item = { GetItemCount = function() return 1 end, GetItemCooldown = function() return 10, 120, true end, GetItemIconByID = function(id) return 200000 + id end,
				GetItemSpell = function(id) if id == 4001 then return "Use", 23723 end end }
			e.C_DurationUtil = { CreateDuration = function() return { SetTimeFromStart = function(d, start, duration) d.start, d.duration = start, duration end } end }
			e._slotGroups = true
			Slots.Install(e)
			e.AuraContainerSortMethod, e.AuraContainerSortDirection = { Default = 0, AuraInstanceIDOnly = 8 }, { Normal = 0, Reverse = 1 }
		end,
	})
	AB.Enable(env, K)
	if frames then K.Options.Write("HudStyle", "style", "frames") end
	env.RunTimers()
	return env, K, ns
end

function F.Clean(env, K, what)
	assert(#env._errors == 0 and K.ErrorCount() == 0, what .. ": " .. AB.Errors(env))
end

function F.Auras(_, list, harmful)
	local auras = {}
	for i, id in ipairs(list) do
		auras[i] = { id = id, count = 2, icon = 300000 + id, harmful = harmful, mine = true, start = 0, duration = 30 }
	end
	return auras
end

-- Every region a piece holds, its own frames, its aura containers and the engine's buttons under them.
function F.Walk(region, fn)
	fn(region)
	for _, kid in ipairs(region._regions or {}) do F.Walk(kid, fn) end
	for _, kid in ipairs(region._kids or {}) do F.Walk(kid, fn) end
end

-- A round socket frame: a medal's ring, enamel or dark track. The three classes' pieces (a look, the five-second ring) are objects, grooves and overlays, never set in one.
function F.Round(K)
	local round = {}
	for _, name in ipairs({ "orbRing", "medRing", "medEnamel" }) do round[(K.Tokens.Texture(name))] = name end
	return function(region)
		local texture = region._state and region._state.Texture
		return texture and round[texture[1]]
	end
end

function F.Find(ns, key, form, slot)
	for _, p in pairs(ns.SlabTrackers.state.forms[form or "crest"].pieces) do
		if p:IsVisible() and p.spec.key == key and (not slot or p.spec.slot == slot) then return p end
	end
end

function F.Lit(p)
	for _, lit in ipairs(p.lits or {}) do
		if lit:IsShown() then return true end
	end
	return false
end

return F
