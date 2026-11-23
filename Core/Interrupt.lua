-- Interrupt.lua: finds the player's interrupt spell, whether it is ready and when it comes back, for the cast bars that watch it; it listens only while one does.
local _, ns = ...

local Interrupt = { spell = nil, ready = nil, readyAt = nil, named = "", running = false }
ns.Interrupt = Interrupt

local OWNER = "Interrupt"
local watchers = {}
local logged = {}

local function IsSecret(value)
	return issecretvalue ~= nil and issecretvalue(value) == true
end

local function LogOnce(key, message)
	if not logged[key] then
		logged[key] = true
		ns.DevTest.Log(OWNER, message)
	end
end

local INTERRUPTS = {
	WARRIOR = { 6554, 6552, 1672, 1671, 72 },
	ROGUE = { 1769, 1768, 1767, 1766 },
	MAGE = { 2139 },
	SHAMAN = { 10414, 10413, 10412, 8046, 8045, 8044, 8042 },
	PRIEST = { 15487 },
	WARLOCK = { 19647, 19244 },
	PALADIN = { 425609 },
	DRUID = { 410176, 1238122, 16979 },
}
Interrupt.INTERRUPTS = INTERRUPTS

function Interrupt.Spell(class, known)
	local list = type(class) == "string" and INTERRUPTS[class]
	if not list then
		return nil
	end
	for i = 1, #list do
		local id = list[i]
		if known(id) == true then
			return id
		end
	end
	return nil
end

function Interrupt.Ready(info, fromCooldownEvent)
	if IsSecret(info) or type(info) ~= "table" then
		return nil
	end
	local active = info.isActive
	if IsSecret(active) or type(active) ~= "boolean" then
		return nil
	end
	if not active or fromCooldownEvent ~= true then
		return not active
	end
	local gcd = info.isOnGCD
	if IsSecret(gcd) then
		return nil
	end
	return gcd == true
end

local function Known(id)
	local book = C_SpellBook
	if not (book and type(book.IsSpellKnown) == "function") then
		return false
	end
	local known = book.IsSpellKnown(id)
	if not IsSecret(known) and known == true then
		return true
	end
	local banks = Enum and Enum.SpellBookSpellBank
	if banks and banks.Pet ~= nil then
		known = book.IsSpellKnown(id, banks.Pet)
		return not IsSecret(known) and known == true
	end
	return false
end

local function PlayerClass()
	local _, file = UnitClass("player")
	if IsSecret(file) or type(file) ~= "string" then
		return nil
	end
	return file
end

function Interrupt.NamedSpell(text)
	local api = C_Spell
	if api and type(api.GetSpellIDForSpellIdentifier) == "function" then
		local id = api.GetSpellIDForSpellIdentifier(text)
		if not IsSecret(id) and type(id) == "number" then
			return id
		end
	end
	return text
end

local function Plain(value)
	return not IsSecret(value) and type(value) == "number" and value == value
end

local function ReadyAt(info, ready)
	if ready ~= false or IsSecret(info) or type(info) ~= "table" then
		return nil
	end
	local start, duration = info.startTime, info.duration
	if Plain(start) and Plain(duration) and duration > 0 then
		return start + duration
	end
	return nil
end

function Interrupt.Update(fromCooldownEvent, spellChanged)
	local ready, readyAt
	local spell = Interrupt.spell
	local api = C_Spell
	if spell and api and type(api.GetSpellCooldown) == "function" then
		local ok, info = pcall(api.GetSpellCooldown, spell)
		if ok then
			ready = Interrupt.Ready(info, fromCooldownEvent == true)
			readyAt = ReadyAt(info, ready)
			if ready == nil then
				LogOnce("interrupt-secret", "the interrupt's cooldown came back secret or empty; interruptible casts use the wait colour")
			end
		else
			LogOnce("interrupt-cooldown", "GetSpellCooldown refused the interrupt spell: " .. tostring(info))
		end
	end
	if ready ~= Interrupt.ready or readyAt ~= Interrupt.readyAt or spellChanged then
		Interrupt.ready, Interrupt.readyAt = ready, readyAt
		if Interrupt.running then
			for _, fn in pairs(watchers) do fn() end
		end
	end
end

function Interrupt.Name(text)
	Interrupt.named = text
end

function Interrupt.Resolve()
	local named = Interrupt.named
	local spell
	if type(named) == "string" and named ~= "" then
		spell = Interrupt.NamedSpell(named)
	else
		local class = PlayerClass()
		spell = Interrupt.Spell(class, Known)
		if not spell and class and not INTERRUPTS[class] then
			LogOnce("interrupt-class", "no interrupt is listed for " .. class .. "; interruptible casts keep their normal colour")
		end
	end
	local changed = spell ~= Interrupt.spell
	if changed then
		Interrupt.spell = spell
		ns.DevTest.Log(OWNER, spell and ("the interrupt is spell " .. tostring(spell)) or "no interrupt spell is known; interruptible casts keep their normal colour")
	end
	Interrupt.Update(false, changed)
end

local function OnCooldown()
	Interrupt.Update(true)
end

function Interrupt.Target(unit)
	if type(UnitShouldDisplaySpellTargetName) ~= "function" or type(UnitSpellTargetName) ~= "function" then
		return nil
	end
	local show = UnitShouldDisplaySpellTargetName(unit)
	if IsSecret(show) or show ~= true then
		return nil
	end
	local name = UnitSpellTargetName(unit)
	if not IsSecret(name) and (type(name) ~= "string" or name == "") then
		return nil
	end
	local class, me
	if type(UnitSpellTargetClass) == "function" then
		class = UnitSpellTargetClass(unit)
	end
	if type(PlayerIsSpellTarget) == "function" then
		local ok, value = pcall(PlayerIsSpellTarget, unit)
		if ok then me = value end
	end
	return name, class, me
end

function Interrupt.By(guid)
	if type(guid) == "nil" or type(UnitNameFromGUID) ~= "function" then
		return nil
	end
	local name = UnitNameFromGUID(guid)
	if not IsSecret(name) and (type(name) ~= "string" or name == "") then
		return nil
	end
	local class
	if type(UnitClassFromGUID) == "function" then
		local _, file = UnitClassFromGUID(guid)
		class = file
	end
	local player = type(UnitGUID) == "function" and UnitGUID("player")
	return name, class, not IsSecret(guid) and not IsSecret(player) and guid == player
end

function Interrupt.Watch(owner, fn)
	watchers[owner] = fn
	if not Interrupt.running then
		Interrupt.running = true
		ns.Events.Register(OWNER, "SPELL_UPDATE_COOLDOWN", OnCooldown)
		ns.Events.Register(OWNER, "SPELLS_CHANGED", Interrupt.Resolve)
	end
	Interrupt.Resolve()
end

function Interrupt.Unwatch(owner)
	watchers[owner] = nil
	if Interrupt.running and next(watchers) == nil then
		Interrupt.running = false
		Interrupt.ready, Interrupt.readyAt = nil, nil
		ns.Events.UnregisterAll(OWNER)
	end
end
