-- ranged_env.lua: the stub game a hunter, mage or warlock crest test boots (KstyleUI_ActionBars/SlabRanged.lua): New builds the class with its known spells, bags, an on-use trinket in slot 13 (opts.trinket), a change to the addon before it is enabled (opts.before), pet, ammo, the minimap's tracking (opts.tracking, a Track spell; env._herbs adds Find Herbs) the target's creature type number (opts.creature) and whether it can be attacked (env._attackable), the pet's focus, spellbook (opts.petSpells) and autocast (env._autocast), the group (env._grouped), the pet's target (env._petTarget) and spell range (env._range), usable strikes, item and spell cooldowns and secret auras behind Blizzard's aura slots; Piece and Seated find a switch's piece, Shown asks whether the engine plays a group, Tint compares a region's colour, Icons lists every spell or item icon under a frame, Clean asserts no error, and Listening says whether the tracker lifecycle holds an event.
local AB = dofile("Tools/regression/actionbars_env.lua")
local Slots = dofile("Tools/regression/aura_slots.lua")

local SIZES = { { 1920, 1080 }, { 2560, 1440 }, { 5120, 1440 }, { 3840, 2160 } }
local KNOWN = {
	HUNTER = { 13165, 883, 1130, 1978, 19552, 3045, 19574, 75, 2643, 19506, 24293 },
	MAGE = { 168, 759, 11426, 12574, 116, 118, 12042, 11958, 2139, 122 },
	WARLOCK = { 172, 980, 348, 688, 6201, 1120, 18094, 18288, 706, 702, 17962, 2362, 6789 },
}

-- The shared stub's Hide runs no OnHide. With opts.hiding a shown frame that hides, by Hide or SetShown(false), runs OnHide on
-- itself and every shown descendant, as the client does, so a test reaches a hide handler only through the code that hides it.
local function Hidden(frame)
	local fn = frame._scripts and frame._scripts.OnHide
	if fn then fn(frame) end
	for _, kid in ipairs(frame._kids or {}) do
		if kid._shown then Hidden(kid) end
	end
end

local function Hiding(env)
	local meta = getmetatable(env.UIParent)
	if not meta.hiding then
		local index = meta.__index
		local wrapped = {}
		for _, key in ipairs({ "Hide", "SetShown" }) do
			wrapped[key] = function(self, shown, ...)
				local visible = self:IsVisible()
				index(self, key)(self, shown, ...)
				if visible and not self:IsVisible() then Hidden(self) end
			end
		end
		meta.__index = function(object, key)
			local owner = rawget(object, "_env")
			return owner and owner._hiding and wrapped[key] or index(object, key)
		end
		meta.hiding = true
	end
	env._hiding = true
end

