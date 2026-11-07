-- test-meters-module.lua: KstyleUI_Meters registers off, builds nothing until Enable, places its three elements, declares every setting and cleans up on Disable.
local M = dofile("Tools/regression/meters_env.lua")
local CoreEnv = M.CoreEnv

local env, K, ns = M.New()

-- Off in code, free while off.
local listed = false
for _, name in ipairs(K.Modules.List()) do
	listed = listed or name == "Meters"
end
assert(listed, "the module registers as Meters")
assert(K.Modules.IsEnabled("Meters") == false, "the module is off by default")
assert(#env._frames == env._moduleFrames, "the module made no frames at load")
assert(ns.Swing.holder == nil and ns.Threat.holder == nil and ns.Damage.holder == nil, "no element is built before Enable")

-- Defaults and the settings schema.
local settings = K.Store.Module("Meters")
assert(settings.damage.mode == "window", "the damage meter is KstyleUI's own window by default")
assert(settings.damage.meter == "DamageDone", "the damage meter shows damage done by default")
assert(settings.threat.warnAt == 80 and settings.threat.dangerAt == 95, "threat warns at 80% and 95%")
assert(settings.swing.mainHand and settings.swing.offHand and settings.swing.ranged, "every swing bar is on")
assert(type(settings.damage.color) == "table" and type(settings.damage.color.r) == "number", "colours are r, g, b tables")

local schema = K.Options.Get("Meters")
assert(type(schema) == "table", "the module declares a settings schema")
assert(type(K.Options.Preview("Meters")) == "function", "the schema carries a live preview builder")
local keys = {}
for _, row in ipairs(schema) do
	if row.key then
		keys[row.key] = row
	end
end
for _, section in ipairs({ "damage", "threat" }) do
	for _, field in ipairs({ "shown", "font", "fontSize", "outline", "texture", "colorSource", "color", "fill", "titleSize", "rowHeight", "spacing" }) do
		assert(keys[section .. "." .. field], "the schema has a row for " .. section .. "." .. field)
	end
end
for _, field in ipairs({ "shown", "mainHand", "offHand", "ranged", "font", "fontSize", "outline", "texture", "colorSource", "color", "orientation", "reverse" }) do
	assert(keys["swing." .. field], "the schema has a row for swing." .. field)
end
for _, key in ipairs({ "accent", "accentColor", "threat.warnings", "threat.warnAt", "threat.dangerAt", "damage.mode" }) do
	assert(keys[key], "the schema has a row for " .. key)
end
local sources = {}
for _, option in ipairs(keys["damage.colorSource"].options) do
	sources[option.value] = true
end
assert(sources.class and sources.reaction and sources.custom, "bars colour by class, reaction or a custom colour")
assert(keys["damage.color"].showWhen({ damage = { colorSource = "custom" } }) == true, "the custom colour shows for a custom source")
assert(keys["damage.color"].showWhen({ damage = { colorSource = "class" } }) == false, "the custom colour hides otherwise")
assert(keys["accentColor"].showWhen({ accent = "custom" }) == true, "the custom accent shows for a custom accent")
local fonts = keys["damage.font"].options()
assert(fonts[1].value == "", "the first font is the interface font")
assert(#fonts >= 2, "the font list holds KstyleUI's fonts")

-- The defaults follow the design file: 14-unit rows five units apart, five rows in the damage meter's footprint.
assert(ns.defaults.damage.rowHeight == 14 and ns.defaults.threat.rowHeight == 14, "rows are 14 units")
assert(ns.defaults.damage.spacing == 5 and ns.defaults.threat.spacing == 5, "rows sit 5 units apart")
assert(ns.Logic.FitRows(130 - 8 - 9 - 8 - 8, 14, 5) == 5, "the damage footprint fits five rows under its title")
assert(ns.Logic.FitRows(104 - 8 - 9 - 8 - 8, 14, 5) == 4, "the threat footprint fits four rows under its title")

-- Enable builds and places the three elements.
M.Enable(env, K)
assert(K.Modules.IsRunning("Meters"), "the module runs")
for _, key in ipairs({ "meters.damage", "meters.threat", "meters.swing" }) do
	local found
	for _, element in ipairs(K.Layout.Elements()) do
		if element.key == key then
			found = element
		end
	end
	assert(found, key .. " registers with Layout")
	assert(found.module == "Meters", key .. " belongs to the module")
	assert(found.label == K.Setup.Layouts.Element(key).label, key .. " uses the setup's label")
	assert(found.opts.resizable == true, key .. " is resizable")
	local placed = K.Layout.Get(key)
	local default = K.Setup.Layouts.Default(key)
	assert(placed.anchor == default.anchor and placed.x == default.x and placed.y == default.y, key .. " starts at the DPS layout's position")
	local element = K.Setup.Layouts.Element(key)
	assert(placed.width <= element.width and placed.height <= element.height, key .. " fits its footprint")
end
assert(ns.Damage.holder:IsShown(), "the damage meter shows")
assert(ns.Threat.holder:IsShown(), "the threat meter holder shows")

-- A meter switched off hides its element; switching it on shows it again.
M.Write(env, K, "threat.shown", false)
assert(not ns.Threat.holder:IsShown(), "the threat meter hides when switched off")
assert(not K.Layout.Live("meters.threat"), "and has no mover in Layout Mode")
M.Write(env, K, "threat.shown", true)
assert(ns.Threat.holder:IsShown(), "the threat meter shows again")
assert(K.Layout.Live("meters.threat"), "and its mover comes back")
M.Write(env, K, "swing.shown", false)
assert(not K.Layout.Live("meters.swing"), "a swing timer switched off has no mover")
M.Write(env, K, "swing.shown", true)
assert(K.Layout.Live("meters.swing"), "until it is switched on")

-- A meter switched off stays hidden when Layout's shown rule brings its holder back.
K.Layout.Set("meters.threat", "shown", "combat")
K.Layout.Set("meters.damage", "shown", "combat")
env.RunTimers()
M.Write(env, K, "threat.shown", false)
M.Write(env, K, "damage.mode", "skin")
env.SetCombat(true)
env.RunTimers()
assert(not ns.Threat.list.panel:IsShown(), "a switched-off threat meter stays hidden in combat")
assert(not ns.Damage.list.panel:IsShown(), "the damage window stays hidden in combat while Blizzard's is restyled")
env.SetCombat(false)
env.RunTimers()
M.Write(env, K, "threat.shown", true)
M.Write(env, K, "damage.mode", "window")
K.Layout.Set("meters.threat", "shown", nil)
K.Layout.Set("meters.damage", "shown", nil)
env.RunTimers()
assert(ns.Damage.list.panel:IsShown(), "the damage window shows again")

-- Disable hides every element and leaves no OnUpdate running.
M.Disable(env, K)
assert(not K.Modules.IsRunning("Meters"), "the module stopped")
for _, part in ipairs({ ns.Damage, ns.Threat, ns.Swing }) do
	assert(not part.holder:IsShown(), "Disable hides the element")
end
M.W.Settle(env)
for _, frame in ipairs(env._frames) do
	if frame._scripts.OnUpdate then
		error("an OnUpdate still runs after Disable")
	end
end

-- Enable again reuses the frames it built.
local frames = #env._frames
M.Enable(env, K)
assert(#env._frames == frames, "a second Enable builds nothing new")
assert(ns.Damage.holder:IsShown(), "the damage meter shows again")
assert(CoreEnv.Count(env._errors, nil) == 0 and #env._errors == 0, "no Lua error: " .. tostring(env._errors[1]))

print("meters module ok")
