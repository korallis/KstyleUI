-- test-cooldowns-slot.lua: the cooldown rows are the shared action slot: an opaque well, the sweep's lit edge and a centred number, and the slot's gilt ready flash when a cooldown the game classified as real ends, never when only the global cooldown does, nor when a row reuses a slot.
local C = dofile("Tools/regression/cooldowns_env.lua")
local W = C.W

local env, K, ns = C.New({ setup = function(e)
	C.Game(e)
	e._cdm.cooldown[1001] = { active = true, gcd = false }
end })
C.Enable(env, K)
local row = ns.Mirror.Row("essential")
local icon = row.icons[1]
assert(icon.well and icon.lumenGlow and icon.press, "a cooldown icon is a slot")
assert(W.LastCall(icon.cooldown, "SetDrawEdge")[1] == true, "its sweep draws the lit edge")
local fr, fg, fb = K.Tokens.Color("slotFill")
assert(W.SameColor(icon.chrome.fill[5], fr, fg, fb, 1), "its body is opaque")
assert(icon.onCooldown == true and not icon.readyFlash:IsPlaying(), "a spell assumed cooling does not flash")
env.FireEvent("SPELL_UPDATE_COOLDOWN")
assert(icon.onCooldown == true and not icon.readyFlash:IsPlaying(), "the cooldown event confirms a real cooldown")
env._cdm.cooldown[1001] = { active = false }
env.FireEvent("SPELL_UPDATE_COOLDOWN")
assert(icon.onCooldown == false and icon.readyFlash:IsPlaying() and icon.readyWash:IsShown(), "the end of a real cooldown flashes the slot gilt")
icon.readyFlash:Stop()
env._cdm.cooldown[1001] = { active = true, gcd = true }
env.FireEvent("SPELL_UPDATE_COOLDOWN")
env._cdm.cooldown[1001] = { active = false }
env.FireEvent("SPELL_UPDATE_COOLDOWN")
assert(not icon.readyFlash:IsPlaying(), "the global cooldown alone never flashes")
assert(#env._errors == 0, tostring(env._errors[1]))

-- A load or rebuild during the global cooldown assumes the spell is cooling; the next cooldown event that calls it the
-- global cooldown ends that assumption without a flash.
do
	local genv, GK, gns = C.New({ setup = function(e)
		C.Game(e)
		e._cdm.cooldown[1001] = { active = true, gcd = true }
	end })
	C.Enable(genv, GK)
	local first = gns.Mirror.Row("essential").icons[1]
	assert(first.onCooldown == true, "the first refresh cannot trust isOnGCD")
	genv.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(first.onCooldown == false and not first.readyFlash:IsPlaying(), "the global cooldown found by the event does not flash")
	assert(#genv._errors == 0, tostring(genv._errors[1]))
end

-- A hidden slot forgets its cooldown, so the row reusing it for a ready spell does not flash.
do
	row:SetCount(0)
	assert(icon.onCooldown == nil and icon.coolingTrusted == false, "a hidden slot drops its cooldown state")
	icon.readyFlash:Stop()
	env._cdm.cooldown[1001] = { active = false }
	env.FireEvent("SPELL_UPDATE_COOLDOWN")
	assert(not icon.readyFlash:IsPlaying(), "the reused slot does not flash")
end
print("cooldowns slot ok")
