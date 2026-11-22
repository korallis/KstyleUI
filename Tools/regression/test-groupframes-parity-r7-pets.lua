-- test-groupframes-parity-r7-pets.lua: EllesmereUI parity round 7: party pets beside their owners follow the owner's unit in combat through the header's refreshUnitChange, sit past party targets, leave raids to the pet frames, reach the preview and switch back; the dispel highlight under the bar's fills drops below the predictions and returns.
local H = dofile("Tools/regression/groupframes_r3a.lua")
local G = H.G
local write, frame, noErrors, boot, near = H.write, H.frame, H.noErrors, H.boot, H.near

local function setup(env)
	H.setup(env)
	G.Secure(env)
	env._units = { pet = { name = "Wolf", class = "HUNTER", health = 60, maxHealth = 100 }, partypet2 = { name = "Treant", class = "DRUID", health = 40, maxHealth = 100 } }
end

local function petOf(ns, unit)
	return frame(ns, unit).owner.kstylePet
end

-- Party pets beside their owners.
do
	local env, K, ns = boot({ setup = setup })
	write(env, K, "pets.enabled", true)
	local header = ns.Extras.groups.pets.header
	assert(header:GetAttribute("showParty") == true and petOf(ns, "party1") == nil, "off: party pets stay in the pet frames and nothing is made")
	write(env, K, "pets.beside", true)
	assert(header:GetAttribute("showParty") == false and header:GetAttribute("showPlayer") == false, "on: the pet frames leave party pets to their owners")
	local mine, druid, none = petOf(ns, "player"), petOf(ns, "party2"), petOf(ns, "party1")
	assert(mine:GetAttribute("unit") == "pet" and druid:GetAttribute("unit") == "partypet2" and none:GetAttribute("unit") == "partypet1", "each owner's pet unit")
	assert(mine:IsShown() and druid:IsShown() and not none:IsShown(), "shown while the pet exists")
	local f = ns.Button.Content(druid)
	assert(f.unit == "partypet2" and f.extra == "pets" and f.kind == "raid", "dressed as the pet frames are")
	local owner = frame(ns, "party2").owner
	local _, rel, _, x = druid:GetPoint(1)
	assert(rel == owner and x > owner:GetWidth(), "beside its owner, past the debuffs")
	write(env, K, "targets.enabled", true)
	local _, _, _, x2 = druid:GetPoint(1)
	assert(near(x2, x + ns.Settings.current.targets.width + K.Tokens.Size("gapSmall")), "and past the party target")
	assert(druid:GetHeight() <= ns.Settings.current.party.height + 1e-3, "never taller than the party frame")
	env.SetCombat(true)
	G.SetRoster(env, "party", { { name = "Sylaen", class = "DRUID", role = "HEALER" }, { name = "Thaldren", class = "WARRIOR", role = "TANK" } })
	assert(#env._blocked == 0, "the roster changes in combat without a protected call")
	local moved = petOf(ns, "party1")
	assert(moved:GetAttribute("unit") == "partypet1", "the pet follows its owner's new unit in combat")
	env.SetCombat(false)
	env.RunTimers()
	write(env, K, "party.selfPosition", "LAST")
	assert(ns.Headers.me.kstylePet and ns.Headers.me.kstylePet:GetAttribute("unit") == "pet", "your own button keeps your pet")
	local pv = H.preview(env, K)
	local sample = pv.extras.pets[1]
	assert(select(2, sample:GetPoint(1)) == pv.partyFrames[2] and sample:GetParent() == pv.party, "the preview's pets sit beside the party samples, on the party's canvas")
	write(env, K, "party.selfPosition", "SORTED")
	write(env, K, "pets.beside", false)
	assert(not mine:IsShown() and not druid:IsShown() and druid:GetAttribute("unit") == nil and owner:GetAttribute("refreshUnitChange") == nil, "off: every pet beside goes")
	assert(header:GetAttribute("showParty") == true, "and the pet frames take party pets again")
	pv:Refresh()
	assert(select(2, sample:GetPoint(1)) ~= pv.partyFrames[2] and sample:GetParent() == pv.extras.pets.holder, "the preview's pets return to their frames")
	noErrors(env, K)
end
collectgarbage()

-- The dispel highlight under the bar's fills.
do
	local env, K, ns = boot({ setup = setup })
	local f = frame(ns, "party1")
	local slot = f.dispelFrame
	local level = slot:GetFrameLevel()
	assert(level > f.predict:GetFrameLevel(), "off: the highlight sits over the predictions")
	write(env, K, "auras.dispelUnder", true)
	assert(slot:GetFrameLevel() == f.predict:GetFrameLevel() and f.healAbsorbs:GetFrameLevel() > slot:GetFrameLevel() and f.absorbs:GetFrameLevel() > slot:GetFrameLevel(), "on: heal absorbs and shields draw over it")
	env._aurasSecret = true
	env.SetCombat(true)
	write(env, K, "auras.dispelUnder", false)
	assert(slot:GetFrameLevel() == f.predict:GetFrameLevel(), "secret auras wait")
	env._aurasSecret = false
	env.SetCombat(false)
	env.FireEvent("PLAYER_REGEN_ENABLED")
	env.RunTimers()
	assert(slot:GetFrameLevel() == level, "off restores the level when auras are readable")
	local pv = H.preview(env, K)
	write(env, K, "auras.dispelUnder", true)
	pv:Refresh()
	local sample = pv.partyFrames[2]
	assert(sample.sampleDispel:GetFrameLevel() == sample.predict:GetFrameLevel(), "the preview follows")
	noErrors(env, K)
end
print("groupframes parity round 7 pets ok: party pets beside their owners in combat and the preview, the dispel highlight under the fills")
