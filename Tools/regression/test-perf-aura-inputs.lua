-- test-perf-aura-inputs.lua: unchanged group aura inputs do no font work, while settings, scale and theme changes still restyle.
local G = dofile("Tools/regression/group_env.lua")
local A = dofile("Tools/regression/auras_env.lua")
local env, K, ns = G.New()
G.SetRoster(env, "party", G.Members(2))
K.Modules.Enable("GroupFrames")
env.RunTimers()
local f = ns.Button.Content(ns.Headers.party:GetAttribute("child1"))
A.Assign(env, f.auras, "debuffs", 1)
env.RunTimers()
local fonts, real = 0, ns.Style.SetFont
ns.Style.SetFont = function(...)
	fonts = fonts + 1
	return real(...)
end
ns.Auras.Restyle(f)
assert(fonts == 0, "P5c: skip aura groups whose geometry, font, swipe, accent and priority inputs did not change")
K.Options.Write("GroupFrames", "party.auraSize", 24)
assert(fonts > 0, "P5c: changed aura geometry must still restyle every required engine button before restrictions")
local before = fonts
K.Callbacks.Fire("ThemeChanged")
assert(fonts > before, "P5c: a font-role or colour theme change must invalidate aura inputs")
before = fonts
K.Callbacks.Fire("ScaleChanged")
assert(fonts > before, "P5c: a physical pixel or font floor change must invalidate aura inputs")
env._aurasSecret = true
K.Options.Write("GroupFrames", "party.auraSize", 18)
assert(#env._errors == 0, "P5c: never inspect or mutate restricted aura buttons to check cached inputs")
env._aurasSecret = false
env.RunTimers()
assert(#env._errors == 0, table.concat(env._errors, "\n"))
print("perf aura inputs ok")
