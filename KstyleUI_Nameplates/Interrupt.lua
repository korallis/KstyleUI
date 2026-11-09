-- Interrupt.lua: finds the player's interrupt spell and whether it is ready, so cast bars can say which casts the player can stop right now.
local _, ns = ...

local K = KstyleUI
local Settings, Logic = ns.Settings, ns.Logic
local IsSecret = Logic.IsSecret
local LogOnce = ns.LogOnce
local MODULE = Settings.MODULE

local Interrupt = { spell = nil, ready = true, running = false }
ns.Interrupt = Interrupt

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

local function NamedSpell(text)
	local api = C_Spell
	if api and type(api.GetSpellIDForSpellIdentifier) == "function" then
		local id = api.GetSpellIDForSpellIdentifier(text)
		if not IsSecret(id) and type(id) == "number" then
			return id
		end
	end
	return text
end

function Interrupt.Resolve()
	local named = Settings.Get("cast.interruptSpell")
	local spell
	if type(named) == "string" and named ~= "" then
		spell = NamedSpell(named)
	else
		local class = PlayerClass()
		spell = Logic.InterruptSpell(class, Known)
		if not spell and class and not Logic.INTERRUPTS[class] then
			LogOnce("interrupt-class", "no interrupt is listed for " .. class .. "; cast bars show interruptible and not")
		end
	end
	if spell ~= Interrupt.spell then
		Interrupt.spell = spell
		K.DevTest.Log(MODULE, spell and ("the interrupt is spell " .. tostring(spell)) or "no interrupt spell is known; cast bars show interruptible and not")
	end
	Interrupt.Update()
end

local function Repaint()
	ns.Cast.RepaintAll()
end

function Interrupt.Update()
	local ready = true
	local spell = Interrupt.spell
	local api = C_Spell
	if spell and api and type(api.GetSpellCooldown) == "function" then
		local ok, info = pcall(api.GetSpellCooldown, spell)
		if ok then
			local state = Logic.InterruptReady(info)
			if state == false then
				ready = false
			elseif state == nil then
				LogOnce("interrupt-secret", "the interrupt's cooldown came back secret or empty; its casts read as interruptible")
			end
		else
			LogOnce("interrupt-cooldown", "GetSpellCooldown refused the interrupt spell: " .. tostring(info))
		end
	end
	if ready ~= Interrupt.ready then
		Interrupt.ready = ready
		if Interrupt.running then
			Repaint()
		end
	end
end

local function OnCooldown()
	if Interrupt.running then
		Interrupt.Update()
	end
end

local function OnSpells()
	if Interrupt.running then
		Interrupt.Resolve()
	end
end

function Interrupt.Start()
	Interrupt.running = true
	K.Events.Register(MODULE, "SPELL_UPDATE_COOLDOWN", OnCooldown)
	K.Events.Register(MODULE, "SPELLS_CHANGED", OnSpells)
	Interrupt.Resolve()
end

function Interrupt.Stop()
	Interrupt.running = false
	Interrupt.ready = true
end
