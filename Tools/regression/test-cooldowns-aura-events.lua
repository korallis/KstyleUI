-- test-cooldowns-aura-events.lua: the tracked buff mirror refreshes at most once a frame, only for UNIT_AURA updates that touch a tracked spell or a shown aura, and listens to the target only while a tracked buff can come from it.
local C = dofile("Tools/regression/cooldowns_env.lua")

local cooldowns = C.Sample()
cooldowns[302].linkedSpellIDs = { 3555 }
local env, K, ns = C.New({ cooldowns = cooldowns, setup = C.Game })
local cdm = env._cdm
cdm.auras[3001] = { auraInstanceID = 71 }
cdm.auras[4001] = { auraInstanceID = 81 }
K.Options.Write("Cooldowns", "path", "mirror")
C.Enable(env, K)
env.RunTimers()
local buffs, bars = ns.Mirror.Row("buffs"), ns.Mirror.Row("bars")
assert(buffs.count == 1 and bars.count == 1, "one buff and one bar show at the start")

-- Each refresh searches the player for every tracked buff once. Spell 4002 is the first spell of its
-- entry and is never overridden, so its lookups count the refreshes.
local function Refreshes()
	local n = 0
	for _, args in ipairs(C.Calls(env, "GetPlayerAuraBySpellID")) do
		if args[1] == 4002 then
			n = n + 1
		end
	end
	return n
end

local function Aura(unit, info)
	env.FireEvent("UNIT_AURA", unit, info)
end

-- Frame(fn) runs fn, ends the frame, and returns how many refreshes ran.
local function Frame(fn)
	local before = Refreshes()
	fn()
	env.RunTimers()
	return Refreshes() - before
end

local function Expect(n, fn, what)
	local got = Frame(fn)
	assert(got == n, what .. ": expected " .. n .. " refreshes, got " .. got)
end

local function AuraUnits()
	for _, frame in ipairs(env._frames) do
		local registered, unit1, unit2 = frame:IsEventRegistered("UNIT_AURA")
		if registered then
			return table.concat({ unit1, unit2 }, " ")
		end
	end
	return ""
end

local function Logged(text)
	for _, line in ipairs(env.KstyleUIDB.devlog) do
		if line.module == "Cooldowns" and tostring(line.message):find(text, 1, true) then
			return true
		end
	end
	return false
end

-- Several UNIT_AURA events in one frame make one refresh, after the events.
local before = Refreshes()
cdm.auras[3002] = { auraInstanceID = 72 }
Aura("player", { isFullUpdate = true })
Aura("player", { addedAuras = { { spellId = 3002, auraInstanceID = 72 } } })
Aura("player", { updatedAuraInstanceIDs = { 71 } })
assert(Refreshes() == before and buffs.count == 1, "UNIT_AURA does no aura work inside the event")
env.RunTimers()
assert(Refreshes() - before == 1, "three events in one frame refresh once, got " .. (Refreshes() - before))
assert(buffs.count == 2, "the refresh shows the new buff")

-- Updates that touch no tracked spell and no shown aura are skipped.
Expect(0, function()
	Aura("player", { addedAuras = { { spellId = 9999, auraInstanceID = 500 } } })
end, "an untracked aura added")
Expect(0, function()
	Aura("player", { removedAuraInstanceIDs = { 500 } })
end, "an aura removed that no row shows")
Expect(0, function()
	Aura("player", { updatedAuraInstanceIDs = { 501, 502 } })
end, "auras updated that no row shows")
Expect(0, function()
	Aura("player", {})
end, "an empty update")
Expect(0, function()
	Aura("target", { updatedAuraInstanceIDs = { 71 } })
end, "a target aura whose ID matches a player aura a row shows")

-- Updates that touch a tracked spell or a shown aura refresh.
Expect(1, function()
	Aura("player", { addedAuras = { { spellId = 3555, auraInstanceID = 600 } } })
end, "a linked spell's aura added")
cdm.stacks[71] = "4"
Expect(1, function()
	Aura("player", { updatedAuraInstanceIDs = { 71 } })
end, "a shown aura updated")
assert(buffs.icons[1].count:GetText() == "4", "the stack count follows the update")
cdm.auras[3002] = nil
Expect(1, function()
	Aura("player", { removedAuraInstanceIDs = { 72 } })
end, "a shown aura removed")
assert(buffs.count == 1, "the removed buff drops out")
Expect(1, function()
	Aura("player", { isFullUpdate = true })
end, "a full update")
Expect(1, function()
	Aura("player", nil)
end, "an event with no update info")

-- An update it cannot read while aura data is readable refreshes rather than risk a stale row.
Expect(1, function()
	Aura("player", env.Secret({ isFullUpdate = false }))
end, "secret update info")
Expect(1, function()
	Aura("player", { addedAuras = { { spellId = env.Secret(9999), auraInstanceID = 700 } } })
end, "an added aura with a secret spell ID")
Expect(1, function()
	Aura("player", { removedAuraInstanceIDs = { env.Secret(500) } })
end, "a secret removed instance ID")
assert(Logged("could not be read"), "the devlog records the full refresh for an update it cannot read")

