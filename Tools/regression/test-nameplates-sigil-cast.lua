-- test-nameplates-sigil-cast.lua: one target, one cast: while the target sigil shows the target's cast, that unit's plate hides its own cast bar and keeps its name and health; other plates keep theirs, and a setting brings the plate's cast back.
local N = dofile("Tools/regression/nameplates_env.lua")

local env, K, ns = N.New()

-- A stand-in for KstyleUI_UnitFrames: the plates read the sigil's settings through KstyleUI.Options alone.
local running = false
K.Modules.Register({
	name = "UnitFrames",
	defaults = { target = { enabled = true, castbar = true } },
	Enable = function()
		running = true
	end,
	Disable = function()
		running = false
	end,
})
K.Options.Register("UnitFrames", {
	{ type = "toggle", key = "target.enabled", label = "Target", help = "Shows the target sigil." },
	{ type = "toggle", key = "target.castbar", label = "Cast bar", help = "Shows the target's cast on the sigil." },
})

N.Add(env, "nameplate1", { name = "Bloodtalon Matriarch" })
N.Add(env, "nameplate2", { name = "Mirefin Oracle" })
local boss, add = ns.Plates.Get("nameplate1"), ns.Plates.Get("nameplate2")
N.Cast(env, "nameplate1", { name = "Terrifying Screech", text = "Terrifying Screech", texture = 136124, notInterruptible = false })
N.Cast(env, "nameplate2", { name = "Mirefin Hex", text = "Mirefin Hex", texture = 136071, notInterruptible = false })
N.Target(env, "nameplate1")

local function showsCast(plate)
	return plate.cast:IsVisible()
end

assert(not running and showsCast(boss) and showsCast(add), "without the unit frames every plate shows its cast")

K.Modules.Enable("UnitFrames")
assert(running, "the stand-in runs")
assert(not showsCast(boss), "the sigil shows the target's cast, so the target's plate does not repeat it")
assert(boss.health:IsVisible() and boss.name:IsVisible(), "the target's plate keeps its name and health")
assert(boss.casting, "the cast still runs underneath, so it shows the moment the sigil stops showing it")
assert(showsCast(add), "another plate keeps its cast")

N.Target(env, "nameplate2")
assert(showsCast(boss) and not showsCast(add), "the dedup follows the target")
N.Target(env, "nameplate1")

K.Options.Write("UnitFrames", "target.castbar", false)
assert(showsCast(boss), "a sigil without a cast bar leaves the plate's cast")
K.Options.Write("UnitFrames", "target.castbar", true)
assert(not showsCast(boss), "and it hides again with the sigil's cast bar")

assert(ns.Settings.Get("cast.hideOnTarget") == true, "on by default")
assert(ns.Settings.Row("cast.hideOnTarget").type == "toggle", "a toggle on the plates' page")
K.Options.Write("Nameplates", "cast.hideOnTarget", false)
assert(showsCast(boss), "off: the target's plate shows its cast too")
K.Options.Write("Nameplates", "cast.hideOnTarget", true)
assert(not showsCast(boss), "on again")

K.Modules.Disable("UnitFrames")
assert(showsCast(boss), "with the unit frames off the plate shows the cast again")

assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
print("nameplates sigil cast ok")
