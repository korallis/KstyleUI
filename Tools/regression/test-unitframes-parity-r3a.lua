-- test-unitframes-parity-r3a.lua: parity round 3a (mini frames) keeps v0.2.8 looks and makes no pet cast bar until asked, then writes and applies raid marker size, happiness position, the pet cast bar with its width and height, hide when idle, copy auras from, buff icon zoom and the boss simple aura display, each on after its events, off back to the original state, and in the preview.
local U = dofile("Tools/regression/unitframes_env.lua")
local W = U.W

local env, K, ns = U.New({
	saved = { version = 42, profiles = { Default = { UnitFrames = { enabled = true } } }, characters = {}, layouts = {} },
	setup = function(e)
		e.C_PetInfo = { GetPetHappiness = function() return 3 end }
		e.HasPetUI = function() return true, true end
	end,
})
local Settings, Frames = ns.Settings, ns.Frames

local function near(a, b, eps)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (eps or 1e-6)
end

local function clean(where)
	assert(#env._errors == 0 and K.ErrorCount() == 0, where .. ": " .. tostring(env._errors[1]))
end

local function write(key, value)
	K.Options.Write("UnitFrames", key, value)
	env.RunTimers()
end

local function keys(schema)
	local out = {}
	for _, row in ipairs(schema) do
		if row.key then out[row.key] = row end
	end
	return out
end

-- Old profiles keep today's look and make no pet cast bar.
for _, kind in ipairs(U.KINDS) do
	assert(Settings.Value(kind, "markerSize") == 0 and Settings.Value(kind, "castbarHideIdle") == true, kind .. " keeps marker size and idle hiding")
	assert(Settings.Value(kind, "auraCopy") == "" and Settings.Value(kind, "auraBuffZoom") == -1, kind .. " keeps its own aura look")
end
assert(Settings.Value("pet", "castbar") == false and Settings.Value("pet", "happinessPosition") == "", "the pet cast bar and badge place start as today")
assert(Settings.Value("boss", "auraSimple") == "" and Settings.Value("boss", "auraPosition") == "LEFT" and Settings.Value("boss", "auraSize") == 22, "boss auras keep their rows")
local pet = Frames.Get("pet").views[1]
assert(pet.castbar == nil, "no pet cast bar is made until it is turned on")

local schema = keys(Settings.Schema())
assert(schema["pet.castbarWidth"] and not schema["boss.castbarWidth"], "only the pet has a cast bar width")
assert(schema["pet.castbarHideIdle"] and schema["boss.castbarHideIdle"] and not schema["player.castbarHideIdle"], "pet and boss can keep an idle bar")
assert(schema["pet.happinessPosition"] and not schema["target.happinessPosition"], "only the pet places a happiness badge")
assert(schema["boss.auraSimple"] and not schema["target.auraSimple"], "only boss frames have the simple display")
assert(schema["target.markerSize"] and schema["target.auraBuffZoom"] and schema["boss.auraCopy"], "marker size, buff zoom and copy rows exist")
for _, option in ipairs(schema["boss.auraCopy"].options) do
	assert(option.value ~= "boss" and option.value ~= "pet", "a frame copies only other frames that have auras")
end
assert(near(schema["target.auraBuffZoom"].shown(-1), 0.07), "an unset buff zoom paints the aura zoom it follows")

-- Raid marker size: replaces icon size + 4, the name lane follows, 0 restores it.
U.SetUnit(env, "target", { name = "Ogre", level = 62, health = 3000, healthMax = 4000, reaction = 2, canAttack = true, marker = 8 })
env.FireEvent("RAID_TARGET_UPDATE")
local target = Frames.Get("target").views[1]
local size = W.LastCall(target.marker, "SetSize")
assert(near(size[1], target.s.iconSize + ns.Geometry.MARKER_EXTRA, 0.5), "the marker starts at the icon size plus 4")
write("target.markerSize", 30)
size = W.LastCall(target.marker, "SetSize")
assert(near(size[1], 30, 0.5) and near(size[2], 30, 0.5) and target.geometry.marker.w == 30, "the marker takes its own size")
assert(target.marker:IsShown(), "a marked unit keeps its marker")
env.FireEvent("RAID_TARGET_UPDATE")
assert(target.marker:IsShown() and near(W.LastCall(target.marker, "SetSize")[1], 30, 0.5), "a marker change keeps the size")
write("target.markerSize", 0)
assert(near(W.LastCall(target.marker, "SetSize")[1], target.s.iconSize + ns.Geometry.MARKER_EXTRA, 0.5), "0 follows the icon size again")
clean("marker")

-- Happiness position: today's spot by default, each other place on choice, back on reset.
U.SetUnit(env, "pet", { name = "Wolf", level = 58, health = 1460, healthMax = 2000, power = 80, powerMax = 100, reaction = 5 })
write("pet.happiness", true)
local badge = assert(pet.extraIcon, "happiness on makes the badge")
local spot = W.LastCall(badge, "SetPoint")
assert(spot[1] == "BOTTOMRIGHT" and spot[3] == "TOPRIGHT" and spot[4] == 0 and spot[5] > 0, "the badge sits above the right end")
local gap = spot[5]
write("pet.happinessPosition", "LEFT")
spot = W.LastCall(badge, "SetPoint")
assert(spot[1] == "RIGHT" and spot[2] == pet.parent and spot[3] == "LEFT" and near(spot[4], -gap) and spot[5] == 0, "Left puts it beside the frame's left edge")
write("pet.happinessPosition", "TOPLEFT")
spot = W.LastCall(badge, "SetPoint")
assert(spot[1] == "BOTTOMLEFT" and spot[3] == "TOPLEFT", "Above the left end")
env.FireEvent("UNIT_HAPPINESS", "pet")
assert(badge:IsShown() and W.LastCall(badge, "SetPoint")[1] == "BOTTOMLEFT", "a mood change keeps the place")
write("pet.style", "plate")
assert(W.LastCall(badge, "SetPoint")[1] == "BOTTOMLEFT", "a plate keeps the chosen place")
write("pet.happinessPosition", "")
assert(W.LastCall(badge, "SetAllPoints")[1] == pet.icons.resting, "Standard on a plate restores the resting slot")
write("pet.style", "lumen")
spot = W.LastCall(badge, "SetPoint")
assert(spot[1] == "BOTTOMRIGHT" and spot[3] == "TOPRIGHT", "Standard on a row restores the spot above the right end")
write("pet.happiness", false)
clean("happiness")

-- Pet cast bar: made on first use, under the frame, its width and height, its casts, and Blizzard's bar.
assert(not K.Safe.IsHidden(env.PetCastingBarFrame), "Blizzard's pet cast bar stays while ours is off")
write("pet.castbar", true)
local cb = assert(pet.castbar, "turning the pet cast bar on makes it")
local point = W.LastCall(cb.frame, "SetPoint")
local _, bh = pet.button:GetSize()
assert(point[1] == "TOPLEFT" and point[2] == pet.button and -point[5] >= bh + 3.5, "the bar hangs under the frame")
local bw = pet.button:GetSize()
local fw, fh = cb.frame:GetSize()
assert(near(fw, bw, 0.5) and near(fh, 12, 0.5), "it matches the frame's width at 12 units tall")
assert(not cb.frame:IsShown(), "an idle pet cast bar stays hidden")
assert(K.Safe.IsHidden(env.PetCastingBarFrame), "Blizzard's pet cast bar hides while ours shows")
write("pet.castbarWidth", 180)
write("pet.castbarHeight", 16)
fw, fh = cb.frame:GetSize()
assert(near(fw, 180, 0.5) and near(fh, 16, 0.5), "width and height apply")
env._units.pet.cast = { name = "Bite", texture = 132278, start = 1000, finish = 2000, spellID = 17253 }
env.FireEvent("UNIT_SPELLCAST_START", "pet", "Cast-1", 17253)
assert(cb.active and cb.frame:IsShown() and U.Shown(env, cb.text):find("BITE", 1, true), "the pet's cast shows: " .. U.Shown(env, cb.text))
env._units.pet.cast = nil
env.FireEvent("UNIT_SPELLCAST_STOP", "pet", "Cast-1", 17253)
env.RunTimers()
assert(not cb.active, "the cast ends")
env.SetCombat(true)
write("pet.castbarWidth", 120)
assert(near(cb.frame:GetSize(), 180, 0.5), "a combat change waits")
env.SetCombat(false)
env.RunTimers()
assert(near(cb.frame:GetSize(), 120, 0.5), "combat's end applies the width")
write("pet.enabled", false)
assert(not K.Safe.IsHidden(env.PetCastingBarFrame), "with no pet frame, Blizzard's pet cast bar returns")
write("pet.enabled", true)
write("pet.castbar", false)
assert(not K.Safe.IsHidden(env.PetCastingBarFrame), "off restores Blizzard's pet cast bar")
env._units.pet.cast = { name = "Bite", texture = 132278, start = 1000, finish = 2000, spellID = 17253 }
env.FireEvent("UNIT_SPELLCAST_START", "pet", "Cast-2", 17253)
assert(not cb.active and not cb.frame:IsShown(), "off ignores the pet's casts")
env._units.pet.cast = nil
clean("pet cast bar")

-- Hide when idle off: the empty track stays between casts, on the pet and the boss card, after every cast event.
write("pet.castbar", true)
write("pet.castbarHideIdle", false)
assert(cb.idle and cb.frame:IsShown() and cb.frame:GetAlpha() == 1, "an idle bar shows its track")
assert(select(1, U.Bar(env, cb.bar)) == 0 and U.Shown(env, cb.text) == "" and U.Shown(env, cb.timer) == "", "the idle track is empty")
env._units.pet.cast = { name = "Bite", texture = 132278, start = 1000, finish = 2000, spellID = 17253 }
env.FireEvent("UNIT_SPELLCAST_START", "pet", "Cast-3", 17253)
assert(cb.active and U.Shown(env, cb.text):find("BITE", 1, true), "a cast fills the track")
env._units.pet.cast = nil
env.FireEvent("UNIT_SPELLCAST_FAILED", "pet", "Cast-3", 17253)
env.RunTimers()
assert(cb.frame:IsShown() and U.Shown(env, cb.text) == "" and not cb.label:IsShown(), "after the failed flash the empty track returns")
env.FireEvent("UNIT_PET", "player")
assert(cb.frame:IsShown() and not cb.active, "a pet change keeps the idle track")
ns.CastBars.Disable()
assert(not cb.frame:IsShown(), "switching the cast bars off hides an idle track too")
ns.CastBars.Enable()
assert(cb.idle and cb.frame:IsShown(), "and switching them on brings it back")
write("pet.castbarHideIdle", true)
assert(not cb.idle and not cb.frame:IsShown(), "on hides the idle bar again")

U.SetUnit(env, "boss1", { name = "Magmatus", level = -1, classification = "worldboss", health = 500, healthMax = 1000, reaction = 2, canAttack = true })
env.FireEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
env.RunTimers()
local boss = Frames.Get("boss").views[1]
local rest = boss.panel:GetHeight()
assert(not boss.castbar.frame:IsShown() and near(rest, K.Widgets.Snap(boss.parent, boss.geometry.rest)), "an idle boss card folds to its resting height")
write("boss.castbarHideIdle", false)
assert(boss.castbar.frame:IsShown() and near(boss.panel:GetHeight(), K.Widgets.Snap(boss.parent, boss.geometry.glass.h)), "an idle boss bar keeps the card open")
write("boss.castbarHideIdle", true)
assert(not boss.castbar.frame:IsShown() and near(boss.panel:GetHeight(), rest), "on folds the card again")
clean("idle")

-- Copy auras from: the boss takes the target's look, follows its changes, keeps its own place; no loop.
local entries = boss.auras.buttons
local function sizes(list)
	return W.LastCall(list[1].button, "SetSize")[1]
end
write("boss.auraCopy", "target")
assert(Settings.Value("boss", "auraSize") == Settings.Value("target", "auraSize") and Settings.Value("boss", "auraColumns") == Settings.Value("target", "auraColumns"), "the boss copies the target's look")
assert(Settings.Value("boss", "auraPosition") == "LEFT", "the boss keeps its own position")
assert(near(sizes(entries), K.Widgets.Snap(boss.auras.host, Settings.Value("target", "auraSize")), 0.01), "boss aura buttons take the copied size")
write("target.auraSize", 32)
assert(near(sizes(entries), K.Widgets.Snap(boss.auras.host, 32), 0.01), "a change on the target reaches the boss")
write("target.auraColumns", 5)
assert(Settings.Value("boss", "auraColumns") == 5 and boss.auras.container._groups.debuffs.max == 5, "any target aura change restyles the copying boss")
write("target.auraColumns", 4)
write("target.auraCopy", "boss")
assert(Settings.Value("target", "auraSize") == 22 and Settings.Value("boss", "auraSize") == 32, "copying both ways reads each frame's own look once")
write("target.auraCopy", "")
write("boss.auraCopy", "")
assert(near(sizes(entries), K.Widgets.Snap(boss.auras.host, 22), 0.01), "own settings restore the boss's look")
write("target.auraSize", 27.6)
clean("copy")

-- Buff icon zoom: buffs follow the aura zoom until set, then crop on their own; reset follows again.
write("target.auraFilter", "both")
local buff, debuff
for _, entry in ipairs(target.auras.buttons) do
	if entry.buff then buff = entry else debuff = entry end
end
assert(buff and debuff, "the target has buff and debuff buttons")
assert(near(W.LastCall(buff.icon, "SetTexCoord")[1], 0.07), "an unset buff zoom follows the aura zoom")
write("target.auraBuffZoom", 0.2)
assert(near(W.LastCall(buff.icon, "SetTexCoord")[1], 0.2) and near(W.LastCall(debuff.icon, "SetTexCoord")[1], 0.07), "buffs crop on their own")
write("target.auraZoom", 0.12)
assert(near(W.LastCall(buff.icon, "SetTexCoord")[1], 0.2) and near(W.LastCall(debuff.icon, "SetTexCoord")[1], 0.12), "the aura zoom then moves only debuffs")
write("target.auraBuffZoom", -1)
assert(near(W.LastCall(buff.icon, "SetTexCoord")[1], 0.12), "reset buffs follow the aura zoom again")
write("target.auraZoom", 0.07)
write("target.auraFilter", "mine")
clean("buff zoom")

-- Simple aura display: icons as tall as each boss slot, beside it, through holder resizes; off restores the rows.
local uf = Frames.Get("boss")
local G = ns.Geometry
local function slot()
	return (uf.holder:GetHeight() - G.BOSS_GAP * (G.BOSS_COUNT - 1)) / G.BOSS_COUNT
end
write("boss.auraSimple", "RIGHT")
assert(Settings.Value("boss", "auraPosition") == "RIGHT" and near(Settings.Value("boss", "auraSize"), slot()), "simple display takes the slot's height")
local host = boss.auras.host
assert(near(host:GetHeight(), K.Widgets.Snap(host, slot()), 0.01), "the aura block is as tall as the frame")
point = W.LastCall(host, "SetPoint")
assert(point[1] == "TOPLEFT" and point[2] == boss.button and point[3] == "TOPRIGHT", "it sits right of the frame")
local slotBefore = slot()
uf.holder:SetSize(222, 434)
Frames.Relayout(uf)
assert(slot() > slotBefore and near(sizes(entries), K.Widgets.Snap(host, slot()), 0.01), "a taller column grows the icons")
write("boss.auraFilter", "both")
assert(near(host:GetHeight(), K.Widgets.Snap(host, slot()), 0.5), "debuffs and buffs share the frame's height")
write("boss.auraFilter", "mine")
uf.holder:SetSize(222, 334)
Frames.Relayout(uf)
write("boss.auraSimple", "")
assert(Settings.Value("boss", "auraPosition") == "LEFT" and near(sizes(entries), K.Widgets.Snap(host, 22), 0.01), "off restores the boss rows")
clean("simple")

-- The preview shows each option.
write("edit", "pet")
write("pet.happiness", true)
write("pet.happinessPosition", "RIGHT")
write("pet.castbarWidth", 150)
local pane = ns.Preview.Build(env.UIParent)
local sample = pane.views.pet
local cast = assert(pane.casts.pet, "the pet preview shows its cast bar")
fw, fh = cast.frame:GetSize()
assert(cast.frame:IsShown() and near(fw, 150) and near(fh, 16), "at its width and height")
point = W.LastCall(cast.frame, "SetPoint")
assert(-point[5] > select(2, pane.holders.pet:GetSize()), "under the sample frame")
assert(W.LastCall(sample.extraIcon, "SetPoint")[1] == "LEFT", "the badge sits right of the sample")
write("pet.markerSize", 26)
write("edit", "target")
pane:Refresh()
assert(pane.views.target.geometry.marker.w == 16, "the target sample keeps its own marker size")
write("target.markerSize", 26)
write("target.auraFilter", "buffs")
write("target.auraBuffZoom", 0.25)
pane:Refresh()
assert(pane.views.target.geometry.marker.w == 26, "the sample marker takes its size")
assert(near(W.LastCall(pane.auraTiles.target[1].icon, "SetTexCoord")[1], 0.25), "sample buffs take the buff zoom")
write("edit", "boss")
write("boss.auraSimple", "LEFT")
pane:Refresh()
local tile = pane.auraTiles.boss[1].skin
assert(near(select(2, tile:GetSize()), K.Widgets.Snap(tile, slot()), 0.5), "the boss sample shows the simple display")
write("boss.auraCopy", "target")
write("boss.auraSimple", "")
pane:Refresh()
assert(near(select(2, tile:GetSize()), K.Widgets.Snap(tile, Settings.Value("target", "auraSize")), 0.5), "the boss sample copies the target's look")
clean("preview")

-- Medallions: the pet's medallion reaches below its slab, so the pet cast bar starts under the medallion.
K.Options.Write("HudStyle", "style", "medallions")
env.RunTimers()
local medal = pet.geometry.medal
assert(medal and medal.y + medal.h > select(2, pet.button:GetSize()), "the pet medallion hangs below the slab")
point = W.LastCall(cb.frame, "SetPoint")
assert(-point[5] >= medal.y + medal.h + 3.5, "the pet cast bar starts below the medallion")
write("pet.castbarHideIdle", false)
local cursor = cb.bar.fillCursor
assert(cb.frame:IsShown() and not (cursor and cursor:IsShown()), "the idle Medallions track shows no progress edge")
env._units.pet.cast = { name = "Bite", texture = 132278, start = 1000, finish = 2000, spellID = 17253 }
env.FireEvent("UNIT_SPELLCAST_START", "pet", "Cast-4", 17253)
assert(cb.bar.fillCursor and cb.bar.fillCursor:IsShown(), "a cast brings the progress edge back")
env._units.pet.cast = nil
env.FireEvent("UNIT_SPELLCAST_STOP", "pet", "Cast-4", 17253)
env.RunTimers()
assert(not cb.bar.fillCursor:IsShown(), "and the idle track drops it again")
write("pet.castbarHideIdle", true)
write("pet.happiness", true)
write("pet.happinessPosition", "LEFT")
spot = W.LastCall(pet.extraIcon, "SetPoint")
assert(spot[1] == "RIGHT" and spot[3] == "LEFT" and spot[4] <= medal.x - 1.5, "Left clears the medallion")
write("pet.happinessPosition", "TOPLEFT")
spot = W.LastCall(pet.extraIcon, "SetPoint")
assert(spot[1] == "BOTTOMLEFT" and spot[5] >= -medal.y + 1.5, "Above the left end clears the medallion's top")
write("pet.happinessPosition", "")
write("pet.happiness", false)
K.Options.Write("HudStyle", "style", "frames")
env.RunTimers()
clean("medallions")
print("test-unitframes-parity-r3a: ok")