local function New(class, opts)
	opts = opts or {}
	local size = opts.size or SIZES[1]
	local env, K, ns = AB.New({
		class = class,
		width = size[1],
		height = size[2],
		setup = function(e)
			e._known = {}
			for _, id in ipairs(opts.known or KNOWN[class] or {}) do e._known[id] = true end
			e.C_SpellBook = e.C_SpellBook or {}
			e.C_Secrets = { ShouldAurasBeSecret = function() return e._aurasSecret == true end }
			e._aurasSecret = opts.secret
			e._bags, e._cooling, e._usable = opts.bags or {}, {}, {}
			e.C_Item = e.C_Item or {}
			e.C_Item.GetItemCount = function(id) return e._bags[id] or 0 end
			e.C_Item.GetItemIconByID = function(id) return 5000000 + id end
			e.C_Item.GetItemCooldown = function(id)
				local c = e._cooling[id]
				if c then return c[1], c[2], true end
				return 0, 0, true
			end
			e.C_Spell.IsSpellUsable = function(id) return e._usable[id] == true, false end
			e.C_Spell.GetSpellCooldown = function() return { isActive = false, isOnGCD = false } end
			e.C_Spell.GetSpellCooldownDuration = function() return { start = 0, finish = 0 } end
			e._ammo = 1000
			e.UnitUsesAmmo = function() return true end
			e.C_PaperDollInfo = { GetInventorySlotInfo = function() return 0 end }
			e.GetInventoryItemCount = function() return e._ammo end
			e.Enum.PowerType = e.Enum.PowerType or { Mana = 0 }
			e.UnitPowerPercent = function() return 0.25 end
			e.C_CurveUtil = { CreateCurve = function() return { AddPoint = function() end, SetType = function() end } end }
			e.C_DurationUtil = { CreateDuration = function() return { SetTimeFromStart = function(d, start, duration) d.start, d.duration = start, duration end } end }
			e.GetTime = e.GetTime or function() return e._now or 0 end
			e._petSpells = {}
			for _, id in ipairs(opts.petSpells or {}) do e._petSpells[id] = true end
			e.C_SpellBook.IsSpellKnown = function(id, bank) if bank == 1 then return e._petSpells[id] == true end return e._known[id] == true end
			e.Enum.SpellBookSpellBank = e.Enum.SpellBookSpellBank or { Player = 0, Pet = 1 }
			e._pet = opts.pet
			local exists = e.UnitExists
			e.UnitExists = function(unit) if unit == "pet" then return e._pet ~= nil end return exists(unit) end
			e.UnitIsDead = function(unit) return unit == "pet" and e._pet ~= nil and e._pet.dead or false end
			e.UnitHealthMax = function() return e.Secret(e._pet and e._pet.max or 0) end
			e.UnitHealth = function() return e.Secret(e._pet and e._pet.max - e._pet.missing or 0) end
			e.UnitHealthMissing = function() return e.Secret(e._pet and e._pet.missing or 0) end
			e.C_PetInfo = { GetPetHappiness = function() return e._pet and e._pet.mood end }
			e._tracking, e._creature = opts.tracking, opts.creature
			e.C_Minimap = {
				GetNumTrackingTypes = function() return 2 end,
				GetTrackingInfo = function(i)
					if i == 1 then return { name = "Find Herbs", spellID = 2383, active = e._herbs == true } end
					return { name = "Tracking", spellID = e._tracking or 1494, active = e._tracking ~= nil }
				end,
			}
			-- UnitCreatureType's second return is the creature type ID; the name is the client's, a secret with a secret ID.
			e.UnitCreatureType = function(unit)
				if unit == "target" and e._target and e._creature ~= nil then
					return type(e._creature) ~= "number" and e.Secret("Creature") or "Creature", e._creature
				end
			end
			e._attackable = true
			e.UnitCanAttack = function(_, unit) return unit == "target" and e._target and e._attackable or false end
			e.UnitPower = function(unit) return e.Secret(unit == "pet" and e._pet and e._pet.focus or 0) end
			e.UnitPowerMax = function(unit) return e.Secret(unit == "pet" and e._pet and 100 or 0) end
			e._autocast, e._range, e._rangeChecks = {}, {}, {}
			e.C_Spell.GetSpellAutoCast = function(id) return true, e._autocast[id] end
			e.C_Spell.EnableSpellRangeCheck = function(id, on) e._rangeChecks[id] = on end
			e.C_Spell.IsSpellInRange = function(id, unit) if unit == "target" and e._target then return e._range[id] end end
			e.IsInGroup = function() return e._grouped end
			local exists = e.UnitExists
			e.UnitExists = function(unit) if unit == "pettarget" then return e._petTarget ~= nil end return exists(unit) end
			e.UnitIsUnit = function(a, b) if a == "pettarget" and b == "target" then return e._petTarget == "yours" end return a == b end
			e.GetInventoryItemID = function(_, slot) return opts.trinket and slot == 13 and 5002 or nil end
			e.GetInventoryItemCooldown = function() return 0, 0, 1, false end
			e.C_Item.GetItemSpell = function(id) if id == 5002 then return "Use", 9002 end end
			e.C_SpecializationInfo = opts.tree and { GetSpecialization = function() return opts.tree end }
			e._slotGroups = true
			e.AuraContainerSortMethod = { Default = 0, AuraInstanceIDOnly = 8 }
			e.AuraContainerSortDirection = { Normal = 0, Reverse = 1 }
			Slots.Install(e)
		end,
	})
	if opts.hiding then
		Hiding(env)
	end
	env._owned = {}
	local events = K.Events
	for _, name in ipairs({ "Register", "RegisterUnit" }) do
		local register = events[name]
		events[name] = function(owner, event, ...)
			env._owned[owner] = env._owned[owner] or {}
			env._owned[owner][event] = true
			return register(owner, event, ...)
		end
	end
	local clear = events.UnregisterAll
	events.UnregisterAll = function(owner)
		env._owned[owner] = nil
		return clear(owner)
	end
	if opts.frames then
		K.Options.Write("HudStyle", "style", "frames")
	end
	if opts.before then
		opts.before(env, K, ns)
	end
	AB.Enable(env, K)
	env.RunTimers()
	return env, K, ns