-- An override moves the tracked spell: the override event refreshes, and the new spell's auras count.
Expect(1, function()
	env.FireEvent("COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED", 3002, 3222)
end, "an override of a tracked buff")
Expect(1, function()
	Aura("player", { addedAuras = { { spellId = 3222, auraInstanceID = 800 } } })
end, "the override spell's aura added")

-- While aura data is secret nothing is read. The first update after it, even an unrelated one, refreshes.
cdm.secretAuras = true
Expect(0, function()
	Aura("player", env.Secret({ isFullUpdate = true }))
end, "an update while auras are secret")
cdm.secretAuras = false
Expect(1, function()
	Aura("player", { addedAuras = { { spellId = 9999, auraInstanceID = 900 } } })
end, "the first update after auras turn readable")
Expect(0, function()
	Aura("player", { addedAuras = { { spellId = 9999, auraInstanceID = 901 } } })
end, "the next unrelated update")

-- While a tracked buff is not on the player, its aura can come from the target, so the target is listened to.
assert(AuraUnits() == "player target", "the target is listened to while a tracked buff is missing from the player, got " .. AuraUnits())
cdm.targetAuras["Spell 4002"] = { auraInstanceID = 82 }
Expect(1, function()
	env.SetTarget(true)
end, "a target change")
assert(bars.count == 2, "the target's debuff adds a bar")
Expect(0, function()
	Aura("target", { addedAuras = { { spellId = 9999, auraInstanceID = 83 } } })
end, "an untracked debuff on the target")
Expect(1, function()
	Aura("target", { updatedAuraInstanceIDs = { 82 } })
end, "the shown target debuff updated")

-- A buff on the player wins over a debuff on the target, even when the debuff matches the entry's
-- override spell and the buff only its base spell, as in Blizzard's viewer, which scans the player first.
cdm.targetAuras["Spell 3222"] = { auraInstanceID = 84 }
cdm.auras[3002] = { auraInstanceID = 72 }
Expect(1, function()
	Aura("player", { addedAuras = { { spellId = 3002, auraInstanceID = 72 } } })
end, "the base spell's buff added")
local overridden
for i = 1, buffs.count do
	if buffs.icons[i].entry.spellID == 3002 then
		overridden = buffs.icons[i].entry
	end
end
assert(overridden and overridden.auraUnit == "player" and overridden.auraID == 72, "the player's buff wins over the target's debuff")
cdm.targetAuras["Spell 3222"] = nil

-- With every tracked buff on the player, the target cannot change a row: it is not listened to.
cdm.auras[4002] = { auraInstanceID = 92 }
Expect(1, function()
	Aura("player", { isFullUpdate = true })
end, "a full update with every tracked buff on the player")
assert(AuraUnits() == "player", "only the player is listened to, got " .. AuraUnits())
Expect(0, function()
	Aura("target", { isFullUpdate = true })
end, "a target update while every tracked buff is on the player")
Expect(0, function()
	env.SetTarget(false)
end, "a target change while every tracked buff is on the player")

-- A tracked buff leaving the player listens to the target again.
cdm.auras[4002] = nil
Expect(1, function()
	Aura("player", { removedAuraInstanceIDs = { 92 } })
end, "a shown buff removed")
assert(AuraUnits() == "player target", "the target is listened to again, got " .. AuraUnits())
env.SetTarget(true)
env.RunTimers()
Expect(1, function()
	Aura("target", { isFullUpdate = true })
end, "a target update once a tracked buff can come from it")

-- A refresh queued before the module stops does nothing.
Aura("player", { isFullUpdate = true })
K.Modules.Disable("Cooldowns")
Expect(0, function() end, "a refresh queued before Disable")
assert(AuraUnits() == "", "Disable stops listening to UNIT_AURA")

-- Started while aura data is secret, the rows stay empty; the first update after it turns readable fills them.
do
	local env2, K2, ns2 = C.New({ setup = C.Game })
	env2._cdm.auras[3001] = { auraInstanceID = 71 }
	env2._cdm.secretAuras = true
	K2.Options.Write("Cooldowns", "path", "mirror")
	C.Enable(env2, K2)
	env2.RunTimers()
	local row = ns2.Mirror.Row("buffs")
	assert(row.count == 0, "nothing is read while aura data is secret")
	env2._cdm.secretAuras = false
	env2.FireEvent("UNIT_AURA", "player", { addedAuras = { { spellId = 9999, auraInstanceID = 500 } } })
	env2.RunTimers()
	assert(row.count == 1, "the first update after aura data turns readable fills the rows")
end

print("cooldowns aura events ok")
