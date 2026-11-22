-- test-ornament-aura-safety.lua: tracked ornament callbacks never read visibility from engine aura descendants.
local A = dofile("Tools/regression/auras_env.lua")
local env, K = A.New({ layout = true })
K.Modules.Enable("Auras")
env.RunTimers()
local buffs = A.Container(env, "HELPFUL")
local buttons = A.Buttons(buffs)
assert(#buttons > 0, "engine aura buttons exist")
local guarded = 0
for _, button in ipairs(buttons) do
	for _, object in ipairs(A.Descendants(button)) do
		object.IsShown = function() error("read IsShown inside engine aura button") end
		object.IsVisible = function() error("read IsVisible inside engine aura button") end
		guarded = guarded + 1
	end
end
assert(guarded > #buttons, "engine aura descendants were guarded")
local errors = #env._errors
env._aurasSecret = true
K.Options.Write("Widgets", "ornaments", "Full")
K.Callbacks.Fire("ThemeChanged")
K.Callbacks.Fire("ScaleChanged")
K.Callbacks.Fire("ProfileChanged", "Default", "Default")
K.Widgets.RestyleAll()
assert(#env._errors == errors, "callbacks must not read engine aura visibility: " .. tostring(env._errors[errors + 1]))
print("ok ornament callbacks avoid engine aura visibility reads")