end

-- Piece(ns, key, choice) -> the piece built for the switch's row and choice (1 when unset), and whether it shows.
local function Piece(ns, key, choice)
	local state = ns.SlabTrackers.state
	local form = state.form
	for i, row in ipairs(ns.SlabTrackers.CLASSES[ns.class] or {}) do
		local p = row.key == key and form and form.pieces[i .. ":" .. (choice or 1)]
		if p then return p, p:IsShown() end
	end
end

-- Seated(ns, key) -> the piece showing in the switch's seat, whichever choice it is.
local function Seated(ns, key)
	for c = 1, 8 do
		local p, shows = Piece(ns, key, c)
		if shows then return p end
	end
end

-- Shown(button, group) -> whether the engine plays the group, on the aura's showing or on each new aura.
local function Shown(button, group)
	for _, list in ipairs({ button._shownAnimations or {}, button._assignedAnimations or {} }) do
		for _, g in ipairs(list) do
			if g == group then return true end
		end
	end
	return false
end

local function Updating(frame)
	local n = frame:GetScript("OnUpdate") and 1 or 0
	for _, child in ipairs(frame._kids or {}) do
		n = n + Updating(child)
	end
	return n
end

local function Clean(env, K)
	assert(#env._errors == 0 and K.ErrorCount() == 0, AB.Errors(env))
end

-- Tint(region, K, token, white) -> whether the region is drawn in the token's colour, lifted toward white by that share.
local function Tint(region, K, token, white)
	white = white or 0
	local r, g, b = K.Tokens.Color(token)
	r, g, b = white + (1 - white) * r, white + (1 - white) * g, white + (1 - white) * b
	local vr, vg, vb = region:GetVertexColor()
	return math.abs(vr - r) + math.abs(vg - g) + math.abs(vb - b) < 1e-3
end

-- Icons(frame, found) -> found, listing every region under frame that shows a spell or item icon: a texture given a
-- file ID, or a region an aura slot paints its aura's icon into.
local function Icons(frame, found)
	if frame._icon then found[#found + 1] = "an aura slot's icon" end
	for _, region in ipairs(frame._regions or {}) do
		local texture = region._state and region._state.Texture
		if texture and type(texture[1]) == "number" then found[#found + 1] = "file ID " .. texture[1] end
	end
	for _, kid in ipairs(frame._kids or {}) do Icons(kid, found) end
	return found
end

local function Learn(env, ...)
	for _, id in ipairs({ ... }) do env._known[id] = true end
	env.FireEvent("SPELLS_CHANGED")
end

-- Listening(env, event) -> whether the crest trackers hold the event, so a test sees a switch give its events back.
local function Listening(env, event)
	local owned = env._owned["ActionBars.SlabTrackers"]
	return owned ~= nil and owned[event] == true
end

return { AB = AB, Slots = Slots, SIZES = SIZES, KNOWN = KNOWN, New = New, Piece = Piece, Seated = Seated, Shown = Shown, Updating = Updating, Clean = Clean, Tint = Tint, Icons = Icons, Learn = Learn,
	Listening = Listening }
