-- test-unitframes-target-orbs.lua: under the Orbs HUD style the target takes the wide bar form at top centre, sized from the Orbs table; a size saved under Orbs stays with Orbs; Frames keeps its column; a target the player set to plate stays a plate.
local U = dofile("Tools/regression/unitframes_env.lua")

local function near(a, b)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 0.01
end

local env, K, ns = U.New()
local Settings, Frames, Layout, Layouts = ns.Settings, ns.Frames, K.Layout, K.Setup.Layouts
local KEY = "unitframes.target"

local function noErrors(where)
	assert(#env._errors == 0, where .. ": " .. tostring(env._errors[1]))
	assert(K.ErrorCount() == 0, where .. ": KstyleUI caught an error")
end

U.SetUnit(env, "target", { name = "Galestrider", level = 6, health = 1206, healthMax = 1698, reaction = 2, canAttack = true, creature = "Beast", power = 10, powerMax = 100 })
env.SetTarget(true)
local view = Frames.Get("target").views[1]
local frames = Layout.Get(KEY)
assert(Settings.Form("target") == "column" and view.form == "column", "Frames keeps the column target")

K.Options.Write("HudStyle", "style", "orbs")
local orbs = Layouts.Style("orbs", "DPS", KEY)
assert(orbs.width and orbs.height, "the Orbs table sizes the target")
assert(Settings.Form("target") == "bar" and view.form == "bar", "under Orbs the target is the wide bar: " .. tostring(Settings.Form("target")) .. " " .. tostring(view.form) .. " " .. tostring(Settings.Value("target", "style")) .. " " .. K.HudStyle.Current())
local s = Layout.Get(KEY)
assert(s.anchor == "TOP" and near(s.x, 0) and near(s.y, orbs.y), "at top centre")
assert(near(s.width, orbs.width) and near(s.height, orbs.height), "at the Orbs table's size: " .. s.width .. " x " .. s.height)
assert(not view.portraitFrame:IsShown(), "no portrait")
assert(view.geometry and view.geometry.form == "bar" and not view.geometry.power, "the bar form lays out no power bar")
noErrors("Orbs")

assert(Layout.Set(KEY, "width", orbs.width - 60), "a narrower bar saves under Orbs")
local saved = env.KstyleUIDB.layouts.Default
assert(near(saved["orbs:" .. KEY].width, orbs.width - 60), "the size is stored under orbs:")
assert(saved[KEY] == nil or saved[KEY].width == nil, "the Frames size is untouched")

K.Options.Write("HudStyle", "style", "frames")
local back = Layout.Get(KEY)
assert(Settings.Form("target") == "column" and view.form == "column", "Frames gets its column back")
assert(near(back.width, frames.width) and near(back.height, frames.height) and back.anchor == frames.anchor, "at its Frames place and size")

local PET = "unitframes.pet"
assert(Layout.Set(PET, "width", 180), "a pet frame width saved under Frames")
K.Options.Write("HudStyle", "style", "orbs")
assert(near(Layout.Get(KEY).width, orbs.width - 60), "the Orbs size returns with Orbs")
assert(Layouts.Style("orbs", "DPS", PET) and Layouts.Style("orbs", "DPS", PET).width == nil, "Orbs places the pet frame but does not size it")
assert(near(Layout.Get(PET).width, 180), "a size the Orbs table does not set is shared with Frames")

K.Options.Write("UnitFrames", "target.style", "plate")
assert(Settings.Form("target") == "plate" and view.form ~= "bar", "a target set to plate stays a plate under Orbs")
noErrors("switches")
print("ok target orbs")
