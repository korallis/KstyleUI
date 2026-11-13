-- test-unitframes-target-bar.lua: the target's wide bar form (the KSTY-44 Orbs mock-up): one clean bar the frame's width, the name centred above it, the level diamond off its left end, the percent inside it, the creature type and values under it, one centred debuff row below, no portrait, no power and no inline cast.
local U = dofile("Tools/regression/unitframes_env.lua")

local env, K, ns = U.New()
local Settings, Geometry, Frames = ns.Settings, ns.Geometry, ns.Frames

local function near(a, b, eps)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (eps or 1e-6)
end

local function noErrors(where)
	assert(#env._errors == 0, where .. ": " .. tostring(env._errors[1]))
	assert(K.ErrorCount() == 0, where .. ": KstyleUI caught an error")
end

assert(Settings.Form("target") == "column", "Frames keeps the column target by default")
local choices = {}
for _, option in ipairs(Settings.CHOICES.styleTarget) do
	choices[option.value or option[1]] = true
end
assert(choices.bar and choices.column, "the target's style offers the wide bar beside the column")
K.Options.Write("UnitFrames", "player.style", "bar")
assert(Settings.Form("player") ~= "bar", "only the target takes the wide bar")
K.Options.Write("UnitFrames", "player.style", "column")
K.Options.Write("UnitFrames", "target.style", "bar")
assert(Settings.Form("target") == "bar", "style bar is the bar form")

local W0, H0 = 617.5, 120
local g = Geometry.Frame(Settings.Snapshot("target"), W0, H0, 1)
local B = Geometry.BAR
assert(g.form == "bar" and not g.portrait and not g.power and not g.cast and g.chrome == false, "no portrait, power, cast or glass")
assert(near(g.health.x, 0) and near(g.health.w, W0) and near(g.health.h, B.health), "one bar the frame's width, the mock-up's 18 px tall")
assert(g.name and near(g.name.x, 0) and near(g.name.w, W0) and g.name.y + g.name.h <= g.health.y, "the name spans the frame above the bar")
assert(near(g.healthText.y, g.health.y) and near(g.healthText.h, g.health.h) and near(g.healthText.w, W0), "the percent sits inside the bar")
assert(g.caption.y >= g.health.y + g.health.h and near(g.caption.x, 0), "the creature type sits under the bar's left end")
assert(near(g.healthSub.x + g.healthSub.w, W0) and near(g.healthSub.y, g.caption.y), "the values sit under its right end, on the same line")
local bcx, bcy = g.badge.x + g.badge.w / 2, g.badge.y + g.badge.h / 2
assert(g.badge.x + g.badge.w <= 0 and near(bcy, g.health.y + g.health.h / 2), "the level diamond hangs off the bar's left end, centred on it")
assert(near(bcx, -B.discOut), "at the mock-up's 26 px from the end")
assert(g.aura and g.aura.centred and near(g.aura.x, W0 / 2) and g.aura.y > g.health.y + g.health.h, "one debuff row, centred under the bar")
local left, right = Geometry.Reach(Settings.Snapshot("target"))
assert(near(left, B.discOut + B.disc / 2) and right == 0, "the diamond's reach is reported on the left")

U.SetUnit(env, "target", { name = "Galestrider", level = 6, health = 1206, healthMax = 1698, reaction = 2, canAttack = true, creature = "Beast", power = 10, powerMax = 100 })
env.SetTarget(true)
local view = Frames.Get("target").views[1]
assert(view.form == "bar", "the live target is the bar form")
assert(view.health.unitBar and view.health:IsShown(), "its bar is the clean unit bar")
assert(not view.power:IsShown() and not view.portraitFrame:IsShown(), "no power bar and no portrait show")
assert(view.disc:IsShown() and U.Shown(env, view.levelText) == "6", "the level shows in the diamond")
assert(U.Shown(env, view.name) == "GALESTRIDER" and view.name:GetJustifyH() == "CENTER", "the name is centred: " .. U.Shown(env, view.name))
assert(U.Shown(env, view.healthText):find("71", 1, true) and view.healthText:GetJustifyH() == "CENTER", "the percent reads inside the bar: " .. U.Shown(env, view.healthText))
assert(U.Shown(env, view.caption) == "Beast" and view.caption:GetJustifyH() == "LEFT", "the creature type: " .. U.Shown(env, view.caption))
local values = U.Shown(env, view.healthSub)
assert(values:find("1", 1, true) and values:find("/", 1, true) and view.healthSub:GetJustifyH() == "RIGHT", "current and max under the right end: " .. values)
assert(ns.CastBars.ElementLive("target"), "the target's cast moves to its own element")
local host = view.auras and view.auras.host
if host then
	local point, rel, relPoint = host:GetPoint(1)
	assert(point == "TOP" and rel == view.button and relPoint == "TOPLEFT", "the debuff row hangs centred under the bar")
end
noErrors("bar form")

K.Options.Write("UnitFrames", "target.style", "column")
assert(Frames.Get("target").views[1].form == "column" and view.portraitFrame:IsShown(), "back to the column, the portrait returns")
noErrors("back to column")
print("unitframes target bar ok")
