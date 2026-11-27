-- test-unitframes-parity-r3a-review.lua: the PR #625 review probes: an unplaced pet cast bar in combat, idle decorations after relayout, the happiness badge over the raid marker, the pet spell icon row and tiny widths, simple boss auras, mixed preview zoom, copy restyles and missing cast APIs.
local U = dofile("Tools/regression/unitframes_env.lua")
local W = U.W
local env, K, ns = U.New()
local Settings, Frames = ns.Settings, ns.Frames

local function write(key, value)
	K.Options.Write("UnitFrames", key, value)
	env.RunTimers()
end

local function near(a, b, eps)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (eps or 1e-6)
end

local function rowShown(key)
	return K.Options.Row("UnitFrames", key).showWhen(Settings.Module())
end

local function unit(key)
	U.SetUnit(env, key, { name = "Caster", level = 60, health = 900, healthMax = 1000, reaction = 2 })
end
unit("pet"); unit("boss1"); unit("target")
env.FireEvent("UNIT_PET", "player"); env.FireEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
local pet = Frames.Get("pet")

-- First enabling the pet cast bar in combat shows nothing unplaced; combat's end places it.
env.SetCombat(true)
write("pet.castbar", true)
write("pet.castbarHideIdle", false)
local cb = pet.views[1].castbar
assert(not (cb and cb.frame:IsShown()), "an unplaced pet cast bar stays hidden in combat")
env.SetCombat(false)
env.RunTimers()
cb = assert(pet.views[1].castbar, "combat's end makes the pet cast bar")
assert(cb.frame:IsShown() and cb.frame:GetWidth() and W.LastCall(cb.frame, "SetPoint"), "combat's end places and shows the idle track")

-- An idle track stays empty through relayouts and restyles, in Frames and Medallions.
K.Options.Write("HudStyle", "style", "frames")
env.RunTimers()
assert(not cb.label:IsShown() and not cb.lock:IsShown(), "the idle track shows no Casting label after combat's layout")
pet.holder:SetSize(180, 42)
assert(not cb.label:IsShown() and not cb.lock:IsShown(), "a resize keeps the idle track empty")
write("pet.castbarColor", "gold")
assert(not cb.label:IsShown(), "a restyle keeps the idle track empty")
K.Options.Write("HudStyle", "style", "medallions")
env.RunTimers()
assert(not (cb.bar.fillCursor and cb.bar.fillCursor:IsShown()), "the Medallions idle track shows no progress edge")
pet.holder:SetSize(200, 46)
assert(not (cb.bar.fillCursor and cb.bar.fillCursor:IsShown()), "a resize keeps the Medallions idle track without its edge")

-- The happiness badge never covers the raid marker, wherever it sits.
env.HasPetUI = function() return true, true end
env.C_PetInfo = { GetPetHappiness = function() return 3 end }
write("pet.happiness", "always")
write("pet.markerSize", 48)
env._units.pet.marker = 8
env.FireEvent("RAID_TARGET_UPDATE")
local function clear(where)
	local v = pet.views[1]
	local m, icon = v.geometry.marker, v.extraIcon
	local pt, size = W.LastCall(icon, "SetPoint"), W.LastCall(icon, "SetSize")[1]
	local w, h = v.parent:GetSize()
	local x = (pt[3]:find("LEFT") and 0 or w) + pt[4] - (pt[1]:find("RIGHT") and size or 0)
	local y = pt[1]:find("BOTTOM") and -pt[5] - size or h / 2 - size / 2 - pt[5]
	local ow = math.min(m.x + m.w, x + size) - math.max(m.x, x)
	local oh = math.min(m.y + m.h, y + size) - math.max(m.y, y)
	assert(icon:IsShown() and v.marker:IsShown() and (ow <= 0.01 or oh <= 0.01), where .. ": the badge overlaps the marker by " .. ow .. " x " .. oh)
end
for _, style in ipairs({ "medallions", "frames" }) do
	K.Options.Write("HudStyle", "style", style)
	env.RunTimers()
	for _, look in ipairs({ "lumen", "plate" }) do
		write("pet.style", look)
		for _, spot in ipairs({ "LEFT", "TOPLEFT", "RIGHT", "TOPRIGHT" }) do
			write("pet.happinessPosition", spot)
			clear(style .. " " .. look .. " " .. spot)
		end
	end
end
write("pet.happinessPosition", "")
write("pet.markerSize", 0)
write("pet.happiness", "unhappy")

-- On Frames the pet's Spell icon row shows only where its cast bar draws the icon, and a tiny width keeps a usable bar.
write("edit", "pet")
write("pet.style", "lumen")
assert(not rowShown("pet.castbarIcon"), "the pet's line cast bar draws no icon, so its row hides")
write("pet.style", "plate")
assert(rowShown("pet.castbarIcon"), "the plate draws the icon, so its row shows")
write("pet.castbarIcon", true)
env._units.pet.cast = { name = "Bite", texture = 132278, start = 1000, finish = 10000, spellID = 17253 }
env.FireEvent("UNIT_SPELLCAST_START", "pet", "Cast-1", 17253)
assert(cb.active and cb.iconFrame:IsShown(), "the plate's pet cast shows its icon")
write("pet.castbarWidth", 1)
assert(cb.geometry.bar.w > 0 and cb.geometry.text.w > 0, "a 1-unit width keeps a usable fill and spell name")
env._units.pet.cast = nil
env.FireEvent("UNIT_SPELLCAST_STOP", "pet", "Cast-1", 17253)
env.RunTimers()
write("pet.castbarWidth", 0)
write("pet.castbarIcon", false)
K.Options.Write("HudStyle", "style", "medallions")
env.RunTimers()
assert(not rowShown("pet.castbarIcon"), "a Medallions cast bar draws no icon, so its row hides")

