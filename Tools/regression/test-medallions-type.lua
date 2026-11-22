-- test-medallions-type.lua: under the Medallions HUD style the number, time and timer roles draw in Barlow Semi Condensed SemiBold and the world role in its Bold (KSTY-110, Lee's ruling of 2026-11-16), every other role keeps its type set, a per-role choice still wins, text already on screen follows a style switch, and Frames and Orbs keep their faces.
local W = dofile("Tools/regression/widget_env.lua")

local function file(path)
	return (path:match("([^\\/]+)$"))
end

local ROLES = { "display", "heading", "title", "caps", "names", "unit", "body", "prose", "caption", "number", "time", "timer", "world" }
local BARLOW = { number = "BarlowSemiCondensedTabular-SemiBold.ttf", time = "BarlowSemiCondensedTabular-SemiBold.ttf", timer = "BarlowSemiCondensedTabular-SemiBold.ttf", world = "BarlowSemiCondensedTabular-Bold.ttf" }

local env, K = W.New()
local parent = env.CreateFrame("Frame", nil, env.UIParent)
local health = K.Widgets.Text(parent, "number")
local label = K.Widgets.Text(parent, "body")
env.RunTimers()
for _, role in ipairs(ROLES) do
	local path = K.Tokens.Font(role)
	if BARLOW[role] then
		assert(file(path) == BARLOW[role], "Medallions draws " .. role .. " in " .. BARLOW[role] .. ", got " .. file(path))
	else
		assert(not file(path):find("Barlow", 1, true), "Medallions keeps " .. role .. " in its type set")
	end
end
assert(K.Tokens.FontPath("BarlowSemiBold") == (K.Tokens.Font("number")), "the face key names the same file")
assert(file((health:GetFont())) == BARLOW.number, "a number on screen is Barlow")
assert(file((label:GetFont())) == file((K.Tokens.Font("body"))), "body text on screen keeps its type set's face")

assert(K.Theme.SetRoleFonts({ number = "InterSemiBold" }))
assert(file((K.Tokens.Font("number"))) == "Inter-SemiBold.ttf", "a per-role choice beats the style's face")
assert(file((K.Tokens.Font("time"))) == BARLOW.time, "and leaves the other number roles in Barlow")
K.Theme.SetRoleFonts({})

K.Options.Write("Appearance", "typeSet", "Lumen")
env.RunTimers()
assert(file((K.Tokens.Font("number"))) == BARLOW.number, "Lumen's numbers are Barlow under Medallions too")
assert(file((K.Tokens.Font("body"))) == "AlegreyaSansTabular-Regular.ttf", "Lumen's body stays Lumen")
K.Options.Write("Appearance", "typeSet", "Folio")
env.RunTimers()

assert(#env._errors == 0, tostring(env._errors[1]))
assert(K.ErrorCount() == 0, "no addon error")
print("ok - test-medallions-type")
