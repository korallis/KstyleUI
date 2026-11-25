-- The readability audit requires six simultaneous unmergeable hits to follow distinct paths.
local CT = dofile("Tools/regression/combattext_env.lua")
local env, K, ns = CT.New()
CT.Enable(env, K)
K.Options.Write("CombatText", "direction", "down")
local emitter = ns.Module.fieldEmitter
for _, amount in ipairs({ 1274, 2431, 438, 864, 980, 1420 }) do
	CT.Hit(env, "player", "WOUND", "", env.Secret(amount), 1)
end
assert(#emitter.active == 6, "all six secret hits remain visible")
local seen = {}
for i, number in ipairs(emitter.active) do
	local _, _, _, x, y = number.frame:GetPoint(1)
	local key = x .. "," .. y
	print("hit", i, key)
	assert(not seen[key], "two simultaneous hits share the origin " .. key)
	seen[key] = true
end
