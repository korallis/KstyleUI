-- test-widgets-restyle-forbidden.lua: a scoped restyle stops at a forbidden or access-restricted frame (an aura tile on a locked nameplate or while auras are secret) instead of raising the client's forbidden-object error, and still restyles widgets under the scaled root.
local U = dofile("Tools/regression/unitframes_env.lua")
local env, K = U.New({ enabled = false })
local Widgets = K.Widgets
local root = K.Scale.Root()

local locked = env.CreateFrame("Frame", nil, env.UIParent)
rawset(locked, "IsForbidden", function() return true end)
rawset(locked, "GetParent", function() error("calling 'GetParent' on bad self (Attempt to access forbidden object from code tainted by an AddOn)", 2) end)
-- An aura tile under access restrictions is not forbidden, yet every method but CanBeAccessedInContext raises.
local restricted = env.CreateFrame("Frame", nil, env.UIParent)
restricted._denied = true
local restyled = { locked = 0, mine = 0 }
Widgets.Track({ frame = locked, Restyle = function() restyled.locked = restyled.locked + 1 end })
Widgets.Track({ frame = restricted, Restyle = function() restyled.locked = restyled.locked + 1 end })
local mine = env.CreateFrame("Frame", nil, root)
Widgets.Track({ frame = mine, Restyle = function() restyled.mine = restyled.mine + 1 end })

Widgets.RestyleUnder({ [root] = true })
assert(restyled.locked == 0, "a widget on a forbidden or access-restricted frame is not under the scaled root")
assert(restyled.mine == 1, "a widget under the scaled root still restyles")
assert(#env._errors == 0 and K.ErrorCount() == 0, tostring(env._errors[1]))
print("ok scoped restyle skips forbidden frames")
