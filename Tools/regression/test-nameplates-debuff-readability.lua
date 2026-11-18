-- test-nameplates-debuff-readability.lua: readable debuffs in both plate presets, engine-owned expiring colour, and the previous text appearance as an option.
local N = dofile("Tools/regression/nameplates_env.lua")
local env, K, ns = N.New()
K.Options.Write("HudStyle", "style", "medallions")
for _, preset in ipairs({ "lumen", "dungeon" }) do
	K.Options.Write("Nameplates", "preset", preset)
	assert(ns.Settings.Get("debuffs.size") == 22, "both presets keep 22-unit Medallions debuffs")
	assert(ns.Settings.Get("debuffs.textSize") >= 11 and ns.Settings.Get("debuffs.showTime"), "timers show at the number role's reading size")
end
N.Add(env, "nameplate1")
local plate = ns.Plates.Get("nameplate1")
local button = plate.auras._groups.debuffs.frames[1]
local timer = button._aura.timer
local face, size, flags = timer:GetFont()
assert(face == K.Tokens.Font("number") and size >= 11 and flags == "OUTLINE", "the remaining time uses outlined number ink")
assert(timer:GetPoint(1) == "TOP" and timer:GetJustifyH() == "CENTER", "time is centred under its icon")
local half = K.Widgets.Snap(button, ns.Settings.Get("debuffs.size")) / 2
assert(select(4, timer:GetPoint(1)) == K.Widgets.Snap(button, half) - half, "snap the timer centre when its tile has an odd pixel width")
assert(button._aura.count:GetPoint(1) == "TOPRIGHT", "stacks keep their corner")
local color = button._aura.timerOptions.textColor
assert(color and color.property == env.Enum.DurationTextBindingProperty.RemainingDuration, "the engine samples the remaining duration")
assert(color.curve.type == env.Enum.LuaCurveType.Step and #color.curve.points == 2, "expiring ink uses a two-step curve")
assert(color.curve.points[1].x == 0 and color.curve.points[2].x == 5, "the warning starts below five seconds")
local r, g, b = K.Tokens.Color("hostile")
assert(N.SameColor(color.curve.points[1].color.r, color.curve.points[1].color.g, color.curve.points[1].color.b, r, g, b), "expiring timers use hostile ink")
K.Options.Write("Nameplates", "debuffs.expiring", 0)
K.Options.Write("Nameplates", "debuffs.readableText", false)
assert(not button._aura.timerOptions.textColor, "zero turns off the expiring colour")
assert(select(1, timer:GetFont()) == ns.Settings.Get("font"), "off restores the previous text face")
K.Options.Write("Nameplates", "debuffs.showTime", false)
K.Options.Write("Nameplates", "debuffs.size", 17)
K.Options.Write("Nameplates", "debuffs.textSize", 10)
assert(button:GetWidth() == 17 and not timer:IsVisible(), "the old icon size and hidden timer remain available")
env._aurasSecret = true
K.Options.Write("Nameplates", "debuffs.expiring", 3)
assert(not button._aura.timerOptions.textColor, "secret aura buttons wait for a safe restyle")
env._aurasSecret = false
env.RunTimers()
assert(button._aura.timerOptions.textColor.curve.points[2].x == 3, "the queued binding is applied when safe")
assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
print("nameplates readable debuffs ok")
