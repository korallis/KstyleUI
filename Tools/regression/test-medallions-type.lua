-- test-medallions-type.lua: under the Medallions HUD style the number, time and timer roles draw in Barlow Semi Condensed SemiBold and the world role in its Bold (KSTY-110, Lee's ruling of 2026-11-16), every other role keeps its type set, a per-role choice still wins, text already on screen follows a style switch, and Frames and Orbs keep their faces.
local W = dofile("Tools/regression/widget_env.lua")

local function file(path)
	return (path:match("([^\\/]+)$"))
end

local ROLES = { "display", "heading", "title", "caps", "names", "unit", "body", "prose", "caption", "number", "time", "timer", "world" }
local BARLOW = { number = "BarlowSemiCondensedTabular-SemiBold.ttf", time = "BarlowSemiCondensedTabular-SemiBold.ttf", timer = "BarlowSemiCondensedTabular-SemiBold.ttf", world = "BarlowSemiCondensedTabular-Bold.ttf" }

local env, K = W.New()
local frames = {}
for _, role in ipairs(ROLES) do
	frames[role] = { K.Tokens.Font(role) }
	assert(not file(frames[role][1]):find("Barlow", 1, true), "Frames draws " .. role .. " in its type set, not Barlow")
end
local parent = env.CreateFrame("Frame", nil, env.UIParent)
local health = K.Widgets.Text(parent, "number")
local label = K.Widgets.Text(parent, "body")
assert(file((health:GetFont())) == file(frames.number[1]), "a number on screen starts in the type set's face")

env.RunTimers()
for _, role in ipairs(ROLES) do
	local path, size, flags = K.Tokens.Font(role)
	if BARLOW[role] then
		assert(file(path) == BARLOW[role], "Medallions draws " .. role .. " in " .. BARLOW[role] .. ", got " .. file(path))
	else
		assert(path == frames[role][1], "Medallions keeps " .. role .. "'s face")
	end
	assert(size == frames[role][2] and flags == frames[role][3], role .. " keeps its size and flags")
end
assert(K.Tokens.FontPath("BarlowSemiBold") == (K.Tokens.Font("number")), "the face key names the same file")
assert(file((health:GetFont())) == BARLOW.number, "a number already on screen turns to Barlow")
assert(file((label:GetFont())) == file(frames.body[1]), "body text already on screen keeps its face")

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

for _, style in ipairs({ "orbs", "frames" }) do
	env.RunTimers()
	for _, role in ipairs(ROLES) do
		local path, size, flags = K.Tokens.Font(role)
		assert(path == frames[role][1] and size == frames[role][2] and flags == frames[role][3], style .. " draws " .. role .. " as before Medallions")
	end
	assert(file((health:GetFont())) == file(frames.number[1]), style .. ": the number on screen returns to the type set's face")
end
assert(#env._errors == 0, tostring(env._errors[1]))
assert(K.ErrorCount() == 0, "no addon error")
print("ok - test-medallions-type")
