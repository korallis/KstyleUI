-- test-unitframes-column-keep.lua: a column frame's portrait and side auras stand outside its element, so a saved position that would put them off screen is shifted back on, out of combat only.
local U = dofile("Tools/regression/unitframes_env.lua")

local env, K, ns = U.New()
local Layout, Geometry, Frames, Settings = K.Layout, ns.Geometry, ns.Frames, ns.Settings

local function noErrors(where)
	assert(#env._errors == 0, where .. ": " .. tostring(env._errors[1]))
	assert(K.ErrorCount() == 0, where .. ": KstyleUI caught an error")
end

local function near(a, b, eps)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (eps or 0.5)
end

local rootW = Layout.RootSize()
local PLAYER, TARGET = "unitframes.player", "unitframes.target"
local playerLeft, targetRight = Geometry.Reach(Settings.Snapshot("player")), select(2, Geometry.Reach(Settings.Snapshot("target")))
assert(near(playerLeft, 91.5), "the player reaches 91.5 left of its element")
assert(near(targetRight, 14 + 77.5 + 16.5 + 4 * 27.6 + 3 * 4), "the target reaches its portrait and four 27.6-unit debuffs to the right, got " .. targetRight)

local function PutLeft(key, left)
	local was = Layout.Rect(key)
	assert(Layout.Set(key, "x", Layout.Get(key).x + (left - was)), "Layout takes the position")
end

PutLeft(PLAYER, 20)
env.RunTimers()
local left, _, w = Layout.Rect(PLAYER)
assert(near(left, playerLeft, 1), "a player saved 20 units from the screen's left edge is moved so its portrait is on screen: left " .. left)
assert(Layout.Get(PLAYER).x == Layout.Get(PLAYER).x and left - playerLeft >= -1, "and no further")
assert(w == 491, "its size is unchanged")
local settled = Layout.Get(PLAYER).x
Frames.Relayout(Frames.Get("player"))
env.RunTimers()
assert(Layout.Get(PLAYER).x == settled, "a position that already clears the edge is left alone")
PutLeft(PLAYER, 300)
env.RunTimers()
assert(near(Layout.Rect(PLAYER), 300), "a centred player is not moved")

local _, _, tw = Layout.Rect(TARGET)
PutLeft(TARGET, rootW - tw - 30)
env.RunTimers()
local tl = Layout.Rect(TARGET)
assert(near(tl + tw + targetRight, rootW, 1), "a target saved 30 units from the right edge is moved so its debuffs end at the edge: " .. tl)
PutLeft(TARGET, 500)
env.RunTimers()
assert(near(Layout.Rect(TARGET), 500), "a target with room to spare is not moved")

K.Options.Write("UnitFrames", "target.auras", false)
local reachOff = select(2, Geometry.Reach(Settings.Snapshot("target")))
assert(near(reachOff, 14 + 77.5), "with the debuffs off the target reaches only its portrait")
PutLeft(TARGET, rootW - tw - 100)
env.RunTimers()
assert(near(Layout.Rect(TARGET), rootW - tw - 100), "which still fits at 100 units from the edge")
K.Options.Write("UnitFrames", "target.auras", true)

assert(Layout.Set(PLAYER, "scale", 1.5) == false, "these elements cannot be scaled, so a reach is always in root units")
PutLeft(PLAYER, 300)
env.RunTimers()

local before = Layout.Get(PLAYER).x
env.SetCombat(true)
PutLeft(PLAYER, 20)
env.RunTimers()
local inCombat = Layout.Get(PLAYER).x
assert(near(Layout.Rect(PLAYER), 20), "in combat the saved position stays where it was put")
assert(inCombat ~= before, "the move itself was written")
env.SetCombat(false)
env.RunTimers()
assert(near(Layout.Rect(PLAYER), playerLeft, 1), "the shift runs when combat ends")
local after = Layout.Get(PLAYER).x
env.RunTimers()
assert(Layout.Get(PLAYER).x == after, "and runs once")
noErrors("keep")
