-- test-unitframes-name-fit.lua: a unit name that does not fit its line drops to the body size before it truncates, and a name that fits keeps the frame's own size (round 3: Opus #7, Muse #1, Fable R3-9: the focus card cut "ELUNARA FR..." with room to spare). Text is measured with the kit fonts' real advances.
local U = dofile("Tools/regression/unitframes_env.lua")
local D = dofile("Tools/regression/databars_env.lua")

local env, K, ns = U.New()
env._textWidth = D.TextWidth
local Frames, Settings = ns.Frames, ns.Settings

local function size(text)
	local _, s = text:GetFont()
	return s
end

local focus = Frames.Get("focus").views[1]
local _, full = Settings.Font("focus", "name")
local _, bodySize = K.Tokens.Font("body")
local body = bodySize
assert(body < full, "the focus name's own size is larger than the body size")

U.SetUnit(env, "focus", { name = "Elunara", level = 39, health = 300, healthMax = 400, reaction = 2, canAttack = true })
env.FireEvent("PLAYER_FOCUS_CHANGED")
assert(math.abs(size(focus.name) - full) < 0.01, "a short name keeps the frame's own size")
assert(not focus.name:IsTruncated(), "and shows whole")

U.SetUnit(env, "focus", { name = "Elunara Frostweaver", level = 39, health = 300, healthMax = 400, reaction = 2, canAttack = true })
env.FireEvent("UNIT_NAME_UPDATE", "focus")
assert(math.abs(size(focus.name) - body) < 0.01, "a long name drops to the body size: " .. tostring(size(focus.name)))
assert(not focus.name:IsTruncated(), "and then shows whole: " .. tostring(focus.name:GetUnboundedStringWidth()) .. " in " .. tostring(focus.name:GetWidth()))

U.SetUnit(env, "focus", { name = "Elunara", level = 39, health = 300, healthMax = 400, reaction = 2, canAttack = true })
env.FireEvent("UNIT_NAME_UPDATE", "focus")
assert(math.abs(size(focus.name) - full) < 0.01, "a short name again takes the frame's own size back")

-- A name too long even at the body size still truncates at the body size; nothing shrinks further.
U.SetUnit(env, "focus", { name = "Elunara Frostweaver the Everlasting Moonshadow", level = 39, health = 300, healthMax = 400, reaction = 2, canAttack = true })
env.FireEvent("UNIT_NAME_UPDATE", "focus")
assert(math.abs(size(focus.name) - body) < 0.01, "a very long name stops at the body size")

assert(#env._errors == 0, tostring(env._errors[1]))
assert(K.ErrorCount() == 0, "no errors caught by KstyleUI.Call")
print("unitframes name fit ok")
