-- test-unitframes-crest-display.lua: display changes refresh the fan default without changing a saved position or scale.
local U = dofile("Tools/regression/unitframes_env.lua")
local width, height = 1920, 1080
local env, K, ns = U.New({ width = width, height = height, uiScale = 768 / 1080, before = function(game, core)
	game.GetPhysicalScreenSize = function() return width, height end
	core.Store.Module("UnitFrames").auraLayout = "fan"
end })
local key = ns.Fan.KEY
local narrow = K.Layout.Get(key).y
width, height = 5120, 1440
env.FireEvent("DISPLAY_SIZE_CHANGED")
env.RunTimers()
local wide = K.Layout.Get(key).y
assert(narrow ~= wide, "recompute the crest fan default from the current display aspect")
local defaults = K.Layout.Element(key).default
assert(wide == defaults.y and K.Scale.Aspect() ~= "16:9", "the fan follows the new layout class")
K.Layout.Set(key, "x", 60)
K.Layout.Set(key, "y", 380)
K.Layout.Set(key, "scale", 0.7)
width, height = 1920, 1080
env.FireEvent("DISPLAY_SIZE_CHANGED")
env.RunTimers()
local saved = K.Layout.Get(key)
assert(saved.x == 60 and saved.y == 380 and saved.scale == 0.7, "display changes preserve the player's whole position and scale")
assert(K.Layout.Element(key).default.y == narrow, "the narrow default is recalculated even for a moved fan")
K.Layout.Reset(key)
assert(K.Layout.Get(key).y == narrow and K.Layout.Get(key).scale == 1, "Reset uses the new display default and the original scale")
assert(#env._errors == 0 and K.ErrorCount() == 0, "display changes have no Lua errors")
print("ok crest display defaults")
