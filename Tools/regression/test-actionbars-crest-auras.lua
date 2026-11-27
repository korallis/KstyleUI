-- test-actionbars-crest-auras.lua: the crest's marks as looping spell-light auras (KstyleUI_ActionBars/SlabMedals.lua Medals.Mark, the KSTY-51 plan): a lit mark draws its aura sheet over the empty socket, and the sheet's FlipBook loops only at Full with the crest awake; Calm, Off and the resting crest hold its still cell; while auras are secret nothing touches the aura, and the motion chosen then shows once the restriction ends.
local R = dofile("Tools/regression/ranged_env.lua")
local Slots, New, Piece, Clean, Aura = R.Slots, R.New, R.Piece, R.Clean, R.Aura

local env, K, ns = New("HUNTER")
env.SetTarget(true)
Slots.Set(env, "player", { { id = 14318, icon = 136076, start = 0 } })
local fire = Piece(ns, "crestAspect").lits[1].art
assert(Aura(fire, "Glyphs\\Hawk") and Aura(fire.still, "Glyphs\\Hawk"), "the hawk's fire and still mark both draw its aura sheet")
local left, right, top, bottom = fire.still:GetTexCoord()
assert(left == 0 and right == 0.25 and top == 0 and bottom == 0.25, "the still mark shows the sheet's first cell")

local function Burning()
	return fire:GetAlpha() == 1 and fire.still:GetAlpha() == 0 and fire.loop:IsPlaying()
end
local function Still()
	return fire:GetAlpha() == 0 and fire.still:GetAlpha() == 1 and not fire.loop:IsPlaying()
end
local function Motion(level)
	K.Options.Write("Medallions", "motion", level)
	env.RunTimers()
end

assert(Burning(), "at Full with the crest awake the aura loops")
Motion("calm")
assert(Still(), "Calm holds the still mark")
Motion("off")
assert(Still(), "Off holds the still mark")
Motion("full")
assert(Burning(), "back at Full the loop plays again")
env.SetTarget(false)
env.RunTimers()
assert(ns.Slab.Resting() and Still(), "the resting crest holds the still mark")
env.SetTarget(true)
env.RunTimers()
assert(Burning(), "a target wakes the crest and its aura loops")

env._aurasSecret = true
env.SetCombat(true)
Motion("calm")
env.FireEvent("UNIT_AURA", "player")
-- The stub forbids every region under an engine aura button while auras are secret, so any touch is an error here.
Clean(env, K)
env._aurasSecret = false
env.FireEvent("ADDON_RESTRICTION_STATE_CHANGED", 1, 0)
assert(Still(), "Calm, chosen while auras were secret, holds the still mark once the restriction ends")
Motion("full")
assert(Burning(), "and Full loops it again")
env.SetCombat(false)
Clean(env, K)

print("actionbars crest auras ok")
