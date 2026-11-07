-- test-meters-preview.lua: the Meters page's live preview draws sample meters with the current settings, and the settings window opens on the Meters page.
local O = dofile("Tools/regression/options_env.lua")
local M = dofile("Tools/regression/meters_env.lua")
local Load = dofile("Tools/regression/load_files.lua")

local env, K = O.New({
	setup = function(env)
		M.Game(env)
	end,
	before = function(env)
		Load(M.Files(), env)
	end,
})
local ns = env._addons.KstyleUI_Meters

local function Text(fontString)
	local args = M.Last(fontString, "SetText")
	return args and args[1]
end

local build = K.Options.Preview("Meters")
assert(type(build) == "function", "the Meters schema carries a preview builder")
local parent = env.CreateFrame("Frame", nil, env.UIParent)
parent:SetSize(420, 220)
local frame = build(parent)
assert(type(frame.Refresh) == "function", "the preview refreshes after a setting changes")
assert(frame.damage.count > 0, "the preview shows sample damage rows")
assert(frame.threat.count > 0, "the preview shows sample threat rows")
assert(Text(frame.damage.title) == "DAMAGE DONE", "the sample damage meter is titled")
assert(frame.threat.warning == 1, "the sample player at 88% shows the warning")

-- Settings show in the preview.
K.Options.Write("Meters", "damage.colorSource", "custom")
frame:Refresh()
local custom = ns.Get("damage.color")
local colour = M.Last(frame.damage.rows[1].bar, "SetStatusBarColor")
assert(colour[1] == custom.r and colour[2] == custom.g and colour[3] == custom.b, "a custom bar colour shows")
K.Options.Write("Meters", "threat.warnAt", 90)
frame:Refresh()
assert(frame.threat.warning == 0, "a higher warning threshold clears the sample warning")
K.Options.Write("Meters", "threat.warnings", false)
K.Options.Write("Meters", "threat.warnAt", 60)
frame:Refresh()
assert(frame.threat.warning == 0, "warnings switched off show no warning")
K.Options.Write("Meters", "damage.shown", false)
frame:Refresh()
assert(not frame.damage.holder:IsShown(), "a meter switched off leaves the preview")
K.Options.Write("Meters", "damage.meter", "Hps")
K.Options.Write("Meters", "damage.shown", true)
frame:Refresh()
assert(Text(frame.damage.title) == "HEALING PER SECOND", "the sample follows the chosen meter")
K.Options.Write("Meters", "damage.fontSize", 14)
frame:Refresh()
local font = M.Last(frame.damage.rows[1].name, "SetFont")
assert(font[2] == 14 * K.Theme.FontScale(), "the text size reaches the rows")
K.Options.Write("Meters", "damage.outline", "OUTLINE")
frame:Refresh()
font = M.Last(frame.damage.rows[1].name, "SetFont")
assert(font[3] == "OUTLINE", "the outline reaches the rows")

-- The settings window opens on the Meters page and builds the preview.
local opened = K.Options.Open("Meters")
env.RunTimers()
assert(opened ~= false, "the settings window opens on the Meters page")
assert(#env._errors == 0, "no Lua error: " .. tostring(env._errors[1]))

print("meters preview ok")
