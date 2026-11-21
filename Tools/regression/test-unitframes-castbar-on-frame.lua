-- test-unitframes-castbar-on-frame.lua: Medallions hangs the player and target cast bars under their frames; the setting off, a moved bar or Frames and Orbs keep the bars above the crest.
local U = dofile("Tools/regression/unitframes_env.lua")
local W = U.W

local function new(layout)
	return U.New({
		saved = { version = 2, characters = {}, layouts = { Default = layout or {} },
			profiles = { Default = { UnitFrames = { enabled = true }, HudStyle = { style = "medallions" } } } },
		setup = function(e)
			e.GetNetStats = function() return 0, 0, 20, 200 end
			e._gcd = {}
			e.C_Spell.GetSpellCooldown = function(id) return { startTime = 10, duration = 1.5, isEnabled = true, isActive = true, isOnGCD = e._gcd[id] } end
			e.C_Spell.GetSpellCooldownDuration = function(id) return { spell = id, GetRemainingDuration = function() return 1.2 end } end
			e.C_Spell.IsSpellImportant = function() return true end
		end,
	})
end

local function near(a, b, eps)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (eps or 0.6)
end

local env, K, ns = new()
local CastBars, Settings = ns.CastBars, ns.Settings
local function clean(where)
	assert(#env._errors == 0 and K.ErrorCount() == 0, where .. ": " .. tostring(env._errors[1]))
end
local function write(key, value)
	K.Options.Write("UnitFrames", key, value)
	env.RunTimers()
end

assert(Settings.Module().castbarOnFrame == true, "Cast bars on unit frames starts on")
U.SetUnit(env, "target", { name = "Wolf", level = 10, health = 50, healthMax = 100, reaction = 2, canAttack = true,
	cast = { name = "Howl", texture = 135808, start = 1000, finish = 3800, spellID = 999 } })
env.SetTarget(true)
env._time = 2.2
env._units.player.cast = { name = "Lightning Bolt", texture = 136048, start = 1000, finish = 3500, spellID = 188196 }
env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-1", 188196)
W.Tick(env, 0.1)

for _, kind in ipairs({ "player", "target" }) do
	local view = ns.Frames.Get(kind).views[1]
	local g, cb = view.geometry, CastBars.Inline(kind)[1]
	assert(not CastBars.ElementLive(kind) and not K.Layout.Live("unitframes.castbar." .. kind), kind .. ": the bar above the crest gives way, and Layout Mode drops its mover")
	assert(not CastBars.Get(kind)[1].frame:IsShown(), kind .. ": nothing is left in the lane above the crest")
	assert(view.s.inlineCast == true, kind .. ": the frame carries the cast")
	assert(cb.frame:IsShown() and cb.active and cb.medal and cb.geometry.medal, kind .. ": the frame's own bar shows the cast in the Medallions look")
	assert(cb.slab and cb.slab[5]:IsShown() and not cb.iconFrame:IsShown(), kind .. ": the unit slab material, no spell icon, like the bars it replaces")
	local fw, fh = cb.frame:GetSize()
	assert(near(fw, g.health.w) and near(fh, 20), kind .. ": the bar's frame is the health bar's width, got " .. tostring(fw))
	assert(near(view.button:GetBottom() - cb.frame:GetTop(), K.Widgets.Snap(cb.frame, 2)) and near(cb.frame:GetLeft() - view.button:GetLeft(), g.health.x), kind .. ": the bar hangs under the frame, below its health bar")
end
local pcb, tcb = CastBars.Inline("player")[1], CastBars.Inline("target")[1]
assert(U.Shown(env, pcb.text) == "LIGHTNING BOLT" and U.Shown(env, tcb.text) == "HOWL", "both spell names show")
assert(pcb.bar.fillCursor and pcb.bar.fillCursor:IsShown(), "the spark rides the fill")
local ar, ag, ab = K.Theme.Accent()
local fill = W.LastCall(pcb.bar, "SetStatusBarColor")
assert(near(fill[1], ar, 1e-6) and near(fill[2], ag, 1e-6) and near(fill[3], ab, 1e-6), "the player's cast fills in the class accent")
clean("on frames")

write("player.castbarLatency", true)
env._units.player.cast = { name = "Frostbolt", texture = 135846, start = 1000, finish = 3000, spellID = 116 }
env.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-2", 116)
assert(pcb.latency and pcb.latency:IsShown(), "the latency zone still shows")
env._units.player.cast = nil
env.FireEvent("UNIT_SPELLCAST_INTERRUPTED", "player", "Cast-2", 116)
local hr, hg, hb = K.Tokens.Color("hostile")
local stopped = W.LastCall(pcb.bar, "SetStatusBarColor")
assert(near(stopped[1], hr, 1e-6) and near(stopped[2], hg, 1e-6) and near(stopped[3], hb, 1e-6) and pcb.frame:IsShown(), "an interrupt holds the hostile bar")
env.RunTimers()
W.Tick(env, 0.5)
env._units.player.channel = { name = "Arcane Missiles", texture = 136096, start = 4000, finish = 7000, spellID = 5143 }
env.FireEvent("UNIT_SPELLCAST_CHANNEL_START", "player", "Cast-3", 5143)
assert(pcb.active and pcb.channel and pcb.frame:IsShown(), "a channel runs on the frame's bar")
env._units.player.channel = nil
env.FireEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player", "Cast-3", 5143)
env.RunTimers()
W.Tick(env, 0.5)
write("player.castbarGcd", true)
env._gcd = { [116] = true }
env.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-4", 116)
env.FireEvent("SPELL_UPDATE_COOLDOWN")
assert(pcb.gcd and pcb.frame:IsShown(), "the global cooldown fills the frame's bar")
env.RunTimers()
write("target.castbarImportant", true)
env.FireEvent("UNIT_SPELLCAST_START", "target", "Cast-5", 999)
assert(tcb.important and tcb.important:IsShown(), "an important target cast shows its outline")
clean("cast behaviours")

write("castbarOnFrame", false)
W.Tick(env, 0.1)
for _, kind in ipairs({ "player", "target" }) do
	local view = ns.Frames.Get(kind).views[1]
	assert(CastBars.ElementLive(kind) and K.Layout.Live("unitframes.castbar." .. kind), kind .. ": off gives the bar above the crest back")
	assert(not view.s.inlineCast and not CastBars.Inline(kind)[1].frame:IsShown(), kind .. ": and the frame carries no bar")
end
assert(CastBars.Get("target")[1].frame:IsShown(), "the target's cast shows above the crest again")
write("castbarOnFrame", true)
assert(not CastBars.ElementLive("player") and ns.Frames.Get("player").views[1].s.inlineCast, "on again puts it back on the frame")
clean("toggle")

K.Options.Write("HudStyle", "style", "frames")
W.Tick(env, 0.1)
assert(CastBars.ElementLive("player") and not CastBars.ElementLive("target") and Settings.Snapshot("player").inlineCast == false, "Frames keeps its own placement")
K.Options.Write("HudStyle", "style", "orbs")
assert(CastBars.ElementLive("player") and CastBars.ElementLive("target"), "Orbs keeps its own placement")
clean("styles")

local moved = { anchor = "BOTTOM", x = 40, y = 600 }
local env2, K2, ns2 = new({ ["medallions:unitframes.castbar.player"] = moved })
local holder = ns2.CastBars.Holder("player")
local place = K2.Layout.Get("unitframes.castbar.player")
assert(ns2.CastBars.ElementLive("player") and place.x == 40 and place.y == 600, "a player who moved the cast bar keeps it where they put it")
assert(holder:IsShown() and not ns2.Frames.Get("player").views[1].s.inlineCast, "and the player frame stays as it was")
assert(not ns2.CastBars.ElementLive("target") and ns2.Frames.Get("target").views[1].s.inlineCast, "the unmoved target bar still goes on its frame")
K2.Layout.Reset("unitframes.castbar.player")
env2.RunTimers()
assert(not ns2.CastBars.ElementLive("player") and ns2.Frames.Get("player").views[1].s.inlineCast, "resetting the moved bar puts it on the frame")
assert(#env2._errors == 0 and K2.ErrorCount() == 0, "saved positions: " .. tostring(env2._errors[1]))
print("unitframes castbar on frame ok")
