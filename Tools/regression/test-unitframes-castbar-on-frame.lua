-- test-unitframes-castbar-on-frame.lua: Medallions hangs the player and target cast bars under their frames; the setting off, or a moved or hidden bar keeps the bars above the crest.
local U = dofile("Tools/regression/unitframes_env.lua")
local W = U.W

local function new(layout)
	return U.New({
		saved = { version = 2, characters = {}, layouts = { Default = layout or {} },
			profiles = { Default = { UnitFrames = { enabled = true } } } },
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
	local cb = CastBars.Inline(kind)[1]
	assert(not CastBars.ElementLive(kind) and not K.Layout.Live("unitframes.castbar." .. kind), kind .. ": the bar above the crest gives way, and Layout Mode drops its mover")
	assert(not CastBars.Get(kind)[1].frame:IsShown(), kind .. ": nothing is left in the lane above the crest")
	assert(view.s.inlineCast == true, kind .. ": the frame carries the cast")
	assert(cb.frame:IsShown() and cb.active and cb.geometry.medal, kind .. ": the frame's own bar shows the cast in the Medallions look")
	assert(cb.slab and cb.slab[5]:IsShown(), kind .. ": the unit slab material")
	assert(cb.iconFrame:IsShown() == Settings.Value(kind, "castbarIcon"), kind .. ": Spell icon decides the icon (player on, target off by default)")
	local fw, fh = cb.frame:GetSize()
	assert(near(fw, view.button:GetWidth()) and near(fh, 20), kind .. ": the bar's frame is the frame's width, like the focus and boss bars, got " .. tostring(fw))
	assert(near(view.button:GetBottom() - cb.frame:GetTop(), K.Widgets.Snap(cb.frame, 2)) and near(cb.frame:GetLeft(), view.button:GetLeft()), kind .. ": the bar hangs under the frame, flush with its slab")
end
write("target.castbarIcon", true)
for _, kind in ipairs({ "player", "target" }) do
	local view, cb = ns.Frames.Get(kind).views[1], CastBars.Inline(kind)[1]
	local medal, left = view.geometry.medal, view.button:GetLeft()
	assert(cb.iconFrame:IsShown() and (cb.iconFrame:GetLeft() >= left + medal.x + medal.w or cb.iconFrame:GetRight() <= left + medal.x), kind .. ": Spell icon on shows the icon clear of the medallion")
	assert(cb.iconFrame:GetBottom() >= cb.frame:GetBottom() and cb.iconFrame:GetTop() <= cb.frame:GetTop(), kind .. ": the icon sits inside the bar's slab")
end
write("player.castbarIcon", false)
assert(not CastBars.Inline("player")[1].iconFrame:IsShown(), "Spell icon off hides it")
write("player.castbarIcon", true)
write("target.castbarIcon", false)
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

local env3, K3, ns3 = new()
local inl, sep = ns3.CastBars.Inline("player")[1], ns3.CastBars.Get("player")[1]
local function cast(id)
	env3._units.player.cast = { name = "Frostbolt", texture = 135846, start = 1000, finish = 100000, spellID = 116 }
	env3.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-" .. id, 116)
end
local function shows(where, onFrame, above)
	assert(inl.frame:IsVisible() == onFrame and sep.frame:IsVisible() == above, where .. ": on the frame " .. tostring(inl.frame:IsVisible()) .. ", above the crest " .. tostring(sep.frame:IsVisible()))
end
cast(1)
shows("a cast", true, false)
local function interruptible() inl.handler("UNIT_SPELLCAST_INTERRUPTIBLE", "player") end
interruptible()
dofile("Tools/regression/instruction_budget.lua")(interruptible, 420, "a cast event costs no more than staging's 414: it reads the placement CastBars.Apply chose; resolve the layout only when switching listeners")
K3.Options.Write("UnitFrames", "castbarOnFrame", false)
cast(2)
shows("off", false, true)
env3.SetCombat(true)
K3.Options.Write("UnitFrames", "castbarOnFrame", true)
cast(3)
shows("turned on in combat, the bar above the crest keeps the cast until combat ends", false, true)
env3.SetCombat(false)
env3.RunTimers()
cast(4)
shows("after combat", true, false)
assert(K3.Layout.Set("unitframes.castbar.player", "shown", "never"))
env3.RunTimers()
cast(5)
shows("a cast bar the player set to Never stays hidden", false, false)
assert(K3.Layout.Get("unitframes.castbar.player").shown == "never" and ns3.CastBars.ElementLive("player"), "and keeps its own element and rule")
assert(K3.Layout.Set("unitframes.castbar.player", "shown", "always"))
env3.RunTimers()
cast(6)
shows("Always again", true, false)
K3.Options.Write("UnitFrames", "player.style", "plate")
env3.RunTimers()
cast(7)
shows("Plate under Medallions", true, false)
local plate = ns3.Frames.Get("player").views[1]
local button, panel = plate.button, plate.geometry.panel
assert(near(button:GetBottom() - inl.frame:GetTop(), K3.Widgets.Snap(inl.frame, 2)) and near(inl.frame:GetLeft() - button:GetLeft(), panel.x) and near(inl.frame:GetWidth(), panel.w), "the Plate frame carries its cast under its plate, at the plate's width")
assert(#env3._errors == 0 and K3.ErrorCount() == 0, "combat, rule and Plate: " .. tostring(env3._errors[1]))
print("unitframes castbar on frame ok")