-- A tiny Medallions width keeps a usable bar.
write("pet.style", "plate")
env._units.pet.cast = { name = "Bite", texture = 132278, start = 1000, finish = 10000, spellID = 17253 }
env.FireEvent("UNIT_SPELLCAST_START", "pet", "Cast-1", 17253)
write("pet.castbarWidth", 1)
assert(cb.bar:GetWidth() > 0 and W.LastCall(cb.text, "SetWidth")[1] > 0, "a 1-unit width keeps a usable fill and spell name")
env._units.pet.cast = nil
env.FireEvent("UNIT_SPELLCAST_STOP", "pet", "Cast-1", 17253)
env.RunTimers()
write("pet.castbarWidth", 0)
write("pet.style", "lumen")

-- Simple boss auras: one row of each group, as tall as the boss slot between the boss gaps.
local boss = Frames.Get("boss")
local function slot()
	return (boss.holder:GetHeight() - Settings.Value("boss", "gap") * 4) / 5
end
write("edit", "boss")
write("boss.auraRows", 2)
write("boss.auraSimple", "LEFT")
assert(Settings.Value("boss", "auraRows") == 1 and near(Settings.Value("boss", "auraSize"), slot()), "one row of slot-tall icons")
write("boss.gap", 12)
assert(near(Settings.Value("boss", "auraSize"), slot()), "the icons follow the boss gap")
write("boss.auraFilter", "both")
local spacing = Settings.Value("boss", "auraSpacing")
assert(Settings.Value("boss", "auraRows") == 1 and near(Settings.Value("boss", "auraSize"), (slot() - spacing) / 2), "debuffs and buffs share the slot in one row each")
assert(near(select(2, ns.Auras.Footprint("boss")), slot()), "the block is as tall as the slot")
assert(boss.s.auraPosition == "LEFT" and near(boss.s.auraSize, Settings.Value("boss", "auraSize")), "the snapshot holds the simple look")
assert(not rowShown("boss.auraRows"), "the simple display hides Aura rows")
write("boss.gap", 6)

-- The mixed preview zooms its sample buffs.
write("edit", "target")
write("target.auraFilter", "both")
write("target.auraBuffZoom", 0.25)
local preview = ns.Preview.Build(env.UIParent)
local zoomed = 0
for _, tile in ipairs(preview.auraTiles.target) do
	if tile.skin:IsShown() and W.LastCall(tile.icon, "SetTexCoord")[1] == 0.25 then zoomed = zoomed + 1 end
end
assert(zoomed > 0, "the mixed preview shows its buff samples at the buff zoom")
write("target.auraBuffZoom", -1)
write("target.auraFilter", "mine")

-- A copying boss restyles only for the copied look, and once per view.
local apply, calls = ns.Auras.Apply, 0
ns.Auras.Apply = function(v)
	if v.kind == "boss" then calls = calls + 1 end
	return apply(v)
end
write("boss.auraCopy", "target")
calls = 0
write("target.healthAlpha", 0.75)
assert(calls == 0, "an unrelated target setting leaves the copying boss alone: " .. calls)
write("target.auraSpacing", 3)
assert(calls == #boss.views, "a copied setting applies each boss view's auras once: " .. calls)
ns.Auras.Apply = apply
write("boss.auraCopy", "")
write("boss.auraSimple", "")

-- Missing cast APIs take the safe path.
local errors, kerrors = #env._errors, K.ErrorCount()
local casting, channel = env.UnitCastingInfo, env.UnitChannelInfo
env.UnitCastingInfo, env.UnitChannelInfo = nil, nil
env.FireEvent("UNIT_SPELLCAST_START", "pet", "Cast-2", 17253)
env.FireEvent("UNIT_SPELLCAST_CHANNEL_START", "pet", "Cast-3", 17253)
env.FireEvent("UNIT_PET", "player")
env.UnitCastingInfo, env.UnitChannelInfo = casting, channel
assert(#env._errors == errors and K.ErrorCount() == kerrors, "missing cast APIs raise nothing: " .. tostring(env._errors[#env._errors]))
assert(not cb.active, "and show no cast")

-- The copy and simple redirects cost nothing until a frame uses them, and follow profile switches.
local plain = Settings.Value
write("boss.auraCopy", "target")
assert(Settings.Value ~= plain and Settings.Value("boss", "auraColumns") == Settings.Value("target", "auraColumns"), "copying switches the redirect on")
assert(K.Store.CreateProfile("Plain") and K.Store.SetProfile("Plain"))
env.RunTimers()
assert(Settings.Value == plain, "a profile where no frame copies reads settings plainly")
assert(K.Store.SetProfile("Default"))
env.RunTimers()
assert(Settings.Value ~= plain and Settings.Value("boss", "auraColumns") == Settings.Value("target", "auraColumns"), "switching back copies again")
write("boss.auraCopy", "")
assert(Settings.Value == plain, "no copy, no redirect")
assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
print("test-unitframes-parity-r3a-review: ok")
